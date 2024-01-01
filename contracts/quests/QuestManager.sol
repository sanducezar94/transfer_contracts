// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../Stats.sol";

interface IBadge {
  function getBadgeQuestLimit(address _user) external view returns (uint8);
}

struct ItemDrop {
  uint16 id;
  uint16 chance;
}

struct QuestRequirements {
  Stats stats;
  uint8 total;
}

struct QuestDrops {
  uint8 min;
  uint8 max;
  ItemDrop[5] items;
}

struct QuestData {
  QuestRequirements requirements;
  QuestDrops drops;
}

struct Quest {
  bool initialized;
  QuestData data;
}

contract QuestManager is Ownable, AccessControl {
  mapping(uint16 => uint256) public totalQuests;
  mapping(uint16 => mapping(uint256 => Quest)) quests;

  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  constructor() {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MODERATOR_ROLE, msg.sender);
  }

  function getQuest(
    uint16 _mapId,
    uint256 _questId
  ) public view returns (QuestData memory) {
    return quests[_mapId][_questId].data;
  }

  function getQuestRequirements(
    uint16 _mapId,
    uint256 _questId
  ) external view returns (QuestRequirements memory) {
    return quests[_mapId][_questId].data.requirements;
  }

  function getQuestItemDrops(
    uint16 _mapId,
    uint256 _questId
  ) external view returns (ItemDrop[5] memory) {
    return quests[_mapId][_questId].data.drops.items;
  }

  function updateTotalQuestCount(
    uint16 _mapId,
    uint256 _value
  ) external onlyRole(MODERATOR_ROLE) {
    totalQuests[_mapId] = _value;
  }

  function setQuest(
    uint16 _mapId,
    uint256 _questId,
    QuestData memory questData
  ) public onlyRole(MODERATOR_ROLE) {
    Quest storage quest = quests[_mapId][_questId];
    if (!quest.initialized) {
      totalQuests[_mapId]++;
      quest.initialized = true;
    }
    require(questData.requirements.total > 0, "requirements total");
    quest.data.requirements = questData.requirements;
    quest.data.drops.min = questData.drops.min;
    quest.data.drops.max = questData.drops.max;
    quest.data.drops.items[0] = questData.drops.items[0];
    quest.data.drops.items[1] = questData.drops.items[1];
    quest.data.drops.items[2] = questData.drops.items[2];
    quest.data.drops.items[3] = questData.drops.items[3];
    quest.data.drops.items[4] = questData.drops.items[4];
  }

  function bulkSetQuests(
    uint16 _mapId,
    uint256[] calldata _questIds,
    QuestData[] calldata _quests
  ) external onlyRole(MODERATOR_ROLE) {
    unchecked {
      for (uint256 i = 0; i < _questIds.length; i++) {
        setQuest(_mapId, _questIds[i], _quests[i]);
      }
    }
  }

  function setQuestRequirements(
    uint16 _mapId,
    uint256 _questId,
    QuestRequirements memory _questRequirements
  ) external onlyRole(MODERATOR_ROLE) {
    require(_questRequirements.total > 0, "requirements total");
    quests[_mapId][_questId].data.requirements = _questRequirements;
  }

  function setQuestDrops(
    uint16 _mapId,
    uint256 _questId,
    QuestDrops memory newDrops
  ) external onlyRole(MODERATOR_ROLE) {
    QuestDrops storage drops = quests[_mapId][_questId].data.drops;
    drops.min = newDrops.min;
    drops.max = newDrops.max;
    drops.items[0] = newDrops.items[0];
    drops.items[1] = newDrops.items[1];
    drops.items[2] = newDrops.items[2];
    drops.items[3] = newDrops.items[3];
    drops.items[4] = newDrops.items[4];
  }
}
