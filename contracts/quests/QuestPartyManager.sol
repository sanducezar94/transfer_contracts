// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { Stats, StatsMath } from "../Stats.sol";
import { KnightAttributeManager } from "../knights/KnightAttributeManager.sol";
import { IPeasants, Peasants } from "../peasants/Peasants.sol";
import { PeasantEffectManager } from "../peasants/PeasantEffectManager.sol";
import { Items } from "../items/Items.sol";
import { QuestCooldownManager } from "./QuestCooldownManager.sol";
import { Quest, QuestData, QuestRequirements, QuestManager } from "./QuestManager.sol";
import { BadgeStorage } from "./Badge/BadgeStorage.sol";
import "../constants.sol";

function max(uint256 a, uint256 b) pure returns (uint256) {
  return a >= b ? a : b;
}

function min(uint256 a, uint256 b) pure returns (uint256) {
  return a < b ? a : b;
}

function resizeArr(uint256[] memory arr, uint256 size) pure {
  assembly {
    mstore(arr, size)
  }
}

struct ItemAmounts {
  uint256[] ids;
  uint256[] amounts;
  uint256 total;
}

library ItemAmountsLib {
  function init(uint256 size) internal pure returns (ItemAmounts memory items) {
    items.ids = new uint256[](size);
    items.amounts = new uint256[](size);
  }

  function push(
    ItemAmounts memory items,
    uint256 itemId,
    uint256 index
  ) internal pure returns (uint256) {
    bool found;
    for (uint256 k = 0; k < index; k++) {
      if (items.ids[k] == itemId) {
        found = true;
        items.amounts[k]++;
      }
    }

    if (!found) {
      items.ids[index] = itemId;
      items.amounts[index] = 1;
      index++;
    }
    return index;
  }

  function resize(ItemAmounts memory items, uint256 size) internal pure {
    resizeArr(items.ids, size);
    resizeArr(items.amounts, size);
  }
}

