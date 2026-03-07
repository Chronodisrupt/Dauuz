// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DUZToken} from "../src/DUZToken.sol";
import {DAUUZDistribution} from "../src/DAUUZDistribution.sol";
import {ZoiReserve} from "../src/ZoiReserve.sol";
import {LiquidityReserve} from "../src/LiquidityReserve.sol";
import {MerkleClaim} from "../src/MerkleClaim.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Deploy
 * @notice Deploys all DAUUZ contracts in the correct order on Sepolia.
 *
 * Deployment order:
 *   1. DAUUZDistribution
 *   2. DUZToken (mints 30M to Distribution)
 *   3. ZoiReserve
 *   4. LiquidityReserve
 *   5. MerkleClaim  (contributors — 4,000,000 DUZ)
 *   6. MerkleClaim (community    — 2,000,000 DUZ)
 *   7. Distribution.distribute()  routes all allocations
 *
 * Required env vars (.env):
 *   MULTISIG                   — 2-of-3 Gnosis Safe address (or placeholder on testnet)
 *   MERKLE_ROOT_CONTRIBUTORS   — root from output.json
 *   MERKLE_ROOT_COMMUNITY      — root from output_community.json
 *   ETHERSCAN_API_KEY          — for contract verification
 *
 */
contract Deploy is Script {
    // 90 days claim window in seconds
    uint256 constant CLAIM_WINDOW = 90 days;

    // Placeholder multisig — replace with actual Gnosis Safe address before mainnet
    address constant MULTISIG_PLACEHOLDER =
        0x0000000000000000000000000000000000000001;

    function run() external {
        address multisig = vm.envOr("MULTISIG", MULTISIG_PLACEHOLDER);

        bytes32 contributorsRoot = vm.envBytes32("MERKLE_ROOT_CONTRIBUTORS");
        bytes32 communityRoot = vm.envBytes32("MERKLE_ROOT_COMMUNITY");

        vm.startBroadcast();

        // 1. Deploy Distribution — owns nothing yet, just sets multisig as owner
        DAUUZDistribution distribution = new DAUUZDistribution(multisig);
        console.log("1. DAUUZDistribution :", address(distribution));

        // 2. Deploy DUZToken — entire 30M minted directly to Distribution
        DUZToken token = new DUZToken(address(distribution));
        console.log("2. DUZToken:", address(token));
        console.log(
            "   Distribution balance:",
            token.balanceOf(address(distribution)) / 1e18,
            "DUZ"
        );

        // 3. Deploy ZoiReserve — 4yr vesting, 25% per year
        ZoiReserve zoiReserve = new ZoiReserve(
            multisig,
            IERC20(address(token))
        );
        console.log("3. ZoiReserve:", address(zoiReserve));

        // 4. Deploy LiquidityReserve — 1yr timelock
        LiquidityReserve liquidityReserve = new LiquidityReserve(
            multisig,
            IERC20(address(token))
        );
        console.log("4. LiquidityReserve:", address(liquidityReserve));

        // 5. Deploy MerkleClaim for contributors — 4,000,000 DUZ
        MerkleClaim merkleContributors = new MerkleClaim(
            multisig,
            IERC20(address(token)),
            address(distribution),
            contributorsRoot,
            CLAIM_WINDOW
        );
        console.log(
            "5. MerkleClaim contributors:",
            address(merkleContributors)
        );

        // 6. Deploy MerkleClaim for community — 2,000,000 DUZ
        MerkleClaim merkleCommunity = new MerkleClaim(
            multisig,
            IERC20(address(token)),
            address(distribution),
            communityRoot,
            CLAIM_WINDOW
        );
        console.log("6. MerkleClaim community:", address(merkleCommunity));

        // 7. Route all allocations — multisig must call this in production
        // On testnet deployer EOA is owner so this works directly
        distribution.distribute(
            address(token),
            address(merkleCommunity),
            address(merkleContributors),
            address(zoiReserve),
            address(liquidityReserve)
        );

        console.log("--- Distribution complete ---");
        console.log(
            "Community bal    :",
            token.balanceOf(address(merkleCommunity)) / 1e18,
            "DUZ"
        );
        console.log(
            "Contributors bal :",
            token.balanceOf(address(merkleContributors)) / 1e18,
            "DUZ"
        );
        console.log(
            "Zoi Reserve bal  :",
            token.balanceOf(address(zoiReserve)) / 1e18,
            "DUZ"
        );
        console.log(
            "Liquidity bal    :",
            token.balanceOf(address(liquidityReserve)) / 1e18,
            "DUZ"
        );

        vm.stopBroadcast();
    }
}
