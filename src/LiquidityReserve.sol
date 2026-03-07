// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title LiquidityReserve
 * @notice Holds 14,000,000 DUZ locked for 1 year from deployment.
 *         Full amount becomes claimable after the lock expires.
 *         Only the 2-of-3 Gnosis Safe multisig can withdraw.
 *
 * Schedule:
 *   Locked   — deployment → deployment + 365 days
 *   Unlocked — after deployment + 365 days → 14,000,000 DUZ claimable
 */
contract LiquidityReserve is Ownable {
    error LiquidityReserve__ZeroAddress();
    error LiquidityReserve__StillLocked();
    error LiquidityReserve__AlreadyWithdrawn();

    using SafeERC20 for IERC20;

    uint256 public constant TOTAL_ALLOCATION = 14_000_000 * 1e18;
    uint256 public constant LOCK_DURATION    = 365 days;

    IERC20  public immutable duz;
    uint256 public immutable lockStart;
    uint256 public immutable lockEnd;

    bool public withdrawn;

    event Withdrawn(uint256 amount, uint256 timestamp);

    /**
     * @param multisig  2-of-3 Gnosis Safe — owner and beneficiary.
     * @param _duz      DUZ token address.
     */
    constructor(address multisig, IERC20 _duz) Ownable(multisig) {
        if (multisig == address(0) || address(_duz) == address(0)) {
            revert LiquidityReserve__ZeroAddress();
        }
        duz       = _duz;
        lockStart = block.timestamp;
        lockEnd   = block.timestamp + LOCK_DURATION;
    }

    /**
     * @notice Withdraws the full 14,000,000 DUZ to the multisig owner.
     *         Only callable after the 1 year lock has expired.
     *         Can only be called once.
     */
    function withdraw() external onlyOwner {
        if (block.timestamp < lockEnd) {
            revert LiquidityReserve__StillLocked();
        }
        if (withdrawn) {
            revert LiquidityReserve__AlreadyWithdrawn();
        }

        withdrawn = true;

        uint256 amount = duz.balanceOf(address(this));
        duz.safeTransfer(owner(), amount);

        emit Withdrawn(amount, block.timestamp);
    }


    /// @notice Returns true if the lock has expired.
    function isUnlocked() external view returns (bool) {
        return block.timestamp >= lockEnd;
    }

    /// @notice Seconds remaining until the lock expires. Returns 0 if already unlocked.
    function timeRemaining() external view returns (uint256) {
        if (block.timestamp >= lockEnd) return 0;
        return lockEnd - block.timestamp;
    }
}
