// contracts/GameItems.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

uint256 constant NULL = 0;

uint256 constant ITEM_ID = 0;
uint256 constant ITEM_LEVEL = 1;
uint256 constant ITEM_DURABILITY = 2;
uint256 constant ITEM_CHARGES = 3;
uint256 constant ITEM_DATA = 4;

uint256 constant NULL_QUEST = 0;
uint8 constant MAXIMUM_QUESTS = 4;

uint256 constant NULL_ITEM = 0;
uint256 constant NULL_ITEM_DROP = 100000;
uint256 constant ITEM_MAX_DURABILITY = 10;
uint256 constant NULL_PEASANT = 0;
uint256 constant MAX_QUEST_SLOTS = 5;
uint256 constant MAX_QUEST_DROPS = 5;
uint256 constant MAXIMUM_QUEST_POINTS = 12e4;
uint256 constant MAXIMUM_QUEST_REQUIREMENTS = 5;
uint256 constant MAX_PEASANT_SLOTS = 3;

uint8 constant RARITIES_COUNT = 5;
uint8 constant TRAIT_COUNT = 4;
uint8 constant STAT_RARITY = 0;
uint8 constant STAT_PROFESSION = 1;
uint8 constant STAT_TALENT = 2;
uint8 constant STAT_LABOUR = 3;
uint8 constant STAT_LEVEL = 4;
uint8 constant MAX_STATS = 5;

uint256 constant EQUIPMENT_OFFSET = 10e12;

address constant BURN_WALLET = address(0xDeAd);
