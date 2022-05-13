import { artifacts, ethers, waffle } from "hardhat";
import type { Artifact } from "hardhat/types";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";

import type { Strategy } from "../../src/types/Strategy";
import { Signers } from "../types";
import { shouldInvest } from "./Strategy.behavior";

import { USDT, aavePool, aaveDataProvider, apwineController, apwineFuture, apwineAmm, pairId } from "../common";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.admin = signers[0];
    this.signers.investor = signers[1];
  });

  describe("Strategy", function () {
    beforeEach(async function () {
      const strategyArtifact: Artifact = await artifacts.readArtifact("Strategy");
      this.strategy = <Strategy>await waffle.deployContract(this.signers.admin, strategyArtifact, [
        USDT,
        aavePool,
        aaveDataProvider,
        apwineController,
        apwineAmm,
        apwineFuture,
        pairId
      ]);
    });

    shouldInvest();
  });
});
