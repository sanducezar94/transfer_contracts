// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IToken {
  function mint(address _to, uint256 _amount) external;
}

contract KnightBagHarmony is Ownable {
  using SafeERC20 for IERC20;

  event EmitData(address user, uint256[4] data);

  constructor(address _itemConsumers) {
    ITEM_CONSUMER = _itemConsumers;
  }

  uint256 constant MIN_AMOUNT = 10e18;
  uint256 constant MAX_AMOUNT = 40e18;

  uint256 nonce;

  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  address immutable ITEM_CONSUMER;
  address constant KNIGHT_TOKEN =
    address(0xfa11B2EB19631706af9dEc9d5eFde52F4F798766);

  function isValid(uint256[] memory _values) external view {
    //do nothing
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

  function use(address _user, uint256[] memory _values) external {
    require(msg.sender == ITEM_CONSUMER); // CHECKER
    nonce += 1;
    uint256 randomNumber = generateRandom(nonce);

    uint256 totalAmount = (randomNumber % MAX_AMOUNT) + MIN_AMOUNT;
    IToken(KNIGHT_TOKEN).mint(_user, totalAmount);
  }
}
