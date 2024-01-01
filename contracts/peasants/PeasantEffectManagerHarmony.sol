// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PeasantsHarmony.sol";
import "../Stats.sol";

abstract contract PeasantEffectManagerHarmony is Ownable {
  using StatsMath for Stats;

  mapping(uint8 => Stats) public effects;
  uint16[5] public rarityAmplifier;
  uint16[6] public skillAmplifier;

  function _getPeasantAttributes(
    uint256
  )
    internal
    view
    virtual
    returns (IPeasantsHarmony.PeasantStats memory attributes);

  function getPeasantProfessionEffect(
    uint8 _profession
  ) public view returns (Stats memory) {
    return effects[_profession];
  }

  function setPeasantEffect(
    uint8 _professionId,
    Stats calldata _peasantEffect
  ) external onlyOwner {
    effects[_professionId] = _peasantEffect;
  }

  function setPeasantRarityMultipliers(
    uint16[5] calldata _rarityAmplifier
  ) external onlyOwner {
    rarityAmplifier = _rarityAmplifier;
  }

  function setPeasantSkillMultipliers(
    uint16[6] calldata _skillMultipliers
  ) external onlyOwner {
    skillAmplifier = _skillMultipliers;
  }

  function getPeasantRarityMultipliers()
    public
    view
    returns (uint16[5] memory)
  {
    return rarityAmplifier;
  }

  function getPeasantSkillMultipliers() public view returns (uint16[6] memory) {
    return skillAmplifier;
  }

  function getPeasantEffect(
    uint256 tokenId
  ) public view returns (Stats memory peasantEffects) {
    IPeasantsHarmony.PeasantStats memory attributes = _getPeasantAttributes(
      tokenId
    );
    uint16 amplifier = skillAmplifier[attributes.level] +
      rarityAmplifier[attributes.rarity];
    peasantEffects = effects[attributes.profession];
    return
      Stats({
        health: uint16((amplifier * peasantEffects.health) / 10),
        attack: uint16((amplifier * peasantEffects.attack) / 10),
        defense: uint16((amplifier * peasantEffects.defense) / 10),
        speed: uint16((amplifier * peasantEffects.speed) / 10),
        charisma: uint16((amplifier * peasantEffects.charisma) / 10),
        effectiveness: uint16((amplifier * peasantEffects.effectiveness) / 10)
      });
  }

  function getPeasantsEffects(
    uint256[] memory tokenIds
  ) public view returns (Stats memory peasantsEffects) {
    for (uint256 index = 0; index < tokenIds.length; index++) {
      if (tokenIds[index] == 0) continue;
      peasantsEffects = peasantsEffects.add(getPeasantEffect(tokenIds[index]));
    }
  }
}
