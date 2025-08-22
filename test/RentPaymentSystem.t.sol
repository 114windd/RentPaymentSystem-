// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployRentPaymentSystem} from "../../script/DeployRentPaymentSystem.s.sol";
import {RentPaymentSystem} from "../../src/RentPaymentSystem.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {MockV3Aggregator} from "../../test/MockV3Aggregator.sol";

contract FundMeTest is ZkSyncChainChecker, CodeConstants, StdCheats, Test {
    RentPaymentSystem public rentPaymentSystem;
    HelperConfig public helperConfig;

    uint256 public DECIMALS = 8;
    int256 public INITIAL_PRICE = 2000e8;

    function setUp() external {
        if (helperConfig.localNetworkConfig.priceFeed != address(0)) {
            DeployFundMe deployer = new DeployFundMe();
            (rentPaymentSystem, helperConfig) = deployer.deployFundMe();
        } else {
            MockV3Aggregator mockPriceFeed = new MockV3Aggregator(
                DECIMALS,
                INITIAL_PRICE
            );
            rentPaymentSystem = new FundMe(address(mockPriceFeed));
        }
    }
}
