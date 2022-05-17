// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IAaveLendingPool } from "./interfaces/IAaveLendingPool.sol";
import { IAaveProtocolDataProvider } from "./interfaces/IAaveProtocolDataProvider.sol";
import { IApwineController } from "./interfaces/IApwineController.sol";
import { IApwineRegistry } from "./interfaces/IApwineRegistry.sol";
import { IApwineFutureVault } from "./interfaces/IApwineFutureVault.sol";
import { IApwineAMM } from "./interfaces/IApwineAMM.sol";
import { IApwineAMMRegistry } from "./interfaces/IApwineAMMRegistry.sol";

import "hardhat/console.sol";

contract Strategy {
    using SafeERC20 for IERC20;

    error Input_Balance_Error();
    error Output_Balance_Error();
    error Allowance_Error();
    error Vault_Not_Found();
    error AMM_Disabled(uint256 pairID);

    IAaveLendingPool private immutable aavePool;
    IAaveProtocolDataProvider private immutable aaveData;
    IApwineController private immutable apwineController;
    IApwineRegistry private immutable apwineRegistry;
    IApwineAMMRegistry private immutable apwineAMMRegistry;
    uint256 private constant pairID = 0;

   constructor(
        address _aavePool,
        address _aaveData,
        address _apwineController,
        address _apwineRegistry,
        address _apwineAMMRegistry
    ) {
        // Init vars
        aavePool = IAaveLendingPool(_aavePool);
        aaveData = IAaveProtocolDataProvider(_aaveData);
        apwineController = IApwineController(_apwineController);
        apwineRegistry = IApwineRegistry(_apwineRegistry);
        apwineAMMRegistry = IApwineAMMRegistry(_apwineAMMRegistry);
    }

    function _transferTokens(IERC20 token, uint256 amount) internal {
        if (token.balanceOf(msg.sender) < amount) revert Input_Balance_Error();
        if (token.allowance(msg.sender, address(this)) < amount) revert Allowance_Error();

        token.safeTransferFrom(msg.sender, address(this), amount);
    }

    function _depositOnAave(IERC20 token, uint256 amount) internal returns(IERC20, uint256) {
        if(token.allowance(address(this), address(aavePool)) == 0)
            token.safeApprove(address(aavePool), type(uint256).max);
    
        aavePool.deposit(address(token), amount, address(this), 0);

        (address aToken,,)= aaveData.getReserveTokensAddresses(address(token));
        IERC20 tkn = IERC20(aToken);

        return (tkn, tkn.balanceOf(address(this)));
    }

    function _depositOnApwine(address futureVault, IERC20 aToken, uint256 amount) internal {
        if(IApwineFutureVault(futureVault).getIBTAddress() != address(aToken)) revert Vault_Not_Found();

        if(aToken.allowance(address(this), address(apwineController)) == 0)
            aToken.safeApprove(address(apwineController), type(uint256).max); // approve apwine controller

        apwineController.deposit(futureVault, amount);
    }

    function _swapOnApwine(address futureVault) internal returns (uint256) {
        IERC20 ptoken = IERC20(IApwineFutureVault(futureVault).getPTAddress());
        uint256 ptokenBalance = ptoken.balanceOf(address(this));

        console.log("PTokenBalance", ptokenBalance);

        IApwineAMM amm = IApwineAMM(apwineAMMRegistry.getFutureAMMPool(futureVault));
        if(!amm.getAMMState()) revert AMM_Disabled(pairID);

        if(ptoken.allowance(address(this), address(amm)) == 0)
            ptoken.safeApprove(address(amm), type(uint256).max); // approve apwine amm

        (uint256 minOut, ) = amm.calcOutAndSpotGivenIn(
            pairID, 
            0, 
            ptokenBalance,
            1,
            0
        );

        console.log("minOut", minOut);

        (uint256 amountOut, ) = amm.swapExactAmountIn(
            pairID,
            0, // _tokenIn - this should be the ptoken
            ptokenBalance,
            1, // _tokenOut -  this should be the underlying
            minOut,
            address(this)
        );

        return amountOut;
    }

    function invest(address tkn, uint256 amount, address futureVault) external returns(uint256) {
        IERC20 token = IERC20(tkn);

        console.log("amountIn", amount);
    
        // Step 1 - take tokens from the user
        console.log("Transfering tokens");
        _transferTokens(token, amount);
        console.log("Transfer successful");

        // Step 2 - deposit wanted token on Aave
        console.log("Depositing tokens on Aave");
        (IERC20 aToken, uint256 aTokenBalance) = _depositOnAave(token, amount);
        console.log("aToken received", aTokenBalance);
        console.log("Deposit on Aave successful");

        // Step 3 - deposit aTokens on Apwine
        console.log("Depositing tokens on Apwine");
        _depositOnApwine(futureVault, aToken, aTokenBalance);
        console.log("Deposit on Apwine successful");

        // Step 4 - swap PTokens for the underlying wanted tokens
        console.log("Swapping tokens on Apwine AMM");
        uint256 amountOut = _swapOnApwine(futureVault);
        console.log("Swap successful");

        if(token.balanceOf(address(this)) != amountOut) revert Output_Balance_Error();

        console.log("amountOut", amountOut);

        return amountOut;
    }

    function getFutureVault(address tkn) external view returns (address) {    
        (address token,,)= aaveData.getReserveTokensAddresses(tkn);
   
        for(uint256 i = 0; i < apwineRegistry.futureVaultCount(); i++) {
            if(IApwineFutureVault(apwineRegistry.getFutureVaultAt(i)).getIBTAddress() == token) return apwineRegistry.getFutureVaultAt(i);
        }

        revert Vault_Not_Found();
    }
}
