// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { QuestPartyManager } from "../../quests/QuestPartyManager.sol";

contract AleJug is Ownable {
  using SafeERC20 for IERC20;

  constructor(address _itemConsumer, address _questParty) {
    ITEM_CONSUMER = _itemConsumer;
    questParty = QuestPartyManager(_questParty);
    NFT_COOLDOWN = 4 hours;
  }

  QuestPartyManager immutable questParty;

  address immutable ITEM_CONSUMER;
  uint256 immutable NFT_COOLDOWN;

  function isValid(uint256[] memory _values) external view {
    require(_values.length > 0 && _values.length <= 3);
  }

  function use(address _user, uint256[] memory _values) external {
    require(msg.sender == ITEM_CONSUMER);

    for (uint256 i = 0; i < _values.length; i++) {
      if (_values[i] == 0) continue;
      uint256 cooldownTimestamp = questParty.peasantCooldowns(_values[i]);

      uint256 newCooldownTimestamp = cooldownTimestamp - NFT_COOLDOWN;
      questParty.setPeasantCooldown(_values[i], newCooldownTimestamp);
    }
  }
}
