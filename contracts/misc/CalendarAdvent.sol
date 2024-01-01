// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../utils/FeeTakersETH.sol";

interface IKPItems {
  function mintItems(
    address _to,
    uint256[] memory _itemIds,
    uint256[] calldata _itemAmounts
  ) external;
}

struct Rewards {
  uint16[] itemDrops;
  uint16[] itemWeights;
  uint32 totalWeight;
}

contract CalendarAdvent is Ownable, Payments {
  address immutable itemsAddress =
    address(0xc65b1bcc732Ef407c9e8fAd002BB6708e0817203);

  mapping(address => mapping(uint8 => bool)) dayClaimed;
  mapping(address => bool) public calendarBought;
  mapping(uint8 => uint8) public dayRewardType;

  Rewards public calendarReward;

  uint8 constant TOTAL_DAYS = 24;
  uint256 calendarPrice = 500e18;

  uint256 public deployTime;
  uint256 nonce;

  uint256 rewardInterval = 1 days;

  constructor() {
    deployTime = block.timestamp - (12 * rewardInterval);
  }

  function getDaysPassed() public view returns (uint256) {
    uint256 delta = block.timestamp - deployTime;
    return delta / rewardInterval;
  }

  function claimDay(address _user, uint8 _day) external {
    require(_day >= 0 && _day < TOTAL_DAYS, "Invalid day.");
    require(!dayClaimed[_user][_day], "Day already claimed.");
    require(calendarBought[_user], "You must purchase the calendar first!");

    uint8 daysPassed = uint8(getDaysPassed());
    require(_day < daysPassed, "Reward is not available yet!");

    dayClaimed[_user][_day] = true;

    (uint256[] memory itemDrops, uint256[] memory itemAmounts) = _getDrops(
      dayRewardType[_day]
    );
    IKPItems(itemsAddress).mintItems(_user, itemDrops, itemAmounts);
  }

  function _getRandomNumber(uint256 _nonce) internal view returns (uint256) {
    return
      uint256(
        keccak256(
          abi.encodePacked(
            blockhash(block.number),
            _nonce,
            "CLAENDARACDVENTRAN"
          )
        )
      );
  }

  function _getDrops(
    uint8 _dropType
  )
    internal
    returns (uint256[] memory itemDrops, uint256[] memory itemAmounts)
  {
    Rewards memory reward = calendarReward;
    uint256 totalDrops = _dropType == 0 ? 2 : _dropType == 1
      ? 6
      : _dropType == 2
      ? 15
      : 25;

    itemDrops = new uint256[](totalDrops);
    itemAmounts = new uint256[](totalDrops);

    uint256 number = _getRandomNumber(nonce++);
    unchecked {
      for (uint256 i = 0; i < totalDrops; i++) {
        uint256 dropChance = (number >>= 8) % reward.totalWeight;
        uint256 accruedChance = 0;
        for (uint256 j = 0; j < reward.itemDrops.length; j++) {
          if (
            dropChance >= accruedChance &&
            dropChance < accruedChance + reward.itemWeights[j]
          ) {
            itemDrops[i] = reward.itemDrops[j];
            itemAmounts[i] = 1;
          }
          accruedChance += reward.itemWeights[j];
        }

        if (i % 16 == 0) {
          number = _getRandomNumber(nonce++);
        }
      }
    }
  }

  function getPrice() external view returns (uint256) {
    return calendarPrice;
  }

  function setPrice(uint256 _value) external onlyOwner {
    calendarPrice = _value;
  }

  function buyCalendar() external payable {
    require(!calendarBought[msg.sender], "Calendar already bought.");

    require(msg.value >= calendarPrice);
    calendarBought[msg.sender] = true;

    _makePayment(msg.value);
  }

  function setCalendar() external onlyOwner {
    require(!calendarBought[msg.sender], "Calendar already bought.");
    calendarBought[msg.sender] = true;
  }

  function getClaimedDays(
    address _owner
  ) external view returns (bool[] memory) {
    bool[] memory claimedDays = new bool[](TOTAL_DAYS);

    for (uint8 i = 0; i < TOTAL_DAYS; i++) {
      claimedDays[i] = dayClaimed[_owner][i];
    }

    return claimedDays;
  }

  function _clearDropTable() internal onlyOwner {
    delete calendarReward;
  }

  function setPayees(Payee[] calldata _payees) external onlyOwner {
    _setPayees(_payees);
  }

  function setDropTable(
    uint16[] calldata _itemIds,
    uint16[] calldata _itemWeights
  ) external onlyOwner {
    _clearDropTable();

    calendarReward.itemDrops = _itemIds;
    calendarReward.itemWeights = _itemWeights;

    for (uint256 i = 0; i < _itemIds.length; i++) {
      calendarReward.totalWeight += _itemWeights[i];
    }
  }

  function setDayDropType(uint8[] calldata _dropTypes) external onlyOwner {
    for (uint8 i = 0; i < TOTAL_DAYS; i++) {
      dayRewardType[i] = _dropTypes[i];
    }
  }
}
