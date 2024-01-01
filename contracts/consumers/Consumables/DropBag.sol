// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { Items } from "../../items/Items.sol";

contract DropBag is Ownable {
  event EmitData(address user, uint256[4] data);

  constructor(Items _items, address _itemConsumer, uint256 _drops) {
    items = _items;
    ITEM_CONSUMER = _itemConsumer;
    ITEM_DROP_COUNT = _drops;
  }

  Items items;
  address immutable ITEM_CONSUMER;
  uint256 immutable ITEM_DROP_COUNT;

  uint256 nonce;

  uint256[] dropTable;
  uint256[] dropWeights;
  uint256 totalDropWeights;

  function bulkAddItemsToDropTable(
    uint256[] memory _itemIds,
    uint256[] memory _weights
  ) external onlyOwner {
    for (uint256 i = 0; i < _itemIds.length; ) {
      addItemToDropTable(_itemIds[i], _weights[i]);
      unchecked {
        i++;
      }
    }
  }

  function addItemToDropTable(
    uint256 _itemId,
    uint256 _weight
  ) public onlyOwner {
    dropTable.push(_itemId);
    dropWeights.push(_weight);
    totalDropWeights += _weight;
  }

  function clearDropTable() external onlyOwner {
    delete dropTable;
    delete dropWeights;
    totalDropWeights = 0;
  }

  function isValid(uint256[] memory _values) external view {
    //do nothing
  }

  function use(address _user, uint256[] memory _values) external {
    require(msg.sender == ITEM_CONSUMER); // CHECKER

    uint256 number = uint256(
      keccak256(
        abi.encodePacked(blockhash(block.number), nonce++, "PEASANTUSEITEM")
      )
    );

    uint256[] memory itemDrops = new uint256[](ITEM_DROP_COUNT);
    uint256[] memory itemAmounts = new uint256[](ITEM_DROP_COUNT);
    uint256 dropTableLength = dropTable.length;

    for (uint256 i = 0; i < ITEM_DROP_COUNT; ) {
      uint256 dropChance = (number >>= 8) % totalDropWeights;
      uint256 accruedChance = 0;
      for (uint256 j = 0; j < dropTableLength; ) {
        if (
          dropChance >= accruedChance &&
          dropChance < accruedChance + dropWeights[j]
        ) {
          itemDrops[i] = dropTable[j];
          itemAmounts[i] = 1;
        }
        accruedChance += dropWeights[j];
        unchecked {
          j++;
        }
      }
      unchecked {
        i++;
      }
    }

    items.mintItems(_user, itemDrops, itemAmounts);
  }
}
