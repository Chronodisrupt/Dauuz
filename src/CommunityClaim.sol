// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    MerkleProof
} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * @title MerkleClaim
 * @notice Allows verified contributors to claim their earned DUZ allocation.
 *         Each address and amount is committed to a Merkle tree off-chain.
 *         Users submit a Merkle proof to claim their tokens.
 *
 * Allocation : 4,000,000 DUZ
 * Claim window: set at deployment, after expiry unclaimed tokens
 *               return to the Distribution contract.
 *
 * Ownership:
 *   2-of-3 Gnosis Safe multisig.
 */
contract MerkleClaim is Ownable {
    error MerkleClaim__ZeroAddress();
    error MerkleClaim__AlreadyClaimed();
    error MerkleClaim__InvalidProof();
    error MerkleClaim__ClaimWindowExpired();
    error MerkleClaim__ClaimWindowStillOpen();
    error MerkleClaim__NothingToRecover();

    using SafeERC20 for IERC20;

    uint256 public constant TOTAL_ALLOCATION = 4_000_000 * 1e18;

    IERC20 public immutable duz;
    address public immutable distributionContract;
    uint256 public immutable claimExpiry;
    bytes32 public immutable merkleRoot;

    mapping(address => bool) public hasClaimed;

    event Claimed(address indexed claimant, uint256 amount);
    event UnclaimedRecovered(uint256 amount, uint256 timestamp);

    /**
     * @param multisig      2-of-3 Gnosis Safe — owner.
     * @param _duz          DUZ token address.
     * @param _distribution Distribution contract — receives unclaimed tokens after expiry.
     * @param _merkleRoot   Root of the Merkle tree generated from the contributor snapshot.
     * @param _claimWindow  Duration in seconds the claim window stays open from deployment.
     */
    constructor(
        address multisig,
        IERC20 _duz,
        address _distribution,
        bytes32 _merkleRoot,
        uint256 _claimWindow
    ) Ownable(multisig) {
        if (multisig == address(0)) {
            revert MerkleClaim__ZeroAddress();
        }
        if (address(_duz) == address(0)) {
            revert MerkleClaim__ZeroAddress();
        }
        if (_distribution == address(0)) {
            revert MerkleClaim__ZeroAddress();
        }

        duz = _duz;
        distributionContract = _distribution;
        merkleRoot = _merkleRoot;
        claimExpiry = block.timestamp + _claimWindow;
    }

    /**
     * @notice Claims DUZ tokens for a verified contributor.
     * @param amount  The amount of DUZ the claimant is entitled to.
     * @param proof   Merkle proof verifying the claimant and amount.
     */
    function claim(uint256 amount, bytes32[] calldata proof) external {
        // Check
        if (block.timestamp > claimExpiry) {
            revert MerkleClaim__ClaimWindowExpired();
        }
        if (hasClaimed[msg.sender]) {
            revert MerkleClaim__AlreadyClaimed();
        }
        bytes32 leaf = keccak256(
            bytes.concat(keccak256(abi.encode(msg.sender, amount)))
        );

        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert MerkleClaim__InvalidProof();
        }
        //Effects
        hasClaimed[msg.sender] = true;
        //Interactions
        duz.safeTransfer(msg.sender, amount);

        emit Claimed(msg.sender, amount);
    }

    /**
     * @notice Recovers all unclaimed DUZ back to the Distribution contract
     *         after the claim window has expired.
     *         Only callable by the multisig owner.
     */
    function recoverUnclaimed() external onlyOwner {
        if (block.timestamp <= claimExpiry)
            revert MerkleClaim__ClaimWindowStillOpen();

        uint256 amount = duz.balanceOf(address(this));
        if (amount == 0) revert MerkleClaim__NothingToRecover();

        duz.safeTransfer(distributionContract, amount);

        emit UnclaimedRecovered(amount, block.timestamp);
    }

    // ─── View ─────────────────────────────────────────────────────────────────

    // Returns true if the claim window is still open
    function isClaimOpen() external view returns (bool) {
        return block.timestamp <= claimExpiry;
    }

    // Seconds remaining in the claim window. Returns 0 if expired.
    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= claimExpiry) return 0;
        return claimExpiry - block.timestamp;
    }
}
