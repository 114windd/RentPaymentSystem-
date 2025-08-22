//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "../lib/chainlink-evm/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    /**
     * @dev Gets the latest ETH/USD price from Chainlink price feed
     * @param priceFeed The Chainlink AggregatorV3Interface contract
     * @return The current ETH price in USD with 18 decimals
     */
    function getPrice(
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();

        // Validate price data
        require(answer > 0, "Invalid price data");
        require(updatedAt > 0, "Price data not updated");
        require(block.timestamp - updatedAt < 3600, "Price data too stale"); // 1 hour max

        // Convert from 8 decimals to 18 decimals
        return uint256(answer * 10 ** 10);
    }

    /**
     * @dev Converts ETH amount to USD value
     * @param ethAmount Amount of ETH (in wei, 18 decimals)
     * @param priceFeed The Chainlink AggregatorV3Interface contract
     * @return USD value with 18 decimals
     */
    function getEthValueInUsd(
        uint256 ethAmount,
        AggregatorV3Interface priceFeed
    ) internal view returns (uint256) {
        require(ethAmount > 0, "ETH amount must be greater than 0");

        uint256 ethPrice = getPrice(priceFeed);
        // Both ethPrice and ethAmount have 18 decimals, so divide by 10^18 to normalize
        uint256 ethAmountInUsd = (ethPrice * ethAmount) / 1e18;

        return ethAmountInUsd;
    }

    /**
     * @dev Converts USD amount to required ETH amount (FOR RENT PAYMENTS)
     * @param usdAmount Amount in USD with 18 decimals (e.g., $1200 = 1200 * 10^18)
     * @param priceFeed The Chainlink AggregatorV3Interface contract
     * @return Required ETH amount in wei (18 decimals)
     */
    function getRequiredEthForUsd(
        uint256 usdAmount,
        AggregatorV3Interface priceFeed
    ) public view returns (uint256) {
        require(usdAmount > 0, "USD amount must be greater than 0");

        uint256 ethPrice = getPrice(priceFeed);
        // usdAmount has 18 decimals, ethPrice has 18 decimals
        // To get ETH amount: usdAmount * 10^18 / ethPrice
        uint256 requiredEth = (usdAmount * 1e18) / ethPrice;

        return requiredEth;
    }

    /**
     * @dev Validates that ETH sent covers the USD rent amount
     * @param ethSent Amount of ETH sent (in wei)
     * @param requiredUsd Required rent amount in USD (18 decimals)
     * @param priceFeed The Chainlink AggregatorV3Interface contract
     * @return true if ETH sent is sufficient for rent payment
     */
    function validateRentPayment(
        uint256 ethSent,
        uint256 requiredUsd,
        AggregatorV3Interface priceFeed
    ) internal view returns (bool) {
        require(ethSent > 0, "No ETH sent");
        require(requiredUsd > 0, "Invalid rent amount");

        uint256 usdValueOfEthSent = getEthValueInUsd(ethSent, priceFeed);

        // Allow small tolerance for price fluctuations (0.1% buffer)
        uint256 tolerance = (requiredUsd * 1) / 1000; // 0.1%

        return usdValueOfEthSent >= (requiredUsd - tolerance);
    }
}
