// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { SuperTokenV1Library } from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

contract Fontaine {
    using SuperTokenV1Library for ISuperToken;

    constructor() {
        ISuperToken(msg.sender).setMaxFlowPermissions(msg.sender);
    }
}

