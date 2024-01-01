// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

interface IKnightAttribute {
  function giveAttributePoints(uint256 _knightId, uint256 _points) external;
}

contract GreaterKnightBlessing is Ownable {
  constructor(address _itemConsumer, address _knightAttribute) {
    ITEM_CONSUMER = _itemConsumer;
    knightAttributeAddress = _knightAttribute;
  }

  event PointsEarned(uint8 points);

  uint256 nonce;

  uint8 MIN_POINTS = 2;
  uint8 MAX_POINTS = 5;

  address immutable ITEM_CONSUMER;
  address immutable knightAttributeAddress;

  function isValid(uint256[] memory _values) external view {
    require(_values[0] <= 5000, "Invalid values set.");
  }

  function generateRandom(uint256 _nonce) private view returns (uint256) {
    return
      uint256(
        keccak256(
          abi.encodePacked(
            blockhash(block.number - 1),
            _nonce,
            "GKKNIGHTBLESSING"
          )
        )
      );
  }

  /// values 0 - knight id, 1 - stat type
  function use(address _user, uint256[] memory _values) external {
    require(msg.sender == ITEM_CONSUMER); // CHECKER
    nonce += 1;
    uint256 randomNumber = generateRandom(nonce);

    uint8 totalPoints = uint8((randomNumber % (MAX_POINTS - 1)) + MIN_POINTS);
    IKnightAttribute(knightAttributeAddress).giveAttributePoints(
      _values[0],
      totalPoints
    );
    emit PointsEarned(totalPoints);
  }
}
