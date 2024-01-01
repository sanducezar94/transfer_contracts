// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import { QuestManager } from "../QuestManager.sol";
import { Items } from "../../items/Items.sol";
import { Leaderboard } from "../../misc/Leaderboard.sol";
import "../../utils/FeeTakersETH.sol";
import "../../constants.sol";

struct Badge {
  string name;
  uint256 boughtAt;
  bool initialized;
  uint16 level;
  uint32 exp;
}

struct Map {
  Leaderboard leaderboard;
  bool isMap;
  uint16 minExp;
  uint16 maxExp;
}

struct QuestInfo {
  uint32 questsCompleted;
  uint16 expGained;
  uint8[MAXIMUM_QUESTS] questSetIds;
  uint8[MAXIMUM_QUESTS] generatedQuestSetIds;
}

struct BadgeRestocks {
  uint256 lastFreeRestock;
  uint8 freeRestocks;
  uint8 freeRestockCount;
  uint8 paidRestockCount;
}

contract BadgeStorage is Payments, AccessControl {
  QuestManager questManager;

  constructor(QuestManager _questManager) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(BADGE_MANAGER, msg.sender);

    questManager = _questManager;
    questsNonce = block.number;
  }

  modifier badgeOwner() {
    require(
      badges[msg.sender].initialized || hasRole(BADGE_MANAGER, msg.sender)
    );
    _;
  }

  event BadgeLevelUp(address user);
  event BadgePurchased(address user, string name, uint256 fee);
  event BadgeReroll(address user, uint8[MAXIMUM_QUESTS] questIds);

  bytes32 public constant BADGE_MANAGER = keccak256("BADGE_MANAGER");

  uint256 private questsNonce = 0;

  uint256 public badgePrice = 10e18;
  uint256 public baseRerollPrice = 0.1e18;
  uint256 public nameChangePrice = 0.5e18;

  uint256 constant restockCooldown = 1 days;

  mapping(address => Badge) public badges;
  mapping(address => mapping(uint16 => QuestInfo)) questInfos;
  mapping(address => mapping(uint16 => BadgeRestocks)) badgeRestocks;

  uint8 constant DEFAULT_INVENTORY_SLOTS = 3;
  uint8 constant DEFAULT_FREE_RESTOCKS = 1;
  uint8 constant DEFAULT_DAILY_QUESTS = 4;
  uint8 constant REROLL_SOFT_LIMIT = 10;
  uint8 constant MAX_PAID_RESTOCKS = 50;

  uint256 public totalBadges = 0;

  mapping(uint8 => Map) _maps;

  function buyBadge(address _user, string memory _name) external payable {
    require(badges[_user].initialized == false, "Badge already bought.");
    require(msg.value >= badgePrice || hasRole(BADGE_MANAGER, _user));

    _makePayment(msg.value);

    Badge memory newBadge;
    newBadge.name = _name;
    newBadge.boughtAt = block.timestamp;
    newBadge.initialized = true;
    badges[_user] = newBadge;
    totalBadges++;

    emit BadgePurchased(_user, _name, badgePrice);
  }

  function bulkOwnerRecoverBadges(
    address[] calldata _users,
    Badge[] calldata _badges,
    uint32[] calldata _questsCompleted
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    unchecked {
      uint8 _mapId = 1;
      for (uint256 i = 0; i < _badges.length; i++) {
        if (!badges[_users[i]].initialized) {
          totalBadges++;
        }
        ownerSetBadge(_users[i], _badges[i]);
        questInfos[_users[i]][_mapId].questsCompleted = _questsCompleted[i];
        badgeRestocks[_users[i]][_mapId].freeRestocks = getBadgeQuestLimit(
          _users[i]
        );
      }
    }
  }

  function ownerSetBadge(
    address _user,
    Badge memory _badge
  ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    badges[_user] = _badge;
  }

  function setPayees(
    Payments.Payee[] memory payees
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    _setPayees(payees);
  }

  function setQuestManager(
    QuestManager _questManager
  ) external onlyRole(BADGE_MANAGER) {
    questManager = _questManager;
  }

  function setPaidRestockPrices(
    uint256 _price
  ) external onlyRole(BADGE_MANAGER) {
    baseRerollPrice = _price;
  }

  function setBadgePrice(uint256 _price) external onlyRole(BADGE_MANAGER) {
    badgePrice = _price;
  }

  function registerMap(
    uint8 _mapId,
    Leaderboard _leaderboard,
    uint16 _minExp,
    uint16 _maxExp
  ) external onlyRole(BADGE_MANAGER) {
    _maps[_mapId] = Map(_leaderboard, true, _minExp, _maxExp);
  }

  function changeBadgeName(string memory _name) external payable badgeOwner {
    require(msg.value >= nameChangePrice);
    _makePayment(msg.value);
    badges[msg.sender].name = _name;
  }

  function levelUpBadge(
    address _user,
    uint32 _expRequirement
  ) external onlyRole(BADGE_MANAGER) {
    Badge storage userBadge = badges[_user];

    require(userBadge.exp >= _expRequirement, "Not enough experience.");

    userBadge.level += 1;
    userBadge.exp = userBadge.exp - _expRequirement;

    emit BadgeLevelUp(_user);
  }

  function _getRandomSetForQuest(
    uint8 _mapId,
    uint256 nonce
  ) private view returns (uint8[MAXIMUM_QUESTS] memory numbers) {
    uint256 totalQuests = questManager.totalQuests(_mapId);
    uint256 number = uint256(
      keccak256(
        abi.encodePacked(blockhash(block.number - 1), nonce, "QUESTBADGESTUFFI")
      )
    );
    numbers = [
      uint8((number >>= 8) % totalQuests) + 1,
      uint8((number >>= 16) % totalQuests) + 1,
      uint8((number >>= 24) % totalQuests) + 1,
      uint8((number >>= 32) % totalQuests) + 1
    ];
  }

  function getUserRerollPrice(
    address _owner,
    uint8 _mapId
  ) public view returns (uint256) {
    BadgeRestocks memory restockData = badgeRestocks[_owner][_mapId];
    bool onCooldown = block.timestamp <=
      (restockData.lastFreeRestock + restockCooldown);
    uint8 freeRestockLimit = getBadgeQuestLimit(_owner);

    if (!onCooldown || restockData.freeRestockCount < freeRestockLimit)
      return 0;

    uint16 paidRerollCount = restockData.paidRestockCount;

    if (paidRerollCount < REROLL_SOFT_LIMIT) return baseRerollPrice;
    uint256 incrementalStep = baseRerollPrice / 4;

    return
      baseRerollPrice +
      incrementalStep *
      (1 + paidRerollCount - REROLL_SOFT_LIMIT);
  }

  function rerollDailyQuests(
    address _owner,
    uint8 _mapId
  ) external payable badgeOwner {
    require(_maps[_mapId].isMap, "Invalid map.");
    BadgeRestocks storage badgeData = badgeRestocks[_owner][_mapId];
    QuestInfo storage questInfo = questInfos[_owner][_mapId];

    bool isManager = hasRole(BADGE_MANAGER, msg.sender);

    if (!isManager) {
      bool onCooldown = block.timestamp <=
        (badgeData.lastFreeRestock + restockCooldown);
      require(
        !onCooldown || badgeData.paidRestockCount < MAX_PAID_RESTOCKS,
        "Reached the quest roll limit for today!"
      );

      uint8 freeRestockLimit = getBadgeQuestLimit(_owner);
      if (onCooldown && badgeData.freeRestockCount >= freeRestockLimit) {
        require(msg.value >= getUserRerollPrice(_owner, _mapId));
        _makePayment(msg.value);
        badgeData.paidRestockCount++;
      } else {
        uint256 lastRestock = badgeData.lastFreeRestock;
        //set the 'lastFreeRestock' only when rerolling the first time after cooldown expired
        badgeData.lastFreeRestock = block.timestamp - lastRestock <
          restockCooldown
          ? lastRestock
          : block.timestamp;
        badgeData.freeRestockCount = onCooldown
          ? badgeData.freeRestockCount + 1
          : 1;
        badgeData.paidRestockCount = 0;
      }
    }

    uint8[MAXIMUM_QUESTS] memory questIds = _getRandomSetForQuest(
      _mapId,
      questsNonce++
    );
    questInfo.questSetIds = questIds;
    questInfo.generatedQuestSetIds = questIds;

    updateLeaderboardScore(_owner, _mapId);

    emit BadgeReroll(_owner, questIds);
  }

  function completeQuest(
    address _user,
    uint8 _mapId,
    uint256 _questSlot,
    uint256 _badgeExp
  ) external onlyRole(BADGE_MANAGER) {
    Badge storage badgeData = badges[_user];
    QuestInfo storage questInfo = questInfos[_user][_mapId];

    questInfo.questSetIds[_questSlot] = uint8(NULL_QUEST);

    uint16 badgeExp = _badgeExp == 0 ? 0 : _badgeExp == 1
      ? _maps[_mapId].minExp
      : _maps[_mapId].maxExp;

    badgeData.exp += badgeExp;
    questInfo.expGained += badgeExp;
    questInfo.questsCompleted += 1;
  }

  function updateLeaderboardScore(
    address _user,
    uint8 _mapId
  ) public badgeOwner {
    require(_maps[_mapId].isMap, "Invalid map.");
    uint32 expGained = questInfos[_user][_mapId].expGained;
    questInfos[_user][_mapId].expGained = 0;
    if (expGained > 0) {
      _maps[_mapId].leaderboard.addScore(_user, expGained);
    }
  }

  function purchasedBadge(address _user) external view returns (bool) {
    return badges[_user].initialized;
  }

  function getBadgeRestockInfo(
    address _user,
    uint8 _mapId
  ) external view returns (BadgeRestocks memory) {
    return badgeRestocks[_user][_mapId];
  }

  function getBadgeQuestInfo(
    address _user,
    uint8 _mapId
  ) external view returns (QuestInfo memory) {
    return questInfos[_user][_mapId];
  }

  function getBadgeData(address _user) external view returns (Badge memory) {
    return badges[_user];
  }

  function getBadgeItemSlots(address _user) external view returns (uint8) {
    uint16 badgeLevel = badges[_user].level;
    uint8 bonusItemSlots = badgeLevel >= 50 ? 2 : badgeLevel >= 25 ? 1 : 0;
    return DEFAULT_INVENTORY_SLOTS + bonusItemSlots;
  }

  function getBadgeQuestLimit(address _user) public view returns (uint8) {
    uint16 badgeLevel = badges[_user].level;
    // grant 1 additional free reroll per day after level 50
    return DEFAULT_FREE_RESTOCKS + (badgeLevel >= 50 ? 1 : 0);
  }

  function getBadgeQuestSet(
    address _user,
    uint8 _mapId
  ) public view returns (uint8[MAXIMUM_QUESTS] memory) {
    return questInfos[_user][_mapId].questSetIds;
  }

  function getBadgeQuestAtSlot(
    address _user,
    uint8 _mapId,
    uint8 _slot
  ) public view returns (uint8) {
    return questInfos[_user][_mapId].questSetIds[_slot];
  }
}
