import { expect } from "chai";
import { ethers } from "hardhat";
import { USDT, USDTWhale, getTokens } from "../common";
import { abi } from "@openzeppelin/contracts/build/contracts/ERC20.json";

export function shouldInvest(): void {
  it("should return the same amount invested", async function () {
    this.token = await ethers.getContractAt(abi, USDT);

    const amount = ethers.utils.parseUnits("1000.0", 6); // USDC has got 6 decimal places
    getTokens(this.signers.investor.address, USDT, USDTWhale, amount.mul(100));

    const res = await this.strategy.getFutureVault(USDT);

    this.token.connect(this.signers.investor).approve(this.strategy.address, ethers.constants.MaxUint256);
    await this.strategy.connect(this.signers.investor).invest(USDT, amount, res);
  });
}
