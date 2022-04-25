// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IControlledToken } from "../interfaces/IControlledToken.sol";

contract ControlledToken is
  IControlledToken,
  ERC20,
  ERC20Burnable,
  Pausable,
  AccessControl
{
  bytes32 public constant PAUSER_ROLE = keccak256("GemiviV1: PAUSER_ROLE");
  bytes32 public constant MINTER_ROLE = keccak256("GemiviV1: MINTER_ROLE");

  constructor(
    string memory _name,
    string memory _symbol,
    address _controller
  ) ERC20(_name, _symbol) {
    _grantRole(DEFAULT_ADMIN_ROLE, _controller);
    _grantRole(PAUSER_ROLE, _controller);
    _grantRole(MINTER_ROLE, _controller);
  }

  function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
  }

  function unpause() external onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  function controlledMint(address _to, uint256 _amount)
    external
    onlyRole(MINTER_ROLE)
  {
    _mint(_to, _amount);
  }

  function controlledBurn(address _from, uint256 _amount)
    external
    onlyRole(MINTER_ROLE)
  {
    _burn(_from, _amount);
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  ) internal override whenNotPaused {
    super._beforeTokenTransfer(from, to, amount);
  }
}
