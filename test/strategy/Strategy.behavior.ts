import { expect } from "chai";
import { ethers } from "ethers";
import { USDT, USDTWhale, getTokens } from "../common";

export function shouldInvest(): void {
  it("should return the same amount invested", async function () {
    const amount = ethers.utils.parseUnits("1000.0", 6); // USDC has got 6 decimal places
    getTokens(this.signers.investor.address, USDT, USDTWhale, amount.mul(100));

    const res = await this.strategy.getFutureVault(USDT);
    console.log(res);
    expect( await this.strategy.connect(this.signers.investor).invest(USDT, amount, res[0], res[1]) ).to.equal(amount);
  });
}
