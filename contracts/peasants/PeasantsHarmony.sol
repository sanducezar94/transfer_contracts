//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

interface IPeasantsHarmony {
  struct AttributeView {
    string attribute;
    uint256 value;
  }

  struct PeasantStats {
    uint8 profession;
    uint8 rarity;
    uint8 talent;
    uint8 labour;
    uint8 level;
  }

  function getData(
    uint256 _tokenId
  ) external view returns (uint8, uint8, AttributeView[] memory);

  function ownerOf(uint256 tokenId) external view returns (address);
}
