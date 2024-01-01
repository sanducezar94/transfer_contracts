// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/FeeTakersETH.sol";
import { Items } from "../items/Items.sol";
import { IPeasants, PeasantStats } from "./IPeasants.sol";

function max(uint256 a, uint256 b) pure returns (uint256) {
  return a >= b ? a : b;
}

function min(uint256 a, uint256 b) pure returns (uint256) {
  return a < b ? a : b;
}

struct Badge {
  string name;
  uint256 boughtAt;
  bool initialized;
  uint16 level;
  uint32 exp;
}

interface IBadge {
    function getBadgeData(address _user) external view returns(Badge memory);
}

contract Craft is AccessControl, Payments {
    using SafeERC20 for IERC20;
    Items immutable items;
    address immutable badgeAddress;
    address immutable peasants;
    address immutable knpAddress;

    uint32[4] talentWeight = [0, 500, 1500, 3000];
    uint32[5] rarityWeight = [0, 500, 1000, 2000, 3000];
    uint32[6] levelWeight = [0, 100, 200, 400, 800, 1600];

    uint256[5] knightCost = [0, 25e18, 50e18, 75e18, 100e18];
    uint32[6] successChances = [80000, 60000, 40000, 20000, 0, 0];

    // each level upgrade success chance 1, 2, 3, 4, 5
    mapping(uint256 => PeasantSlots) public peasantSlots;

    uint32 constant baseDoubleChance = 5000;
    uint32 constant baseTripleChance = 1000;

    uint256 constant SLOTS_REFILL = 6 hours;
    uint256 constant ALE_JUG = 59;

    uint8 constant WHETSTONE_ID = 75;
    uint8 constant MAX_LEVEL = 5;
    uint256 constant public ETH_COST = 0.1e18;
    uint256 nonce;
    
    address constant DEAD_ADDRESS = address(0xDeAd);
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

    event ItemCrafted(uint256 itemId, uint8 quality);
    event ItemUpgraded(bool success);

    struct CraftRecipe {
        uint32 id;
        uint256 resultId;
        bool initialized;
        uint8 craftedAmount;
        uint8 professionType;
        uint16 levelRequirement;
        uint8 itemType;

        uint256[] itemIds;
        uint256[] itemAmounts;
    }

    struct PeasantSlots {
        uint256 slotsDebt;
        uint256 lastUsed;
    }

    constructor(Items _items, address _peasants, address _badgeAddress, address _knpAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MODERATOR_ROLE, msg.sender);
        items = _items;
        peasants = _peasants;
        knpAddress = _knpAddress;
        badgeAddress = _badgeAddress;
    }

    uint256 constant NON_FUNGIBLE_OFFSET = 10e12;
    mapping(uint256 => CraftRecipe) public recipes;

    function registerRecipe(CraftRecipe memory _recipe) public onlyRole(DEFAULT_ADMIN_ROLE) {
        recipes[_recipe.id] = _recipe;
    }

    function bulkRegisterRecipes(CraftRecipe[] memory _recipes) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for(uint256 i = 0; i < _recipes.length; i++) {
            registerRecipe(_recipes[i]);
        }
    }

    function _getRandomNumber(uint256 _nonce) internal view returns (uint256) {
        return
        uint256(
            keccak256(
            abi.encodePacked(
                blockhash(block.number),
                _nonce,
                "craftgGetNumb12er"
            )
            )
        );
    }

    function _getCraftAmount(uint256 _multiplier) internal view returns(uint8) {
        uint256 number = _getRandomNumber(nonce) % 1e5;

        if(number <= baseTripleChance + _multiplier) return 3;
        if(number <= baseDoubleChance + _multiplier * 3) return 2;
        return 1;
    }

    function _getSuccessOutcome(uint256 _chance, uint8 _levelAttempt) internal view returns(bool) {
        uint256 number = _getRandomNumber(nonce) % 1e5;

        if(number <= _chance + successChances[_levelAttempt]) {
            return true;
        }
        return false;
    }

    function _pointTokenToItemId(uint256 _tokenId) internal pure returns (uint8) {
        return
      _tokenId >= NON_FUNGIBLE_OFFSET
        ? uint8(_tokenId / NON_FUNGIBLE_OFFSET)
        : uint8(_tokenId);
    }

    function setPayees(
        Payments.Payee[] memory payees
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setPayees(payees);
    }

    function getPeasantAvailableSlots(uint256 _tokenId) public view returns(uint256) {
        PeasantSlots memory slots = peasantSlots[_tokenId];
        PeasantStats memory peasantStats = IPeasants(peasants).getAttributes(_tokenId);

        if(slots.lastUsed == 0) {
            return (peasantStats.labour + 1);
        }

        uint256 deltaSlots = (block.timestamp - slots.lastUsed) / SLOTS_REFILL - slots.slotsDebt;

        return min(deltaSlots, (peasantStats.labour + 1));
    }

    function craftItems(uint256 _recipeId, uint256 _peasantId, uint8 _amount, bool _useAle) external {
        _checkAndSetPeasantCooldown(_peasantId, _amount, _useAle);
        CraftRecipe memory recipe = recipes[_recipeId];

        Badge memory badgeData = IBadge(badgeAddress).getBadgeData(msg.sender);
        require(recipe.initialized, "Invalid recipe.");
        require(recipe.levelRequirement <= badgeData.level, "Badge level is not enough.");

        PeasantStats memory peasantStats = IPeasants(peasants).getAttributes(_peasantId);
        require(peasantStats.profession == recipe.professionType, "Incorrect peasant profession.");

        uint32 multiplier = talentWeight[peasantStats.talent] + rarityWeight[peasantStats.rarity] + levelWeight[peasantStats.level];

        for(uint256 i = 0; i < _amount; i++) {
            _craftItem(_recipeId, _peasantId, multiplier);
        }
    }

    function getNumberOfAles(uint256 _peasantId, uint256 _amount) external view returns(uint256) {
        uint256 slots = getPeasantAvailableSlots(_peasantId);
        if(slots > _amount) return 0;
        return _amount - slots;
    }

    function useAle(uint256 _tokenId, uint256 _amount) external {
        PeasantSlots storage slots = peasantSlots[_tokenId];
        PeasantStats memory stats = IPeasants(peasants).getAttributes(_tokenId);

        require(slots.lastUsed > 0, "Peasant can't use this yet.");
        require(_amount > 0 && _amount <= stats.labour + 1 && _amount <= slots.slotsDebt, "Invalid number of Ale Jugs.");

        items.burn(msg.sender, ALE_JUG, _amount);
        slots.slotsDebt -= _amount;
    }

    function _getAndSetPeasantSlots(uint256 _tokenId) internal returns(uint256) {
        PeasantSlots storage slots = peasantSlots[_tokenId];
        PeasantStats memory peasantStats = IPeasants(peasants).getAttributes(_tokenId);

        if(slots.lastUsed == 0) {
            slots.lastUsed = block.timestamp - (peasantStats.labour + 1) * SLOTS_REFILL;
            return (peasantStats.labour + 1);
        }

        uint256 deltaSlots = (block.timestamp - slots.lastUsed) / SLOTS_REFILL - slots.slotsDebt;

        if(deltaSlots > peasantStats.labour) {
            slots.lastUsed = block.timestamp - (peasantStats.labour + 1) * SLOTS_REFILL;
            slots.slotsDebt = 0;
        }

        return min(deltaSlots, (peasantStats.labour + 1));
    }

    function _checkAndSetPeasantCooldown(uint256 _peasantId, uint256 _amount, bool _useAle) internal {
        uint256 slots = _getAndSetPeasantSlots(_peasantId);
        peasantSlots[_peasantId].slotsDebt += (_amount > slots ? slots : _amount);

        if(!_useAle) {
            require(slots >= _amount, "Peasant must rest first.");
        }
        else {
            items.burn(msg.sender, ALE_JUG, _amount - slots);
        }
    }

    function _craftItem(uint256 _recipeId, uint256 _peasantId, uint32 _multiplier) internal {
        require(IPeasants(peasants).ownerOf(_peasantId) == msg.sender, "Not the owner.");
        CraftRecipe memory recipe = recipes[_recipeId];
        uint8 craftAmount = _getCraftAmount(_multiplier);
        nonce++;

        if(recipe.itemType == 0) {//equipment
            for(uint256 i = 0; i < craftAmount; i++) {
                items.mintItem(msg.sender, recipe.resultId, recipe.craftedAmount);
            }
            items.burnBatch(msg.sender, recipe.itemIds, recipe.itemAmounts);
        }
        else{
            items.burnBatch(msg.sender, recipe.itemIds, recipe.itemAmounts);
            items.mintItem(msg.sender, recipe.resultId, recipe.craftedAmount * craftAmount);
        }

        emit ItemCrafted(recipe.resultId, craftAmount);
    }

    function upgradeItem(uint256[] memory _itemIds, uint256 _peasantId, uint256 _whetstones) external payable {
        require(_itemIds[0] > NON_FUNGIBLE_OFFSET && _itemIds[1] > NON_FUNGIBLE_OFFSET, "Invalid items.");
        require(IPeasants(peasants).ownerOf(_peasantId) == msg.sender, "Not the owner.");
        require(items.balanceOf(msg.sender, _itemIds[0]) > 0 && items.balanceOf(msg.sender, _itemIds[1]) > 0, "Not the owner of items.");

        _checkAndSetPeasantCooldown(_peasantId, 1, false);
        uint8[] memory itemLevels = items.getItemsLevels(_itemIds);
        uint256 chance = 0;

        //whetstones boost the chance by 2%
        chance += _whetstones * 2500;
        // every 0.1 matic boosts the chance by 2.5%
        chance += (msg.value / ETH_COST) * 2500;

        require(itemLevels[0] == itemLevels[1], "Item levels are not the same.");
        require(_pointTokenToItemId(_itemIds[0]) == _pointTokenToItemId(_itemIds[1]), "Item id's are different.");
        require(itemLevels[0] < MAX_LEVEL, "Item is already fully upgraded!");
        uint8 newLevel =  itemLevels[0] + 1;

        PeasantStats memory peasantStats = IPeasants(peasants).getAttributes(_peasantId);
        chance += (talentWeight[peasantStats.talent] + rarityWeight[peasantStats.rarity] + levelWeight[peasantStats.level]) * 5;

        IERC20(knpAddress).safeTransferFrom(msg.sender, address(DEAD_ADDRESS), knightCost[newLevel]);
        if(_whetstones > 0) {
            items.burn(msg.sender, WHETSTONE_ID, _whetstones);
        }
        _makePayment(msg.value);

        bool isSuccessful = _getSuccessOutcome(chance, newLevel);
        nonce++;

        if(isSuccessful) { 
            items.burn(msg.sender, _itemIds[1], 1);
            items.setLevel(_itemIds[0], newLevel);
        }
        emit ItemUpgraded(isSuccessful);
    }
}