// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../items/Items.sol";

struct SmallBadge {
  string name;
  uint256 boughtAt;
  bool initialized;
}

contract LBadgeStorage {
  mapping(address => SmallBadge) public badges;
}

uint256 constant DEFAULT_POSITION = 100;
uint8 constant LEADERBOARD_LENGTH = 10;
uint8 constant MAX_REWARDS = 5;

contract Leaderboard is AccessControl {
  struct User {
    address userAddress;
    uint256 score;
  }

  struct UserRaw {
    address userAddress;
    string name;
    uint256 score;
  }

  struct RewardData {
    uint256[] itemIds;
    uint256[] itemAmounts;
  }

  Items items;
  LBadgeStorage badgeContract;

  mapping(uint256 => mapping(uint256 => User)) epochLeaderboard;
  mapping(uint256 => mapping(address => uint256)) epochUserScore;
  mapping(uint256 => mapping(address => bool)) epochClaimedPrize;
  mapping(uint256 => RewardData) rewards;

  uint256 public deployTimestamp;
  uint256 public epochDuration = 7 days;
  bool hasStarted = false;

  bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");

  constructor(Items _items, LBadgeStorage _badge) {
    _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    _grantRole(MODERATOR_ROLE, msg.sender);

    items = _items;
    badgeContract = _badge;
  }

  function startLeaderboard() public onlyRole(DEFAULT_ADMIN_ROLE) {
    require(!hasStarted);

    deployTimestamp = block.timestamp;
    hasStarted = true;
  }

  function getEpoch() public view returns (uint256) {
    return uint256((block.timestamp - deployTimestamp) / epochDuration);
  }

  function getPrizes()
    external
    view
    returns (RewardData[LEADERBOARD_LENGTH] memory prizeRewards)
  {
    for (uint256 i = 0; i < LEADERBOARD_LENGTH; ) {
      prizeRewards[i] = rewards[i];
      unchecked {
        i++;
      }
    }
  }

  function getLeaderboard(
    uint256 _epoch
  ) external view returns (User[LEADERBOARD_LENGTH] memory leaderboard) {
    for (uint256 i = 0; i < LEADERBOARD_LENGTH; ) {
      leaderboard[i] = epochLeaderboard[_epoch][i];
      unchecked {
        i++;
      }
    }
  }

  function getLeaderboardWithNames(
    uint256 _epoch
  ) external view returns (UserRaw[LEADERBOARD_LENGTH] memory leaderboard) {
    for (uint256 i = 0; i < LEADERBOARD_LENGTH; ) {
      (string memory name, , ) = badgeContract.badges(
        epochLeaderboard[_epoch][i].userAddress
      );
      leaderboard[i] = UserRaw(
        epochLeaderboard[_epoch][i].userAddress,
        name,
        epochLeaderboard[_epoch][i].score
      );
      unchecked {
        i++;
      }
    }
  }

  function getCurrentEpochScore(address _user) public view returns (uint256) {
    uint256 epoch = getEpoch();
    return epochUserScore[epoch][_user];
  }

  function epochEnded(uint256 _epoch) public view returns (bool) {
    uint256 currentEpoch = getEpoch();
    return _epoch < currentEpoch;
  }

  function getScore(
    address _user,
    uint256 _epoch
  ) public view returns (uint256) {
    return epochUserScore[_epoch][_user];
  }

  function setPrizeRewards(
    RewardData[LEADERBOARD_LENGTH] memory _rewards
  ) external onlyRole(MODERATOR_ROLE) {
    for (uint256 i = 0; i < LEADERBOARD_LENGTH; ) {
      rewards[i] = _rewards[i];
      unchecked {
        i++;
      }
    }
  }

  function _claimPrize(address _user, uint256 _position) internal {
    RewardData memory prizeRewards = rewards[_position];
    items.mintItems(_user, prizeRewards.itemIds, prizeRewards.itemAmounts);
  }

  function claimPrize(address _user, uint256 _epoch) public returns (bool) {
    require(hasStarted, "Leaderboard is not enabled.");
    require(!epochClaimedPrize[_epoch][_user], "Prize already claimed.");
    require(epochEnded(_epoch), "The competition is still ongoing.");

    uint256 length = LEADERBOARD_LENGTH;
    uint256 userScore = epochUserScore[_epoch][_user];

    for (uint256 i = 0; i < length; ) {
      if (
        epochLeaderboard[_epoch][i].score == userScore &&
        epochLeaderboard[_epoch][i].userAddress == _user
      ) {
        epochClaimedPrize[_epoch][_user] = true;
        _claimPrize(_user, i);
        return true;
      }

      unchecked {
        i++;
      }
    }

    epochClaimedPrize[_epoch][_user] = true;
    return true;
  }

  function claimLastEpochPrize(address _user) external {
    uint256 currentEpoch = getEpoch();
    require(currentEpoch > 0, "Epoch 0 still going.");

    claimPrize(_user, currentEpoch - 1);
  }

  function hasClaimedPrize(
    uint256 _epoch,
    address _user
  ) external view returns (bool) {
    return epochClaimedPrize[_epoch][_user];
  }

  function isOnLeaderboard(
    uint256 _epoch,
    address _address
  ) public view returns (bool, uint8) {
    for (uint8 i = 0; i < LEADERBOARD_LENGTH; ) {
      if (epochLeaderboard[_epoch][i].userAddress == _address) {
        return (true, i);
      }

      unchecked {
        i++;
      }
    }

    return (false, 0);
  }

  function addScore(
    address _user,
    uint256 _score
  ) external onlyRole(MODERATOR_ROLE) returns (bool) {
    if (!hasStarted) return false;

    uint256 epoch = getEpoch();
    uint256 totalScore = epochUserScore[epoch][_user] + _score;
    epochUserScore[epoch][_user] = totalScore;

    (bool hasEntry, uint256 position) = isOnLeaderboard(epoch, _user);

    // shift before
    if (hasEntry) {
      for (uint256 i = 0; i < position; ) {
        if (epochLeaderboard[epoch][i].score < totalScore) {
          User memory currentUser = epochLeaderboard[epoch][i];

          for (uint256 j = i + 1; j < LEADERBOARD_LENGTH; j++) {
            if (j == position + 1) break;

            User memory nextUser = epochLeaderboard[epoch][j];
            epochLeaderboard[epoch][j] = currentUser;
            currentUser = nextUser;
          }

          epochLeaderboard[epoch][i] = User(_user, totalScore);

          return true;
        }
        unchecked {
          i++;
        }
      }

      epochLeaderboard[epoch][position].score = totalScore;
      return false;
    }

    // shift after
    if (epochLeaderboard[epoch][LEADERBOARD_LENGTH - 1].score < totalScore) {
      for (uint256 i = 0; i < LEADERBOARD_LENGTH; ) {
        if (epochLeaderboard[epoch][i].score < totalScore) {
          User memory currentUser = epochLeaderboard[epoch][i];
          for (uint256 j = i + 1; j < LEADERBOARD_LENGTH; ) {
            User memory nextUser = epochLeaderboard[epoch][j];
            epochLeaderboard[epoch][j] = currentUser;
            currentUser = nextUser;
            unchecked {
              j++;
            }
          }

          epochLeaderboard[epoch][i] = User(_user, totalScore);
          return true;
        }

        unchecked {
          i++;
        }
      }
    }

    return false;
  }
}
