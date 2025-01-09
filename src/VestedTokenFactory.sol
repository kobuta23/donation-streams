// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.19;

import { AFTokenProxy } from "./Token.sol";
import { ISuperTokenFactory } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract VestedTokenFactory {
    // Superfluid factory address
    ISuperTokenFactory public immutable superTokenFactory;
    
    // Events
    event TokenDeployed(address indexed tokenAddress, string name, string symbol);

    constructor(address _superTokenFactory) {
        superTokenFactory = ISuperTokenFactory(_superTokenFactory);
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 vestingDuration,
        uint256 deployerAllocation
    ) external returns (address) {
        // Deploy new token
        AFTokenProxy token = new AFTokenProxy();
        
        // Initialize the token
        token.initialize(
            superTokenFactory,
            name,
            symbol,
            totalSupply,
            vestingDuration,
            msg.sender,
            deployerAllocation
        );
        
        // Emit event
        emit TokenDeployed(address(token), name, symbol);
        
        return address(token);
    }

}