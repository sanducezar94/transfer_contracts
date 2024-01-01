// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

struct AttributeView {
    string attribute;
    uint256 value;
}

interface IPeasants {
    function getData(uint256 _tokenId) external view returns (uint8, uint8, AttributeView[] memory);
    function ownerOf(uint256 _ownerOf) external view returns(address);
}

contract PeasantTranslater {
    address peasantsAddress;

    struct PeasantStats {
        uint8 profession;
        uint8 rarity;
        uint8 talent;
        uint8 labour;
        uint8 level;
    }

    constructor(address _peasantsAddress) {
        peasantsAddress = _peasantsAddress;
    }

    function _getPeasantStat(uint256 _value) internal pure returns(uint8) {
        if(_value == 1e18) return 0;
        if(_value == 1.1e18) return 1;
        if(_value == 1.2e18) return 2;
        return 3;
    }

    function getAttributes(uint256 _tokenId) external view returns (PeasantStats memory stats) {
       (uint8 profession, uint8 rarity, AttributeView[] memory attributes) = IPeasants(peasantsAddress).getData(_tokenId);

        stats.profession = profession;
        stats.rarity = rarity;
        stats.level = uint8(attributes[3].value);

        stats.labour = _getPeasantStat(attributes[1].value);
        stats.talent = _getPeasantStat(attributes[0].value);
    }

    function ownerOf(uint256 _tokenId) external view returns(address) {
        return IPeasants(peasantsAddress).ownerOf(_tokenId);
    }

}