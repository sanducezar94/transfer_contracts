//SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/FeeTakersETH.sol";

interface KPItems {
  function getItemsPrice(
    uint256[] calldata _tokenIds
  ) external view returns (uint256[] memory prices);

  function mintItems(
    address _to,
    uint256[] memory _itemIds,
    uint256[] calldata _itemAmounts
  ) external;

  function burnBatch(
    address to,
    uint256[] memory ids,
    uint256[] memory amounts
  ) external;
}

interface KNPToken {
  function mint(address _to, uint256 _amount) external;
}

interface KNPBadge {
  function purchasedBadge(address _user) external view returns (bool);
}

function resizeArr(uint256[] memory arr, uint256 size) pure {
  assembly {
    mstore(arr, size)
  }
}

struct ItemAmounts {
  uint256[] ids;
  uint256[] amounts;
  uint256 total;
}

library ItemAmountsLib {
  function init(uint256 size) internal pure returns (ItemAmounts memory items) {
    items.ids = new uint256[](size);
    items.amounts = new uint256[](size);
  }

  function insert(
    ItemAmounts memory items,
    uint256 itemId,
    uint256 index
  ) internal pure returns (uint256) {
    bool found;
    for (uint256 k = 0; k < index; k++) {
      if (items.ids[k] == itemId) {
        found = true;
        items.amounts[k]++;
      }
    }

    if (!found) {
      items.ids[index] = itemId;
      items.amounts[index] = 1;
      index++;
    }
    return index;
  }

  function resize(ItemAmounts memory items, uint256 size) internal pure {
    resizeArr(items.ids, size);
    resizeArr(items.amounts, size);
  }
}

