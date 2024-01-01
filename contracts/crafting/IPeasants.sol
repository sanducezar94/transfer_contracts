// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct PeasantStats {
    uint8 profession;
    uint8 rarity;
    uint8 talent;
    uint8 labour;
    uint8 level;
}

interface IPeasants {
    function getAttributes(
    uint256 _tokenId
  ) external view returns (PeasantStats memory);

  function increaseAttribute(
    uint256 _tokenId,
    uint8 _attributeIndex,
    uint8 _value
  ) external;

  function ownerOf(uint256 _tokenId) external view returns(address);

  function increaseAttributeLevel(uint256 _tokenId, string memory _attribute, uint256 _amount) external;
}