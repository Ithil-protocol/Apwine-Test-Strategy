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

    IAaveLendingPool private immutable aavePool;
    IAaveProtocolDataProvider private immutable aaveData;
    IApwineController private immutable apwineController;
    IApwineRegistry private immutable apwineRegistry;
    IApwineAMMRegistry private immutable apwineAMMRegistry;

   constructor(
        address _aavePool,
        address _aaveData,
        address _apwineController,
        address _apwineAMMRegistry
    ) {
        // Init vars
        aavePool = IAaveLendingPool(_aavePool);
        aaveData = IAaveProtocolDataProvider(_aaveData);
        apwineController = IApwineController(_apwineController);
        apwineAMMRegistry = IApwineAMMRegistry(_apwineAMMRegistry);

        console.log(apwineController.getRegistryAddress());

        apwineRegistry = IApwineRegistry(apwineController.getRegistryAddress());
    }

    function invest(address tkn, uint256 amount) external returns(uint256) {
        IERC20 token = IERC20(tkn);
        if (token.balanceOf(msg.sender) < amount) revert Input_Balance_Error();
        if (token.allowance(msg.sender, address(this)) < amount) revert Allowance_Error();

        // Step 1 - take tokens from the user
        token.safeTransferFrom(msg.sender, address(this), amount);
        if(token.allowance(address(this), address(aavePool)) == 0)
            token.safeApprove(address(aavePool), type(uint256).max); // approve aave

        // Step 2 - deposit wanted token on Aave
        aavePool.deposit(address(token), amount, address(this), 0);

        // Step 3 - get Apwine data
        (address futureVault, uint256 pairID) = _getFutureVault(tkn);
        IApwineAMM amm = IApwineAMM(apwineAMMRegistry.getFutureAMMPool(futureVault));

        // Step 4 - deposit aTokens on Apwine
        (address aToken,,) = aaveData.getReserveTokensAddresses(tkn);
        if(IERC20(aToken).allowance(address(this), address(apwineController)) == 0)
            IERC20(aToken).safeApprove(address(apwineController), type(uint256).max); // approve apwine controller

        apwineController.deposit(futureVault, amount);

        // Step 4 - swap PTokens for the underlying wanted tokens
        IERC20 ptoken = IERC20(IApwineFutureVault(futureVault).getPTAddress());
        uint256 ptokenBalance = ptoken.balanceOf(address(this));
        (uint256 amountOut, ) = amm.swapExactAmountIn(
            pairID,
            0, // _tokenIn - this should be the ptoken
            ptokenBalance,
            1, // _tokenOut -  this should be the underlying
            amm.getSpotPrice(pairID, 0, 1) * ptokenBalance, // TBD check math, 0 (ptoken) and 1 (fytoken) should be repaced with tokenIDs
            address(this)
        );

        if(token.balanceOf(address(this)) != amountOut) revert Output_Balance_Error();

        return amountOut;
    }

    function _getFutureVault(address token) internal view returns (address, uint256) {
        for(uint256 i = 0; i < apwineRegistry.futureVaultCount(); i++) {
            if(IApwineFutureVault(apwineRegistry.getFutureVaultAt(i)).getIBTAddress() == token) return (apwineRegistry.getFutureVaultAt(i), i);
        }
    }
}
