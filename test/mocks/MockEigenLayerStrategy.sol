// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockEigenLayerStrategy {
    bool public wasProcessOffChainComputationCalled;
    bytes public lastInput;
    bytes public mockResult;

    function processOffChainComputation(bytes calldata _input) external returns (bytes memory) {
        wasProcessOffChainComputationCalled = true;
        lastInput = _input;
        return mockResult;
    }

    function setMockResult(bytes memory _mockResult) external {
        mockResult = _mockResult;
    }

    function reset() external {
        wasProcessOffChainComputationCalled = false;
        delete lastInput;
        delete mockResult;
    }
}