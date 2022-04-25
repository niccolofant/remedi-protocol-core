// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

library Math {
  function sqrt(uint256 y, uint256 precision) public pure returns (uint256 z) {
    y = y / precision;

    if (y > 3) {
      z = y;
      uint256 x = y / 2 + 1;
      while (x < z) {
        z = x;
        x = (y / x + x) / 2;
      }
    } else if (y != 0) {
      z = 1;
    }
  }
}
