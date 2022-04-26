// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.10;

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IAave } from "./interfaces/IAave.sol";
import { IController } from "./interfaces/IController.sol";
import { IAMM } from "./interfaces/IAMM.sol";
import "hardhat/console.sol";

contract Strategy {
    using SafeERC20 for IERC20;

    error Input_Balance_Error();
    error Output_Balance_Error();
    error Allowance_Error();

    IERC20 private immutable token;
    IERC20 private immutable aToken;
    IAave private immutable aave;
    address private immutable ptoken;
    address private immutable fytoken;
    IController private immutable controller; // Apwine controller
    IAMM private immutable amm; // Apwine AMM
    address private immutable futureVault;
    uint256 private immutable pairID;

   constructor(
        address _token,
        address _aToken,
        address _aavePool,
        address _controller,
        address _amm,
        address _futureVault,
        uint256 _pairID
    ) {
        // Init vars
        token = IERC20(_token);
        aToken = IERC20(_aToken);
        aave = IAave(_aavePool);
        controller = IController(_controller);
        amm = IAMM(_amm);
        futureVault = _futureVault;
        pairID = _pairID;

        // get PToken and FYToken addresses from the AMM
        ptoken = amm.getPTAddress(); // <== Fails here
        fytoken = amm.getFYTAddress();

        // token transfer approves
        token.safeApprove(_aavePool, type(uint256).max); // approve aave
        aToken.safeApprove(_controller, type(uint256).max); // approve apwine controller
        //ptoken.safeApprove(_amm, type(uint256).max); // approve apwine amm
        //fytoken.safeApprove(_amm, type(uint256).max); // approve apwine amm
    }

    function invest(uint256 amount) external returns(uint256) {
        if (token.balanceOf(msg.sender) < amount) revert Input_Balance_Error();
        if (token.allowance(msg.sender, address(this)) < amount) revert Allowance_Error();

        // Step 1 - take tokens from the user
        token.safeTransferFrom(msg.sender, address(this), amount);

        // Step 2 - deposit wanted token on Aave
        aave.deposit(address(token), amount, address(this), 0);

        // Step 3 - deposit aTokens on Apwine
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
