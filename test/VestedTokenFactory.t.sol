// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {VestedTokenFactory} from "../src/VestedTokenFactory.sol";
import {AFTokenProxy} from "../src/Token.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {Fontaine} from "../src/Fontaine.sol";
import {console} from "forge-std/console.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";

contract VestedTokenFactoryTest is Test {
    // Constants for Base network
    address constant SUPER_TOKEN_FACTORY = 0xe20B9a38E0c96F61d1bA6b42a61512D56Fea1Eb3;
    address constant MARKET = address(0x123); // Replace with actual market address
    
    VestedTokenFactory factory;
    using SuperTokenV1Library for ISuperToken;

    address deployer;
    address user;

    function setUp() public {
        // Fork Base mainnet
        vm.createSelectFork(vm.envString("BASE_RPC_URL"));
        
        deployer = makeAddr("deployer");
        user = makeAddr("user");
        
        // Deploy factory with real SuperToken factory address
        vm.prank(deployer);
        factory = new VestedTokenFactory(SUPER_TOKEN_FACTORY);
    }

    function test_CreateToken() public {
        // Test parameters
        string memory name = "Test Token";
        string memory symbol = "TEST";
        uint256 totalSupply = 1000000e18;
        uint256 vestingDuration = 365 days;
        uint256 deployerAllocation = 100000e18;

        // Create token
        vm.prank(deployer);
        address tokenAddress = factory.createToken(
            name,
            symbol,
            totalSupply,
            vestingDuration,
            deployerAllocation
        );

        // Verify token was created
        AFTokenProxy token = AFTokenProxy(payable(tokenAddress));
        assertEq(token.deployer(), deployer);
        // Verify token parameters
        assertEq(token.market(), MARKET);
        assertEq(token.vestingDuration(), vestingDuration);
        
        // Verify deployer allocation
        assertEq(ISuperToken(address(token)).balanceOf(deployer), deployerAllocation);
        
        // Verify remaining tokens are held by token contract
        assertEq(
            ISuperToken(address(token)).balanceOf(MARKET), 
            totalSupply - deployerAllocation
        );
    }

    function test_TokenTransferAndStream() public {
        // Deploy token
        vm.prank(deployer);
        address tokenAddress = factory.createToken(
            "Stream Token",
            "STR",
            1000e18,
            365 days,
            100e18
        );
        
        AFTokenProxy token = AFTokenProxy(payable(tokenAddress));
        ISuperToken sToken = ISuperToken(address(token));

        console.log("MARKET balance of sToken", sToken.balanceOf(MARKET));
        // verify the MARKET has the right amount of tokens
        assertEq(sToken.balanceOf(MARKET), 900e18);

        // Test market transfer creates stream
        vm.prank(MARKET);
        uint256 timestamp = block.timestamp;
        token.transfer(user, 100e18);
        console.log("MARKET balance of sToken after transfer", sToken.balanceOf(MARKET));
        // Verify stream was created
        // Note: Additional verification of Superfluid stream would be needed here
        assertEq(ISuperToken(address(token)).balanceOf(user), 0); // Initial balance is 0 as tokens are streamed
        // check the right amount of tokens was moved to the fontaine
        // calculate the fontaine address 
        bytes32 salt = keccak256(abi.encodePacked(user, address(token), timestamp));
        address fontaine = address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            address(token),
            salt,
            keccak256(type(Fontaine).creationCode)
        )))));
        console.log("fontaine balance of sToken", sToken.balanceOf(fontaine));
        int96 flowrate = sToken.getFlowRate(fontaine, user);
        console.log("flowrate", uint256(int256(flowrate)));
        uint256 bufferAmount = sToken.getBufferAmountByFlowRate(flowrate);
        console.log("bufferAmount", bufferAmount);
        assertEq(ISuperToken(address(token)).balanceOf(fontaine), 100e18 - bufferAmount); // it should be less than 100%, because the buffer was already deducted
        vm.warp(block.timestamp + 1 days);
        console.log("user balance of sToken after 1 day", sToken.balanceOf(user));
        assertEq(ISuperToken(address(token)).balanceOf(user), uint256(int256(flowrate)) * 1 days);
    }

    function testFail_InvalidTotalSupply() public {
        vm.prank(deployer);
        factory.createToken(
            "Failed Token",
            "FAIL",
            1000e18,
            365 days,
            2000e18 // Deployer allocation > total supply
        );
    }
} 