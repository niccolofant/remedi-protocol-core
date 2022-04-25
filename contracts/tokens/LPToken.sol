// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { ControlledToken } from "./ControlledToken.sol";

contract LPToken is ControlledToken {
  constructor(
    string memory _name,
    string memory _symbol,
    address _controller
  ) ControlledToken(_name, _symbol, _controller) {
    require(_controller != address(0), "GemiviV1: ZERO_ADDRESS");
  }
}
