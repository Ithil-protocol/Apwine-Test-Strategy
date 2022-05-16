import { ethers } from "hardhat";
import { BigNumber, Signer } from "ethers";
import ERC20 from "@openzeppelin/contracts/build/contracts/ERC20.json";

export const USDT = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
export const USDTWhale = "0x5754284f345afc66a98fbB0a0Afe71e0F007B949";
export const aavePool = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9";
export const aaveDataProvider = "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d";
export const apwineController = "0x4bA30FA240047c17FC557b8628799068d4396790";
export const apwineRegistry  = "0x72d15EAE2Cd729D8F2e41B1328311f3e275612B9";
export const apwineAmmRegistry = "0x6646A35e74e35585B0B02e5190445A324E5D4D01";

export const getTokens = async (user: string, token: any, whale: string, amount: BigNumber) => {
    const contract = await ethers.getContractAt(ERC20.abi, token);
  
    await ethers.provider.send("hardhat_impersonateAccount", [whale]);
    const impersonatedAccount = ethers.provider.getSigner(whale);
    await contract.connect(impersonatedAccount).transfer(user, amount);
};
