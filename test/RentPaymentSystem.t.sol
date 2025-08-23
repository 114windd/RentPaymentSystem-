// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRentPaymentSystem} from "../script/DeployRentPaymentSystem.s.sol";
import {RentPaymentSystem} from "../src/RentPaymentSystem.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {CodeConstants} from "../src/CodeConstants.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {MockV3Aggregator} from "./MockV3Aggregator.sol";

contract RentPaymentSystemTest is Test, CodeConstants {
    RentPaymentSystem public rentPaymentSystem;
    HelperConfig public helperConfig;

    function setUp() external {
        // Instead of calling the deployer, let's recreate the deployment logic here
        helperConfig = new HelperConfig();
        address priceFeed = helperConfig
            .getConfigByChainId(block.chainid)
            .priceFeed;

        if (priceFeed != address(0)) {
            // Use the real price feed
            rentPaymentSystem = new RentPaymentSystem(priceFeed);
        } else {
            // Use mock price feed for local testing
            MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
                DECIMALS,
                INITIAL_PRICE
            );
            rentPaymentSystem = new RentPaymentSystem(address(mockPriceFeed));
        }
    }
}
