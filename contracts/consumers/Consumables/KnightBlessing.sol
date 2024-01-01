// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IKnightAttribute {
  function giveAttributePoints(uint256 _knightId, uint256 _points) external;
}

contract KnightBlessing is Ownable {
  constructor(address _itemConsumer, address _knightAttribute) {
    ITEM_CONSUMER = _itemConsumer;
    knightAttributeAddress = _knightAttribute;
  }

  address immutable ITEM_CONSUMER;
  address immutable knightAttributeAddress;

  function isValid(uint256[] memory _values) external view {
    require(_values[0] <= 5000, "Invalid knight id.");
  }

  /// values 0 - knight id, 1 - stat type
  function use(address _user, uint256[] memory _values) external {
    require(msg.sender == ITEM_CONSUMER); // CHECKER
    IKnightAttribute(knightAttributeAddress).giveAttributePoints(_values[0], 1);
  }
}
