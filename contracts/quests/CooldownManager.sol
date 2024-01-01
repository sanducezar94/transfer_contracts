// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

abstract contract CooldownManager  {
  mapping(address => uint256) public cooldowns;

  uint256 constant BASE_COOLDOWN = 24 hours;

  function _setKnightCooldown(address _user, uint256 _timestamp) internal {
    cooldowns[_user] = _timestamp;
  }

  function isOnCooldown(address _user) internal view returns (bool) {
    return cooldowns[_user] + BASE_COOLDOWN > block.timestamp;
  }

  function checkAndUpdateUserCooldown(address _user, uint256 _timestamp) internal {
    require(cooldowns[_user] + BASE_COOLDOWN < _timestamp);
    cooldowns[_user] = _timestamp;
  }
}
