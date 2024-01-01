// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract FundManagerPolygon is AccessControl {
  bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

  constructor() {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(WITHDRAWER_ROLE, msg.sender);
  }

  function withdraw(
    address _account,
    uint256 _amount
  ) public onlyRole(WITHDRAWER_ROLE) {
    uint256 contractBalance = address(this).balance;
    require(contractBalance > _amount, "Insufficient quest funds.");
    (bool success, ) = _account.call{ value: _amount }("");
    require(success);
  }

  function grantWithdrawerRole(
    address _account
  ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    _grantRole(WITHDRAWER_ROLE, _account);
  }

  function removeWithdrawerRole(
    address _account
  ) public onlyRole(DEFAULT_ADMIN_ROLE) {
    _revokeRole(WITHDRAWER_ROLE, _account);
  }

  function emergencyWithdraw() public onlyRole(DEFAULT_ADMIN_ROLE) {
    uint256 contractBalance = address(this).balance;
    address caller = msg.sender;
    (bool success, ) = caller.call{ value: contractBalance }("");
    require(success);
  }

  receive() external payable {}
}
