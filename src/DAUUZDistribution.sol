// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title DAUUZDistribution
 * @notice Receives the entire 30,000,000 DUZ supply at token deployment
 *         and routes each allocation to its designated contract.
 *
 * Allocation:
 *   2,000,000  → communityAirdrop   (Community & Airdrop contract)
 *   4,000,000  → merkleClaim        (Contributor Merkle Claim contract)
 *  10,000,000  → zoiReserve         (Zoi Reserve — 4yr vesting)
 *  14,000,000  → liquidityReserve   (Liquidity Reserve — 1yr timelock)
 *  ──────────
 *  30,000,000  TOTAL
 *
 * Ownership:
 *   Owner is a 2-of-3 Gnosis Safe multisig — no single EOA can call
 *   distribute(). The Safe address is passed in at deployment.
 */
contract DAUUZDistribution is Ownable{
    error DAUUZDistribution__ZeroAddress();
    error DAUUZDistribution__AlreadyDistributed();
    error DAUUZDistribution__NotYetDistributed();
    error DAUUZDistribution__NothingToRecover();
    error DAUUZDistribution__InvalidTokenBalance();

    using SafeERC20 for IERC20;

    uint256 public constant COMMUNITY_AIRDROP_AMOUNT = 2_000_000 * 1e18;
    uint256 public constant MERKLE_CLAIM_AMOUNT = 4_000_000 * 1e18;
    uint256 public constant ZOI_RESERVE_AMOUNT = 10_000_000 * 1e18;
    uint256 public constant LIQUIDITY_RESERVE_AMOUNT = 14_000_000 * 1e18;
    uint256 public constant TOTAL_SUPPLY = 30_000_000 * 1e18;

    // ─── State ────────────────────────────────────────────────────────────────
    
    address public communityAirdrop;
    address public merkleClaim;
    address public zoiReserve;
    address public liquidityReserve;
    IERC20 public duz;
    bool public distributed;


    // ─── Events ───────────────────────────────────────────────────────────────

    event Distributed(
        address indexed token,
        address communityAirdrop,
        address merkleClaim,
        address zoiReserve,
        address liquidityReserve
    );

    event UnclaimedRecovered(address indexed token, uint256 amount);

    // ─── Constructor ──────────────────────────────────────────────────────────

    /// @param multisig  Address of the 2-of-3 Gnosis Safe that owns this contract.
    constructor(address multisig) Ownable(multisig) {
        if ( multisig == address(0)) {
            revert DAUUZDistribution__ZeroAddress();
        }
        
    }

    /**
     * @notice Routes the full 30M DUZ supply to each sub-contract.
     *         Can only be called once by the multisig owner.
     */
    function distribute(
        address _token,
        address _communityAirdrop,
        address _merkleClaim,
        address _zoiReserve,
        address _liquidityReserve
    ) external onlyOwner {
        // Checks
        if (distributed) {
            revert DAUUZDistribution__AlreadyDistributed();
        }
    
        if (_communityAirdrop == address(0)) {
            revert DAUUZDistribution__ZeroAddress();
        }
        if (_merkleClaim == address(0)) {
            revert DAUUZDistribution__ZeroAddress();
        }
        if (_zoiReserve == address(0)) {
            revert DAUUZDistribution__ZeroAddress();
        }
        if (_liquidityReserve == address(0)) {
            revert DAUUZDistribution__ZeroAddress();
        }

        if (_token == address(0)) {
            revert DAUUZDistribution__ZeroAddress();
        }

        duz = IERC20(_token);

        
        if (duz.balanceOf(address(this)) != TOTAL_SUPPLY) {
            revert DAUUZDistribution__InvalidTokenBalance();
        }

        // Effects
        distributed = true;
        communityAirdrop = _communityAirdrop;
        merkleClaim = _merkleClaim;
        zoiReserve = _zoiReserve;
        liquidityReserve = _liquidityReserve;

        // Interactions
        duz.safeTransfer(_communityAirdrop, COMMUNITY_AIRDROP_AMOUNT);
        duz.safeTransfer(_merkleClaim, MERKLE_CLAIM_AMOUNT);
        duz.safeTransfer(_zoiReserve, ZOI_RESERVE_AMOUNT);
        duz.safeTransfer(_liquidityReserve, LIQUIDITY_RESERVE_AMOUNT);

        emit Distributed(
            address(duz),
            _communityAirdrop,
            _merkleClaim,
            _zoiReserve,
            _liquidityReserve
        );
    }

    /**
     * @notice Recovers unclaimed tokens returned from the Merkle Claim contract.
     *         Forwards them to the multisig owner.
     */
    function recoverUnclaimed() external onlyOwner {
        if (!distributed) {
            revert DAUUZDistribution__NotYetDistributed();
        }

        uint256 amount = duz.balanceOf(address(this));
        if (amount == 0) {
            revert DAUUZDistribution__NothingToRecover();
        }

        duz.safeTransfer(owner(), amount);

        emit UnclaimedRecovered(address(duz), amount);
    }

    // ─── View function─────────────────────────────────────────────────────────────────

    function getAllocation()
        external
        pure
        returns (
            uint256 _communityAirdropAmount,
            uint256 _merkleClaimAmount,
            uint256 _zoiReserveAmount,
            uint256 _liquidityReserveAmount
        )
    {
        return (
            COMMUNITY_AIRDROP_AMOUNT,
            MERKLE_CLAIM_AMOUNT,
            ZOI_RESERVE_AMOUNT,
            LIQUIDITY_RESERVE_AMOUNT
        );
    }
}
