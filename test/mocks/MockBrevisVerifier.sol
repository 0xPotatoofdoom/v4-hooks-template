// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockBrevisVerifier {
    bool public verificationResult;
    bytes public lastProof;
    uint256[] public lastPublicInputs;

    function verifyProof(bytes calldata _proof, uint256[] calldata _publicInputs) external view returns (bool) {
        return verificationResult;
    }

    function setVerificationResult(bool _result) external {
        verificationResult = _result;
    }

    function getLastVerificationInputs() external view returns (bytes memory, uint256[] memory) {
        return (lastProof, lastPublicInputs);
    }

    function reset() external {
        verificationResult = false;
        delete lastProof;
        delete lastPublicInputs;
    }
}