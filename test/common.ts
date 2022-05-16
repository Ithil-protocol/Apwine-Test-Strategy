import { ethers, network } from "hardhat";
import { BigNumber, Signer } from "ethers";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";

export const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
export const aUSDT = "0xBcca60bB61934080951369a648Fb03DF4F96263C";
export const apwToken = "0x4104b135DBC9609Fc1A9490E61369036497660c8";
export const aavePool = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9";
export const aaveDataProvider = "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d";
export const aave = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9";
export const uniRouterV2 = "0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D";
export const apwineController = "0x4ba30fa240047c17fc557b8628799068d4396790";
export const apwineFuture = "0xb524c16330a76182ef617f08f5e6996f577ac64a";
export const apwineAmm = "0xb932c4801240753604c768c991eb640bcd7c06eb";
export const pairId = 1; // TBC
export const USDTWhale = "0x67aB29354a70732CDC97f372Be81d657ce8822cd";

export const getTokens = async (user: string, token: any, whale: string, signer: any, amount: BigNumber) => {
  await ethers.provider.send("hardhat_impersonateAccount", [USDTWhale]);
  const contract = await ethers.getContractAt(ERC20.abi, token);

  await network.provider.request({
    method: "hardhat_impersonateAccount",
    params: [USDTWhale],
  });
  const impersonatedAccount = ethers.provider.getSigner(whale);

  var USDTBalence = new ethers.Contract(USDT, ERC20.abi, impersonatedAccount);

  await contract.connect(impersonatedAccount).transfer(user, amount);
  console.log("Balance of user after trasnfer: ", await USDTBalence.balanceOf(user));

  return USDT;
};
