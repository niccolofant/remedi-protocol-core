/* SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract PairFactory is Ownable {
  event MarketPairCreated(
    address indexed marketPair,
    address indexed token1,
    address indexed token2
  );

  mapping(address => mapping(address => address)) public getPair;
  // IMarketPair[] public pairs;
  uint256 public feeForLiquidityProviders;

  function createMarketPair(address _tokenA, address _tokenB)
    external
    onlyOwner
    returns (address pair)
  {
    require(_tokenA != _tokenB, "RemediV1: IDENTICAL_ADDRESSES");
    (address token0, address token1) = _tokenA < _tokenB
      ? (_tokenA, _tokenB)
      : (_tokenA, _tokenB);

    require(token0 != address(0), "RemediV1: ZERO_ADDRESS");
    require(token1 != address(0), "RemediV1: ZERO_ADDRESS");

    require(getPair[token0][token1] == address(0), "RemediV1: PAIR_EXISTS");

    // IMarketPair memory _marketPair = new IMarketPair(_token1, _token2);
    // pair = address(_marketPair)
    // pairs.push(_marketPair)
    // getPais[token0][token1] = _marketPair
    // getPais[token1][token0] = _marketPair

    // emit MarketPairCreated(address(_marketPair), token0, token1);
  }

  function pairsLength() external view returns (uint256) {
    return pairs.length;
  }
}
*/