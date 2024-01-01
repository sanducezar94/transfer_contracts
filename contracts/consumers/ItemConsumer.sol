// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { Items } from "../items/Items.sol";

uint256 constant EQUIPMENT_OFFSET = 10e12;

interface IKPItemConsumer {
  function use(address _user, uint256[] memory _values) external;

  function isValid(uint256[] memory _values) external view;
}

contract ItemConsumer is Ownable, AccessControl {
  Items items;

  constructor(Items _items) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MODERATOR_ROLE, msg.sender);
    items = _items;
  }

  struct WhitelistItem {
    bool valid;
    uint256 itemId;
  }

  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  mapping(address => WhitelistItem) whitelist;
  mapping(uint256 => bool) public canMultiuse;

  function addToWhitelist(
    address _contract,
    uint256 _itemId
  ) public onlyRole(MODERATOR_ROLE) {
    whitelist[_contract] = WhitelistItem({ valid: true, itemId: _itemId });
  }

  function bulkAddToWhitelist(
    address[] calldata _contracts,
    uint256[] calldata _itemIds,
    bool[] calldata multiUse
  ) external onlyOwner {
    for (uint256 i = 0; i < _itemIds.length; i++) {
      addToWhitelist(_contracts[i], _itemIds[i]);
      canMultiuse[_itemIds[i]] = multiUse[i];
    }
  }

  function removeFromWhitelist(
    address _contract
  ) external onlyRole(MODERATOR_ROLE) {
    whitelist[_contract].valid = false;
  }

  function _resolveItemId(uint256 _tokenId) internal pure returns (uint256) {
    if (_tokenId > EQUIPMENT_OFFSET) {
      return _tokenId / EQUIPMENT_OFFSET;
    }
    return _tokenId;
  }

  function useItem(
    uint256 _tokenId,
    address _contract,
    uint256[] memory _values
  ) external {
    require(whitelist[_contract].valid, "Contract is not whitelisted.");

    uint256 itemId = _resolveItemId(_tokenId);
    require(itemId == whitelist[_contract].itemId, "Invalid item id.");

    IKPItemConsumer(_contract).isValid(_values);
    items.burn(msg.sender, itemId, 1);
    IKPItemConsumer(_contract).use(msg.sender, _values);
  }

  function useItems(
    uint256 _tokenId,
    address _contract,
    uint256[] memory _values,
    uint256 _amount
  ) external {
    require(whitelist[_contract].valid, "Contract is not whitelisted.");

    uint256 itemId = _resolveItemId(_tokenId);
    require(canMultiuse[itemId], "Item can not be multi used.");
    items.burn(msg.sender, _tokenId, _amount);
    require(itemId == whitelist[_contract].itemId, "Invalid item id.");

    for (uint256 i = 0; i < _amount; i++) {
      IKPItemConsumer(_contract).isValid(_values);
      IKPItemConsumer(_contract).use(msg.sender, _values);
    }
  }
}
