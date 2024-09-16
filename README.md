# RugGuard

## Description
RugGuard is a revolutionary Uniswap v4 hook that provides built-in protection against rug pulls in DeFi projects. By implementing smart withdrawal limits and vesting periods, RugGuard creates a safety net for investors, fostering trust and stability in the ecosystem. It's not just a feature—it's a paradigm shift in DeFi security that could unlock billions in cautious capital.

## Contract Overview
This contract is a hook for Uniswap v4, designed to provide protection against rug pulls in liquidity pools. It monitors liquidity changes and assigns risk scores to pools.

## Main Functionality

1. **Liquidity Monitoring:**
   - Tracks liquidity changes in pools.
   - Enforces a cooldown period and threshold for large liquidity changes.

2. **Risk Scoring:**
   - Assigns and updates risk scores based on liquidity changes.
   - Increases score for liquidity removals, decreases for additions.

3. **Swap Protection:**
   - Prevents swaps in pools with high risk scores.

4. **Customizable Thresholds:**
   - Allows setting custom liquidity change thresholds for each pool.

## Potential Improvements
1. Incentivize users to add liquidity to the pool in case the risk score of the pool is high, using `afterAddLiquidityReturnDelta`.

## Partner Integrations

### EigenLayer
By integrating EigenLayer, the RugGuard contract enhances its capabilities for processing complex computations related to pool management and risk assessment in a more efficient and scalable manner.

  1. **Off-Chain Computation Processing :**
     Rugguard uses EigenLayer for processing off-chain computations, particularly after swap operations. This allows for complex computations to be performed off-chain, potentially reducing on-chain gas costs and improving scalability

### Chainlink 
The RugGuard leverages multiple Chainlink features to enhance its functionality and security:

1. **Chainlink Price Feeds :**
  The contract uses Chainlink Price Feeds to get real-time price information for tokens in the Uniswap V4 pools. This is implemented through:
     - Mapping of token addresses to their respective Chainlink price feed contracts.
     - `updatePrice` function fetches the latest price data for tokens in a pool.
   - Usage:
     - Calculate and update the price ratio between tokens in a pool.
     - Contribute to risk assessment and monitoring of pool activity.

1. **Chainlink Automation :**
The contract implements Chainlink Automation (formerly known as Keepers) to perform regular upkeep tasks. This is achieved through:
     - Implements the `AutomationCompatibleInterface`.
     - `checkUpkeep` function determines if upkeep is needed for a pool.
     - `performUpkeep` function executes necessary upkeep tasks.
   - Usage:
     - Automated updating of 24-hour trading volumes.
     - Triggering additional checks for high-risk pools.
     - Regular maintenance of pool data without manual intervention.

### Brevis
The RugGuard integrates Brevis for zero-knowledge proof verification, enhancing the security and privacy of certain operations. Ruuguard uses Brevis to verify proofs that can update the risk score of a pool. This allows for complex off-chain computations of risk scores to be verified on-chain, enhancing the security and privacy of your risk assessment mechanism.
- Usage:
  - Perform complex risk calculations off-chain.
  - Verify the results of these calculations on-chain without revealing the details of the calculation.
  - Update the pool's risk score based on these verified calculations.
