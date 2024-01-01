// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { QuestPartyManager } from "../../quests/QuestPartyManager.sol";
import { Items } from "../../items/Items.sol";

contract CooldownConsumers is Ownable {
  using SafeERC20 for IERC20;

  constructor(address _questParty, address _items) {
    questParty = QuestPartyManager(_questParty);
    items = Items(_items);
    NFT_COOLDOWN = 2 hours;
  }

  QuestPartyManager immutable questParty;
  Items immutable items;
  uint256 immutable NFT_COOLDOWN;

  uint256 constant GINSENG_TEA = 63;
  uint256 constant ALE_JUG = 59;

  function useGinseng(uint256[] memory _knights) external {
    items.burn(msg.sender, GINSENG_TEA, _knights.length);
    for (uint256 i = 0; i < _knights.length; i++) {
      uint256 cooldownTimestamp = questParty.knightCooldowns(_knights[i]);

      uint256 newCooldownTimestamp = cooldownTimestamp - NFT_COOLDOWN;
      questParty.setKnightCooldown(_knights[i], newCooldownTimestamp);
    }
  }

  function useAleJug(uint256[] memory _peasants) external {
    uint256 burnAmount = _peasants.length / 3;
    if (_peasants.length % 3 != 0) burnAmount += 1;
    items.burn(msg.sender, ALE_JUG, burnAmount);
    for (uint256 i = 0; i < _peasants.length; i++) {
      uint256 cooldownTimestamp = questParty.peasantCooldowns(_peasants[i]);

      uint256 newCooldownTimestamp = cooldownTimestamp - NFT_COOLDOWN * 2;
      questParty.setPeasantCooldown(_peasants[i], newCooldownTimestamp);
    }
  }
}
