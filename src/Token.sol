// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.19;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CustomSuperTokenBase } from
    "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/CustomSuperTokenBase.sol";
import {
    IERC20,
    ISuperToken,
    ISuperTokenFactory
} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { UUPSProxy } from "@superfluid-finance/ethereum-contracts/contracts/upgradability/UUPSProxy.sol";
import { Fontaine } from "./Fontaine.sol";
import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

contract AFTokenProxy is CustomSuperTokenBase, UUPSProxy {

    error TransferNotAllowed();
    using SuperTokenV1Library for ISuperToken;

    address public market;
    uint256 public vestingDuration;
    address public deployer;

    constructor(){ }

    function initialize(
        ISuperTokenFactory factory,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 _vestingDuration, // the duration of the vesting
        address _deployer,
        uint256 deployerAllocation // the initial balance of the deployer. Can be zero
    ) external {
        // check the the sum of the allocations is equal to the total supply
        uint256 initialMarketAllocation = totalSupply - deployerAllocation;
        vestingDuration = _vestingDuration;
        factory.initializeCustomSuperToken(address(this));
        deployer = _deployer;
        ISuperToken(address(this)).initialize(IERC20(address(0)), 18, name, symbol);
        if (deployerAllocation > 0) {
            ISuperToken(address(this)).selfMint(deployer, deployerAllocation, "");
        }
        // mint the initialMarketAllocation to this contract itself
        if (initialMarketAllocation > 0) {
            ISuperToken(address(this)).selfMint(address(this), initialMarketAllocation, "");
        }
        // deploy uniswap V3 market
        // market = deployUniswapV3Market();
        // deposit initial market allocation
        market = address(0x123); //setting here for testing purposes.
        ISuperToken(address(this)).selfTransferFrom(address(this), address(this), market, initialMarketAllocation); // TODO: remove this line
    }

    /**
     * @dev Hijack the {ISuperToken.transfer} function to allow only whitelisted users to transfer
     */
    function transfer(address recipient, uint256 amount) public virtual returns (bool) {
        if (msg.sender == market) {
            // TODO: decide if transfer 1% or emit transfer event so it pops up in wallets
            fontaineStream(msg.sender, recipient, amount);
        } else {
            ISuperToken(address(this)).selfTransferFrom(msg.sender, msg.sender, recipient, amount);
        }

        return true;
    }

    /**
     * @dev Hijack the {ISuperToken.transferFrom} function to allow only whitelisted users to transfer
     */
    function transferFrom(address holder, address recipient, uint256 amount) public returns (bool) {
        if (msg.sender == market) {
            // TODO: decide if transfer 1% or emit transfer event
            fontaineStream(holder, recipient, amount);
        } else {
            ISuperToken(address(this)).selfTransferFrom(holder, msg.sender, recipient, amount);
        }

        return true;
    }

    function fontaineStream(address from, address to, uint256 amount) internal {
        // deploy a fontaine
        // using this salt, if you know when the trade was made, you can find the fontaine
        bytes32 salt = keccak256(abi.encodePacked(to, address(this), block.timestamp));
        address fontaine = address(new Fontaine{salt: salt}());
        // transfer it the funds
        ISuperToken(address(this)).selfTransferFrom(from, msg.sender, fontaine, amount);
        // call the createStream function
        ISuperToken(address(this)).createFlowFrom(fontaine, to, int96(uint96(amount / vestingDuration)));
    }

}