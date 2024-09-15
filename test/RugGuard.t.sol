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

/// @title RugGuardTest
/// @notice Test contract for the RugGuard smart contract
/// @dev This contract contains unit tests for the RugGuard functionality
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

    /// @notice Set up the test environment
    /// @dev Deploys necessary contracts and initializes the test state
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
                    | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                    | Hooks.AFTER_ADD_LIQUIDITY_FLAG
            )
        );

        bytes memory constructorArgs = abi.encode(manager, eigenLayerStrategy, brevisVerifier);
        deployCodeTo("RugGuard.sol:RugGuard", constructorArgs, flags);

        hook = RugGuard(payable(flags));

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
            1000 ether,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        address token0 = Currency.unwrap(currency0);
        address token1 = Currency.unwrap(currency1);

        // Set up price feeds
        hook.setPriceFeed(address(token0), address(priceFeed0));
        hook.setPriceFeed(address(token1), address(priceFeed1));
    }

    /// @notice Test the initialization of the RugGuard contract
    /// @dev Verifies that the initial state of the contract is set correctly
    function testInitialization() public {
        (, uint256 liquidityChangeThreshold, uint256 totalLiquidity, uint256 riskScore,,,) = hook.poolInfo(poolId);

        assertEq(liquidityChangeThreshold, hook.DEFAULT_LIQUIDITY_CHANGE_THRESHOLD());
        assertEq(totalLiquidity, 1000 ether);
        assertEq(riskScore, 45);
    }

    /// @notice Test adding liquidity to the pool
    /// @dev Verifies that liquidity addition updates the pool state correctly
    function testLiquidityAddition() public {
        uint256 addAmount = 5 ether;
        (uint256 newTokenId,) = posm.mint(
            config,
            addAmount,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            MAX_SLIPPAGE_ADD_LIQUIDITY,
            address(this),
            block.timestamp,
            ZERO_BYTES
        );

        (
            uint256 lastLiquidityChangeTimestamp,
            uint256 liquidityChangeThreshold,
            uint256 totalLiquidity,
            uint256 riskScore,
            uint256 totalVolume24h,
            uint256 lastVolumeUpdateTimestamp,
            int256 lastPrice
        ) = hook.poolInfo(poolId);

        assertEq(totalLiquidity, 1005 ether);
        assertEq(riskScore, 40);
    }

    /// @notice Test removing liquidity from the pool
    /// @dev Verifies that liquidity removal updates the pool state correctly
    function testLiquidityRemoval() public {
        (
            uint256 lastLiquidityChangeTimestamp,
            uint256 liquidityChangeThreshold,
            uint256 initialTotalLiquidity,
            uint256 initialRiskScore,
            uint256 totalVolume24h,
            uint256 lastVolumeUpdateTimestamp,
            int256 lastPrice
        ) = hook.poolInfo(poolId);

        uint256 removeAmount = 10 ether;

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

        (
            uint256 finalLastLiquidityChangeTimestamp,
            uint256 finalLiquidityChangeThreshold,
            uint256 finalTotalLiquidity,
            uint256 finalRiskScore,
            uint256 finalTotalVolume24h,
            uint256 finalLastVolumeUpdateTimestamp,
            int256 finalLastPrice
        ) = hook.poolInfo(poolId);

        assertEq(finalTotalLiquidity, initialTotalLiquidity - removeAmount);
        assertEq(finalRiskScore, initialRiskScore);
    }

    /// @notice Test swapping with low risk
    /// @dev Verifies that swaps are allowed when the pool risk is low
    function testSwapWithLowRisk() public {
        priceFeed0.setLatestAnswer(1000e8);
        priceFeed1.setLatestAnswer(1000e8);
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        BalanceDelta swapDelta = swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        assertEq(int256(swapDelta.amount0()), amountSpecified);
    }

    /// @notice Test swapping with high risk
    /// @dev Verifies that swaps are prevented when the pool risk is high
    /**
     * The test is working fine but unable to assertRevert since the error is wrapped inside other error calls made by uniswap
     */
    function testSwapWithHighRisk() public {
        bytes32 slot = keccak256(abi.encode(poolId, uint256(3)));
        vm.store(address(hook), slot, bytes32(uint256(95)));
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        vm.expectRevert("RugGuard: Pool risk too high for swaps");
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
    }

    /// @notice Test updating the liquidity change threshold
    /// @dev Verifies that the liquidity change threshold can be updated correctly
    function testLiquidityChangeThresholdUpdate() public {
        uint256 newThreshold = 20 ether;
        hook.setLiquidityChangeThreshold(key, newThreshold);
        (, uint256 threshold,,,,,) = hook.poolInfo(poolId);
        assertEq(threshold, newThreshold);
    }

    /// @notice Test EigenLayer integration
    /// @dev Verifies that the EigenLayer strategy is called during a swap
    function testEigenLayerIntegration() public {
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        assertTrue(eigenLayerStrategy.wasProcessOffChainComputationCalled());
    }

    /// @notice Test Brevis integration
    /// @dev Verifies that the Brevis proof verification works correctly
    function testBrevisIntegration() public {
        bytes memory mockProof = abi.encodePacked("mock proof");
        uint256[] memory publicInputs = new uint256[](2);
        publicInputs[0] = uint256(PoolId.unwrap(poolId));
        publicInputs[1] = 60; // New risk score
        brevisVerifier.setVerificationResult(true);
        hook.verifyBrevisProof(mockProof, publicInputs);
        (,,, uint256 riskScore,,,) = hook.poolInfo(poolId);
        assertEq(riskScore, 60);
    }

    /// @notice Test Chainlink integration
    /// @dev Verifies that the Chainlink price feeds are used correctly during a swap
    function testChainlinkIntegration() public {
        priceFeed0.setLatestAnswer(1000e8);
        priceFeed1.setLatestAnswer(2000e8);
        bool zeroForOne = true;
        int256 amountSpecified = -1e18;
        swap(key, zeroForOne, amountSpecified, ZERO_BYTES);
        (,,,,,, int256 lastPrice) = hook.poolInfo(poolId);
        assertEq(lastPrice, 5e17); // 1000 / 2000 * 1e18
    }

    /// @notice Test the checkUpkeep function
    /// @dev Verifies that the checkUpkeep function returns the correct result
    function testCheckUpkeep() public {
        // Set conditions for upkeep
        vm.warp(block.timestamp + 2 days);
        bytes32 slot = keccak256(abi.encode(poolId, uint256(3)));
        vm.store(address(hook), slot, bytes32(uint256(85)));
        bytes memory checkData = abi.encode(poolId);
        (bool upkeepNeeded,) = hook.checkUpkeep(checkData);
        assertTrue(upkeepNeeded);
    }

    /// @notice Test the performUpkeep function
    /// @dev Verifies that the performUpkeep function executes correctly
    function testPerformUpkeep() public {
        // Set conditions for upkeep
        vm.warp(block.timestamp + 2 days);
        bytes32 slot = keccak256(abi.encode(poolId, uint256(3)));
        vm.store(address(hook), slot, bytes32(uint256(85)));
        bytes memory performData = abi.encode(poolId);
        hook.performUpkeep(performData);
        (,,,, uint256 totalVolume24h,,) = hook.poolInfo(poolId);
        assertEq(totalVolume24h, 0);
    }
}