contract QuestPartyManager is
  Ownable,
  AccessControl,
  ReentrancyGuard,
  PeasantEffectManager,
  QuestCooldownManager
{
  using StatsMath for Stats;
  using ItemAmountsLib for ItemAmounts;

  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  IERC721 public immutable knights;
  Peasants public immutable peasants;
  Items public immutable items;

  QuestManager public immutable questManager;
  BadgeStorage public immutable badge;

  KnightAttributeManager public immutable knightsAttributes;

  uint256 questNonce;

  constructor(
    IERC721 _knights,
    Peasants _peasants,
    Items _items,
    QuestManager _questManager,
    BadgeStorage _badge,
    KnightAttributeManager _knightsAttributes
  ) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MODERATOR_ROLE, msg.sender);

    knights = _knights;
    peasants = _peasants;
    items = _items;
    questManager = _questManager;
    badge = _badge;
    knightsAttributes = _knightsAttributes;
  }

  function _getPeasantAttributes(
    uint256 id
  ) internal view override returns (IPeasants.PeasantStats memory attributes) {
    return peasants.getAttributes(id);
  }

  function getPeasantAttributesDC(
    uint256 id
  ) external view returns (IPeasants.PeasantStats memory attributes) {
    return peasants.getAttributes(id);
  }

  event QuestFinished(address user, uint256 badgeExp);

  struct Party {
    uint256 knight;
    uint256[] peasants;
    ItemAmounts items;
  }

  function setKnightCooldown(
    uint256 _knightId,
    uint256 _timestamp
  ) external onlyRole(MODERATOR_ROLE) {
    _setKnightCooldown(_knightId, _timestamp);
  }

  function setPeasantCooldown(
    uint256 _peasantId,
    uint256 _timestamp
  ) external onlyRole(MODERATOR_ROLE) {
    _setPeasantCooldown(_peasantId, _timestamp);
  }

  function createParty(
    uint256 _knightId,
    uint256[3] calldata _peasants,
    uint256[5] calldata _items
  ) internal pure returns (Party memory party) {
    party.knight = _knightId;
    {
      party.peasants = new uint256[](3);
      uint256 numberOfPeasents;
      for (uint256 index = 0; index < _peasants.length; index++) {
        if (_peasants[index] == NULL_PEASANT) continue;
        for (uint256 k = 0; k < index; k++) {
          require(party.peasants[k] != _peasants[index]);
        }
        party.peasants[numberOfPeasents] = _peasants[index];
        numberOfPeasents++;
      }
      resizeArr(party.peasants, numberOfPeasents);
    }

    {
      party.items = ItemAmountsLib.init(5);
      uint256 numberOfItems;
      for (uint256 index = 0; index < _items.length; index++) {
        if (_items[index] == NULL_ITEM) continue;
        numberOfItems = party.items.push(_items[index], numberOfItems);
        party.items.total++;
      }
      party.items.resize(numberOfItems);

      for (uint256 i = 0; i < numberOfItems; i++) {
        if (party.items.ids[i] >= EQUIPMENT_OFFSET) {
          require(party.items.amounts[i] == 1, "Equipment not unique.");
        }
      }
    }
  }

  function validateAndUpdateParty(
    Party memory party,
    uint256 maxItems
  ) internal {
    require(knights.ownerOf(party.knight) == msg.sender);
    require(peasants.isOwnerOf(msg.sender, party.peasants));
    require(maxItems >= party.items.total, "max items");

    checkAndUpdateKnightCooldown(party.knight);
    if (party.peasants.length > 0) {
      bulkCheckAndUpdatePeasantsCooldown(party.peasants);
    }

    uint256 itemCount = party.items.ids.length;
    if (itemCount > 0) {
      ItemAmounts memory burnItems = ItemAmountsLib.init(itemCount);
      unchecked {
        for (uint256 i = 0; i < itemCount; i++) {
          if (party.items.ids[i] >= EQUIPMENT_OFFSET) {
            continue;
          }

          burnItems.ids[burnItems.total] = party.items.ids[i];
          burnItems.amounts[burnItems.total] = party.items.amounts[i];
          burnItems.total++;
        }

        if (burnItems.total > 0) {
          if (burnItems.total > 1) {
            burnItems.resize(burnItems.total);
            items.burnBatch(msg.sender, burnItems.ids, burnItems.amounts);
          } else {
            items.burn(msg.sender, burnItems.ids[0], burnItems.amounts[0]);
          }
        }
      }
    }
  }

  function startQuest(
    uint8 _mapId,
    uint256 _knightId,
    uint256[3] calldata _peasants,
    uint256[5] calldata _items,
    uint8 _questSlot
  ) external nonReentrant {
    uint256 questId = badge.getBadgeQuestAtSlot(msg.sender, _mapId, _questSlot);
    uint8 maxBadgeItems = badge.getBadgeItemSlots(msg.sender);

    require(questId != NULL_QUEST);
    Party memory party = createParty(_knightId, _peasants, _items);
    validateAndUpdateParty(party, maxBadgeItems);
    playQuest(_mapId, questId, _questSlot, party);
  }

  uint256 constant threshold = MAXIMUM_QUEST_REQUIREMENTS / 2;

  function playQuest(
    uint8 _mapId,
    uint256 questId,
    uint256 questSlot,
    Party memory party
  ) internal {
    QuestData memory quest = questManager.getQuest(_mapId, questId);
    uint256 random = generateRandom(questNonce++);
    uint256 filled = getRequirementsFilled(
      quest.requirements,
      getPartyStats(party)
    );

    uint256 exp = filled > threshold ? 1 : 0;
    uint256 drops = calculateDrops(filled, quest.drops.max, random >>= 8);

    // badge roll
    if (filled > threshold && (random >>= 8) % 100 <= 10 + 45 * (filled - 3)) {
      exp = 2;
    }
    // pitty roll
    if (drops == 0 && (random >>= 8) % 100 <= 25) {
      drops = 1;
      exp = 1;
    }

    ItemAmounts memory dropItems = ItemAmountsLib.init(drops);
    if (drops > 0) {
      unchecked {
        for (uint256 i = 0; i < drops; i++) {
          uint256 dropChance = (random >>= 8) % 10000;
          uint256 accruedChance = 0;
          for (uint256 j = 0; j < quest.drops.items.length; j++) {
            uint256 itemChance = quest.drops.items[j].chance;
            uint256 itemId = quest.drops.items[j].id;
            if (
              itemChance > 0 &&
              dropChance >= accruedChance &&
              dropChance < accruedChance + itemChance
            ) {
              dropItems.total = dropItems.push(itemId, dropItems.total);
              break;
            }
            accruedChance += itemChance;
          }
        }
      }
      dropItems.resize(dropItems.total);

      if (dropItems.total == 1) {
        items.mintItem(msg.sender, dropItems.ids[0], dropItems.amounts[0]);
      } else if (dropItems.total > 1) {
        items.mintItems(msg.sender, dropItems.ids, dropItems.amounts);
      }
    }

    badge.completeQuest(msg.sender, _mapId, questSlot, exp);
    emit QuestFinished(msg.sender, exp);
  }

  function generateRandom(uint256 nonce) private view returns (uint256) {
    return
      uint256(
        keccak256(
          abi.encodePacked(blockhash(block.number - 1), nonce, "QUESTPARTYTEST")
        )
      );
  }

  function getPartyStats(
    Party memory party
  ) public view returns (Stats memory) {
    Stats memory stats = knightsAttributes.getKnightStats(party.knight).mul(10);
    Stats memory peasantBonuses = getPeasantsEffects(party.peasants);
    Stats memory itemBonuses = items.getItemsEffectsTotal(
      party.items.ids,
      party.items.amounts
    );

    peasantBonuses = peasantBonuses.simpleAdd(
      peasantBonuses
        .simpleMul(peasantBonuses.effectiveness + itemBonuses.effectiveness)
        .div(1e2)
    );
    stats = stats.add(itemBonuses).add(peasantBonuses);

    return stats;
  }

  function getRequirementsFilled(
    QuestRequirements memory req,
    Stats memory stats
  ) public pure returns (uint256) {
    // get the relative value of each requirement point
    uint256 pointsPerRequirement = MAXIMUM_QUEST_POINTS / req.total;

    uint256 filled;

    if (stats.health >= req.stats.health && req.stats.health != 0) filled++;
    if (stats.attack >= req.stats.attack && req.stats.attack != 0) filled++;
    if (stats.defense >= req.stats.defense && req.stats.defense != 0) filled++;
    if (stats.speed >= req.stats.speed && req.stats.speed != 0) filled++;
    if (stats.charisma >= req.stats.charisma && req.stats.charisma != 0)
      filled++;

    // get the relative position in the bracket based on the number of requirements per quest
    if (filled > 0) {
      filled = getBracket(
        ((pointsPerRequirement * filled * 1e3) / MAXIMUM_QUEST_POINTS)
      );
    }

    return filled;
  }

  function getBracket(uint256 _value) private pure returns (uint256) {
    if (_value <= 200) return 1;
    if (_value <= 400) return 2;
    if (_value <= 600) return 3;
    if (_value <= 800) return 4;
    if (_value <= 1000) return 5;
    return 0;
  }

  function calculateDrops(
    uint256 filled,
    uint256 maxDrops,
    uint256 seed
  ) internal pure returns (uint256 drops) {
    if (filled < 3) return 0;
    drops = max(
      getMinDrops(filled, maxDrops),
      getItemDrops(seed % 100, maxDrops)
    );
  }

  function getItemDrops(
    uint256 _chance,
    uint256 _maxDrops
  ) internal pure returns (uint8) {
    if (_maxDrops <= 2) {
      return _chance < 33 && _maxDrops >= 2 ? 2 : 1;
    } else {
      if (_chance < 25) return 3;
      else if (_chance >= 25 && _chance < 60) return 2;
      return 1;
    }
  }

  function getMinDrops(
    uint256 _requirementsFilled,
    uint256 _maxDrops
  ) internal pure returns (uint256) {
    // 0 guaranteed drops if requirements filled are less than 4
    if (_requirementsFilled < 4) return 0;
    if (_requirementsFilled == 4) return 1;
    // guarantee 2 minimum drops when there's 5 requirements met but take into account the quest max drops
    return _maxDrops >= 2 ? 2 : 1;
  }
}