contract Vendors is AccessControl, Payments {
  using SafeERC20 for IERC20;
  using ItemAmountsLib for ItemAmounts;

  struct UserData {
    uint256 lastReroll;
    uint8 rerollCount;
    ItemAmounts stock;
  }

  struct DropTable {
    uint32[] itemIds;
    uint16 totalItems;
  }

  constructor(
    address _itemsAddress,
    address _knpAddress,
    address _badgeAddress
  ) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

    itemsAddress = _itemsAddress;
    knpAddress = _knpAddress;
    badgeAddress = _badgeAddress;
  }

  address immutable DEAD_ADDRESS =
    address(0x000000000000000000000000000000000000dEaD);
  address immutable itemsAddress;
  address immutable knpAddress;
  address immutable badgeAddress;

  mapping(uint8 => DropTable) professionTables;
  mapping(address => UserData) users;

  uint8 constant COMMON_RARITY = 1;
  uint8 constant RARE_RARITY = 2;
  uint8 constant LEGENDARY_RARITY = 3;

  uint256 nonce;
  uint8 STOCK_SIZE = 20;

  uint256 BASE_REROLL_PRICE = 0.05e18;
  uint256 REROLL_INCREMENT_PRICE = 0.05e18;
  uint256 REROLL_COOLDOWN = 1 days;

  uint256 SELL_RATIO = 4;

  function _getRandomNumber(uint256 _nonce) internal view returns (uint256) {
    return
      uint256(
        keccak256(
          abi.encodePacked(
            blockhash(block.number),
            _nonce,
            "VENDORREROLLRANDOM"
          )
        )
      );
  }

  function setRerollPrices(
    uint256 _value,
    uint256 _incrementValue
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    BASE_REROLL_PRICE = _value;
    REROLL_INCREMENT_PRICE = _incrementValue;
  }

  function _getRarity(uint256 _chance) internal pure returns (uint8) {
    if (_chance <= 1) return LEGENDARY_RARITY;
    if (_chance > 1 && _chance <= 10) return RARE_RARITY;
    return COMMON_RARITY;
  }

  function setPayees(
    Payments.Payee[] memory payees
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setPayees(payees);
  }

  function setStockSize(uint8 _size) external {
    STOCK_SIZE = _size;
  }

  function setProfessionStock(
    uint8 _rarity,
    uint32[] calldata _itemIds
  ) external {
    professionTables[_rarity] = DropTable(_itemIds, uint16(_itemIds.length));
  }

  function _getDropsOfRarity(
    ItemAmounts memory _stockItems,
    uint8 _rarityType,
    uint8 _count,
    uint256 _index
  ) internal returns (uint256) {
    DropTable memory drops = professionTables[_rarityType];
    uint256 number = _getRandomNumber(nonce++);

    uint256 numberOfItems = _index;

    for (uint256 i = 0; i < _count; i++) {
      uint256 itemIndex = (number >>= 8) % drops.totalItems;
      numberOfItems = _stockItems.insert(
        drops.itemIds[itemIndex],
        numberOfItems
      );
    }

    return numberOfItems - _index;
  }

  function rerollStock(address _user) external payable {
    require(
      KNPBadge(badgeAddress).purchasedBadge(_user),
      "You must purchase a Badge first!"
    );
    uint256 rerollPrice = getRerollPrice(_user);

    UserData storage userData = users[_user];

    if (rerollPrice == 0) {
      userData.lastReroll = block.timestamp;
      userData.rerollCount = 0;
      userData.stock = _getVendorStock();
    } else {
      require(msg.value >= rerollPrice, "Invalid transaction value.");
      _makePayment(msg.value);
      userData.rerollCount++;
      userData.stock = _getVendorStock();
    }
  }

  function buyBasket(
    uint256[] calldata itemIndexes,
    uint256[] calldata itemAmounts
  ) external {
    ItemAmounts memory stock = users[msg.sender].stock;
    uint256 basketValue;

    uint256[] memory itemIds = new uint256[](itemIndexes.length);
    for (uint256 i = 0; i < itemIndexes.length; i++) {
      itemIds[i] = stock.ids[itemIndexes[i]];
    }

    uint256[] memory itemPrices = KPItems(itemsAddress).getItemsPrice(itemIds);

    for (uint256 i = 0; i < itemIndexes.length; i++) {
      uint256 slot = itemIndexes[i];
      require(stock.amounts[slot] >= itemAmounts[i], "Out of stock.");
      basketValue += itemAmounts[i] * itemPrices[i];
      stock.amounts[slot] -= itemAmounts[i];
    }

    users[msg.sender].stock = stock;

    IERC20(knpAddress).safeTransferFrom(msg.sender, address(this), basketValue);
    KPItems(itemsAddress).mintItems(msg.sender, itemIds, itemAmounts);
  }

  function sellItems(
    uint256[] calldata itemIds,
    uint256[] calldata itemAmounts
  ) external {
    uint256[] memory itemPrices = KPItems(itemsAddress).getItemsPrice(itemIds);
    uint256 totalValue;

    for (uint256 i = 0; i < itemIds.length; i++) {
      totalValue += itemPrices[i] * itemAmounts[i];
    }

    KPItems(itemsAddress).burnBatch(msg.sender, itemIds, itemAmounts);
    IERC20(knpAddress).transfer(msg.sender, totalValue / SELL_RATIO);
  }

  function getBasketPrice(
    uint256[] calldata itemIndexes,
    uint256[] calldata itemAmounts
  ) external view returns (uint256 basketValue) {
    ItemAmounts memory stock = users[msg.sender].stock;

    uint256[] memory itemIds = new uint256[](itemIndexes.length);
    for (uint256 i = 0; i < itemIndexes.length; i++) {
      itemIds[i] = stock.ids[i];
    }

    uint256[] memory itemPrices = KPItems(itemsAddress).getItemsPrice(itemIds);
    for (uint256 i = 0; i < itemIndexes.length; i++) {
      basketValue += itemAmounts[i] * itemPrices[i];
    }
  }

  function _getVendorStock() internal returns (ItemAmounts memory stockItems) {
    uint256 number = _getRandomNumber(5 + nonce++);

    uint8 commonItems;
    uint8 rareItems;
    uint8 legendaryItems;

    for (uint8 i = 0; i < STOCK_SIZE; i++) {
      uint8 itemRarity = _getRarity((number >>= 8) % 200);

      if (itemRarity == COMMON_RARITY) commonItems++;
      if (itemRarity == RARE_RARITY) rareItems++;
      if (itemRarity == LEGENDARY_RARITY) legendaryItems++;
    }

    stockItems = ItemAmountsLib.init(commonItems + rareItems + legendaryItems);

    uint256 uniqueItems;
    uint256 index = _getDropsOfRarity(
      stockItems,
      COMMON_RARITY,
      commonItems,
      0
    );
    uniqueItems += index;
    index = _getDropsOfRarity(stockItems, RARE_RARITY, rareItems, uniqueItems);
    uniqueItems += index;
    index = _getDropsOfRarity(
      stockItems,
      LEGENDARY_RARITY,
      legendaryItems,
      uniqueItems
    );
    uniqueItems += index;

    stockItems.resize(uniqueItems);
  }

  function getRerollPrice(address _user) public view returns (uint256) {
    UserData memory userData = users[_user];

    uint256 delta = block.timestamp - userData.lastReroll;
    if (delta >= REROLL_COOLDOWN) {
      return 0;
    }

    return BASE_REROLL_PRICE + (REROLL_INCREMENT_PRICE * userData.rerollCount);
  }

  function getUserStock(
    address _user
  ) external view returns (ItemAmounts memory) {
    return users[_user].stock;
  }

  function getUserInfo(address _user) external view returns (UserData memory) {
    return users[_user];
  }
}
