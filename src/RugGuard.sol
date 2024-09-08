// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";

/// @title RugGuard
/// @notice A contract to protect against rug pulls in Uniswap V4 pools
/// @dev Implements BaseHook to integrate with Uniswap V4
contract RugGuard is BaseHook {
    using PoolIdLibrary for PoolKey;

    /// @notice Struct to store information about each pool
    struct PoolInfo {
        uint256 lastLiquidityChangeTimestamp;
        uint256 liquidityChangeThreshold;
        uint256 totalLiquidity;
        uint256 riskScore;
    }

    /// @notice Mapping of pool IDs to their respective PoolInfo
    mapping(PoolId => PoolInfo) public poolInfo;

    /// @notice Default threshold for liquidity changes
    uint256 public constant DEFAULT_LIQUIDITY_CHANGE_THRESHOLD = 10 ether;
    /// @notice Cooldown period between significant liquidity changes
    uint256 public constant COOLDOWN_PERIOD = 1 days;
    /// @notice Maximum risk score a pool can have
    uint256 public constant MAX_RISK_SCORE = 100;

    /// @notice Emitted when liquidity changes in a pool
    event LiquidityChanged(PoolId indexed poolId, int256 liquidityDelta, uint256 newTotalLiquidity);
    /// @notice Emitted when a pool's risk score is updated
    event RiskScoreUpdated(PoolId indexed poolId, uint256 newRiskScore);
    /// @notice Emitted when a pool's liquidity change threshold is updated
    event ThresholdUpdated(PoolId indexed poolId, uint256 newThreshold);

    /// @notice Constructor to initialize the RugGuard contract
    /// @param _poolManager Address of the Uniswap V4 pool manager
    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    /// @notice Defines the hook's permissions
    /// @return Hooks.Permissions struct with the hook's permissions
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true, // Updates the default values for state variables
            beforeAddLiquidity: true, // Checks if we can update liquidity in the pool
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true, // Checks if we can update liquidity in the pool
            afterRemoveLiquidity: false,
            beforeSwap: true, // Checks if the pool conditions enable for swapping tokens
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice Initializes a new pool with default values
    /// @param key The PoolKey for the new pool
    /// @return bytes4 Function selector
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
            riskScore: 50
        });
        return BaseHook.afterInitialize.selector;
    }

    /// @notice Handles liquidity addition
    /// @param key The PoolKey for the pool
    /// @param params Liquidity modification parameters
    /// @return bytes4 Function selector
    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes calldata
    ) external override returns (bytes4) {
        updatePoolInfo(key.toId(), params.liquidityDelta);
        return BaseHook.beforeAddLiquidity.selector;
    }

    /// @notice Handles liquidity removal
    /// @param key The PoolKey for the pool
    /// @param params Liquidity modification parameters
    /// @return bytes4 Function selector
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams memory params,
        bytes calldata
    ) external override returns (bytes4) {
        return _handleLiquidityChange(key, params.liquidityDelta);
    }

    /// @notice Checks if a swap can be executed based on pool risk
    /// @param key The PoolKey for the pool
    /// @return tuple containing function selector, BeforeSwapDelta, and fee
    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        PoolId poolId = key.toId();
        PoolInfo storage pool = poolInfo[poolId];

        require(pool.riskScore < MAX_RISK_SCORE, "RugGuard: Pool risk too high for swaps");

        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    /// @notice Hook called after a swap
    /// @return tuple containing function selector and int128
    function afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4, int128)
    {
        return (BaseHook.afterSwap.selector, 0);
    }

    /// @notice Handles liquidity changes and enforces thresholds
    /// @param key The PoolKey for the pool
    /// @param liquidityDelta The change in liquidity
    /// @return bytes4 Function selector
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

    /// @notice Updates pool information after a liquidity change
    /// @param poolId The ID of the pool
    /// @param liquidityDelta The change in liquidity
    function updatePoolInfo(PoolId poolId, int256 liquidityDelta) internal {
        PoolInfo storage pool = poolInfo[poolId];

        pool.totalLiquidity = uint256(int256(pool.totalLiquidity) + liquidityDelta);
        pool.lastLiquidityChangeTimestamp = block.timestamp;

        if (liquidityDelta < 0) {
            pool.riskScore = min(pool.riskScore + 5, MAX_RISK_SCORE);
        } else {
            pool.riskScore = pool.riskScore > 5 ? pool.riskScore - 5 : 0;
        }

        emit LiquidityChanged(poolId, liquidityDelta, pool.totalLiquidity);
        emit RiskScoreUpdated(poolId, pool.riskScore);
    }

    /// @notice Sets a new liquidity change threshold for a pool
    /// @param key The PoolKey for the pool
    /// @param newThreshold The new threshold value
    function setLiquidityChangeThreshold(PoolKey calldata key, uint256 newThreshold) external {
        PoolId poolId = key.toId();
        poolInfo[poolId].liquidityChangeThreshold = newThreshold;
        emit ThresholdUpdated(poolId, newThreshold);
    }

    /// @notice Returns the minimum of two uint256 values
    /// @param a First value
    /// @param b Second value
    /// @return The minimum of a and b
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}
