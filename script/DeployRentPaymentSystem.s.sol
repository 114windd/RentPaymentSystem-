//SPDX-License-Identifier:MIT   
pragma solidity ^0.8.19;    

import {Script} from "forge-std/Script.sol";  
import {RentPaymentSystem} from "../src/RentPaymentSystem.sol";  
import {HelperConfig} from "./HelperConfig.s.sol";     

contract DeployRentPaymentSystem is Script {   

    function run() external returns (RentPaymentSystem, HelperConfig) {                  
        HelperConfig helperConfig = new HelperConfig();                   
        address priceFeed = helperConfig.getConfigByChainId(block.chainid).priceFeed;                   
        
        vm.startBroadcast();                  
        RentPaymentSystem rentPaymentSystem = new RentPaymentSystem(priceFeed);                  
        vm.stopBroadcast();                  
        
        return (rentPaymentSystem, helperConfig);          
    }

}
