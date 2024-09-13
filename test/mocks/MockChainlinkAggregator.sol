// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockChainlinkAggregator {
    int256 private _latestAnswer;
    uint256 private _latestTimestamp;
    uint80 private _latestRound;

    function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        return (_latestRound, _latestAnswer, _latestTimestamp, _latestTimestamp, _latestRound);
    }

    function setLatestAnswer(int256 _answer) external {
        _latestAnswer = _answer;
        _latestTimestamp = block.timestamp;
        _latestRound++;
    }

    function getLatestAnswer() external view returns (int256) {
        return _latestAnswer;
    }

    function reset() external {
        delete _latestAnswer;
        delete _latestTimestamp;
        delete _latestRound;
    }
}