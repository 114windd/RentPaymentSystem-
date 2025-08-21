// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
/**
 * @title RentPaymentSystem
 * @author Korede
 * @notice
 */

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract RentPaymentSystem {
    uint256 public nextAgreementID;
    mapping(uint256 agreementID => TenancyAgreement agreement) agreements;
    mapping(address landlordAddress => Tenant[] tenants) landlordToTenants;
    mapping(address => Landlord) landlordProfiles;
    mapping(address => Tenant) tenantProfiles;

    enum rentPaymentStatus {
        PENDING,
        PAID,
        OVERDUE
    }

    event AgreementCreated(
        uint256 indexed agreementID,
        address indexed landlordAddress,
        address indexed tenantAddress,
        uint256 rentUSD,
        uint256 depositUSD
    );
    //Landlord
    struct Landlord {
        address landlordAddress;
        string landlordName;
        string landlordContact;
    }
    //Tenant(s)
    struct Tenant {
        address tenantAddress;
        string tenantName;
        string tenantEmail;
        address LandlordAddress;
    }
    //Tenancy Agreement
    struct TenancyAgreement {
        uint256 startDate; //Start of tenancy
        uint256 endDate; // End of tenancy
        uint256 dueDate; // Date rent is due
        uint256 period; //period in which one has to pay rent (30 days)
        uint256 rentUSD; // Rent amount USD
        uint256 rentETH; // Rent amount ETH
        uint256 depositUSD; // Deposit Amount USD
        uint256 depositETH; // Deposit Amount ETH
        address landlordAddress;
        address tenantAddress;
        rentPaymentStatus paymentStatus; //Rent either paid , pending or overdue
    }

    //Create landlord profile
    function createLandlordProfile(
        /** Error Checking information to implmenet 
             - Making sure there is no dupicate profile (check address)
            - Create a custom modifer to check for duplicate profile
            */
        address landlordAddress,
        string memory landlordName,
        string memory landlordContact
    ) public {
        landlordProfiles[landlordAddress] = Landlord(
            landlordAddress,
            landlordName,
            landlordContact
        );
    }

    //Create tenant  profile
    function createTenantProfile(
        /** Error Checking information to implmenet 
         - Making sure there is no dupicate profile (check address)
         - Create a custom modifer to check for duplicate profile
        */
        address tenantAddress,
        string memory tenantName,
        string memory tenantEmail,
        address landlordAddress
    ) public {
        tenantProfiles[tenantAddress] = Tenant(
            tenantAddress,
            tenantName,
            tenantEmail,
            landlordAddress
        );
    }

    //Creates new tenancy agreement
    function createAgreement(
        uint256 startDate, //Start of tenancy
        uint256 endDate, // End of tenancy
        uint256 dueDate, //Day when rent is due
        uint256 period, //How often rent is paid (30 days)
        uint256 rentUSD, // Rent amount USD
        uint256 rentETH, // Rent amount ETH
        uint256 depositUSD, // Deposit Amount USD
        uint256 depositETH, // Deposit Amount ETH
        address landlordAddress, // Landlord address
        address tenantAddress, // Tenant address
        rentPaymentStatus paymentStatus // Payment status (paid, pending, overdue)
    ) public {
        /** Error checking information to implement
         * Tenant must exist
         * Landlord must exist
         * Start date must be less than end date
         * Due date must be less than end date
         * Start date must be less than due date
         * Tenant and landlord cannot be the same
         * Tenant cannot have another landlord
         */

        //Create Agreement
        agreements[nextAgreementID] = TenancyAgreement(
            startDate,
            endDate,
            dueDate,
            period,
            rentUSD,
            rentETH,
            depositUSD,
            depositETH,
            landlordAddress,
            tenantAddress,
            paymentStatus
        );

        //Add new tenant to Landlord => tenant list
        landlordToTenants[landlordAddress].push(tenantProfiles[tenantAddress]);

        //Emit event
        emit AgreementCreated(
            nextAgreementID,
            landlordAddress,
            tenantAddress,
            rentUSD,
            depositUSD
        );

        // Increment agreement ID
        nextAgreementID++;
    }

    // Tenant Deposits rent here
    function payRent(address landlord) external payable {}

    //Landlord withdraws the rent the tenant payed
    function withdrawRent(address tenant) external {}

    //Checks if tenant has paid late or is overdue
    function checkLatePayment(address tenant, address landlord) external {}

    //Terminates lease , destroying the agreement
    function terminateLease(address tenant) external {}

    //Landlord refunds the deposit to the tenant
    function refundDeposit(address tenant) external {}
}
