// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockValuationEngine {
    // returns intrinsic value in 1e18 fixed point
    function getIntrinsicValueAt(uint256) external pure returns (uint256) {
        return 1e18;
    }
}
