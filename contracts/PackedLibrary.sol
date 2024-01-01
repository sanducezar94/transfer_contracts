// contracts/GameItems.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Packed {
    function pack(uint256 packed, uint256 number, uint8 position) public pure returns (uint256) {
        return (number << (16 * position)) | packed;
    }

    function unpack(uint256 packed, uint8 position) public pure returns (uint256) {
        return (packed >> (16 * position)) & 0xff;
    }

    function update(uint256 packed, uint256 number, uint8 position) public pure returns (uint256) {
        uint256 mask = 0xff << (16 * position);
        return (packed & ~mask) | ((number << (16 * position)) & mask);
    }
}