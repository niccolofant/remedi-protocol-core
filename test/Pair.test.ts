import { expect } from "chai";
import {
  ERC20TokenInstance,
  LPTokenInstance,
  PairInstance,
} from "../types/truffle-contracts";
const { expectRevert } = require("@openzeppelin/test-helpers");

const Pair = artifacts.require("Pair");
const ERC20Token = artifacts.require("ERC20Token");
const LPToken = artifacts.require("LPToken");

/**
 * @TODO Finish tests
 */
contract("Pair", (accounts) => {
  let tokenA: ERC20TokenInstance;
  let tokenB: ERC20TokenInstance;
  let lpToken: LPTokenInstance;
  let pair: PairInstance;

  // Accounts
  const owner = accounts[0];
  const lpProvider1 = accounts[1];
  const lpProvider2 = accounts[2];
  const swapper = accounts[3];

  beforeEach(async () => {
    tokenA = await ERC20Token.new("Token A", "TKA", { from: owner });
    tokenB = await ERC20Token.new("Token B", "TKB", { from: owner });
    lpToken = await LPToken.new("LPToken", "LPT", owner, { from: owner });
    pair = await Pair.new(tokenA.address, tokenB.address, lpToken.address, {
      from: owner,
    });

    // Set the pair as minter
    const minterRole = await lpToken.MINTER_ROLE();
    await lpToken.grantRole(minterRole, pair.address, {
      from: owner,
    });

    // // Mint tokens and set correct allowances for Liquidity Pool provider 1
    // await tokenA.mint(lpProvider1, web3.utils.toWei("5"), { from: owner });
    // await tokenA.approve(pair.address, web3.utils.toWei("5"), {
    //   from: lpProvider1,
    // });
    // await tokenB.mint(lpProvider1, web3.utils.toWei("20"), { from: owner });
    // await tokenB.approve(pair.address, web3.utils.toWei("20"), {
    //   from: lpProvider1,
    // });

    // // Mint tokens and set correct allowances for Liquidity Pool provider 2
    // await tokenA.mint(lpProvider2, web3.utils.toWei("50"), { from: owner });
    // await tokenA.approve(pair.address, web3.utils.toWei("50"), {
    //   from: lpProvider2,
    // });
    // await tokenB.mint(lpProvider2, web3.utils.toWei("200"), { from: owner });
    // await tokenB.approve(pair.address, web3.utils.toWei("200"), {
    //   from: lpProvider2,
    // });

    // // Mints tokens for the swapper
    // await tokenA.mint(swapper, web3.utils.toWei("10"), { from: owner });
    // await tokenA.approve(pair.address, web3.utils.toWei("10"), {
    //   from: swapper,
    // });
  });

  describe("_initializePair", () => {
    it("should initialize the pair correctly", async () => {
      expect(await pair.name()).to.eq("Token A - Token B Pair");
      expect(await pair.getTokenA()).to.eq(tokenA.address);
      expect(await pair.getTokenB()).to.eq(tokenB.address);
      expect(await pair.getLpToken()).to.eq(lpToken.address);
    });
  });

  describe("getHoldingsOf", () => {
    it("should return the correct holdings of the specified address", async () => {
      await tokenA.mint(lpProvider1, web3.utils.toWei("5"), { from: owner });
      await tokenB.mint(lpProvider1, web3.utils.toWei("20"), { from: owner });

      const {
        0: tokenABalance,
        1: tokenBBalance,
        2: lpTokenBalance,
      } = await pair.getHoldingsOf(lpProvider1);

      expect(tokenABalance.toString()).to.eq(web3.utils.toWei("5"));
      expect(tokenBBalance.toString()).to.eq(web3.utils.toWei("20"));
      expect(lpTokenBalance.toString()).to.eq(web3.utils.toWei("0"));
    });
  });

  describe("getPoolDetails", () => {
    it("should return the correct pool details", async () => {
      await tokenA.mint(lpProvider1, web3.utils.toWei("5"), { from: owner });
      await tokenA.approve(pair.address, web3.utils.toWei("5"), {
        from: lpProvider1,
      });
      await tokenB.mint(lpProvider1, web3.utils.toWei("20"), { from: owner });
      await tokenB.approve(pair.address, web3.utils.toWei("20"), {
        from: lpProvider1,
      });
      await pair.provideLiquidity(
        web3.utils.toWei("5"),
        web3.utils.toWei("20"),
        { from: lpProvider1 }
      );

      const {
        0: tokenABalance,
        1: tokenBBalance,
        2: lpTokenBalance,
      } = await pair.getPoolDetails();

      expect(tokenABalance.toString()).to.eq(web3.utils.toWei("5"));
      expect(tokenBBalance.toString()).to.eq(web3.utils.toWei("20"));
      expect(lpTokenBalance.toString()).to.eq(web3.utils.toWei("10"));
    });
  });

  describe("getRequiredTokenA", () => {
    it("should revert if the pool is empty", async () => {
      await expectRevert(
        pair.getRequiredTokenA(web3.utils.toWei("1")),
        "RemediV1: NO_ACTIVE_POOL"
      );
    });

    it("should return the correct amount of tokenA required, given a tokenB amount (excluding swap fees)", async () => {
      await tokenA.mint(lpProvider1, web3.utils.toWei("5"), { from: owner });
      await tokenA.approve(pair.address, web3.utils.toWei("5"), {
        from: lpProvider1,
      });
      await tokenB.mint(lpProvider1, web3.utils.toWei("20"), { from: owner });
      await tokenB.approve(pair.address, web3.utils.toWei("20"), {
        from: lpProvider1,
      });
      await pair.provideLiquidity(
        web3.utils.toWei("5"),
        web3.utils.toWei("20"),
        { from: lpProvider1 }
      );

      const requiredTokenA = await pair.getRequiredTokenA(
        web3.utils.toWei("75")
      );

      expect(requiredTokenA.toString()).to.eq(web3.utils.toWei("18.75"));
    });
  });

  describe("getRequiredTokenB", () => {
    it("should revert if the pool is empty", async () => {
      await expectRevert(
        pair.getRequiredTokenB(web3.utils.toWei("1")),
        "RemediV1: NO_ACTIVE_POOL"
      );
    });

    it("should return the correct amount of tokenB required, given a tokenA amount (excluding swap fees)", async () => {
      await tokenA.mint(lpProvider1, web3.utils.toWei("5"), { from: owner });
      await tokenA.approve(pair.address, web3.utils.toWei("5"), {
        from: lpProvider1,
      });
      await tokenB.mint(lpProvider1, web3.utils.toWei("20"), { from: owner });
      await tokenB.approve(pair.address, web3.utils.toWei("20"), {
        from: lpProvider1,
      });
      await pair.provideLiquidity(
        web3.utils.toWei("5"),
        web3.utils.toWei("20"),
        { from: lpProvider1 }
      );

      const requiredTokenB = await pair.getRequiredTokenB(
        web3.utils.toWei("1")
      );

      expect(requiredTokenB.toString()).to.eq(web3.utils.toWei("4"));
    });
  });
});
