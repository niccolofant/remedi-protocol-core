// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IControlledToken {
  function pause() external;

  function unpause() external;

  function controlledMint(address _to, uint256 _amount) external;

  function controlledBurn(address _from, uint256 _amount) external;
}
