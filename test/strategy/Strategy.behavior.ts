import { expect } from "chai";
import { ethers } from "ethers";

export function shouldInvest(): void {
  it("should return the same amount invested", async function () {
    const amount = ethers.utils.parseUnits("1000.0", 6); // USDC has got 6 decimal places
    expect(await this.strategy.connect(this.signers.admin).invest(amount)).to.equal(amount);
  });
}
