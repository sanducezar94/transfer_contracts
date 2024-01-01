// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract KnightAttributeManagerOld is AccessControl {
    struct AttributeInfo {
        uint256 health;
        uint256 attack;
        uint256 defense;
        uint256 speed;
        uint256 charisma;
        uint256[2] boostedStats;
        uint256 attributePoints;
        uint256 attributePointsDebt;
        uint256 attributePointsTotal;
    }

    constructor(address _knightAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MODERATOR_ROLE, msg.sender);
        knightAddress = _knightAddress;
    }

    mapping(uint256 => AttributeInfo) public knightAttributes;
    mapping(uint256 => AttributeInfo) public knightOriginalAttributes;

    mapping(uint256 => uint256[]) public boostedWeights;

    address public knightAddress;

    uint256 nonce;
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    event AttributeIncrease(uint256 knightId, uint256 totalPoints, uint256[5] values, uint256[5] finalValues);
    event KnightBless(uint256 knightId, uint256 attributeIndex, uint256 points);
    event KnightReset(uint256 knightId, uint256 points);

    function bulkSetKnightAttribute(uint256[] memory _knightIds, AttributeInfo[] memory _attributes)
        external
        onlyRole(MODERATOR_ROLE)
    {
        uint256 length = _knightIds.length;
        for (uint256 i = 0; i < length;) {
            setKnightAttributes(_knightIds[i], _attributes[i]);
            unchecked {
                i++;
            }
        }
    }

    function bulkSetKnightInitialAttribute(uint256[] memory _knightIds, AttributeInfo[] memory _attributes)
        external
        onlyRole(MODERATOR_ROLE)
    {
        uint256 length = _knightIds.length;
        for (uint256 i = 0; i < length;) {
            setKnightInitialAttributes(_knightIds[i], _attributes[i]);
            unchecked {
                i++;
            }
        }
    }

    function setKnightAttributes(uint256 _knightId, AttributeInfo memory _attributes) public onlyRole(MODERATOR_ROLE) {
        knightAttributes[_knightId] = _attributes;
    }

    function setKnightInitialAttributes(uint256 _knightId, AttributeInfo memory _attributes)
        public
        onlyRole(MODERATOR_ROLE)
    {
        knightOriginalAttributes[_knightId] = _attributes;
    }

    function blessKnight(uint256 _knightId, uint256 _attributeIndex, uint256 _value)
        external
        onlyRole(MODERATOR_ROLE)
    {
        AttributeInfo memory _knightAttributes = knightAttributes[_knightId];

        uint256[8] memory randomNumbers = _getRandomSet(nonce++);
        uint256 chance = 20
            * (
                _convertBool(_knightAttributes.boostedStats[0] == _attributeIndex)
                    + _convertBool(_knightAttributes.boostedStats[1] == _attributeIndex)
            );
        uint256 pointValue = randomNumbers[0] % 100 <= chance ? _value + 1 : _value;

        knightAttributes[_knightId].attributePointsTotal += pointValue;
        increaseKnightAttribute(_knightId, _attributeIndex, pointValue);

        emit KnightBless(_knightId, _attributeIndex, pointValue);
    }

    function setKnightAttribute(uint256 _knightId, uint256 _attributeIndex, uint256 _value)
        external
        onlyRole(MODERATOR_ROLE)
    {
        if (_attributeIndex == 0) {
            knightAttributes[_knightId].health = _value;
        } else if (_attributeIndex == 1) {
            knightAttributes[_knightId].attack = _value;
        } else if (_attributeIndex == 2) {
            knightAttributes[_knightId].defense = _value;
        } else if (_attributeIndex == 3) {
            knightAttributes[_knightId].speed = _value;
        } else if (_attributeIndex == 4) {
            knightAttributes[_knightId].charisma = _value;
        }
    }

    function increaseKnightAttribute(uint256 _knightId, uint256 _attributeIndex, uint256 _value)
        public
        onlyRole(MODERATOR_ROLE)
    {
        if (_attributeIndex == 0) {
            knightAttributes[_knightId].health += _value * 10;
        } else if (_attributeIndex == 1) {
            knightAttributes[_knightId].attack += _value;
        } else if (_attributeIndex == 2) {
            knightAttributes[_knightId].defense += _value;
        } else if (_attributeIndex == 3) {
            knightAttributes[_knightId].speed += _value;
        } else if (_attributeIndex == 4) {
            knightAttributes[_knightId].charisma += _value;
        }
    }

    function resetStats(uint256 _knightId) public onlyRole(MODERATOR_ROLE) {
        AttributeInfo storage _knightAttributes = knightAttributes[_knightId];
        AttributeInfo memory _knightOriginalAttributes = knightOriginalAttributes[_knightId];

        _knightAttributes.health = _knightOriginalAttributes.health;
        _knightAttributes.defense = _knightOriginalAttributes.defense;
        _knightAttributes.attack = _knightOriginalAttributes.attack;
        _knightAttributes.speed = _knightOriginalAttributes.speed;
        _knightAttributes.charisma = _knightOriginalAttributes.charisma;
        _knightAttributes.attributePoints += _knightAttributes.attributePointsTotal;
        _knightAttributes.attributePointsTotal = 0;

        emit KnightReset(_knightId, _knightAttributes.attributePoints);
    }

    function allocateAttributePoints(uint256 _knightId, uint256[5] memory _values) public {
        uint256 totalPoints = _values[0] + _values[1] + _values[2] + _values[3] + _values[4];
        AttributeInfo memory _knightAttributes = knightAttributes[_knightId];

        bool isModerator = hasRole(MODERATOR_ROLE, msg.sender);
        require(isModerator || IERC721(knightAddress).ownerOf(_knightId) == msg.sender, "Not the owner.");
        require(isModerator || totalPoints <= _knightAttributes.attributePoints, "Not enough skill points.");

        uint256[5] memory finalValues = _calculateBoostedStats(_knightId, _values);

        _knightAttributes.health += finalValues[0] * 10;
        _knightAttributes.attack += finalValues[1];
        _knightAttributes.defense += finalValues[2];
        _knightAttributes.speed += finalValues[3];
        _knightAttributes.charisma += finalValues[4];

        if (!isModerator) {
            _knightAttributes.attributePoints -= totalPoints;
        }
        _knightAttributes.attributePointsTotal += totalPoints;

        knightAttributes[_knightId] = _knightAttributes;

        emit AttributeIncrease(_knightId, totalPoints, _values, [uint256(0), 0, 0, 0, 0]);
    }

    function _calculateBoostedStats(uint256 _knightId, uint256[5] memory _values)
        private
        returns (uint256[5] memory finalValues)
    {
        AttributeInfo memory _knightAttributes = knightAttributes[_knightId];

        for (uint256 i = 0; i < _values.length; i++) {
            uint256 percentageChance = 20
                * (
                    _convertBool(_knightAttributes.boostedStats[0] == i)
                        + _convertBool(_knightAttributes.boostedStats[1] == i)
                );

            if (percentageChance == 0 || percentageChance > 40) {
                finalValues[i] = _values[i];
                continue;
            }
            finalValues[i] += _getBoostedStat(_values[i], percentageChance);
        }

        return finalValues;
    }

    function _getBoostedStat(uint256 stats, uint256 _percentageChance) private returns (uint256) {
        uint256[8] memory randomNumbers = _getRandomSet(nonce++);
        uint256 totalStats = stats;
        for (uint256 i = 0; i < stats;) {
            if (randomNumbers[i % 8] % 100 <= _percentageChance) {
                totalStats++;
            }

            if (i % 8 == 0) {
                randomNumbers = _getRandomSet(nonce++);
            }
            unchecked {
                i++;
            }
        }

        return totalStats;
    }

    function _convertBool(bool a) private pure returns (uint8) {
        if (a == true) return 1;
        return 0;
    }

    function giveAttributePoints(uint256 _knightId, uint256 _points) external onlyRole(MODERATOR_ROLE) {
        knightAttributes[_knightId].attributePoints += _points;
    }

    function getKnightAttributes(uint256 _knightId) public view returns (AttributeInfo memory) {
        return knightAttributes[_knightId];
    }

    function getKnightsAttributes(uint256[] memory _knightsIds) external view returns (AttributeInfo[] memory) {
        AttributeInfo[] memory _attributes = new AttributeInfo[](_knightsIds.length);

        for (uint256 i = 0; i < _knightsIds.length;) {
            _attributes[i] = getKnightAttributes(_knightsIds[i]);
            unchecked {
                i++;
            }
        }

        return _attributes;
    }

    function _getRandomSet(uint256 _nonce) private view returns (uint256[8] memory) {
        uint256 number = uint256(keccak256(abi.encodePacked(blockhash(block.number), _nonce, "POLGYONKNIGHTATTR")));
        return [
            number,
            (number >> 8),
            (number >> 16),
            (number >> 24),
            (number >> 32),
            (number >> 40),
            (number >> 48),
            (number >> 56)
        ];
    }
}
