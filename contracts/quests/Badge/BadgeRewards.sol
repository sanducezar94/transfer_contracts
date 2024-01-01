// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { Items } from "../../items/Items.sol";
import { Badge, BadgeStorage } from "./BadgeStorage.sol";
import "../../constants.sol";

struct LevelReward {
  uint256[] itemIds;
  uint256[] itemAmounts;
}

interface KPItems {
  function mintItems(
    address _to,
    uint256[] memory _itemIds,
    uint256[] calldata _itemAmounts
  ) external;
}

contract BadgeRewards is AccessControl {
  KPItems immutable items;
  BadgeStorage immutable badge;

  constructor(
    address _items,
    BadgeStorage _badge,
    uint16 _maxLevel,
    uint16 _expPerLevel
  ) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(BADGE_MANAGER, msg.sender);

    items = KPItems(_items);
    badge = _badge;

    MAX_BADGE_LEVEL = _maxLevel;
    EXP_PER_LEVEL = _expPerLevel;
  }

  bytes32 public constant BADGE_MANAGER = keccak256("BADGE_MANAGER");

  uint16 public MAX_BADGE_LEVEL;
  uint16 public EXP_PER_LEVEL;

  mapping(uint16 => LevelReward) levelRewards;
  mapping(address => uint16) public playerLevels;

  function bulkSetBadgeRewards(
    uint16[] calldata _levels,
    LevelReward[] calldata _levelRewards
  ) public onlyRole(BADGE_MANAGER) {
    unchecked {
      for (uint256 i = 0; i < _levelRewards.length; i++) {
        levelRewards[_levels[i]].itemIds = _levelRewards[i].itemIds;
        levelRewards[_levels[i]].itemAmounts = _levelRewards[i].itemAmounts;
      }
    }
  }

  function bulkSetPlayerLevels(
    address[] calldata _users,
    uint16[] calldata _levels
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    for (uint256 i = 0; i < _users.length; i++) {
      playerLevels[_users[i]] = _levels[i];
    }
  }

  function getExpPerLevel() external view returns (uint16) {
    return EXP_PER_LEVEL;
  }

  function getMaxLevel() external view returns (uint16) {
    return MAX_BADGE_LEVEL;
  }

  function setExpPerLevel(uint16 _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
    EXP_PER_LEVEL = _value;
  }

  function setMaxLevel(uint16 _value) external onlyRole(DEFAULT_ADMIN_ROLE) {
    MAX_BADGE_LEVEL = _value;
  }

  function claimBadgeLevelReward(uint16 _level) external {
    uint16 playerLevel = playerLevels[msg.sender];
    require(
      playerLevel + 1 == _level && _level <= MAX_BADGE_LEVEL,
      "Invalid level."
    );

    bool hasBadge = badge.purchasedBadge(msg.sender);
    require(hasBadge, "Badge not purchased.");

    playerLevels[msg.sender] = _level;
    badge.levelUpBadge(msg.sender, EXP_PER_LEVEL);

    LevelReward memory reward = levelRewards[_level];
    items.mintItems(msg.sender, reward.itemIds, reward.itemAmounts);
  }
}
