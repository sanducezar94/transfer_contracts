// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

struct SmallBadge {
  string name;
  uint256 boughtAt;
  bool initialized;
}

interface IKPBadge {
  function purchasedBadge(address _user) external view returns (bool);
}

contract KPBadge {
  mapping(address => SmallBadge) public badges;
}

struct EmissionData {
  uint256 lastClaimed;
}

interface KNPToken {
  function mint(address _to, uint256 _amount) external;

  function burn(address _from, uint256 _amount) external;
}

contract BadgeEmissions is AccessControl {
  constructor(address _badgeAddress, address _knightTokenAddress) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    badgeAddress = _badgeAddress;
    knightTokenAddress = _knightTokenAddress;
    kpBadge = KPBadge(_badgeAddress);
  }

  uint256 constant GENESIS_STAMP = 1669282890;

  address knightTokenAddress;
  address badgeAddress;

  KPBadge kpBadge;

  struct BadgeEmissionData {
    uint256 lastClaimed;
    uint256 totalClaimed;
    bool hasClaimed;
  }

  event BadgeClaim(address user, uint256 income);
  mapping(address => BadgeEmissionData) badgeEmissions;

  uint256 constant BADGE_INCOME = 5e18;

  uint256[5] itemIds;
  uint256[5] itemAmounts;

  function _getIncomeDelta(uint256 _timestamp) internal view returns (uint256) {
    return (BADGE_INCOME * (block.timestamp - _timestamp)) / 1 days;
  }

  function getPendingIncome(address _user) public view returns (uint256) {
    (, uint256 boughtAt, bool initialized) = kpBadge.badges(_user);

    if (!initialized || boughtAt < GENESIS_STAMP) return 0;

    uint256 lastClaimed = badgeEmissions[_user].hasClaimed
      ? badgeEmissions[_user].lastClaimed
      : boughtAt;
    return _getIncomeDelta(lastClaimed);
  }

  function claimBadgeIncome(address _user) public {
    bool purchased = IKPBadge(badgeAddress).purchasedBadge(_user);
    require(purchased, "Badge not purchased.");

    BadgeEmissionData storage emissionData = badgeEmissions[_user];
    uint256 income = getPendingIncome(_user);

    emissionData.hasClaimed = true;
    emissionData.lastClaimed = block.timestamp;
    emissionData.totalClaimed += income;

    KNPToken(knightTokenAddress).mint(_user, income);

    emit BadgeClaim(_user, income);
  }
}
