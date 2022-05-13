// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import { IAaveLendingPool } from "./interfaces/IAaveLendingPool.sol";
import { IAaveProtocolDataProvider } from "./interfaces/IAaveProtocolDataProvider.sol";
import { IController } from "./interfaces/IController.sol";
import { IAMM } from "./interfaces/IAMM.sol";
import "hardhat/console.sol";

contract Strategy {
    using SafeERC20 for IERC20;

    error Input_Balance_Error();
    error Output_Balance_Error();
    error Allowance_Error();

    IERC20 private immutable token;
    IAaveLendingPool private immutable aavePool;
    IAaveProtocolDataProvider private immutable aaveData;
    IERC1155 private ptoken;
    IERC1155 private fytoken;
    IController private immutable controller; // Apwine controller
    IAMM private immutable amm; // Apwine AMM
    address private immutable futureVault;
    uint256 private immutable pairID;

   constructor(
        address _token,
        address _aavePool,
        address _aaveData,
        address _controller,
        address _amm,
        address _futureVault,
        uint256 _pairID
    ) {
        // Init vars
        token = IERC20(_token);
        aavePool = IAaveLendingPool(_aavePool);
        aaveData = IAaveProtocolDataProvider(_aaveData);
        controller = IController(_controller);
        amm = IAMM(_amm);
        futureVault = _futureVault;
        pairID = _pairID;

        // get PToken and FYToken addresses from the AMM
        //console.log(amm.getPTAddress());
        //ptoken = IERC1155(amm.getPTAddress()); // <== Fails here
        //fytoken = IERC1155(amm.getFYTAddress());

        // token transfer approves
        token.safeApprove(_aavePool, type(uint256).max); // approve aave
    }

    function invest(uint256 amount) external returns(uint256) {
        if (token.balanceOf(msg.sender) < amount) revert Input_Balance_Error();
        if (token.allowance(msg.sender, address(this)) < amount) revert Allowance_Error();

        // Step 1 - take tokens from the user
        token.safeTransferFrom(msg.sender, address(this), amount);

        // Step 2 - deposit wanted token on Aave
        aavePool.deposit(address(token), amount, address(this), 0);

        // Step 3 - deposit aTokens on Apwine
        (address aToken,,) = aaveData.getReserveTokensAddresses(address(token));
        if(IERC20(aToken).allowance(address(this), address(controller)) == 0)
            IERC20(aToken).safeApprove(address(controller), type(uint256).max); // approve apwine controller

        controller.deposit(futureVault, amount);

        // Step 4 - swap PTokens for the underlying wanted tokens
        uint256 ptokenBalance = 0;//ptoken.balanceOf(address(this));
        (uint256 amountOut, ) = amm.swapExactAmountIn(
            pairID,
            0, // TBD this should be the ptoken token ID
            ptokenBalance,
            1, // TBD this should be the fytoken token ID
            amm.getSpotPrice(pairID, 0, 1) * ptokenBalance, // TBD check math, 0 (ptoken) and 1 (fytoken) should be repaced with tokenIDs
            address(this)
        );

        if(token.balanceOf(address(this)) != amountOut) revert Output_Balance_Error();

        return amountOut;
    }
}
