// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.4 <0.8.11;

import { Vm } from "./ds/Vm.sol";

import { IERC20 } from "@openzeppelin/contracts/v4/token/ERC20/IERC20.sol";
import { ITornadoProxy, ITornadoInstance } from "../interfaces/ITornadoProxy.sol";
import { IVerifier } from "../interfaces/IVerifier.sol";
import { IHasher } from "../interfaces/IHasher.sol";

import { AztecTornadoBridge } from "../AztecTornadoBridge.sol";
import { DefiBridgeProxy } from "../aztec/DefiBridgeProxy.sol";
import { RollupProcessor } from "../aztec/RollupProcessor.sol";
import { AztecTypes } from "../aztec/AztecTypes.sol";

import "../../lib/ds-test/src/test.sol";

contract AztecTornadoBridgeTest is DSTest {

    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    DefiBridgeProxy defiBridgeProxy;
    RollupProcessor rollupProcessor;

    AztecTornadoBridge aztecTornadoBridge;
    ITornadoProxy tornadoRouter;

    IHasher tornadoHasher;
    IVerifier tornadoVerifier;
    IVerifier resolverVerifier;

    function _aztecPreSetup() internal {
        defiBridgeProxy = new DefiBridgeProxy();
        rollupProcessor = new RollupProcessor(address(defiBridgeProxy));
    }

    function _tornadoPreSetup() internal {
        bytes memory empty;

        resolverVerifier = IVerifier(deployArtifact("ResolveVerifier", "Verifier", empty));
        tornadoVerifier = IVerifier(deployArtifact("WithdrawVerifier", "Verifier", empty));
        tornadoHasher = IHasher(deployArtifact("Hasher", "Hasher", empty));
        tornadoRouter = ITornadoProxy(
          deployArtifact("TornadoProxy", "TornadoProxy",
            abi.encode(
              address(0x0), address(this),
              [
                ITornadoProxy.Tornado(
                  ITornadoInstance(
                    deployArtifact("ETHTornado", "ETHTornado",
                      abi.encode(
                        address(tornadoVerifier), address(tornadoHasher),
                        1 ether, 16
                      )
                    )
                  ),
                  ITornadoProxy.Instance(
                    false, IERC20(address(0x0)),
                    ITornadoProxy.InstanceState.ENABLED
                  )
                ),
                ITornadoProxy.Tornado(
                  ITornadoInstance(
                    deployArtifact("ETHTornado", "ETHTornado",
                      abi.encode(
                        address(tornadoVerifier), address(tornadoHasher),
                        10 ether, 16
                      )
                    )
                  ),
                  ITornadoProxy.Instance(
                    false, IERC20(address(0x0)),
                    ITornadoProxy.InstanceState.ENABLED
                  )
                )
              ]
            )
          )
       );
    }

    function setUp() public {
        _aztecPreSetup();
        _tornadoPreSetup();

        aztecTornadoBridge = new AztecTornadoBridge(
          address(this),
          address(tornadoRouter)
        );
    }

    function testAztecTornadoBridge() payable public {
      vm.deal(address(this), 1 ether);

      bytes32 noteCommitment;
      uint64 inputAmount = uint64(1 ether);
      AztecTypes.AztecAsset memory uninitAsset;
      AztecTypes.AztecAsset memory inputAsset = AztecTypes.AztecAsset({
          id: 1,
          erc20Address: address(0x0),
          assetType: AztecTypes.AztecAssetType.ETH
      });

      uninitAsset.assetType = AztecTypes.AztecAssetType.ETH;

      aztecTornadoBridge.convert{ value: 1 ether }(
          inputAsset, uninitAsset, uninitAsset, uninitAsset,
          uint256(noteCommitment), 1, inputAmount
      );

      assertEq(address(this).balance, 0, "deposit failure");
    }

    function deployArtifact(
      string memory fileName,
      string memory contractName,
      bytes memory args
    ) public returns (address deploymentAddress) {
      deploymentAddress = vm.deployCode(
          string(abi.encodePacked(fileName, ".sol:", contractName)),
          args
      );
    }

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
