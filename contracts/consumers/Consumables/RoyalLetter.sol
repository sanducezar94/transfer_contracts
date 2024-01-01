// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { BadgeStorage } from "../../quests/Badge/BadgeStorage.sol";

contract RoyalLetter is Ownable, AccessControl {
  using SafeERC20 for IERC20;

  constructor(BadgeStorage _badge, address _itemConsumer) {
    badge = _badge;
    ITEM_CONSUMER = _itemConsumer;
  }

  address immutable ITEM_CONSUMER;
  BadgeStorage badge;

  bytes32 public constant ITEM_CONSUMER_ROLE = keccak256("ITEM_CONSUMER_ROLE");
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  function isValid(uint256[] memory _values) external view {
    require(_values.length == 1, "Invalid map.");
  }

  function use(address _user, uint256[] memory _values) external {
    require(msg.sender == ITEM_CONSUMER); // CHECKER

    badge.rerollDailyQuests(_user, uint8(_values[0]));
  }
}
