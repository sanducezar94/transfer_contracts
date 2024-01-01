//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract Payments {
  struct Payee {
    address addr;
    uint256 weighting;
  }
  Payee[] private _payees;
  uint256 private _totalWeighting;

  function getPayees() external view virtual returns (Payee[] memory) {
    return _payees;
  }

  function _setPayees(Payee[] memory payees) internal virtual {
    if (_payees.length > 0) _deletePayees();
    for (uint256 i; i < payees.length; i++) {
      Payee memory payee = payees[i];
      require(payee.weighting > 0, "All payees must have a weighting.");
      require(payee.addr != address(0), "Payee cannot be the zero address.");
      _totalWeighting += payee.weighting;
      _payees.push(payee);
    }
  }

  function _tryMakePayment(uint256 value) internal virtual {
    for (uint256 i; i < _payees.length; i++) {
      Payee storage payee = _payees[i];
      uint256 payment = (payee.weighting * value) / _totalWeighting;
      (bool succ, ) = payee.addr.call{ value: payment }("");
      require(succ, "Issue with one of the payees.");
    }
  }

  function _makePayment(uint256 value) internal virtual {
    require(_payees.length > 0, "No payees set up.");
    _tryMakePayment(value);
  }

  function _deletePayees() internal virtual {
    delete _totalWeighting;
    delete _payees;
  }

  function withdraw() external {
    uint256 contractBalance = address(this).balance;
    address caller = msg.sender;
    (bool success, ) = caller.call{ value: contractBalance }("");
    require(success);
  }
}
