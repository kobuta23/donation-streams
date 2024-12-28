// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.19;

import { RewardController } from "./RewardController.sol";

import { Ownable } from "@openzeppelin-v5/contracts/access/Ownable.sol";
import { CustomSuperTokenBase } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/CustomSuperTokenBase.sol";
import {
    IERC20,
    ISuperToken,
    ISuperTokenFactory
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { UUPSProxy } from "@superfluid-finance/ethereum-contracts/contracts/upgradability/UUPSProxy.sol";

contract AFTokenProxy is CustomSuperTokenBase, UUPSProxy, Ownable {

    error TransferNotAllowed();

    mapping(address => bool) public whitelistedForTransfer;

    bool public whitelistingEnabled = true;

    constructor() Ownable(msg.sender) { }

    function initialize(
        ISuperTokenFactory factory,
        string memory name,
        string memory symbol,
        address receiver,
        uint256 initialSupply
    ) external {
        factory.initializeCustomSuperToken(address(this));

        ISuperToken(address(this)).initialize(IERC20(address(0)), 18, name, symbol);
        ISuperToken(address(this)).selfMint(receiver, initialSupply, "");

        whitelistedForTransfer[receiver] = true;
    }

    function setWhitelistingEnabled(bool _enabled) external onlyOwner {
        whitelistingEnabled = _enabled;
    }

    function updateWhitelist(address user, bool isWhitelisted) external onlyOwner {
        whitelistedForTransfer[user] = isWhitelisted;
    }

    /**
     * @dev Hijack the {ISuperToken.transfer} function to allow only whitelisted users to transfer
     */
    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        if (whitelistingEnabled && !whitelistedForTransfer[msg.sender] && !whitelistedForTransfer[recipient]) {
            revert TransferNotAllowed();
        }

        ISuperToken(address(this)).selfTransferFrom(msg.sender, msg.sender, recipient, amount);

        return true;
    }

    /**
     * @dev Hijack the {ISuperToken.transferFrom} function to allow only whitelisted users to transfer
     */
    function transferFrom(address holder, address recipient, uint256 amount) public returns (bool) {
        if (whitelistingEnabled && !whitelistedForTransfer[msg.sender] && !whitelistedForTransfer[recipient]) {
            revert TransferNotAllowed();
        }

        ISuperToken(address(this)).selfTransferFrom(holder, msg.sender, recipient, amount);

        return true;
    }

}