// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

import { Vm } from "./ds/Vm.sol";

import { DefiBridgeProxy } from "../aztec/DefiBridgeProxy.sol";
import { RollupProcessor } from "../aztec/RollupProcessor.sol";

// Example-specific imports
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { AztecTornadoBridge } from "../AztecTornadoBridge.sol";

import { AztecTypes } from "../aztec/AztecTypes.sol";

import "../../lib/ds-test/src/test.sol";

contract AztecTornadoBridgeTest is DSTest {

    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    DefiBridgeProxy defiBridgeProxy;
    RollupProcessor rollupProcessor;

    AztecTornadoBridge aztecTornadoBridge;

    function _aztecPreSetup() internal {
        defiBridgeProxy = new DefiBridgeProxy();
        rollupProcessor = new RollupProcessor(address(defiBridgeProxy));
    }

    function _tornadoPreSetup() internal {
      // initialise contracts
    }

    function setUp() public {
        _aztecPreSetup();
        _tornadoPreSetup();

        aztecTornadoBridge = new AztecTornadoBridge();
    }


    function testAztecTornadoBridge() public {}


    function assertNotEq(address a, address b) internal {
        if (a == b) {
            emit log("Error: a != b not satisfied [address]");
            emit log_named_address("  Expected", b);
            emit log_named_address("    Actual", a);
            fail();
        }
    }


    function _setTokenBalance(
        address token,
        address user,
        uint256 balance
    ) internal {
        uint256 slot = 2; // May vary depending on token

        vm.store(
            token,
            keccak256(abi.encode(user, slot)),
            bytes32(uint256(balance))
        );

        assertEq(IERC20(token).balanceOf(user), balance, "wrong balance");
    }

}
