// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract QuestCooldownManager is Ownable, AccessControl {
  mapping(uint256 => uint256) public knightCooldowns;
  mapping(uint256 => uint256) public peasantCooldowns;

  uint256 constant BASE_COOLDOWN = 2 hours;

  function _setPeasantCooldown(uint256 _tokenId, uint256 _timestamp) internal {
    peasantCooldowns[_tokenId] = _timestamp;
  }

  function _setKnightCooldown(uint256 _tokenId, uint256 _timestamp) internal {
    knightCooldowns[_tokenId] = _timestamp;
  }

  function isKnightOnCooldown(uint256 _tokenId) internal view returns (bool) {
    return knightCooldowns[_tokenId] + BASE_COOLDOWN > block.timestamp;
  }

  function isPeasantOnCooldown(uint256 _tokenId) internal view returns (bool) {
    return knightCooldowns[_tokenId] + BASE_COOLDOWN * 2 > block.timestamp;
  }

  function bulkGetKnightCooldownTimestamp(
    uint256[] calldata _tokenIds
  ) external view returns (uint256[] memory cooldowns) {
    cooldowns = new uint256[](_tokenIds.length);
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      cooldowns[i] = knightCooldowns[_tokenIds[i]];
    }
  }

  function bulkGetPeasantCooldownTimestamp(
    uint256[] calldata _tokenIds
  ) external view returns (uint256[] memory cooldowns) {
    cooldowns = new uint256[](_tokenIds.length);
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      cooldowns[i] = peasantCooldowns[_tokenIds[i]];
    }
  }

  function _checkAndUpdatePeasantCooldown(
    uint256 _tokenId,
    uint256 _timestamp
  ) internal {
    require(peasantCooldowns[_tokenId] + BASE_COOLDOWN * 2 < _timestamp);
    peasantCooldowns[_tokenId] = _timestamp;
  }

  function bulkCheckAndUpdatePeasantsCooldown(
    uint256[] memory _tokenIds
  ) internal {
    uint256 timestamp = block.timestamp;
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      _checkAndUpdatePeasantCooldown(_tokenIds[i], timestamp);
    }
  }

  function checkAndUpdatePeasantCooldown(uint256 _tokenId) internal {
    _checkAndUpdatePeasantCooldown(_tokenId, block.timestamp);
  }

  function _checkAndUpdateKnightCooldown(
    uint256 _tokenId,
    uint256 _timestamp
  ) internal {
    require(knightCooldowns[_tokenId] + BASE_COOLDOWN < _timestamp);
    knightCooldowns[_tokenId] = _timestamp;
  }

  function bulkCheckAndUpdateKnightsCooldown(
    uint256[] memory _tokenIds
  ) internal {
    uint256 timestamp = block.timestamp;
    for (uint256 i = 0; i < _tokenIds.length; i++) {
      _checkAndUpdateKnightCooldown(_tokenIds[i], timestamp);
    }
  }

  function checkAndUpdateKnightCooldown(uint256 _tokenId) internal {
    _checkAndUpdateKnightCooldown(_tokenId, block.timestamp);
  }
}
