import { expect } from "chai";
import { ethers } from "hardhat";
import { USDT, USDTWhale, getTokens } from "../common";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";

export function shouldInvest(): void {
  it("should return the same amount invested", async function () {
    const amount = ethers.utils.parseUnits("1000.0", 6); // USDC has got 6 decimal places
    const amount2 = ethers.utils.parseUnits("100.0", 6); // USDC has got 6 decimal places

    const val = await getTokens(this.signers.investor.address, USDT, USDTWhale, this.signers.admin, amount.mul(100));
    const impersonatedAccount = ethers.provider.getSigner(USDTWhale);
    var USDTBalence = new ethers.Contract(USDT, ERC20.abi, impersonatedAccount);

    let ee = await USDTBalence.approve(this.signers.investor.address, amount);
    let i = await this.strategy.connect(this.signers.investor).invest(amount);

    expect(await this.strategy.connect(this.signers.investor).invest(amount2)).to.equal(amount2);
  });
}
