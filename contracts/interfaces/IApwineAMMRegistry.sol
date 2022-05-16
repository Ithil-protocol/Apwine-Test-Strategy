// SPDX-License-Identifier: MIT
pragma solidity >=0.8.10;

interface IApwineAMMRegistry {
    /**
     * @notice Getter for the controller address
     * @return the address of the controller
     */
    function getFutureAMMPool(address _futureVaultAddress) external view returns (address);

    function isRegisteredAMM(address _ammAddress) external view returns (bool);
}
