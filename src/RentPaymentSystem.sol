// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
/**
 * @title RentPaymentSystem
 * @author Korede
 * @notice A decentralized rent payment system with Chainlink price feeds and automation
 */

import {AggregatorV3Interface} from "../lib/chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {AutomationCompatibleInterface} from "../lib/chainlink-evm/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {PriceConverter} from "./PriceConverter.sol";

contract RentPaymentSystem is AutomationCompatibleInterface {
    AggregatorV3Interface public priceFeed;
    uint256 public nextAgreementID;

    // Individual balance tracking
    mapping(address tenantAddress => mapping(address landlordAddress => uint256 rentAmount))
        public rentBalance; // tenant => landlord => rent amount
    mapping(address => uint256) public depositBalance; // tenant => deposit amount
    mapping(address => bool) public isDepositPaid; // tenant => deposit status

    // Existing mappings
    mapping(uint256 agreementID => TenancyAgreement agreement)
        public agreements;
    mapping(address landlordAddress => Tenant[] tenants)
        public landlordToTenants;
    mapping(address tenantAddress => Landlord landlord) public tenantToLandlord;
    mapping(address landlordProfiles => Landlord) public landlordProfiles;
    mapping(address tenantAddress => Tenant) public tenantProfiles;
    mapping(address landlordAddress => TenancyAgreement[])
        public landlordToAgreement;
    mapping(address tenantAddress => mapping(address landlordAddress => TenancyAgreement))
        public masterAgreements;

    // Custom Errors (Gas Efficient)
    error OnlyLandlordAllowed();
    error OnlyTenantAllowed();
    error AgreementDoesNotExist();
    error LandlordProfileAlreadyExists();
    error TenantProfileAlreadyExists();
    error LandlordProfileDoesNotExist();
    error TenantProfileDoesNotExist();
    error StartDateMustBeBeforeEndDate();
    error DueDateMustBeBeforeOrEqualToEndDate();
    error StartDateMustBeBeforeDueDate();
    error TenantAndLandlordCannotBeSame();
    error AgreementAlreadyExists();
    error RentAlreadyPaid();
    error DepositMustBePaidFirst();
    error NotEnoughETHSent();
    error DepositAlreadyPaid();
    error RentNotPaid();
    error CannotWithdrawBeforeDueDate();
    error NoRentToWithdraw();
    error TransferFailed();
    error LeaseStillActive();
    error NoDepositToRefund();
    error NoDepositBalance();
    error DepositRefundFailed();
    error PaymentNotYetDue();
    error PaymentAlreadyMade();

    enum rentPaymentStatus {
        PENDING,
        PAID,
        OVERDUE
    }

    // Events
    event DepositPaid(
        address indexed tenantAddress,
        address indexed landlordAddress,
        uint256 amountPaid
    );

    event AgreementCreated(
        uint256 indexed agreementID,
        address indexed landlordAddress,
        address indexed tenantAddress,
        uint256 rentUSD,
        uint256 depositUSD
    );

    event RentPaid(
        address indexed tenantAddress,
        address indexed landlordAddress,
        uint256 indexed amountPaid
    );

    event RentWithdrawn(
        address indexed landlordAddress,
        address indexed tenantAddress,
        uint256 amount
    );

    event DepositRefunded(
        address indexed tenantAddress,
        address indexed landlordAddress,
        uint256 amount
    );

    event LatePayment(
        address indexed tenantAddress,
        address indexed landlordAddress,
        uint256 dueDate
    );

    event RentReleased(
        address indexed landlordAddress,
        address indexed tenantAddress,
        uint256 amount
    );

    // Structs
    struct Landlord {
        address landlordAddress;
        string landlordName;
        string landlordContact;
    }

    struct Tenant {
        address tenantAddress;
        string tenantName;
        string tenantEmail;
        address LandlordAddress;
    }

    struct TenancyAgreement {
        uint256 startDate;
        uint256 endDate;
        uint256 dueDate;
        uint256 period;
        uint256 rentUSD;
        uint256 rentETH;
        uint256 depositUSD;
        uint256 depositETH;
        address landlordAddress;
        address tenantAddress;
        rentPaymentStatus paymentStatus;
    }

    // Constructor
    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    // Modifiers
    modifier onlyLandlord(address tenant) {
        if (msg.sender != tenantToLandlord[tenant].landlordAddress) {
            revert OnlyLandlordAllowed();
        }
        _;
    }

    modifier onlyTenant() {
        if (tenantProfiles[msg.sender].tenantAddress != msg.sender) {
            revert OnlyTenantAllowed();
        }
        _;
    }

    modifier agreementExists(address tenant, address landlord) {
        if (masterAgreements[tenant][landlord].landlordAddress == address(0)) {
            revert AgreementDoesNotExist();
        }
        _;
    }

    // Profile creation functions
    function createLandlordProfile(
        address landlordAddress,
        string memory landlordName,
        string memory landlordContact
    ) public {
        if (landlordProfiles[landlordAddress].landlordAddress != address(0)) {
            revert LandlordProfileAlreadyExists();
        }

        landlordProfiles[landlordAddress] = Landlord(
            landlordAddress,
            landlordName,
            landlordContact
        );
    }

    function createTenantProfile(
        address tenantAddress,
        string memory tenantName,
        string memory tenantEmail,
        address landlordAddress
    ) public {
        if (tenantProfiles[tenantAddress].tenantAddress != address(0)) {
            revert TenantProfileAlreadyExists();
        }
        if (landlordProfiles[landlordAddress].landlordAddress == address(0)) {
            revert LandlordProfileDoesNotExist();
        }

        tenantProfiles[tenantAddress] = Tenant(
            tenantAddress,
            tenantName,
            tenantEmail,
            landlordAddress
        );
    }

    function createAgreement(
        uint256 startDate,
        uint256 endDate,
        uint256 dueDate,
        uint256 period,
        uint256 rentUSD,
        uint256 rentETH,
        uint256 depositUSD,
        uint256 depositETH,
        address landlordAddress,
        address tenantAddress,
        rentPaymentStatus paymentStatus
    ) public {
        if (tenantProfiles[tenantAddress].tenantAddress == address(0)) {
            revert TenantProfileDoesNotExist();
        }
        if (landlordProfiles[landlordAddress].landlordAddress == address(0)) {
            revert LandlordProfileDoesNotExist();
        }
        if (startDate >= endDate) {
            revert StartDateMustBeBeforeEndDate();
        }
        if (dueDate > endDate) {
            revert DueDateMustBeBeforeOrEqualToEndDate();
        }
        if (startDate >= dueDate) {
            revert StartDateMustBeBeforeDueDate();
        }
        if (tenantAddress == landlordAddress) {
            revert TenantAndLandlordCannotBeSame();
        }
        if (
            masterAgreements[tenantAddress][landlordAddress].landlordAddress !=
            address(0)
        ) {
            revert AgreementAlreadyExists();
        }

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

        landlordToTenants[landlordAddress].push(tenantProfiles[tenantAddress]);
        tenantToLandlord[tenantAddress] = landlordProfiles[landlordAddress];
        landlordToAgreement[landlordAddress].push(agreements[nextAgreementID]);
        masterAgreements[tenantAddress][landlordAddress] = agreements[
            nextAgreementID
        ];

        emit AgreementCreated(
            nextAgreementID,
            landlordAddress,
            tenantAddress,
            rentUSD,
            depositUSD
        );

        nextAgreementID++;
    }

    function payRent() external payable onlyTenant {
        address landlordAddress = tenantToLandlord[msg.sender].landlordAddress;
        if (
            masterAgreements[msg.sender][landlordAddress].landlordAddress ==
            address(0)
        ) {
            revert AgreementDoesNotExist();
        }
        if (
            masterAgreements[msg.sender][landlordAddress].paymentStatus ==
            rentPaymentStatus.PAID
        ) {
            revert RentAlreadyPaid();
        }
        if (!isDepositPaid[msg.sender]) {
            revert DepositMustBePaidFirst();
        }

        uint256 requiredEth = PriceConverter.getRequiredEthForUsd(
            masterAgreements[msg.sender][landlordAddress].rentUSD,
            priceFeed
        );

        if (msg.value < requiredEth) {
            revert NotEnoughETHSent();
        }

        // Store the rent payment for this tenant-landlord pair
        rentBalance[msg.sender][landlordAddress] = msg.value;

        // Update payment status
        masterAgreements[msg.sender][landlordAddress]
            .paymentStatus = rentPaymentStatus.PAID;

        emit RentPaid(msg.sender, landlordAddress, msg.value);
    }

    function payDeposit() external payable onlyTenant {
        address landlordAddress = tenantToLandlord[msg.sender].landlordAddress;
        if (
            masterAgreements[msg.sender][landlordAddress].landlordAddress ==
            address(0)
        ) {
            revert AgreementDoesNotExist();
        }
        if (isDepositPaid[msg.sender]) {
            revert DepositAlreadyPaid();
        }

        uint256 requiredEth = PriceConverter.getRequiredEthForUsd(
            masterAgreements[msg.sender][landlordAddress].depositUSD,
            priceFeed
        );

        if (msg.value < requiredEth) {
            revert NotEnoughETHSent();
        }

        // Store the deposit amount
        depositBalance[msg.sender] = msg.value;
        isDepositPaid[msg.sender] = true;

        emit DepositPaid(msg.sender, landlordAddress, msg.value);
    }

    function withdrawRent(
        address tenant
    ) external onlyLandlord(tenant) agreementExists(tenant, msg.sender) {
        if (
            masterAgreements[tenant][msg.sender].paymentStatus !=
            rentPaymentStatus.PAID
        ) {
            revert RentNotPaid();
        }
        if (block.timestamp <= masterAgreements[tenant][msg.sender].dueDate) {
            revert CannotWithdrawBeforeDueDate();
        }

        uint256 rentAmount = rentBalance[tenant][msg.sender];
        if (rentAmount == 0) {
            revert NoRentToWithdraw();
        }

        // Reset the balance before transfer (reentrancy protection)
        rentBalance[tenant][msg.sender] = 0;

        // Update payment status to pending for next period
        masterAgreements[tenant][msg.sender].paymentStatus = rentPaymentStatus
            .PENDING;

        // Transfer rent to landlord
        (bool success, ) = payable(msg.sender).call{value: rentAmount}("");
        if (!success) {
            revert TransferFailed();
        }

        emit RentReleased(msg.sender, tenant, rentAmount);
        emit RentWithdrawn(msg.sender, tenant, rentAmount);
    }

    function refundDeposit(
        address tenant
    ) external onlyLandlord(tenant) agreementExists(tenant, msg.sender) {
        if (block.timestamp <= masterAgreements[tenant][msg.sender].endDate) {
            revert LeaseStillActive();
        }
        if (!isDepositPaid[tenant]) {
            revert NoDepositToRefund();
        }

        uint256 depositAmount = depositBalance[tenant];
        if (depositAmount == 0) {
            revert NoDepositBalance();
        }

        // Reset deposit status and balance before transfer
        depositBalance[tenant] = 0;
        isDepositPaid[tenant] = false;

        // Transfer deposit back to tenant
        (bool success, ) = payable(tenant).call{value: depositAmount}("");
        if (!success) {
            revert DepositRefundFailed();
        }

        emit DepositRefunded(tenant, msg.sender, depositAmount);
    }

    function terminateLease(
        address tenant
    ) external onlyLandlord(tenant) agreementExists(tenant, msg.sender) {
        // Set end date to now to effectively terminate the lease
        masterAgreements[tenant][msg.sender].endDate = block.timestamp;

        // Reset payment status
        masterAgreements[tenant][msg.sender].paymentStatus = rentPaymentStatus
            .PENDING;
    }

    // Chainlink Automation functions
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        // Check if any tenant has overdue rent
        upkeepNeeded = false;

        // This is a simplified check - in practice, you'd want to maintain an array of active agreements
        // For now, we'll return false and implement the full logic when we have a way to iterate through agreements

        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        // This function would mark overdue payments as late
        // Implementation depends on how we want to iterate through active agreements
    }

    function checkLatePayment(
        address tenant,
        address landlord
    ) external view returns (bool isLate) {
        if (masterAgreements[tenant][landlord].landlordAddress == address(0)) {
            revert AgreementDoesNotExist();
        }

        TenancyAgreement memory agreement = masterAgreements[tenant][landlord];

        return (block.timestamp > agreement.dueDate &&
            agreement.paymentStatus != rentPaymentStatus.PAID);
    }

    function markPaymentLate(address tenant, address landlord) external {
        if (masterAgreements[tenant][landlord].landlordAddress == address(0)) {
            revert AgreementDoesNotExist();
        }
        if (block.timestamp <= masterAgreements[tenant][landlord].dueDate) {
            revert PaymentNotYetDue();
        }
        if (
            masterAgreements[tenant][landlord].paymentStatus ==
            rentPaymentStatus.PAID
        ) {
            revert PaymentAlreadyMade();
        }

        masterAgreements[tenant][landlord].paymentStatus = rentPaymentStatus
            .OVERDUE;

        emit LatePayment(
            tenant,
            landlord,
            masterAgreements[tenant][landlord].dueDate
        );
    }

    // View functions
    function getRentBalance(
        address tenant,
        address landlord
    ) external view returns (uint256) {
        return rentBalance[tenant][landlord];
    }

    function getDepositBalance(address tenant) external view returns (uint256) {
        return depositBalance[tenant];
    }

    function getAgreement(
        address tenant,
        address landlord
    ) external view returns (TenancyAgreement memory) {
        return masterAgreements[tenant][landlord];
    }
}
