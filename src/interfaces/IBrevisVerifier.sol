// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Brevis Interface (mock)
interface IBrevisVerifier {
    function verifyProof(bytes calldata _proof, uint256[] calldata _publicInputs) external view returns (bool);
}
