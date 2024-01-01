// contracts/GameItems.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "../Stats.sol";

enum ItemType {
  EQUIPMENT,
  CRAFTING_MATERIAL,
  CONSUMABLE
}

uint256 constant ITEM_MAX_LEVEL = 5;

contract Items is ERC1155, AccessControl {
  using StatsMath for Stats;
  using Strings for uint256;

  bytes32 public constant ITEM_MINTER_ROLE = keccak256("ITEM_MINTER_ROLE");
  bytes32 public constant ITEM_BURNER_ROLE = keccak256("ITEM_BURNER_ROLE");
  bytes32 public constant ITEM_EDITOR_ROLE = keccak256("ITEM_EDITOR_ROLE");

  uint256 nextNftId = 1;
  uint256 constant NON_FUNGIBLE_OFFSET = 10e12;

  struct Item {
    ItemType itemType;
    uint8 level;
    uint8 durability;
    uint256 price;
  }

  mapping(uint256 => Item) items;
  mapping(uint256 => Stats[ITEM_MAX_LEVEL]) effects;

  bool public isPaused;

  constructor()
    ERC1155("https://api.kandp.one/matic/api/erc1555items?id={id}")
  {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(ITEM_MINTER_ROLE, msg.sender);
    _grantRole(ITEM_BURNER_ROLE, msg.sender);
    _grantRole(ITEM_EDITOR_ROLE, msg.sender);
  }

  function isOwnerOf(
    address _owner,
    uint256[] calldata ids
  ) external view returns (bool) {
    unchecked {
      for (uint256 index = 0; index < ids.length; index++) {
        if (balanceOf(_owner, ids[index]) > 0) return false;
      }
    }
    return true;
  }

  function setPauseStatus(bool _status) public onlyRole(DEFAULT_ADMIN_ROLE) {
    isPaused = _status;
  }

  function setURI(
    string memory newuri
  ) public onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
    _setURI(newuri);
    return true;
  }

  function setItems(
    uint256[] calldata _itemIds,
    ItemType[] calldata itemTypes,
    uint256[] calldata prices,
    Stats[][] memory _effects
  ) external {
    for (uint256 i = 0; i < itemTypes.length; i++) {
      setItem(_itemIds[i], itemTypes[i], prices[i], _effects[i]);
    }
  }

  function setItem(
    uint256 _itemId,
    ItemType itemType,
    uint256 price,
    Stats[] memory _effects
  ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    items[_itemId].itemType = itemType;
    items[_itemId].price = price;

    for (uint256 i = 0; i < _effects.length; i++) {
      effects[_itemId][i] = _effects[i];
    }
  }

  function _validateMint(
    uint256 itemId,
    uint256 amount
  ) internal returns (uint256 tokenId) {
    if (items[itemId].itemType == ItemType.EQUIPMENT) {
      tokenId = (itemId * NON_FUNGIBLE_OFFSET) + nextNftId++;
      require(amount == 1);
    } else {
      tokenId = itemId;
    }
  }

  function mintItem(
    address _to,
    uint256 itemId,
    uint256 amount
  ) external onlyRole(ITEM_MINTER_ROLE) {
    itemId = _validateMint(itemId, amount);
    _mint(_to, itemId, amount, new bytes(0));
  }

  function mintItems(
    address _to,
    uint256[] memory _itemIds,
    uint256[] calldata _itemAmounts
  ) external onlyRole(ITEM_MINTER_ROLE) {
    for (uint256 i = 0; i < _itemIds.length; i++) {
      if (_itemAmounts[i] == 0) continue;
      _itemIds[i] = _validateMint(_itemIds[i], _itemAmounts[i]);
    }

    _mintBatch(_to, _itemIds, _itemAmounts, new bytes(0));
  }

  event SetItemAttributes(uint256 tokenId, uint8 _level, uint8 durability);
  event SetLevel(uint256 tokenId, uint8 level);
  event SetDurability(uint256 tokenId, uint8 durability);

  function getAttributes(uint256 _tokenId) public view returns (uint8, uint8) {
    return (items[_tokenId].level, items[_tokenId].durability);
  }

  function setAttributes(
    uint256 _tokenId,
    uint8 _level,
    uint8 _durability
  ) public onlyRole(ITEM_EDITOR_ROLE) {
    items[_tokenId].level = _level;
    items[_tokenId].durability = _durability;

    emit SetItemAttributes(_tokenId, _level, _durability);
  }

  function setLevel(
    uint256 _tokenId,
    uint8 _level
  ) external onlyRole(ITEM_EDITOR_ROLE) {
    items[_tokenId].level = _level;

    emit SetLevel(_tokenId, _level);
  }

  function setDurability(
    uint256 _tokenId,
    uint8 _durability
  ) external onlyRole(ITEM_EDITOR_ROLE) {
    items[_tokenId].durability = _durability;

    emit SetDurability(_tokenId, _durability);
  }

  function bulkSetAttributes(
    uint256[] calldata _tokenIds,
    uint8[] calldata _levels,
    uint8[] calldata _durabilities
  ) external onlyRole(ITEM_EDITOR_ROLE) {
    unchecked {
      for (uint256 i = 0; i < _tokenIds.length; i++) {
        setAttributes(_tokenIds[i], _levels[i], _durabilities[i]);
      }
    }
  }

  function _pointTokenToItemId(uint256 _tokenId) internal pure returns (uint8) {
    return
      _tokenId >= NON_FUNGIBLE_OFFSET
        ? uint8(_tokenId / NON_FUNGIBLE_OFFSET)
        : uint8(_tokenId);
  }

  function getItemsType(
    uint256[] calldata _tokenIds
  ) external view returns (ItemType[] memory types) {
    types = new ItemType[](_tokenIds.length);
    for (uint256 index = 0; index < _tokenIds.length; index++) {
      uint256 _itemId = _pointTokenToItemId(_tokenIds[index]);
      types[index] = items[_itemId].itemType;
    }
  }

  function getItemsPrice(
    uint256[] calldata _tokenIds
  ) external view returns (uint256[] memory prices) {
    prices = new uint256[](_tokenIds.length);
    for (uint256 index = 0; index < _tokenIds.length; index++) {
      uint256 _itemId = _pointTokenToItemId(_tokenIds[index]);
      prices[index] = items[_itemId].price;
    }
  }

  function getItemsLevels(
    uint256[] calldata _tokenIds
  ) public view returns (uint8[] memory levels) {
    levels = new uint8[](_tokenIds.length);
    for (uint256 index = 0; index < _tokenIds.length; index++) {
      levels[index] = items[_tokenIds[index]].level;
    }
  }

  function getItemsDurability(
    uint256[] calldata _tokenIds
  ) external view returns (uint8[] memory durabilities) {
    durabilities = new uint8[](_tokenIds.length);
    for (uint256 index = 0; index < _tokenIds.length; index++) {
      durabilities[index] = items[_tokenIds[index]].durability;
    }
  }

  function getEffects(
    uint256 _tokenId
  ) public view returns (Stats[ITEM_MAX_LEVEL] memory) {
    uint256 _itemId = _pointTokenToItemId(_tokenId);
    return effects[_itemId];
  }

  function getItemsEffectsTotal(
    uint256[] calldata _tokenIds,
    uint256[] calldata _amounts
  ) public view returns (Stats memory stats) {
    uint8[] memory _levels = getItemsLevels(_tokenIds);
    for (uint256 index = 0; index < _tokenIds.length; index++) {
      uint256 tokenId = _pointTokenToItemId(_tokenIds[index]);
      stats = stats.add(
        effects[tokenId][_levels[index]].mul(uint16(_amounts[index]))
      );
    }
  }

  function getEffectsForLevel(
    uint256 _tokenId,
    uint256 _level
  ) public view returns (Stats memory) {
    uint256 _itemId = _pointTokenToItemId(_tokenId);
    return effects[_itemId][_level];
  }

  function burnBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
  ) public onlyRole(ITEM_BURNER_ROLE) {
    _burnBatch(to, ids, amounts);
  }

  function burn(
    address to,
    uint256 id,
    uint256 amount
  ) public onlyRole(ITEM_BURNER_ROLE) {
    _burn(to, id, amount);
  }

  function _beforeTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal virtual override {
    require(!isPaused, "ERC1155: Transfers are paused.");
    super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
  }

  function supportsInterface(
    bytes4 interfaceId
  ) public view override(ERC1155, AccessControl) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
