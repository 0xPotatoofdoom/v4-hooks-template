// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {RugGuard} from "../src/RugGuard.sol";
import {PositionConfig} from "v4-periphery/src/libraries/PositionConfig.sol";

import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {EasyPosm} from "./utils/EasyPosm.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract RugGuardTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    RugGuard hook;
    PoolId poolId;

    uint256 initialTokenId;
    PositionConfig config;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        address flags = address(uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_MODIFY_POSITION_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG));
        bytes memory constructorArgs = abi.encode(manager);
        deployCodeTo("RugGuard.sol:RugGuard", constructorArgs, flags);
        hook = RugGuard(flags);

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        poolId = key.toId();
        manager.initialize(key, SQRT_PRICE_1_1, ZERO_BYTES);

        config = PositionConfig({
            poolKey: key,
            tickLower: TickMath.minUsableTick(key.tickSpacing),
            tickUpper: TickMath.maxUsableTick(key.tickSpacing)
        });
        (initialTokenId,) = posm.mint(
            config,
            10_000e18,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );
    }

    function testInitialization() public {
        (uint256 lastTimestamp, uint256 threshold, uint256 totalLiquidity, uint256 riskScore) = hook.poolInfo(poolId);
        assertEq(threshold, hook.DEFAULT_LIQUIDITY_CHANGE_THRESHOLD());
        assertEq(totalLiquidity, 10_000e18);
        assertEq(riskScore, 45);
    }

    function testLiquidityAddition() public {
        uint256 addAmount = 5_000e18;
        (uint256 newTokenId,) = posm.mint(
            config,
            addAmount,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        (,, uint256 totalLiquidity, uint256 riskScore) = hook.poolInfo(poolId);
        assertEq(totalLiquidity, 15_000e18);
        assertEq(riskScore, 40);
    }

    function testLiquidityRemoval() public {
        uint256 removeAmount = 5_000e18;
        posm.decreaseLiquidity(
            initialTokenId,
            config,
            removeAmount,
            MAX_SLIPPAGE_REMOVE_LIQUIDITY,
            MAX_SLIPPAGE_REMOVE_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        (,, uint256 totalLiquidity, uint256 riskScore) = hook.poolInfo(poolId);
        assertEq(totalLiquidity, 5_000e18);
        assertEq(riskScore, 50);
    }

    function testSwapWithLowRisk() public {
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        assertEq(int256(swapDelta.amount0()), amountSpecified);
    }

    function testSwapWithHighRisk() public {
        vm.store(
            address(hook),
            keccak256(abi.encode(poolId, uint256(3))),
            bytes32(uint256(95))
        );

        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        
        vm.expectRevert("RugGuard: Pool risk too high for swaps");
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
    }

    function testLiquidityChangeThresholdUpdate() public {
        uint256 newThreshold = 20 ether;
        hook.setLiquidityChangeThreshold(key, newThreshold);
        
        (,uint256 threshold,,) = hook.poolInfo(poolId);
        assertEq(threshold, newThreshold);
    }
}