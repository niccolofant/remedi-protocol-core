// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { LPToken } from "./tokens/LPToken.sol";

/*
 * @TODO Write documentation for each function
 */
contract Pair is ReentrancyGuard {
  event PairInitialized(
    address indexed _pair,
    address indexed _tokenA,
    address indexed _tokenB,
    address _lpToken
  );

  event LiquidityProvided(
    address indexed _from,
    address indexed _tokenA,
    uint256 _tokenAAmount,
    address indexed _tokenB,
    uint256 _tokenBAmount,
    uint256 _shares
  );

  event LiquidityWithdrawn(
    address indexed _to,
    address indexed _tokenA,
    uint256 _tokenAAmount,
    address indexed _tokenB,
    uint256 _tokenBAmount,
    uint256 _shares
  );

  event TokenASwapped(
    address indexed _to,
    address indexed _tokenA,
    uint256 _tokenAAmount,
    address indexed _tokenB,
    uint256 _tokenBAmount
  );

  event TokenBSwapped(
    address indexed _to,
    address indexed _tokenB,
    uint256 _tokenBAmount,
    address indexed _tokenA,
    uint256 _tokenAAmount
  );

  uint256 public constant PRECISION = 1e18;

  string public name;

  address private factory;
  ERC20 private tokenA;
  ERC20 private tokenB;
  LPToken private lpToken;
  uint256 private kLast;

  modifier validAmount(ERC20 token, uint256 amount) {
    require(amount > 0, "RemediV1: INVALID_AMOUNT");
    require(
      token.balanceOf(msg.sender) >= amount,
      "RemediV1: INSUFFICIENT_FUNDS"
    );
    _;
  }

  modifier validAmounts(ERC20[2] memory tokens, uint256[2] memory amounts) {
    uint256 tokensLength = tokens.length;
    require(tokensLength == amounts.length, "RemediV1: INVALID_AMOUNTS");
    for (uint256 i = 0; i < tokensLength; i++) {
      require(amounts[i] > 0, "RemediV1: INVALID_AMOUNT");
      require(
        tokens[i].balanceOf(msg.sender) >= amounts[i],
        "RemediV1: INSUFFICIENT_FUNDS"
      );
    }
    _;
  }

  modifier activePool() {
    require(getLpToken().totalSupply() > 0, "RemediV1: NO_ACTIVE_POOL");
    _;
  }

  constructor(
    address _tokenA,
    address _tokenB,
    address _lpToken
  ) {
    factory = msg.sender;

    _initializePair(_tokenA, _tokenB, _lpToken);
  }

  function _initializePair(
    address _tokenA,
    address _tokenB,
    address _lpToken
  ) internal {
    tokenA = ERC20(_tokenA);
    tokenB = ERC20(_tokenB);
    lpToken = LPToken(_lpToken);

    name = string(
      abi.encodePacked(getTokenA().name(), " - ", getTokenB().name(), " Pair")
    );

    emit PairInitialized(address(this), _tokenA, _tokenB, _lpToken);
  }

  function provideLiquidity(uint256 _tokenAAmount, uint256 _tokenBAmount)
    external
    validAmounts([getTokenA(), getTokenB()], [_tokenAAmount, _tokenBAmount])
    nonReentrant
    returns (uint256 shares)
  {
    uint256 totalShares = getLpToken().totalSupply();
    uint256 totalTokenA = getTokenA().balanceOf(address(this));
    uint256 totalTokenB = getTokenB().balanceOf(address(this));

    if (totalShares > 0) {
      uint256 tokenAShares = (totalShares * _tokenAAmount) / totalTokenA;
      uint256 tokenBShares = (totalShares * _tokenBAmount) / totalTokenB;
      require(tokenAShares == tokenBShares, "RemediV1: INVALID_AMOUNTS");
    }

    shares =
      sqrt((_tokenAAmount * _tokenBAmount) / PRECISION, PRECISION) *
      PRECISION;
    require(shares > 0, "RemediV1: INVALID_AMOUNTS");

    getLpToken().controlledMint(msg.sender, shares);

    getTokenA().transferFrom(msg.sender, address(this), _tokenAAmount);
    getTokenB().transferFrom(msg.sender, address(this), _tokenBAmount);

    kLast = totalTokenA * totalTokenB;

    emit LiquidityProvided(
      msg.sender,
      address(getTokenA()),
      _tokenAAmount,
      address(getTokenB()),
      _tokenBAmount,
      shares
    );
  }

  function withdrawLiquidity(uint256 _shares)
    external
    activePool
    validAmount(lpToken, _shares)
    nonReentrant
    returns (uint256 tokenAAmount, uint256 tokenBAmount)
  {
    (tokenAAmount, tokenBAmount) = getWithdrawEstimate(_shares);

    uint256 totalTokenA = getTokenA().balanceOf(address(this));
    uint256 totalTokenB = getTokenB().balanceOf(address(this));

    getLpToken().controlledBurn(msg.sender, _shares);

    getTokenA().transferFrom(address(this), msg.sender, tokenAAmount);
    getTokenB().transferFrom(address(this), msg.sender, tokenBAmount);

    kLast = totalTokenA * totalTokenB;

    emit LiquidityWithdrawn(
      msg.sender,
      address(getTokenA()),
      tokenAAmount,
      address(getTokenB()),
      tokenBAmount,
      _shares
    );
  }

  function swapTokenA(uint256 _tokenAAmount)
    external
    activePool
    validAmount(tokenA, _tokenAAmount)
    nonReentrant
    returns (uint256 tokenBAmount)
  {
    (uint256 netAmount, ) = getWithdrawEstimate(_tokenAAmount);
    tokenBAmount = getSwapTokenA(netAmount);

    getTokenA().transferFrom(msg.sender, address(this), _tokenAAmount);
    getTokenB().transferFrom(address(this), msg.sender, tokenBAmount);

    emit TokenASwapped(
      msg.sender,
      address(getTokenA()),
      _tokenAAmount,
      address(getTokenB()),
      tokenBAmount
    );
  }

  function swapTokenB(uint256 _tokenBAmount)
    external
    activePool
    validAmount(tokenB, _tokenBAmount)
    nonReentrant
    returns (uint256 tokenAAmount)
  {
    (uint256 netAmount, ) = getWithdrawEstimate(_tokenBAmount);
    tokenAAmount = getSwapTokenB(netAmount);

    getTokenB().transferFrom(msg.sender, address(this), _tokenBAmount);
    getTokenA().transferFrom(address(this), msg.sender, tokenAAmount);

    emit TokenBSwapped(
      msg.sender,
      address(getTokenB()),
      _tokenBAmount,
      address(getTokenA()),
      tokenAAmount
    );
  }

  function getHoldingsOf(address _of)
    external
    view
    returns (
      uint256 tokenAAmount,
      uint256 tokenBAmount,
      uint256 shares
    )
  {
    tokenAAmount = getTokenA().balanceOf(_of);
    tokenBAmount = getTokenB().balanceOf(_of);
    shares = getLpToken().balanceOf(_of);
  }

  function getPoolDetails()
    external
    view
    returns (
      uint256 tokenAAmount,
      uint256 tokenBAmount,
      uint256 totalShares
    )
  {
    tokenAAmount = getTokenA().balanceOf(address(this));
    tokenBAmount = getTokenB().balanceOf(address(this));
    totalShares = getLpToken().totalSupply();
  }

  function getRequiredTokenA(uint256 _tokenBAmount)
    public
    view
    activePool
    returns (uint256 requiredTokenA)
  {
    requiredTokenA =
      (getTokenA().balanceOf(address(this)) * _tokenBAmount) /
      getTokenB().balanceOf(address(this));
  }

  function getRequiredTokenB(uint256 _tokenAAmount)
    public
    view
    activePool
    returns (uint256 requiredTokenB)
  {
    requiredTokenB =
      (getTokenB().balanceOf(address(this)) * _tokenAAmount) /
      getTokenA().balanceOf(address(this));
  }

  function getSwapTokenA(uint256 _tokenAAmount)
    public
    view
    activePool
    returns (uint256 tokenBAmount)
  {
    uint256 totalTokenA = getTokenA().balanceOf(address(this));
    uint256 totalTokenB = getTokenB().balanceOf(address(this));

    uint256 tokenAAfter = totalTokenA + _tokenAAmount;
    uint256 tokenBAfter = kLast / tokenAAfter;

    tokenBAmount = totalTokenB - tokenBAfter;

    if (tokenBAmount == totalTokenB) tokenBAmount--;
  }

  function getSwapTokenAGivenTokenB(uint256 _tokenBAmount)
    public
    view
    activePool
    returns (uint256 tokenAAmount)
  {
    uint256 totalTokenA = getTokenA().balanceOf(address(this));
    uint256 totalTokenB = getTokenB().balanceOf(address(this));

    require(_tokenBAmount < totalTokenB, "RemediV1: INSUFFICIENT_POOL_BALANCE");

    uint256 tokenBAfter = totalTokenB - _tokenBAmount;
    uint256 tokenAAfter = kLast / tokenBAfter;
    tokenAAmount = tokenAAfter - totalTokenA;
  }

  function getSwapTokenB(uint256 _tokenBAmount)
    public
    view
    activePool
    returns (uint256 tokenAAmount)
  {
    uint256 totalTokenA = getTokenA().balanceOf(address(this));
    uint256 totalTokenB = getTokenB().balanceOf(address(this));

    uint256 tokenBAfter = totalTokenB + _tokenBAmount;
    uint256 tokenAAfter = kLast / tokenBAfter;

    tokenAAmount = totalTokenA - tokenAAfter;

    if (tokenAAmount == totalTokenA) tokenAAmount--;
  }

  function getSwapTokenBGivenTokenA(uint256 _tokenAAmount)
    public
    view
    activePool
    returns (uint256 tokenBAmount)
  {
    uint256 totalTokenA = getTokenA().balanceOf(address(this));
    uint256 totalTokenB = getTokenB().balanceOf(address(this));

    require(_tokenAAmount < totalTokenA, "RemediV1: INSUFFICIENT_POOL_BALANCE");

    uint256 tokenAAfter = totalTokenA - _tokenAAmount;
    uint256 tokenBAfter = kLast / tokenAAfter;
    tokenBAmount = tokenBAfter - totalTokenB;
  }

  function getWithdrawEstimate(uint256 _shares)
    public
    view
    activePool
    returns (uint256 tokenAAmount, uint256 tokenBAmount)
  {
    require(_shares <= getLpToken().totalSupply(), "RemediV1: INVALID_AMOUNT");
    uint256 totalShares = getLpToken().totalSupply();
    uint256 totalTokensA = getTokenA().balanceOf(address(this));
    uint256 totalTokensB = getTokenB().balanceOf(address(this));

    tokenAAmount = (_shares * totalTokensA) / totalShares;
    tokenBAmount = (_shares * totalTokensB) / totalShares;
  }

  function getSwapFees(uint256 _amount)
    public
    pure
    returns (uint256 netAmount, uint256 feeAmount)
  {
    feeAmount = (_amount * 3) / 1000;
    netAmount = _amount - feeAmount;
  }

  function getTokenA() public view returns (ERC20) {
    return tokenA;
  }

  function getTokenB() public view returns (ERC20) {
    return tokenB;
  }

  function getLpToken() public view returns (LPToken) {
    return lpToken;
  }

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
