// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { Items } from "../items/Items.sol";
import { Peasants } from "../peasants/Peasants.sol";

contract PeasantPromoter is AccessControl {
    using SafeERC20 for IERC20;
    Items immutable items;
    Peasants immutable peasants;
    address immutable knpAddress;

    uint256[6] upgradeCost = [0, 25e18, 50e18, 75e18, 0, 0];
    uint8 constant MAX_LEVEL = 5;

    uint256 constant EXPERT_BOOK = 127;
    uint256 constant GRAND_MASTER_BOOK = 128;
    uint8 constant STAT_LEVEL = 4;

    event PeasantUpgraded(uint256 tokenId, uint8 level);

    constructor(Items _items, Peasants _peasants, address _knpAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        items = _items;
        peasants = _peasants;
        knpAddress = _knpAddress;
    }

    function getUpgradeCost(uint256 _tokenId) external view returns(uint256) {
         uint256 peasantLevel = peasants.getAttribute(_tokenId, STAT_LEVEL);
         if(peasantLevel == MAX_LEVEL) return 0;

         return upgradeCost[peasantLevel + 1];
    }

    function upgradePeasant(uint256 _tokenId, uint8 _level) external {
        require(peasants.ownerOf(_tokenId) == msg.sender, "You don't own this peasant.");
        
        uint256 peasantLevel = peasants.getAttribute(_tokenId, STAT_LEVEL);
        require(peasantLevel <= MAX_LEVEL, "Peasant already maximum level.");
        require(peasantLevel + 1 == _level, "Invalid level.");

        if(_level == 4) {
             require(items.balanceOf(msg.sender, EXPERT_BOOK) > 0, "You need 1 Expert Book.");
             items.burn(msg.sender, EXPERT_BOOK, 1);
        }
        if(_level == 5) {
            require(items.balanceOf(msg.sender, GRAND_MASTER_BOOK) > 0, "You need 1 Grand Master Book.");
            items.burn(msg.sender, GRAND_MASTER_BOOK, 1);
        }

        IERC20(knpAddress).safeTransferFrom(msg.sender, address(0x000000000000000000000000000000000000dEaD), upgradeCost[_level]);
        peasants.increaseAttribute(_tokenId, STAT_LEVEL, 1);
    }
}