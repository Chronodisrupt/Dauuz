// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DUZToken} from "src/DUZToken.sol";
import {DAUUZDistribution} from "src/DAUUZDistribution.sol";
import {ZoiReserve} from "src/ZoiReserve.sol";
import {LiquidityReserve} from "src/LiquidityReserve.sol";
import {MerkleClaim} from "src/MerkleClaim.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Merkle} from "murky/src/Merkle.sol";

contract DAUUZTest is Test {

    // -------------------------------------------------------------------------
    // Contracts
    // -------------------------------------------------------------------------

    DUZToken token;
    DAUUZDistribution distribution;
    ZoiReserve zoiReserve;
    LiquidityReserve liquidityReserve;
    MerkleClaim merkleContributors;
    MerkleClaim merkleCommunity;
    Merkle merkle;

    // -------------------------------------------------------------------------
    // Actors
    // -------------------------------------------------------------------------

    address multisig = makeAddr("multisig");
    address contributor1 = makeAddr("contributor1");
    address contributor2 = makeAddr("contributor2");
    address contributor3 = makeAddr("contributor3");
    address community1 = makeAddr("community1");
    address community2 = makeAddr("community2");
    address outsider = makeAddr("outsider");

    // -------------------------------------------------------------------------
    // Merkle tree helpers
    // -------------------------------------------------------------------------

    // Contributor allocations
    uint256 contributor1Amount = 2_000_000 * 1e18;
    uint256 contributor2Amount = 1_000_000 * 1e18;
    uint256 contributor3Amount = 1_000_000 * 1e18;

    // Community allocations
    uint256 community1Amount = 1_200_000 * 1e18;
    uint256 community2Amount = 800_000 * 1e18;

    bytes32 contributorsRoot;
    bytes32 communityRoot;
    bytes32[] contributorLeafs;
    bytes32[] communityLeafs;

    uint256 constant CLAIM_WINDOW = 90 days;

    // -------------------------------------------------------------------------
    // Setup
    // -------------------------------------------------------------------------

    function setUp() public {
        merkle = new Merkle();

        // Build contributor merkle tree
        contributorLeafs = new bytes32[](3);
        contributorLeafs[0] = _leaf(contributor1, contributor1Amount);
        contributorLeafs[1] = _leaf(contributor2, contributor2Amount);
        contributorLeafs[2] = _leaf(contributor3, contributor3Amount);
        contributorsRoot = merkle.getRoot(contributorLeafs);

        // Build community merkle tree
        communityLeafs = new bytes32[](2);
        communityLeafs[0] = _leaf(community1, community1Amount);
        communityLeafs[1] = _leaf(community2, community2Amount);
        communityRoot = merkle.getRoot(communityLeafs);

        // Deploy contracts
        vm.startPrank(multisig);

        distribution = new DAUUZDistribution(multisig);
        token = new DUZToken(address(distribution));
        zoiReserve = new ZoiReserve(multisig, IERC20(address(token)));
        liquidityReserve = new LiquidityReserve(multisig, IERC20(address(token)));
        
        merkleContributors = new MerkleClaim(
            multisig,
            IERC20(address(token)),
            address(distribution),
            contributorsRoot,
            CLAIM_WINDOW
        );

        merkleCommunity = new MerkleClaim(
            multisig,
            IERC20(address(token)),
            address(distribution),
            communityRoot,
            CLAIM_WINDOW
        );

        // Route all allocations
        distribution.distribute(
            address(token),
            address(merkleCommunity),
            address(merkleContributors),
            address(zoiReserve),
            address(liquidityReserve)
        );

        vm.stopPrank();
    }

    // =========================================================================
    // DUZToken
    // =========================================================================

    function test_token_name() public view {
        assertEq(token.name(), "DAUUZ");
    }

    function test_token_symbol() public view {
        assertEq(token.symbol(), "DUZ");
    }

    function test_token_decimals() public view {
        assertEq(token.decimals(), 18);
    }

    function test_token_totalSupply() public view {
        assertEq(token.totalSupply(), 30_000_000 * 1e18);
    }

    function test_token_entireSupplyMintedToDistribution() public view {
        // After distribute() all tokens leave Distribution
        // so we check total supply is still 30M
        assertEq(token.totalSupply(), token.MAX_SUPPLY());
    }

    function test_token_revertZeroAddress() public {
        vm.expectRevert();
        new DUZToken(address(0));
    }

    // =========================================================================
    // DAUUZDistribution
    // =========================================================================

    function test_distribution_correctBalances() public view {
        assertEq(token.balanceOf(address(merkleCommunity)), 2_000_000 * 1e18);
        assertEq(token.balanceOf(address(merkleContributors)), 4_000_000 * 1e18);
        assertEq(token.balanceOf(address(zoiReserve)), 10_000_000 * 1e18);
        assertEq(token.balanceOf(address(liquidityReserve)), 14_000_000 * 1e18);
    }

    function test_distribution_distributedFlagSet() public view {
        assertTrue(distribution.distributed());
    }

    function test_distribution_revertAlreadyDistributed() public {
        vm.prank(multisig);
        vm.expectRevert(DAUUZDistribution.DAUUZDistribution__AlreadyDistributed.selector);
        distribution.distribute(
            address(token),
            address(merkleCommunity),
            address(merkleContributors),
            address(zoiReserve),
            address(liquidityReserve)
        );
    }

    function test_distribution_revertZeroAddress() public {
        DAUUZDistribution freshDist = new DAUUZDistribution(multisig);
        new DUZToken(address(freshDist));

        vm.prank(multisig);
        vm.expectRevert(DAUUZDistribution.DAUUZDistribution__ZeroAddress.selector);
        freshDist.distribute(
            address(0),
            address(merkleContributors),
            address(merkleContributors),
            address(zoiReserve),
            address(liquidityReserve)
        );
    }

    function test_distribution_revertNotOwner() public {
        DAUUZDistribution freshDist = new DAUUZDistribution(multisig);
        new DUZToken(address(freshDist));

        vm.prank(outsider);
        vm.expectRevert();
        freshDist.distribute(
            address(token),
            address(merkleCommunity),
            address(merkleContributors),
            address(zoiReserve),
            address(liquidityReserve)
        );
    }

    function test_distribution_recoverUnclaimed() public {
        // Simulate MerkleClaim returning tokens to distribution
        vm.prank(address(merkleContributors));
        token.transfer(address(distribution), 500_000 * 1e18);

        uint256 before = token.balanceOf(multisig);

        vm.prank(multisig);
        distribution.recoverUnclaimed();

        assertEq(token.balanceOf(multisig) - before, 500_000 * 1e18);
    }

    function test_distribution_revertRecoverNotYetDistributed() public {
        DAUUZDistribution freshDist = new DAUUZDistribution(multisig);
        vm.prank(multisig);
        vm.expectRevert(DAUUZDistribution.DAUUZDistribution__NotYetDistributed.selector);
        freshDist.recoverUnclaimed();
    }

    function test_distribution_revertRecoverNothingToRecover() public {
        vm.prank(multisig);
        vm.expectRevert(DAUUZDistribution.DAUUZDistribution__NothingToRecover.selector);
        distribution.recoverUnclaimed();
    }

    // =========================================================================
    // ZoiReserve
    // =========================================================================

    function test_zoi_vestingStartSet() public view {
        assertEq(zoiReserve.vestingStart(), block.timestamp);
    }

    function test_zoi_nothingClaimableBeforeYear1() public view {
        assertEq(zoiReserve.claimableAmount(), 0);
    }

    function test_zoi_claimableAfterYear1() public {
        vm.warp(block.timestamp + 365 days);
        assertEq(zoiReserve.claimableAmount(), 2_500_000 * 1e18);
    }

    function test_zoi_claimableAfterYear2() public {
        vm.warp(block.timestamp + 730 days);
        assertEq(zoiReserve.claimableAmount(), 5_000_000 * 1e18);
    }

    function test_zoi_claimableAfterAllYears() public {
        vm.warp(block.timestamp + 4 * 365 days);
        assertEq(zoiReserve.claimableAmount(), 10_000_000 * 1e18);
    }

    function test_zoi_claimTransfersTokens() public {
        vm.warp(block.timestamp + 365 days);

        uint256 before = token.balanceOf(multisig);

        vm.prank(multisig);
        zoiReserve.claim();

        assertEq(token.balanceOf(multisig) - before, 2_500_000 * 1e18);
    }

    function test_zoi_claimUpdatesLastClaimed() public {
        vm.warp(block.timestamp + 365 days);
        uint256 expectedLastClaimed = block.timestamp;

        vm.prank(multisig);
        zoiReserve.claim();

        assertEq(zoiReserve.lastClaimed(), expectedLastClaimed);
    }

    function test_zoi_revertNothingToClaim() public {
        vm.prank(multisig);
        vm.expectRevert(ZoiReserve.ZoiReserve__NothingToClaim.selector);
        zoiReserve.claim();
    }

    function test_zoi_revertClaimNotOwner() public {
        vm.warp(block.timestamp + 365 days);
        vm.prank(outsider);
        vm.expectRevert();
        zoiReserve.claim();
    }

    function test_zoi_cannotOverclaim() public {
        vm.warp(block.timestamp + 10 * 365 days);
        assertEq(zoiReserve.claimableAmount(), 10_000_000 * 1e18);
    }

    function test_zoi_unlockTime() public view {
        assertEq(zoiReserve.unlockTime(1), block.timestamp + 365 days);
        assertEq(zoiReserve.unlockTime(2), block.timestamp + 730 days);
        assertEq(zoiReserve.unlockTime(3), block.timestamp + 1095 days);
        assertEq(zoiReserve.unlockTime(4), block.timestamp + 1460 days);
    }

    function test_zoi_unlockTimeInvalidYear() public view {
        assertEq(zoiReserve.unlockTime(0), 0);
        assertEq(zoiReserve.unlockTime(5), 0);
    }

    // =========================================================================
    // LiquidityReserve
    // =========================================================================

    function test_liquidity_lockEndSet() public view {
        assertEq(liquidityReserve.lockEnd(), block.timestamp + 365 days);
    }

    function test_liquidity_isLockedBeforeExpiry() public view {
        assertFalse(liquidityReserve.isUnlocked());
    }

    function test_liquidity_isUnlockedAfterExpiry() public {
        vm.warp(block.timestamp + 365 days);
        assertTrue(liquidityReserve.isUnlocked());
    }

    function test_liquidity_timeRemaining() public view {
        assertEq(liquidityReserve.timeRemaining(), 365 days);
    }

    function test_liquidity_timeRemainingAfterExpiry() public {
        vm.warp(block.timestamp + 365 days + 1);
        assertEq(liquidityReserve.timeRemaining(), 0);
    }

    function test_liquidity_withdrawAfterExpiry() public {
        vm.warp(block.timestamp + 365 days);

        uint256 before = token.balanceOf(multisig);

        vm.prank(multisig);
        liquidityReserve.withdraw();

        assertEq(token.balanceOf(multisig) - before, 14_000_000 * 1e18);
    }

    function test_liquidity_revertWithdrawBeforeExpiry() public {
        vm.prank(multisig);
        vm.expectRevert(LiquidityReserve.LiquidityReserve__StillLocked.selector);
        liquidityReserve.withdraw();
    }

    function test_liquidity_revertDoubleWithdraw() public {
        vm.warp(block.timestamp + 365 days);

        vm.startPrank(multisig);
        liquidityReserve.withdraw();

        vm.expectRevert(LiquidityReserve.LiquidityReserve__AlreadyWithdrawn.selector);
        liquidityReserve.withdraw();
        vm.stopPrank();
    }

    function test_liquidity_revertWithdrawNotOwner() public {
        vm.warp(block.timestamp + 365 days);
        vm.prank(outsider);
        vm.expectRevert();
        liquidityReserve.withdraw();
    }

    // =========================================================================
    // MerkleClaim — Contributors
    // =========================================================================

    function test_merkle_contributorCanClaim() public {
        bytes32[] memory proof = merkle.getProof(contributorLeafs, 0);

        uint256 before = token.balanceOf(contributor1);

        vm.prank(contributor1);
        merkleContributors.claim(contributor1Amount, proof);

        assertEq(token.balanceOf(contributor1) - before, contributor1Amount);
    }

    function test_merkle_contributorMarkedAsClaimed() public {
        bytes32[] memory proof = merkle.getProof(contributorLeafs, 0);

        vm.prank(contributor1);
        merkleContributors.claim(contributor1Amount, proof);

        assertTrue(merkleContributors.hasClaimed(contributor1));
    }

    function test_merkle_revertAlreadyClaimed() public {
        bytes32[] memory proof = merkle.getProof(contributorLeafs, 0);

        vm.startPrank(contributor1);
        merkleContributors.claim(contributor1Amount, proof);

        vm.expectRevert(MerkleClaim.MerkleClaim__AlreadyClaimed.selector);
        merkleContributors.claim(contributor1Amount, proof);
        vm.stopPrank();
    }

    function test_merkle_revertInvalidProof() public {
        bytes32[] memory proof = merkle.getProof(contributorLeafs, 0);

        vm.prank(contributor1);
        vm.expectRevert(MerkleClaim.MerkleClaim__InvalidProof.selector);
        // wrong amount
        merkleContributors.claim(999 * 1e18, proof);
    }

    function test_merkle_revertWrongAddress() public {
        bytes32[] memory proof = merkle.getProof(contributorLeafs, 0);

        // outsider tries to use contributor1's proof
        vm.prank(outsider);
        vm.expectRevert(MerkleClaim.MerkleClaim__InvalidProof.selector);
        merkleContributors.claim(contributor1Amount, proof);
    }

    function test_merkle_revertClaimWindowExpired() public {
        vm.warp(block.timestamp + CLAIM_WINDOW + 1);

        bytes32[] memory proof = merkle.getProof(contributorLeafs, 0);

        vm.prank(contributor1);
        vm.expectRevert(MerkleClaim.MerkleClaim__ClaimWindowExpired.selector);
        merkleContributors.claim(contributor1Amount, proof);
    }

    function test_merkle_isClaimOpen() public view {
        assertTrue(merkleContributors.isClaimOpen());
    }

    function test_merkle_isClaimClosedAfterExpiry() public {
        vm.warp(block.timestamp + CLAIM_WINDOW + 1);
        assertFalse(merkleContributors.isClaimOpen());
    }

    function test_merkle_timeRemaining() public view {
        assertEq(merkleContributors.timeRemaining(), CLAIM_WINDOW);
    }

    function test_merkle_recoverUnclaimedAfterExpiry() public {
        vm.warp(block.timestamp + CLAIM_WINDOW + 1);

        uint256 before = token.balanceOf(address(distribution));

        vm.prank(multisig);
        merkleContributors.recoverUnclaimed();

        assertGt(token.balanceOf(address(distribution)), before);
    }

    function test_merkle_revertRecoverClaimWindowStillOpen() public {
        vm.prank(multisig);
        vm.expectRevert(MerkleClaim.MerkleClaim__ClaimWindowStillOpen.selector);
        merkleContributors.recoverUnclaimed();
    }

    function test_merkle_revertRecoverNothingToRecover() public {
        // Drain the contract first
        bytes32[] memory proof1 = merkle.getProof(contributorLeafs, 0);
        bytes32[] memory proof2 = merkle.getProof(contributorLeafs, 1);
        bytes32[] memory proof3 = merkle.getProof(contributorLeafs, 2);

        vm.prank(contributor1);
        merkleContributors.claim(contributor1Amount, proof1);
        vm.prank(contributor2);
        merkleContributors.claim(contributor2Amount, proof2);
        vm.prank(contributor3);
        merkleContributors.claim(contributor3Amount, proof3);

        vm.warp(block.timestamp + CLAIM_WINDOW + 1);

        vm.prank(multisig);
        vm.expectRevert(MerkleClaim.MerkleClaim__NothingToRecover.selector);
        merkleContributors.recoverUnclaimed();
    }

    // =========================================================================
    // MerkleClaim — Community
    // =========================================================================

    function test_merkle_communityCanClaim() public {
        bytes32[] memory proof = merkle.getProof(communityLeafs, 0);

        uint256 before = token.balanceOf(community1);

        vm.prank(community1);
        merkleCommunity.claim(community1Amount, proof);

        assertEq(token.balanceOf(community1) - before, community1Amount);
    }

    function test_merkle_communityRevertInvalidProof() public {
        // contributor proof does not work on community contract
        bytes32[] memory wrongProof = merkle.getProof(contributorLeafs, 0);

        vm.prank(community1);
        vm.expectRevert(MerkleClaim.MerkleClaim__InvalidProof.selector);
        merkleCommunity.claim(community1Amount, wrongProof);
    }

    // =========================================================================
    // Internal helpers
    // =========================================================================

    function _leaf(address account, uint256 amount) internal pure returns (bytes32) {
        return keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
    }
}
