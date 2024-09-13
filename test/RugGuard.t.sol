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

// Mock contracts for integrations
import {MockEigenLayerStrategy} from "./mocks/MockEigenLayerStrategy.sol";
import {MockBrevisVerifier} from "./mocks/MockBrevisVerifier.sol";
import {MockChainlinkAggregator} from "./mocks/MockChainlinkAggregator.sol";

import {console} from "forge-std/console.sol";

contract RugGuardTest is Test, Fixtures {
    using EasyPosm for IPositionManager;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    RugGuard hook;
    PoolId poolId;
    MockEigenLayerStrategy eigenLayerStrategy;
    MockBrevisVerifier brevisVerifier;
    MockChainlinkAggregator priceFeed0;
    MockChainlinkAggregator priceFeed1;

    uint256 initialTokenId;
    PositionConfig config;

    // Event definitions
    event LiquidityChanged(PoolId indexed poolId, int256 liquidityDelta, uint256 newTotalLiquidity);
    event RiskScoreUpdated(PoolId indexed poolId, uint256 newRiskScore);
    event ThresholdUpdated(PoolId indexed poolId, uint256 newThreshold);

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        // Deploy mock contracts
        eigenLayerStrategy = new MockEigenLayerStrategy();
        brevisVerifier = new MockBrevisVerifier();
        priceFeed0 = new MockChainlinkAggregator();
        priceFeed1 = new MockChainlinkAggregator();

        address flags = address(
            uint160(
                Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                    | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            )
        );
        bytes memory constructorArgs = abi.encode(manager, eigenLayerStrategy, brevisVerifier);
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

        // Set up price feeds
        hook.setPriceFeed(address(currency0), address(priceFeed0));
        hook.setPriceFeed(address(currency1), address(priceFeed1));
    }

    function testInitialization() public {
        (uint256 lastTimestamp, uint256 threshold, uint256 totalLiquidity, uint256 riskScore,,) = hook.poolInfo(poolId);
        assertEq(threshold, hook.DEFAULT_LIQUIDITY_CHANGE_THRESHOLD());
        assertEq(totalLiquidity, 10_000e18);
        assertEq(riskScore, 50);
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

        (,, uint256 totalLiquidity, uint256 riskScore,,) = hook.poolInfo(poolId);
        assertEq(totalLiquidity, 15_000e18);
        assertEq(riskScore, 45);
    }

    function testLiquidityRemoval() public {
        (,, uint256 initialTotalLiquidity, uint256 initialRiskScore,,) = hook.poolInfo(poolId);

        uint256 removeAmount = 1000e18;

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

        (,, uint256 totalLiquidity, uint256 riskScore,,) = hook.poolInfo(poolId);

        assertEq(totalLiquidity, initialTotalLiquidity - removeAmount);
        assertGt(riskScore, initialRiskScore);
    }

    function testSwapWithLowRisk() public {
        priceFeed0.setLatestAnswer(1000e8);
        priceFeed1.setLatestAnswer(1000e8);

        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        assertEq(int256(swapDelta.amount0()), amountSpecified);
    }

    function testSwapWithHighRisk() public {
        bytes32 slot = keccak256(abi.encode(poolId, uint256(3)));
        vm.store(address(hook), slot, bytes32(uint256(95)));

        bool zeroForOne = true;
        int256 amountSpecified = -1e18;

        vm.expectRevert("RugGuard: Pool risk too high for swaps");
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
    }

    function testLiquidityChangeThresholdUpdate() public {
        uint256 newThreshold = 20 ether;
        hook.setLiquidityChangeThreshold(key, newThreshold);

        (, uint256 threshold,,,) = hook.poolInfo(poolId);
        assertEq(threshold, newThreshold);
    }

    function testEigenLayerIntegration() public {
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        assertTrue(eigenLayerStrategy.wasProcessOffChainComputationCalled());
    }

    function testBrevisIntegration() public {
        bytes memory mockProof = abi.encodePacked("mock proof");
        uint256[] memory publicInputs = new uint256[](2);
        publicInputs[0] = uint256(uint160(poolId));
        publicInputs[1] = 60; // New risk score

        brevisVerifier.setVerificationResult(true);
        hook.verifyBrevisProof(mockProof, publicInputs);

        (,,, uint256 riskScore,,) = hook.poolInfo(poolId);
        assertEq(riskScore, 60);
    }

    function testChainlinkIntegration() public {
        priceFeed0.setLatestAnswer(1000e8);
        priceFeed1.setLatestAnswer(2000e8);

        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);

        (,,,,, int256 lastPrice) = hook.poolInfo(poolId);
        assertEq(lastPrice, 5e17); // 1000 / 2000 * 1e18
    }

    function testCheckUpkeep() public {
        // Set conditions for upkeep
        vm.warp(block.timestamp + 2 days);
        bytes32 slot = keccak256(abi.encode(poolId, uint256(3)));
        vm.store(address(hook), slot, bytes32(uint256(85)));

        bytes memory checkData = abi.encode(poolId);
        (bool upkeepNeeded,) = hook.checkUpkeep(checkData);
        assertTrue(upkeepNeeded);
    }

    function testPerformUpkeep() public {
        // Set conditions for upkeep
        vm.warp(block.timestamp + 2 days);
        bytes32 slot = keccak256(abi.encode(poolId, uint256(3)));
        vm.store(address(hook), slot, bytes32(uint256(85)));

        bytes memory performData = abi.encode(poolId);
        hook.performUpkeep(performData);

        (,,,, uint256 totalVolume24h,) = hook.poolInfo(poolId);
        assertEq(totalVolume24h, 0);
    }
}
