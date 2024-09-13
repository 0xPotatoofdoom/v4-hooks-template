// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

// Chainlink Imports
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

// EigenLayer Interface (mock)
interface IEigenLayerStrategy {
    function processOffChainComputation(bytes calldata _input) external returns (bytes memory);
}

// Brevis Interface (mock)
interface IBrevisVerifier {
    function verifyProof(bytes calldata _proof, uint256[] calldata _publicInputs) external view returns (bool);
}

/// @title RugGuard
/// @notice A contract to protect against rug pulls in Uniswap V4 pools with integrations
contract RugGuard is BaseHook, Ownable, ReentrancyGuard, AutomationCompatibleInterface {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    struct PoolInfo {
        uint256 lastLiquidityChangeTimestamp;
        uint256 liquidityChangeThreshold;
        uint256 totalLiquidity;
        uint256 riskScore;
        uint256 totalVolume24h;
        uint256 lastVolumeUpdateTimestamp;
        int256 lastPrice;
    }

    mapping(PoolId => PoolInfo) public poolInfo;

    uint256 public constant DEFAULT_LIQUIDITY_CHANGE_THRESHOLD = 10 ether;
    uint256 public constant COOLDOWN_PERIOD = 1 days;
    uint256 public constant MAX_RISK_SCORE = 100;
    uint256 public constant MIN_LIQUIDITY_THRESHOLD = 1 ether;

    // Chainlink price feed
    mapping(address => AggregatorV3Interface) public priceFeeds;

    // EigenLayer strategy contract
    IEigenLayerStrategy public eigenLayerStrategy;

    // Brevis verifier contract
    IBrevisVerifier public brevisVerifier;

    event LiquidityChanged(PoolId indexed poolId, int256 liquidityDelta, uint256 newTotalLiquidity);
    event RiskScoreUpdated(PoolId indexed poolId, uint256 newRiskScore);
    event ThresholdUpdated(PoolId indexed poolId, uint256 newThreshold);
    event SwapExecuted(PoolId indexed poolId, address indexed trader, uint256 amountIn, uint256 amountOut);
    event PotentialRugPullDetected(PoolId indexed poolId, uint256 riskScore);
    event OffChainComputationProcessed(PoolId indexed poolId, bytes result);
    event ProofVerified(PoolId indexed poolId, bool verified);

    constructor(
        IPoolManager _poolManager,
        IEigenLayerStrategy _eigenLayerStrategy,
        IBrevisVerifier _brevisVerifier
    ) BaseHook(_poolManager) Ownable(msg.sender) {
        eigenLayerStrategy = _eigenLayerStrategy;
        brevisVerifier = _brevisVerifier;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function afterInitialize(address, PoolKey calldata key, uint160, int24, bytes calldata)
        external
        override
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        poolInfo[poolId] = PoolInfo({
            lastLiquidityChangeTimestamp: block.timestamp,
            liquidityChangeThreshold: DEFAULT_LIQUIDITY_CHANGE_THRESHOLD,
            totalLiquidity: 0,
            riskScore: 50,
            totalVolume24h: 0,
            lastVolumeUpdateTimestamp: block.timestamp,
            lastPrice: 0
        });
        return BaseHook.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes calldata
    ) external override returns (bytes4) {
        return _handleLiquidityChange(key, params.liquidityDelta);
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes calldata
    ) external override returns (bytes4) {
        return _handleLiquidityChange(key, -params.liquidityDelta);
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        PoolInfo storage pool = poolInfo[poolId];

        require(pool.riskScore < MAX_RISK_SCORE, "RugGuard: Pool risk too high for swaps");
        require(pool.totalLiquidity >= MIN_LIQUIDITY_THRESHOLD, "RugGuard: Insufficient liquidity");

        updateVolume(poolId, params.amountIn);
        updatePrice(poolId, key.currency0, key.currency1);

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, BalanceDelta delta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
        PoolId poolId = key.toId();
        emit SwapExecuted(poolId, msg.sender, uint256(params.amountIn), uint256(uint128(-delta.amount1())));
        
        // Trigger off-chain computation via EigenLayer
        bytes memory computationInput = abi.encode(poolId, params.amountIn, uint256(uint128(-delta.amount1())));
        bytes memory result = eigenLayerStrategy.processOffChainComputation(computationInput);
        emit OffChainComputationProcessed(poolId, result);

        return (BaseHook.afterSwap.selector, 0);
    }

    function _handleLiquidityChange(PoolKey calldata key, int256 liquidityDelta) internal returns (bytes4) {
        PoolId poolId = key.toId();
        PoolInfo storage pool = poolInfo[poolId];

        if (block.timestamp < pool.lastLiquidityChangeTimestamp + COOLDOWN_PERIOD) {
            require(
                uint256(liquidityDelta > 0 ? liquidityDelta : -liquidityDelta) <= pool.liquidityChangeThreshold,
                "RugGuard: Liquidity change exceeds threshold"
            );
        }

        updatePoolInfo(poolId, liquidityDelta);

        return liquidityDelta > 0 ? this.beforeAddLiquidity.selector : this.beforeRemoveLiquidity.selector;
    }

    function updatePoolInfo(PoolId poolId, int256 liquidityDelta) internal {
        PoolInfo storage pool = poolInfo[poolId];

        uint256 oldLiquidity = pool.totalLiquidity;
        pool.totalLiquidity = uint256(int256(pool.totalLiquidity) + liquidityDelta);
        pool.lastLiquidityChangeTimestamp = block.timestamp;

        updateRiskScore(poolId, oldLiquidity, liquidityDelta);

        emit LiquidityChanged(poolId, liquidityDelta, pool.totalLiquidity);
        emit RiskScoreUpdated(poolId, pool.riskScore);
    }

    function updateRiskScore(PoolId poolId, uint256 oldLiquidity, int256 liquidityDelta) internal {
        PoolInfo storage pool = poolInfo[poolId];

        uint256 liquidityChangePercentage = oldLiquidity > 0 
            ? (uint256(liquidityDelta > 0 ? liquidityDelta : -liquidityDelta) * 100) / oldLiquidity 
            : 100;

        if (liquidityDelta < 0 && liquidityChangePercentage > 10) {
            pool.riskScore = min(pool.riskScore + uint256(liquidityChangePercentage), MAX_RISK_SCORE);
        } else if (liquidityDelta > 0) {
            pool.riskScore = pool.riskScore > 5 ? pool.riskScore - 5 : 0;
        }

        if (pool.totalVolume24h > 0 && pool.totalLiquidity > 0) {
            uint256 volumeToLiquidityRatio = (pool.totalVolume24h * 100) / pool.totalLiquidity;
            if (volumeToLiquidityRatio > 50) {
                pool.riskScore = min(pool.riskScore + 10, MAX_RISK_SCORE);
            } else if (volumeToLiquidityRatio < 10) {
                pool.riskScore = pool.riskScore > 10 ? pool.riskScore - 10 : 0;
            }
        }

        if (pool.riskScore > 80) {
            emit PotentialRugPullDetected(poolId, pool.riskScore);
        }
    }

    function updateVolume(PoolId poolId, uint256 amountIn) internal {
        PoolInfo storage pool = poolInfo[poolId];

        if (block.timestamp >= pool.lastVolumeUpdateTimestamp + 1 days) {
            pool.totalVolume24h = amountIn;
        } else {
            pool.totalVolume24h += amountIn;
        }

        pool.lastVolumeUpdateTimestamp = block.timestamp;
    }

    // Chainlink integration: Update price feed
    function updatePrice(PoolId poolId, address token0, address token1) internal {
        AggregatorV3Interface priceFeed0 = priceFeeds[token0];
        AggregatorV3Interface priceFeed1 = priceFeeds[token1];

        if (address(priceFeed0) != address(0) && address(priceFeed1) != address(0)) {
            (, int256 price0,,,) = priceFeed0.latestRoundData();
            (, int256 price1,,,) = priceFeed1.latestRoundData();

            if (price0 > 0 && price1 > 0) {
                int256 newPrice = (price0 * 1e18) / price1;
                poolInfo[poolId].lastPrice = newPrice;
            }
        }
    }

    function setLiquidityChangeThreshold(PoolKey calldata key, uint256 newThreshold) external onlyOwner {
        PoolId poolId = key.toId();
        poolInfo[poolId].liquidityChangeThreshold = newThreshold;
        emit ThresholdUpdated(poolId, newThreshold);
    }

    // Chainlink Automation compatible function
    function checkUpkeep(bytes calldata checkData) 
        external 
        view 
        override 
        returns (bool upkeepNeeded, bytes memory performData) 
    {
        PoolId poolId = abi.decode(checkData, (PoolId));
        PoolInfo storage pool = poolInfo[poolId];

        upkeepNeeded = (block.timestamp >= pool.lastVolumeUpdateTimestamp + 1 days) ||
                       (pool.riskScore > 80);

        performData = checkData;
    }

    function performUpkeep(bytes calldata performData) external override {
        PoolId poolId = abi.decode(performData, (PoolId));
        PoolInfo storage pool = poolInfo[poolId];

        if (block.timestamp >= pool.lastVolumeUpdateTimestamp + 1 days) {
            pool.totalVolume24h = 0;
            pool.lastVolumeUpdateTimestamp = block.timestamp;
        }

        if (pool.riskScore > 80) {
            // Trigger additional checks or actions for high-risk pools
            emit PotentialRugPullDetected(poolId, pool.riskScore);
        }
    }

    // Brevis integration: Verify zkSNARK proof
    function verifyBrevisProof(bytes calldata _proof, uint256[] calldata _publicInputs) external {
        bool verified = brevisVerifier.verifyProof(_proof, _publicInputs);
        PoolId poolId = PoolId.wrap(bytes32(_publicInputs[0]));
        emit ProofVerified(poolId, verified);

        if (verified) {
            // Update pool info based on verified proof
            // This could include updating risk scores or other metrics
            PoolInfo storage pool = poolInfo[poolId];
            pool.riskScore = _publicInputs[1];
            emit RiskScoreUpdated(poolId, pool.riskScore);
        }
    }

    function setPriceFeed(address token, address priceFeed) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(priceFeed);
    }

    function setEigenLayerStrategy(IEigenLayerStrategy _eigenLayerStrategy) external onlyOwner {
        eigenLayerStrategy = _eigenLayerStrategy;
    }

    function setBrevisVerifier(IBrevisVerifier _brevisVerifier) external onlyOwner {
        brevisVerifier = _brevisVerifier;
    }

    function withdrawToken(address token, uint256 amount) external onlyOwner nonReentrant {
        IERC20(token).safeTransfer(owner(), amount);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    // Fallback function is called when msg.data is not empty
    fallback() external payable {}

    // Function to withdraw Ether from this contract
    function withdrawEther() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No Ether left to withdraw");
        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed.");
    }
}