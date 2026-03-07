// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @title GenerateInput
 * @notice Generates the Merkle tree input JSON from a whitelist of
 *         contributor addresses and their individual DUZ allocations.
 *
 * Usage:
 *   forge script script/GenerateInput.s.sol
 *   Output → /script/target/input.json
 */
contract GenerateInput is Script {

    string[] private types = new string[](2);
    uint256  private count;

    string[] private whitelist = new string[](10);
    uint256[] private amounts  = new uint256[](10);

    string private constant INPUT_PATH = "/script/target/input.json";

    function run() public {
        types[0] = "address";
        types[1] = "uint";

        // Dummy contributor addresses
        whitelist[0] = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266";
        whitelist[1] = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8";
        whitelist[2] = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC";
        whitelist[3] = "0x90F79bf6EB2c4f870365E785982E1f101E93b906";
        whitelist[4] = "0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65";
        whitelist[5] = "0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc";
        whitelist[6] = "0x976EA74026E726554dB657fA54763abd0C3a0aa9";
        whitelist[7] = "0x14dC79964da2C08b23698B3D3cc7Ca32193d9955";
        whitelist[8] = "0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f";
        whitelist[9] = "0xa0Ee7A142d267C1f36714E4a8F75612F20a79720";

        // Individual allocations — total must equal 4,000,000 DUZ
        amounts[0] = 600_000 * 1e18;  // 600,000 DUZ
        amounts[1] = 500_000 * 1e18;  // 500,000 DUZ
        amounts[2] = 450_000 * 1e18;  // 450,000 DUZ
        amounts[3] = 450_000 * 1e18;  // 450,000 DUZ
        amounts[4] = 400_000 * 1e18;  // 400,000 DUZ
        amounts[5] = 400_000 * 1e18;  // 400,000 DUZ
        amounts[6] = 350_000 * 1e18;  // 350,000 DUZ
        amounts[7] = 350_000 * 1e18;  // 350,000 DUZ
        amounts[8] = 250_000 * 1e18;  // 250,000 DUZ
        amounts[9] = 250_000 * 1e18;  // 250,000 DUZ
        
        count = whitelist.length;

        string memory input = _createJSON();
        vm.writeFile(string.concat(vm.projectRoot(), INPUT_PATH), input);
        console.log("DONE: Input written to %s", INPUT_PATH);
    }

    function _createJSON() internal view returns (string memory) {
        string memory countString = vm.toString(count);
        string memory json = string.concat(
            '{ "types": ["address", "uint"], "count":', countString, ',"values": {'
        );

        for (uint256 i = 0; i < whitelist.length; i++) {
            string memory amountString = vm.toString(amounts[i]);
            string memory entry = string.concat(
                '"', vm.toString(i), '"',
                ': { "0":', '"', whitelist[i], '"',
                ', "1":', '"', amountString, '"', ' }'
            );
            if (i == whitelist.length - 1) {
                json = string.concat(json, entry);
            } else {
                json = string.concat(json, entry, ',');
            }
        }

        json = string.concat(json, '} }');
        return json;
    }
}
