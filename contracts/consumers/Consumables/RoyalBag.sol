// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

interface IFundManager {
  function withdraw(address _account, uint256 _amount) external;
}

contract RoyalBag {
  address immutable questFundAddress;
  address immutable ITEM_CONSUMER;

  event TokenWithdraw(uint256 amount);

  constructor(address _questFundAddress, address _itemConsumer) {
    ITEM_CONSUMER = _itemConsumer;
    questFundAddress = _questFundAddress;
  }

  uint256 nonce;
  uint256 constant MIN_AMOUNT = 0.25e18;
  uint256 constant MAX_AMOUNT = 0.5e18;

  function isValid(uint256[] memory _values) external view {
    require(
      address(questFundAddress).balance > MAX_AMOUNT,
      "Quest fund is empty."
    );
  }

  function generateRandom(uint256 _nonce) private view returns (uint256) {
    return
      uint256(
        keccak256(
          abi.encodePacked(
            blockhash(block.number - 1),
            _nonce,
            "PEASANTUSESITEM"
          )
        )
      );
  }

  function _getBrackets(
    uint256 _chance
  ) internal pure returns (uint256, uint256) {
    if (_chance < 50) {
      return (MIN_AMOUNT, MAX_AMOUNT);
    } else {
      return (MIN_AMOUNT, MAX_AMOUNT / 2);
    }
  }

  function _calculateRewardAmount() internal returns (uint256) {
    uint256 randomNumbers = generateRandom(nonce++);

    (uint256 min, uint256 max) = _getBrackets((randomNumbers >>= 8) % 100);

    uint256 amountOfKnight = ((randomNumbers >>= 8) % (max - min)) + min;
    return amountOfKnight;
  }

  function use(address _user, uint256[] memory _values) external {
    require(msg.sender == ITEM_CONSUMER); // CHECKER

    uint256 amountOfKnight = _calculateRewardAmount();
    IFundManager(questFundAddress).withdraw(_user, amountOfKnight);

    emit TokenWithdraw(amountOfKnight);
  }

  receive() external payable {}
}
