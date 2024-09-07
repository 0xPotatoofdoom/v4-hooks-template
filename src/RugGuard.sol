// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";

contract RugGuard is BaseHook {
    using PoolIdLibrary for PoolKey;

    struct PoolInfo {
        uint256 lastLiquidityChangeTimestamp;
        uint256 liquidityChangeThreshold;
        uint256 totalLiquidity;
        uint256 riskScore;
    }

    mapping(PoolId => PoolInfo) public poolInfo;
    
    uint256 public constant DEFAULT_LIQUIDITY_CHANGE_THRESHOLD = 10 ether;
    uint256 public constant COOLDOWN_PERIOD = 1 days;
    uint256 public constant MAX_RISK_SCORE = 100;

    event LiquidityChanged(PoolId indexed poolId, int256 liquidityDelta, uint256 newTotalLiquidity);
    event RiskScoreUpdated(PoolId indexed poolId, uint256 newRiskScore);
    event ThresholdUpdated(PoolId indexed poolId, uint256 newThreshold);

    constructor(IPoolManager _poolManager) BaseHook(_poolManager) {}

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: true,
            beforeModifyPosition: true,
            afterModifyPosition: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
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
            riskScore: 50
        });
        return BaseHook.afterInitialize.selector;
    }

    function beforeModifyPosition(address, PoolKey calldata key, int24 tickLower, int24 tickUpper, int256 liquidityDelta, bytes calldata)
        external
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        PoolInfo storage pool = poolInfo[poolId];
        
        if (block.timestamp < pool.lastLiquidityChangeTimestamp + COOLDOWN_PERIOD) {
            require(
                uint256(liquidityDelta > 0 ? liquidityDelta : -liquidityDelta) <= pool.liquidityChangeThreshold,
                "RugGuard: Liquidity change exceeds threshold"
            );
        }

        updatePoolInfo(poolId, liquidityDelta);

        return this.beforeModifyPosition.selector;
    }

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4)
    {
        PoolId poolId = key.toId();
        PoolInfo storage pool = poolInfo[poolId];

        require(pool.riskScore < MAX_RISK_SCORE, "RugGuard: Pool risk too high for swaps");

        return BaseHook.beforeSwap.selector;
    }

    function afterSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, BalanceDelta, bytes calldata)
        external
        override
        returns (bytes4)
    {
        return BaseHook.afterSwap.selector;
    }

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

    function setLiquidityChangeThreshold(PoolKey calldata key, uint256 newThreshold) external {
        PoolId poolId = key.toId();
        poolInfo[poolId].liquidityChangeThreshold = newThreshold;
        emit ThresholdUpdated(poolId, newThreshold);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}