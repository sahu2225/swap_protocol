// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockPermit2 {
    function permit(
        address owner,
        address spender,
        uint160 amount,
        uint48 expiration,
        uint48 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // Mock implementation
    }

    function transferFrom(
        address from,
        address to,
        uint160 amount,
        address token
    ) external {
        // Mock implementation
    }
}