// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// EigenLayer Interface (mock)
interface IEigenLayerStrategy {
    function processOffChainComputation(bytes calldata _input) external returns (bytes memory);
}
