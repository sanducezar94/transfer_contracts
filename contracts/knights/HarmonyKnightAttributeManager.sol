// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./KnightAttributeManagerOld.sol";
import "../Stats.sol";

struct TrainingCampDataView {
  uint256 tokenId;
  uint256 speed; // $KNIGHT earning speed (per day)
  uint256 earnings;
  uint256 totalEverClaimed;
  uint64 lastCheckout;
  uint8 camp; // 0 or 1
  uint8 weaponsMastery; // 0 -> 3
  uint8 armourMastery; // 0 -> 3
  uint8 horseMastery; // 0 -> 3
  uint8 chivalryMastery; // 0 -> 3
}

interface ITrainingCamp {
  function getTokenAttributes(
    uint256 _tokenId
  ) external view returns (TrainingCampDataView memory);
}

contract KnightAttributeManagerHarmony is AccessControl {
  IERC721 immutable knights;

  struct AttributeInfo {
    uint16 health;
    uint16 attack;
    uint16 defense;
    uint16 speed;
    uint16 charisma;
    uint16[2] boostedStats;
    uint16 attributePoints;
    uint16 attributePointsDebt;
    uint16 attributePointsTotal;
  }

  uint256 nonce;
  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  mapping(uint256 => AttributeInfo) knightAttributes;
  mapping(uint256 => AttributeInfo) knightOriginalAttributes;

  address public trainingCampAddress;

  mapping(uint256 => uint256[]) public boostedWeights;

  event AttributeIncrease(
    uint256 knightId,
    uint256 totalPoints,
    uint256[5] values,
    uint16[5] finalValues
  );

  event KnightBless(uint256 knightId, uint256 attributeIndex, uint256 points);
  event KnightReset(uint256 knightId, uint256 points);
  event KnightSetAttributes(uint256 knightId, uint16[5] attributes);
  event KnightSetBaseAttributes(uint256 knightId, uint16[5] attributes);

  constructor(IERC721 _knights, address _traningCampAddress) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MODERATOR_ROLE, msg.sender);
    knights = _knights;
    trainingCampAddress = _traningCampAddress;
  }

  function bulkSetKnightAttribute(
    uint256[] memory _knightIds,
    AttributeInfo[] memory _attributes
  ) external onlyRole(MODERATOR_ROLE) {
    uint256 length = _knightIds.length;
    for (uint256 i = 0; i < length; ) {
      setKnightAttributes(_knightIds[i], _attributes[i]);
      unchecked {
        i++;
      }
    }
  }

  function bulkSetKnightInitialAttribute(
    uint256[] memory _knightIds,
    AttributeInfo[] memory _attributes
  ) external onlyRole(MODERATOR_ROLE) {
    uint256 length = _knightIds.length;
    for (uint256 i = 0; i < length; ) {
      setKnightInitialAttributes(_knightIds[i], _attributes[i]);
      unchecked {
        i++;
      }
    }
  }

  function setKnightAttributes(
    uint256 _knightId,
    AttributeInfo memory _attributes
  ) public onlyRole(MODERATOR_ROLE) {
    knightAttributes[_knightId] = _attributes;

    emit KnightSetAttributes(
      _knightId,
      [
        _attributes.health,
        _attributes.attack,
        _attributes.defense,
        _attributes.speed,
        _attributes.charisma
      ]
    );
  }

  function setKnightInitialAttributes(
    uint256 _knightId,
    AttributeInfo memory _attributes
  ) public onlyRole(MODERATOR_ROLE) {
    knightOriginalAttributes[_knightId] = _attributes;
    emit KnightSetBaseAttributes(
      _knightId,
      [
        _attributes.health,
        _attributes.attack,
        _attributes.defense,
        _attributes.speed,
        _attributes.charisma
      ]
    );
  }

  function blessKnight(
    uint256 _knightId,
    uint256 _attributeIndex
  ) external onlyRole(MODERATOR_ROLE) {
    AttributeInfo storage _knightAttributes = knightAttributes[_knightId];

    uint256 random = getRandom();
    uint256 chance = 0;

    if (_knightAttributes.boostedStats[0] == _attributeIndex) {
      chance += 20;
    }
    if (_knightAttributes.boostedStats[1] == _attributeIndex) {
      chance += 20;
    }

    uint256 pointValue = (random >>= 8) % 100 <= chance ? 2 : 1;

    knightAttributes[_knightId].attributePointsTotal += uint16(pointValue);
    increaseKnightAttribute(_knightId, _attributeIndex, pointValue);

    emit KnightBless(_knightId, _attributeIndex, pointValue);
  }

  function setKnightAttribute(
    uint256 _knightId,
    uint256 _attributeIndex,
    uint256 _value
  ) external onlyRole(MODERATOR_ROLE) {
    AttributeInfo storage attrs = knightAttributes[_knightId];

    if (_attributeIndex == 0) {
      attrs.health = uint16(_value);
    } else if (_attributeIndex == 1) {
      attrs.attack = uint16(_value);
    } else if (_attributeIndex == 2) {
      attrs.defense = uint16(_value);
    } else if (_attributeIndex == 3) {
      attrs.speed = uint16(_value);
    } else if (_attributeIndex == 4) {
      attrs.charisma = uint16(_value);
    }

    emit KnightSetAttributes(
      _knightId,
      [attrs.health, attrs.attack, attrs.defense, attrs.speed, attrs.charisma]
    );
  }

  function increaseKnightAttribute(
    uint256 _knightId,
    uint256 _attributeIndex,
    uint256 _value
  ) public onlyRole(MODERATOR_ROLE) {
    AttributeInfo storage attrs = knightAttributes[_knightId];

    if (_attributeIndex == 0) {
      attrs.health += uint16(_value * 10);
    } else if (_attributeIndex == 1) {
      attrs.attack += uint16(_value);
    } else if (_attributeIndex == 2) {
      attrs.defense += uint16(_value);
    } else if (_attributeIndex == 3) {
      attrs.speed += uint16(_value);
    } else if (_attributeIndex == 4) {
      attrs.charisma += uint16(_value);
    }

    emit KnightSetAttributes(
      _knightId,
      [attrs.health, attrs.attack, attrs.defense, attrs.speed, attrs.charisma]
    );
  }

  function resetStats(uint256 _knightId) public onlyRole(MODERATOR_ROLE) {
    AttributeInfo storage _knightAttributes = knightAttributes[_knightId];
    AttributeInfo storage _knightOriginalAttributes = knightOriginalAttributes[
      _knightId
    ];

    _knightAttributes.health = _knightOriginalAttributes.health;
    _knightAttributes.defense = _knightOriginalAttributes.defense;
    _knightAttributes.attack = _knightOriginalAttributes.attack;
    _knightAttributes.speed = _knightOriginalAttributes.speed;
    _knightAttributes.charisma = _knightOriginalAttributes.charisma;
    _knightAttributes.attributePoints += _knightAttributes.attributePointsTotal;
    _knightAttributes.attributePointsTotal = 0;

    emit KnightReset(_knightId, _knightAttributes.attributePoints);
  }

  function allocateAttributePoints(
    uint256 _knightId,
    uint256[5] memory _values
  ) public {
    AttributeInfo storage _knightAttributes = knightAttributes[_knightId];

    uint256 totalPoints = _values[0] +
      _values[1] +
      _values[2] +
      _values[3] +
      _values[4];

    bool isModerator = hasRole(MODERATOR_ROLE, msg.sender);
    require(
      isModerator || IERC721(knights).ownerOf(_knightId) == msg.sender,
      "Not the owner."
    );
    require(
      isModerator || totalPoints <= _knightAttributes.attributePoints,
      "Not enough skill points."
    );

    uint16[5] memory finalValues = _calculateBoostedStats(_knightId, _values);

    _knightAttributes.health += finalValues[0] * 10;
    _knightAttributes.attack += finalValues[1];
    _knightAttributes.defense += finalValues[2];
    _knightAttributes.speed += finalValues[3];
    _knightAttributes.charisma += finalValues[4];

    if (!isModerator) {
      _knightAttributes.attributePoints -= uint16(totalPoints);
    }
    _knightAttributes.attributePointsTotal += uint16(totalPoints);

    emit AttributeIncrease(_knightId, totalPoints, _values, finalValues);
  }

  function _calculateBoostedStats(
    uint256 _knightId,
    uint256[5] memory _values
  ) private returns (uint16[5] memory finalValues) {
    AttributeInfo memory _knightAttributes = knightAttributes[_knightId];
    unchecked {
      for (uint256 i = 0; i < _values.length; i++) {
        uint256 percentageChance;

        if (_knightAttributes.boostedStats[0] == i) {
          percentageChance += 20;
        }
        if (_knightAttributes.boostedStats[1] == i) {
          percentageChance += 20;
        }

        if (percentageChance == 0) {
          finalValues[i] = uint16(_values[i]);
          continue;
        }

        finalValues[i] += _getBoostedStat(_values[i], percentageChance);
      }
    }

    return finalValues;
  }

  function getRandom() internal returns (uint256) {
    return
      uint256(
        keccak256(
          abi.encodePacked(
            blockhash(block.number - 1),
            nonce++,
            "POLGYONKNIGHTATTRIP"
          )
        )
      );
  }

  function _getBoostedStat(
    uint256 stats,
    uint256 _percentageChance
  ) private returns (uint16) {
    uint256 random = getRandom();
    uint16 totalStats = uint16(stats);
    unchecked {
      for (uint256 i = 0; i < stats; i++) {
        if ((random >>= 8) % 100 <= _percentageChance) {
          totalStats++;
        }

        if (i % 32 == 0 && i > 0) {
          random = getRandom();
        }
      }
    }
    return totalStats;
  }

  function giveAttributePoints(
    uint256 _knightId,
    uint256 _points
  ) external onlyRole(MODERATOR_ROLE) {
    knightAttributes[_knightId].attributePoints += uint16(_points);
  }

  function getKnightAttributes(
    uint256 _knightId
  ) public view returns (AttributeInfo memory) {
    return knightAttributes[_knightId];
  }

  function getKnightsAttributes(
    uint256[] memory _knightsIds
  ) external view returns (AttributeInfo[] memory) {
    AttributeInfo[] memory _attributes = new AttributeInfo[](
      _knightsIds.length
    );

    unchecked {
      for (uint256 i = 0; i < _knightsIds.length; i++) {
        _attributes[i] = getKnightAttributes(_knightsIds[i]);
      }
    }

    return _attributes;
  }

  function getKnightStats(
    uint256 _knightId
  ) external view returns (Stats memory) {
    AttributeInfo memory attributes = knightAttributes[_knightId];
    return
      Stats({
        health: attributes.health,
        attack: attributes.attack,
        defense: attributes.defense,
        speed: attributes.speed,
        charisma: attributes.charisma,
        effectiveness: 0
      });
  }

  function getUpgradeAvailablePoints(
    uint256 _knightId
  ) public view returns (uint256, uint256) {
    TrainingCampDataView memory campData = ITrainingCamp(trainingCampAddress)
      .getTokenAttributes(_knightId);
    uint256[4] memory upgradeBonuses = [uint256(0), 1, 3, 6];
    uint256 totalPoints = upgradeBonuses[campData.weaponsMastery] +
      upgradeBonuses[campData.armourMastery] +
      upgradeBonuses[campData.horseMastery] +
      upgradeBonuses[campData.chivalryMastery];
    return (
      totalPoints - knightAttributes[_knightId].attributePointsDebt,
      totalPoints
    );
  }

  function getKnightUpgradeBonuses(uint256 _knightId) external {
    require(knights.ownerOf(_knightId) == msg.sender, "Not the owner.");

    (uint256 availablePoints, uint256 totalPoints) = getUpgradeAvailablePoints(
      _knightId
    );
    knightAttributes[_knightId].attributePointsDebt = uint16(totalPoints);
    knightAttributes[_knightId].attributePoints += uint16(availablePoints);
  }
}
