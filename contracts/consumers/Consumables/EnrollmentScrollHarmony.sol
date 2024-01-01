// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IPeasants {
  function mint(
    address _to,
    uint256 _amount,
    uint8[] memory _professionsRolled,
    uint8[] memory _raritiesRolled,
    uint8[] memory _bonusExpRolled,
    uint8[] memory _bonusWageRolled
  ) external;
}

contract EnrollmentScrollHarmony is Ownable {
  uint8[5] peasantRarities = [4, 3, 2, 1, 0];
  uint8[4] peasantTraitValues = [3, 2, 1, 0];
  uint8[4] peasantTraitsChances = [3, 11, 26, 60];
  uint8[5] peasantRaritiesChances = [1, 5, 10, 30, 55];

  uint8 constant PEASANT_RARITIES_COUNT = 5;
  uint8 constant PEASANT_TRAIT_COUNT = 4;

  uint8 peasantProfessionCount;
  uint256 nonce;

  address immutable peasantsAddress;
  address immutable ITEM_CONSUMER;

  event EmitData(address user, uint256[4] data);

  constructor(address _peasants, address _itemConsumer) {
    peasantsAddress = _peasants;
    peasantProfessionCount = 5;

    ITEM_CONSUMER = _itemConsumer;
  }

  function isValid(uint256[] memory _values) external view {
    require(_values.length == 1, "You must specify profession type.");
    require(_values[0] < peasantProfessionCount, "Invalid profession type.");
  }

  function use(address _user, uint256[] memory _values) external {
    require(msg.sender == ITEM_CONSUMER); // CHECKER

    uint256 number = uint256(
      keccak256(
        abi.encodePacked(blockhash(block.number), nonce++, "PEASANTUSEITEM")
      )
    );
    uint8 peasantProfession = uint8(_values[0]);
    uint8 peasantRarity = peasantRarities[
      _rollPeasantRarity((number >>= 8) % 100)
    ];
    uint8 peasantTalent = peasantTraitValues[
      _rollPeasantTrait((number >>= 8) % 100)
    ];
    uint8 peasantLabour = peasantTraitValues[
      _rollPeasantTrait((number >>= 8) % 100)
    ];

    uint8[] memory _professionsRolled = new uint8[](1);
    _professionsRolled[0] = peasantProfession;
    uint8[] memory _raritiesRolled = new uint8[](1);
    _raritiesRolled[0] = peasantRarity;
    uint8[] memory _bonusExpRolled = new uint8[](1);
    _bonusExpRolled[0] = peasantTalent;
    uint8[] memory _bonusWageRolled = new uint8[](1);
    _bonusWageRolled[0] = peasantLabour;

    IPeasants(peasantsAddress).mint(
      _user,
      1,
      _professionsRolled,
      _raritiesRolled,
      _bonusExpRolled,
      _bonusWageRolled
    );
  }

  function _rollPeasantRarity(uint256 _chance) private view returns (uint8) {
    uint256 accruedChance = 0;
    for (uint8 i = 0; i < peasantRaritiesChances.length; ) {
      if (
        _chance >= accruedChance &&
        _chance < accruedChance + peasantRaritiesChances[i]
      ) {
        return i;
      }
      accruedChance += peasantRaritiesChances[i];
      unchecked {
        i++;
      }
    }

    return uint8(peasantRaritiesChances.length - 1);
  }

  function _rollPeasantTrait(uint256 _chance) private view returns (uint8) {
    uint256 accruedChance = 0;
    for (uint8 i = 0; i < peasantTraitValues.length; ) {
      if (
        _chance >= accruedChance &&
        _chance < accruedChance + peasantTraitsChances[i]
      ) {
        return i;
      }
      accruedChance += peasantTraitsChances[i];
      unchecked {
        i++;
      }
    }

    return uint8(peasantTraitsChances.length - 1);
  }

  function setProfessionCount(uint8 _value) external onlyOwner {
    peasantProfessionCount = _value;
  }
}
