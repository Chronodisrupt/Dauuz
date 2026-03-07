// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @author KorexOnChain
 * @title DUZToken
 * @notice Fixed-supply participation token for the DAUUZ ecosystem.
 *         All 30,000,000 DUZ are minted once at deployment to the
 *         Distribution contract. No further minting is ever possible.
 *
 * Allocation (handled by Distribution contract):
 *   2,000,000  — Community & Airdrop
 *   4,000,000  — Contributors & Earned Tasks (Merkle Claim)
 *  10,000,000  — Zoi Reserve       (4-yr vesting, 25 % / yr)
 *  14,000,000  — Liquidity Reserve (1-yr timelock)
 *  ----------
 *  30,000,000  TOTAL
 */

contract DUZToken is ERC20, Ownable {
    error DauuzToken__InvalidDistributionContract();

    uint256 public constant MAX_SUPPLY = 30_000_000 * 1e18;

    constructor(
        address distributionContract
    ) ERC20("DAUUZ", "DUZ") Ownable(distributionContract) {
        if (distributionContract == address(0)) {
            revert DauuzToken__InvalidDistributionContract();
        }
        // One-time mint — entire fixed supply to the distribution contract.
        _mint(distributionContract, MAX_SUPPLY);
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
