// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../constants.sol";

interface IPeasants {
  struct PeasantStats {
    uint8 profession;
    uint8 rarity;
    uint8 talent;
    uint8 labour;
    uint8 level;
  }

  function bulkMint(
    address _to,
    uint256 _amount,
    uint8[] memory _professionsRolled,
    uint8[] memory _raritiesRolled,
    uint8[] memory _bonusExpRolled,
    uint8[] memory _bonusWageRolled
  ) external;

  function getAttributes(
    uint256 _tokenId
  ) external view returns (PeasantStats memory);

  function getAttributesBulk(
    uint256[] memory _tokenIds
  ) external view returns (PeasantStats[] memory data);

  function isOwnerOf(
    address _owner,
    uint256[] calldata ids
  ) external view returns (bool);
  // function getAttributes(uint256 _tokenId) external view returns (uint8[MAX_STATS] memory);
}

contract Peasants is ERC721, AccessControl, IPeasants {
  using Counters for Counters.Counter;
  using Strings for uint256;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PEASANT_EDITOR_ROLE =
    keccak256("PEASANT_EDITOR_ROLE");

  Counters.Counter private tokenIdCounter;
  string private baseUri;

  mapping(uint256 => PeasantStats) stats;

  error PeasantDoesNotExist();

  event PeasantMinted(
    uint256 indexed tokenId,
    address indexed minter,
    uint8 profession,
    uint8 rarity,
    uint8 talent,
    uint8 labour
  );
  event PeasantAttributeSet(uint256 tokenId, uint8 attributeIndex, uint8 value);

  constructor() ERC721("K&P Peasants", "PEASANT") {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MINTER_ROLE, msg.sender);

    baseUri = "https://api.knightsandpeasants.one/matic/api/peasant?id=";
  }

  function setBaseUri(string memory uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
    baseUri = uri;
  }

  function mint(
    address _to,
    uint8 _profession,
    uint8 _rarity,
    uint8 _talent,
    uint8 _labour
  ) external onlyRole(MINTER_ROLE) {
    uint256 _tokenId = tokenIdCounter.current();
    tokenIdCounter.increment();
    _safeMint(_to, _tokenId);

    stats[_tokenId].rarity = _rarity;
    stats[_tokenId].profession = _profession;
    stats[_tokenId].talent = _talent;
    stats[_tokenId].labour = _labour;

    emit PeasantMinted(_tokenId, _to, _profession, _rarity, _talent, _labour);
  }

  function bulkMint(
    address _to,
    uint256 _amount,
    uint8[] memory _professionsRolled,
    uint8[] memory _raritiesRolled,
    uint8[] memory _talentsRolled,
    uint8[] memory _laboursRolled
  ) external onlyRole(MINTER_ROLE) {
    for (uint256 i = 0; i < _amount; i++) {
      uint256 _tokenId = tokenIdCounter.current();
      tokenIdCounter.increment();
      _safeMint(_to, _tokenId);

      // roll the profession based on the available keys
      stats[_tokenId].rarity = _raritiesRolled[i];
      stats[_tokenId].profession = _professionsRolled[i];
      stats[_tokenId].talent = _talentsRolled[i];
      stats[_tokenId].labour = _laboursRolled[i];

      emit PeasantMinted(
        _tokenId,
        _to,
        _professionsRolled[i],
        _raritiesRolled[i],
        _talentsRolled[i],
        _laboursRolled[i]
      );
    }
  }

  function increaseAttribute(
    uint256 _tokenId,
    uint8 _attributeIndex,
    uint8 _value
  ) external onlyRole(PEASANT_EDITOR_ROLE) {
    if (_attributeIndex == STAT_TALENT) {
      stats[_tokenId].talent += _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].talent
      );
    } else if (_attributeIndex == STAT_LABOUR) {
      stats[_tokenId].labour += _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].labour
      );
    } else if (_attributeIndex == STAT_LEVEL) {
      stats[_tokenId].level += _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].level
      );
    }
  }

  function decreaseAttribute(
    uint256 _tokenId,
    uint8 _attributeIndex,
    uint8 _value
  ) external onlyRole(PEASANT_EDITOR_ROLE) {
    if (_attributeIndex == STAT_TALENT) {
      stats[_tokenId].talent -= _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].talent
      );
    } else if (_attributeIndex == STAT_LABOUR) {
      stats[_tokenId].labour -= _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].labour
      );
    } else if (_attributeIndex == STAT_LEVEL) {
      stats[_tokenId].level -= _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].level
      );
    }
  }

  function setAttribute(
    uint256 _tokenId,
    uint8 _attributeIndex,
    uint8 _value
  ) external onlyRole(PEASANT_EDITOR_ROLE) {
    if (_attributeIndex == STAT_TALENT) {
      stats[_tokenId].talent = _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].talent
      );
    } else if (_attributeIndex == STAT_LABOUR) {
      stats[_tokenId].labour = _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].labour
      );
    } else if (_attributeIndex == STAT_LEVEL) {
      stats[_tokenId].level = _value;
      emit PeasantAttributeSet(
        _tokenId,
        _attributeIndex,
        stats[_tokenId].level
      );
    }
  }

  function getAttribute(
    uint256 _tokenId,
    uint256 _attributeIndex
  ) external view returns (uint8) {
    if (_attributeIndex == STAT_TALENT) {
      return stats[_tokenId].talent;
    } else if (_attributeIndex == STAT_LABOUR) {
      return stats[_tokenId].labour;
    } else if (_attributeIndex == STAT_LEVEL) {
      return stats[_tokenId].level;
    } else if (_attributeIndex == STAT_PROFESSION) {
      return stats[_tokenId].profession;
    } else if (_attributeIndex == STAT_RARITY) {
      return stats[_tokenId].rarity;
    }

    return 0;
  }

  function getAttributes(
    uint256 _tokenId
  ) public view returns (PeasantStats memory) {
    return stats[_tokenId];
  }

  function getAttributesBulk(
    uint256[] memory _tokenIds
  ) external view returns (PeasantStats[] memory data) {
    for (uint256 i = 0; i < _tokenIds.length; ) {
      data[i] = getAttributes(_tokenIds[i]);
      unchecked {
        i++;
      }
    }
  }

  function isOwnerOf(
    address _owner,
    uint256[] calldata ids
  ) external view returns (bool) {
    unchecked {
      for (uint256 index = 0; index < ids.length; index++) {
        if (ownerOf(ids[index]) != _owner) return false;
      }
    }

    return true;
  }

  function tokenURI(
    uint256 tokenId
  ) public view override(ERC721) returns (string memory) {
    require(_exists(tokenId), "Token does not exist yet");
    return string(abi.encodePacked(baseUri, uint256(tokenId).toString()));
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC721, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
