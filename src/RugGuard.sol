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
import {Currency} from "v4-core/src/types/Currency.sol";

// Chainlink Imports
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

import {IBrevisVerifier} from "./interfaces/IBrevisVerifier.sol";
import {IEigenLayerStrategy} from "./interfaces/IEigenLayerStrategy.sol";

/**
 * @title RugGuard
 * @author rakshithvk19 and 0xPotatoofdoom
 * @notice A contract to protect against rug pulls in Uniswap V4 pools with integrations
 * @dev Implements BaseHook, Ownable, ReentrancyGuard, and AutomationCompatibleInterface
 */
contract RugGuard is BaseHook, Ownable, ReentrancyGuard, AutomationCompatibleInterface {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    /**
     * @notice Struct to store information about each pool
     * @param lastLiquidityChangeTimestamp Timestamp of the last liquidity change
     * @param liquidityChangeThreshold Maximum allowed liquidity change
     * @param totalLiquidity Total liquidity in the pool
     * @param riskScore Current risk score of the pool
     * @param totalVolume24h Total trading volume in the last 24 hours
     * @param lastVolumeUpdateTimestamp Timestamp of the last volume update
     * @param lastPrice Last recorded price in the pool
     */
    struct PoolInfo {
        uint256 lastLiquidityChangeTimestamp;
        uint256 liquidityChangeThreshold;
        uint256 totalLiquidity;
        uint256 riskScore;
        uint256 totalVolume24h;
        uint256 lastVolumeUpdateTimestamp;
        int256 lastPrice;
    }

    /// @notice Mapping of pool IDs to their respective PoolInfo
    mapping(PoolId => PoolInfo) public poolInfo;

    /// @notice Default threshold for liquidity changes
    uint256 public constant DEFAULT_LIQUIDITY_CHANGE_THRESHOLD = 10 ether;

    /// @notice Cooldown period between significant liquidity changes
    uint256 public constant COOLDOWN_PERIOD = 1 days;

    /// @notice Maximum risk score a pool can have
    uint256 public constant MAX_RISK_SCORE = 100;

    /// @notice Minimum liquidity threshold for a pool
    uint256 public constant MIN_LIQUIDITY_THRESHOLD = 1 ether;

    /// @notice Mapping of token addresses to their respective Chainlink price feeds
    mapping(address => AggregatorV3Interface) public priceFeeds;

    /// @notice EigenLayer strategy contract
    IEigenLayerStrategy public eigenLayerStrategy;

    /// @notice Brevis verifier contract
    IBrevisVerifier public brevisVerifier;

    /**
     * @notice Emitted when liquidity changes in a pool
     * @param poolId The ID of the pool
     * @param liquidityDelta The change in liquidity
     * @param newTotalLiquidity The new total liquidity after the change
     */
    event LiquidityChanged(PoolId indexed poolId, int256 liquidityDelta, uint256 newTotalLiquidity);

    /**
     * @notice Emitted when a pool's risk score is updated
     * @param poolId The ID of the pool
     * @param newRiskScore The new risk score
     */
    event RiskScoreUpdated(PoolId indexed poolId, uint256 newRiskScore);

    /**
     * @notice Emitted when a pool's liquidity change threshold is updated
     * @param poolId The ID of the pool
     * @param newThreshold The new threshold value
     */
    event ThresholdUpdated(PoolId indexed poolId, uint256 newThreshold);

    /**
     * @notice Emitted when a swap is executed in a pool
     * @param poolId The ID of the pool
     * @param trader The address of the trader
     * @param amountIn The amount of tokens swapped in
     * @param amountOut The amount of tokens received
     */
    event SwapExecuted(PoolId indexed poolId, address indexed trader, uint256 amountIn, uint256 amountOut);

    /**
     * @notice Emitted when a potential rug pull is detected
     * @param poolId The ID of the pool
     * @param riskScore The current risk score of the pool
     */
    event PotentialRugPullDetected(PoolId indexed poolId, uint256 riskScore);

    /**
     * @notice Emitted when off-chain computation is processed
     * @param poolId The ID of the pool
     * @param result The result of the off-chain computation
     */
    event OffChainComputationProcessed(PoolId indexed poolId, bytes result);

    /**
     * @notice Emitted when a proof is verified
     * @param poolId The ID of the pool
     * @param verified Whether the proof was verified successfully
     */
    event ProofVerified(PoolId indexed poolId, bool verified);

    /**
     * @notice Constructor for the RugGuard contract
     * @param _poolManager The address of the Uniswap V4 pool manager
     * @param _eigenLayerStrategy The address of the EigenLayer strategy contract
     * @param _brevisVerifier The address of the Brevis verifier contract
     */
    constructor(IPoolManager _poolManager, IEigenLayerStrategy _eigenLayerStrategy, IBrevisVerifier _brevisVerifier)
        BaseHook(_poolManager)
        Ownable(msg.sender)
    {
        eigenLayerStrategy = _eigenLayerStrategy;
        brevisVerifier = _brevisVerifier;
    }

    /**
     * @notice Returns the hook's permissions
     * @return Hooks.Permissions The permissions of the hook
     */
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

    /**
     * @notice Hook called after a pool is initialized
     * @param key The pool key
     * @return The function selector
     */
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

        return this.afterInitialize.selector;
    }

    /**
     * @notice Hook called before liquidity is added to a pool
     * @param key The pool key
     * @param params The liquidity parameters
     * @return The function selector
     */
    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes calldata
    ) external override returns (bytes4) {
        return BaseHook.beforeAddLiquidity.selector;
    }

    /**
     * @notice Hook called after liquidity is added to a pool
     * @param key The pool key
     * @param params The liquidity parameters
     * @param delta The balance delta
     * @return The function selector and balance delta
     */
    function afterAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams memory params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        PoolId poolId = key.toId();
        updatePoolInfo(poolId, params.liquidityDelta);
        return (BaseHook.afterAddLiquidity.selector, delta);
    }

    /**
     * @notice Hook called before liquidity is removed from a pool
     * @param key The pool key
     * @param params The liquidity parameters
     * @return The function selector
     */
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes calldata
    ) external override returns (bytes4) {
        _handleLiquidityChange(key, params.liquidityDelta);
        return this.beforeRemoveLiquidity.selector;
    }

    /**
     * @notice Hook called after liquidity is removed from a pool
     * @param key The pool key
     * @param params The liquidity parameters
     * @param delta The balance delta
     * @return The function selector and balance delta
     */
    function afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams memory params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, BalanceDelta) {
        return (this.afterRemoveLiquidity.selector, delta);
    }

    /**
     * @notice Hook called before a swap is executed
     * @param key The pool key
     * @param params The swap parameters
     * @return The function selector, before swap delta, and fees
     */
    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        PoolInfo storage pool = poolInfo[poolId];

        require(pool.riskScore < MAX_RISK_SCORE, "RugGuard: Pool risk too high for swaps");
        require(pool.totalLiquidity >= MIN_LIQUIDITY_THRESHOLD, "RugGuard: Insufficient liquidity");

        uint256 absAmountSpecified = uint256(params.amountSpecified);

        updateVolume(poolId, absAmountSpecified);

        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        updatePrice(poolId, token0, token1);

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /**
     * @notice Hook called after a swap is executed
     * @param key The pool key
     * @param params The swap parameters
     * @param delta The balance delta
     * @return The function selector and zero value
     */
    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override returns (bytes4, int128) {
        PoolId poolId = key.toId();
        emit SwapExecuted(poolId, msg.sender, uint256(params.amountSpecified), uint256(uint128(-delta.amount1())));

        bytes memory computationInput = abi.encode(poolId, params.amountSpecified, uint256(uint128(-delta.amount1())));
        bytes memory result = eigenLayerStrategy.processOffChainComputation(computationInput);
        emit OffChainComputationProcessed(poolId, result);

        return (BaseHook.afterSwap.selector, 0);
    }

    /**
     * @notice Handles liquidity changes and enforces thresholds
     * @param key The pool key
     * @param liquidityDelta The change in liquidity
     * @return The function selector of the calling function
     */
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

        return msg.sig;
    }

    /**
     * @notice Updates the pool information after a liquidity change
     * @param poolId The ID of the pool
     * @param liquidityDelta The change in liquidity
     */
    function updatePoolInfo(PoolId poolId, int256 liquidityDelta) internal {
        PoolInfo storage pool = poolInfo[poolId];

        uint256 oldLiquidity = pool.totalLiquidity;
        pool.totalLiquidity = uint256(int256(pool.totalLiquidity) + liquidityDelta);
        pool.lastLiquidityChangeTimestamp = block.timestamp;

        updateRiskScore(poolId, oldLiquidity, liquidityDelta);

        emit LiquidityChanged(poolId, liquidityDelta, pool.totalLiquidity);
        emit RiskScoreUpdated(poolId, pool.riskScore);
    }

    /**
     * @notice Updates the risk score of a pool based on liquidity changes and trading volume
     * @param poolId The ID of the pool to update
     * @param oldLiquidity The previous liquidity amount of the pool
     * @param liquidityDelta The change in liquidity (positive for increase, negative for decrease)
     */
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

    /**
     * @notice Updates the 24-hour trading volume of a pool
     * @param poolId The ID of the pool to update
     * @param amountIn The amount of tokens being traded in this transaction
     */
    function updateVolume(PoolId poolId, uint256 amountIn) internal {
        PoolInfo storage pool = poolInfo[poolId];

        if (block.timestamp >= pool.lastVolumeUpdateTimestamp + 1 days) {
            pool.totalVolume24h = amountIn;
        } else {
            pool.totalVolume24h += amountIn;
        }

        pool.lastVolumeUpdateTimestamp = block.timestamp;
    }

    /**
     * @notice Updates the price of a pool using Chainlink price feeds
     * @param poolId The ID of the pool to update
     * @param token0 The address of the first token in the pool
     * @param token1 The address of the second token in the pool
     */
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

    /**
     * @notice Sets the liquidity change threshold for a specific pool
     * @param key The PoolKey struct containing pool information
     * @param newThreshold The new threshold value to set
     */
    function setLiquidityChangeThreshold(PoolKey calldata key, uint256 newThreshold) external onlyOwner {
        PoolId poolId = key.toId();
        poolInfo[poolId].liquidityChangeThreshold = newThreshold;
        emit ThresholdUpdated(poolId, newThreshold);
    }

    /**
     * @notice Checks if upkeep is needed for a specific pool (Chainlink Automation compatible)
     * @param checkData The encoded pool ID to check
     * @return upkeepNeeded Boolean indicating if upkeep is needed
     * @return performData The same data passed in, to be used in performUpkeep
     */
    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        PoolId poolId = abi.decode(checkData, (PoolId));
        PoolInfo storage pool = poolInfo[poolId];

        upkeepNeeded = (block.timestamp >= pool.lastVolumeUpdateTimestamp + 1 days) || (pool.riskScore > 80);

        performData = checkData;
    }

    /**
     * @notice Performs upkeep for a specific pool (Chainlink Automation compatible)
     * @param performData The encoded pool ID for which to perform upkeep
     */
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

    /**
     * @notice Verifies a Brevis zkSNARK proof and updates pool information if valid
     * @param _proof The zkSNARK proof to verify
     * @param _publicInputs The public inputs for the proof verification
     */
    function verifyBrevisProof(bytes calldata _proof, uint256[] calldata _publicInputs) external {
        bool verified = brevisVerifier.verifyProof(_proof, _publicInputs);
        PoolId poolId = PoolId.wrap(bytes32(_publicInputs[0]));
        emit ProofVerified(poolId, verified);

        if (verified) {
            // Update pool info based on verified proof
            PoolInfo storage pool = poolInfo[poolId];
            pool.riskScore = _publicInputs[1];
            emit RiskScoreUpdated(poolId, pool.riskScore);
        }
    }

    /**
     * @notice Sets the Chainlink price feed for a specific token
     * @param token The address of the token
     * @param priceFeed The address of the Chainlink price feed contract
     */
    function setPriceFeed(address token, address priceFeed) external onlyOwner {
        priceFeeds[token] = AggregatorV3Interface(priceFeed);
    }

    /**
     * @notice Sets the EigenLayer strategy contract
     * @param _eigenLayerStrategy The address of the new EigenLayer strategy contract
     */
    function setEigenLayerStrategy(IEigenLayerStrategy _eigenLayerStrategy) external onlyOwner {
        eigenLayerStrategy = _eigenLayerStrategy;
    }

    /**
     * @notice Sets the Brevis verifier contract
     * @param _brevisVerifier The address of the new Brevis verifier contract
     */
    function setBrevisVerifier(IBrevisVerifier _brevisVerifier) external onlyOwner {
        brevisVerifier = _brevisVerifier;
    }

    /**
     * @notice Withdraws a specific ERC20 token from the contract
     * @param token The address of the token to withdraw
     * @param amount The amount of tokens to withdraw
     */
    function withdrawToken(address token, uint256 amount) external onlyOwner nonReentrant {
        IERC20(token).safeTransfer(owner(), amount);
    }

    /**
     * @notice Returns the minimum of two uint256 values
     * @param a The first value
     * @param b The second value
     * @return The smaller of the two input values
     */
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @notice Receives Ether sent to the contract
     */
    receive() external payable {}

    /**
     * @notice Fallback function called when msg.data is not empty
     */
    fallback() external payable {}

    /**
     * @notice Withdraws all Ether from the contract to the owner
     */
    function withdrawEther() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No Ether left to withdraw");
        (bool success,) = payable(owner()).call{value: balance}("");
        require(success, "Transfer failed.");
    }
}
