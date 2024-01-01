//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

struct Stats {
  uint32 health;
  uint32 attack;
  uint32 defense;
  uint32 speed;
  uint32 charisma;
  uint32 effectiveness;
}

library StatsMath {
  function add(
    Stats memory a,
    Stats memory b
  ) internal pure returns (Stats memory) {
    return
      Stats(
        a.health + b.health,
        a.attack + b.attack,
        a.defense + b.defense,
        a.speed + b.speed,
        a.charisma + b.charisma,
        a.effectiveness + b.effectiveness
      );
  }

  function simpleAdd(
    Stats memory a,
    Stats memory b
  ) internal pure returns (Stats memory) {
    return
      Stats(
        a.health + b.health,
        a.attack + b.attack,
        a.defense + b.defense,
        a.speed + b.speed,
        a.charisma + b.charisma,
        a.effectiveness
      );
  }

  function mul(
    Stats memory a,
    uint32 value
  ) internal pure returns (Stats memory) {
    return
      Stats(
        a.health * value,
        a.attack * value,
        a.defense * value,
        a.speed * value,
        a.charisma * value,
        a.effectiveness * value
      );
  }

  function simpleMul(
    Stats memory a,
    uint32 value
  ) internal pure returns (Stats memory) {
    return
      Stats(
        a.health * value,
        a.attack * value,
        a.defense * value,
        a.speed * value,
        a.charisma * value,
        a.effectiveness
      );
  }

  function div(
    Stats memory a,
    uint32 value
  ) internal pure returns (Stats memory) {
    return
      Stats(
        a.health / value,
        a.attack / value,
        a.defense / value,
        a.speed / value,
        a.charisma / value,
        a.effectiveness
      );
  }
}
