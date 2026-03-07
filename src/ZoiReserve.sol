// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title ZoiReserve
 * @notice Holds 10,000,000 DUZ for the Zoi mental wellness utility layer.
 *         Vests at 25% (2,500,000 DUZ) per year over 4 years.
 *         Clock starts at deployment.
 *
 * Ownership:
 *   2-of-3 Gnosis Safe multisig. Only the multisig can claim.
 */
contract ZoiReserve is Ownable {
    error ZoiReserve__ZeroAddress();
    error ZoiReserve__NothingToClaim();

    using SafeERC20 for IERC20;

    // ─── Constants ────────────────────────────────────────────────────────────

    uint256 public constant TOTAL_ALLOCATION = 10_000_000 * 1e18;
    uint256 public constant VEST_PER_YEAR = 2_500_000 * 1e18;
    uint256 public constant YEAR = 365 days;
    uint256 public constant VESTING_DURATION = 4 * 365 days; // full 4yr duration in seconds

    IERC20 public immutable duz;
    uint256 public immutable vestingStart;

    // Timestamp of the last successful claim (starts at vestingStart)
    uint256 public lastClaimed;

    event Claimed(uint256 amount, uint256 timestamp);


    /**
     * @param multisig  2-of-3 Gnosis Safe — owner and beneficiary.
     * @param _duz      DUZ token address.
     */
    constructor(address multisig, IERC20 _duz) Ownable(multisig) {
        if (multisig == address(0) || address(_duz) == address(0)) {
            revert ZoiReserve__ZeroAddress();
        }
        duz = _duz;
        vestingStart = block.timestamp;
        lastClaimed = block.timestamp;
    }

    /**
     * @notice Claims all vested tranches that have not yet been claimed.
     *         Each tranche unlocks every 365 days from vestingStart.
     *         Only callable by the multisig owner.
     */
    function claim() external onlyOwner {
        uint256 claimable = _claimableAmount();
        if (claimable == 0) revert ZoiReserve__NothingToClaim();

        // Move lastClaimed forward by however many full years were just claimed
        uint256 yearsClaimed = claimable / VEST_PER_YEAR;
        lastClaimed += yearsClaimed * YEAR;

        duz.safeTransfer(owner(), claimable);

        emit Claimed(claimable, block.timestamp);
    }

    /// @notice Total DUZ claimable right now (vested but not yet claimed).
    function claimableAmount() external view returns (uint256) {
        return _claimableAmount();
    }

    /// @notice Timestamp when a given year's tranche unlocks (pass 1, 2, 3 or 4).
    function unlockTime(uint256 year) external view returns (uint256) {
        if (year == 0 || year > 4) return 0;
        return vestingStart + (year * YEAR);
    }

    /// @notice Timestamp when the full vesting period ends.
    function vestingEnd() external view returns (uint256) {
        return vestingStart + VESTING_DURATION;
    }

    function _claimableAmount() internal view returns (uint256) {
        uint256 elapsed = block.timestamp - vestingStart;
        uint256 vestedPeriod = lastClaimed - vestingStart;

        // Cap elapsed at total vesting duration so no overclaiming after 4 years
        if (elapsed > VESTING_DURATION) {
            elapsed = VESTING_DURATION;
        }

        uint256 vestedYears = elapsed / YEAR;
        uint256 claimedYears = vestedPeriod / YEAR;

        if (vestedYears <= claimedYears) return 0;

        return (vestedYears - claimedYears) * VEST_PER_YEAR;
    }
}
