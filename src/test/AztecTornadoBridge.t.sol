// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { Vm } from "./ds/Vm.sol";

import { AztecTornadoBridge } from "../AztecTornadoBridge.sol";
import { DefiBridgeProxy } from "../aztec/DefiBridgeProxy.sol";
import { RollupProcessor } from "../aztec/RollupProcessor.sol";
import { AztecTypes } from "../aztec/AztecTypes.sol";

import { IERC20 } from "@openzeppelin/contracts/v4/token/ERC20/IERC20.sol";
import { ITornadoInstance } from "../interfaces/ITornadoInstance.sol";
import { ITornadoProxy } from "../interfaces/ITornadoProxy.sol";
import { IVerifier } from "../interfaces/IVerifier.sol";
import { IHasher } from "../interfaces/IHasher.sol";

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

    function _tornadoPreSetup() internal returns (address[2] memory){
        resolverVerifier = IVerifier(deployArtifact("ResolveVerifier", "Verifier"));
        tornadoVerifier = IVerifier(deployArtifact("WithdrawVerifier", "Verifier"));
        tornadoHasher = IHasher(deployBytecode(bytes("")));

        address oneEthAnonymitySet = deployArtifact("ETHTornado", "ETHTornado",
          abi.encode(
            address(tornadoVerifier), address(tornadoHasher),
            1 ether, 16
          )
        );
        address tenEthAnonymitySet = deployArtifact("ETHTornado", "ETHTornado",
          abi.encode(
            address(tornadoVerifier), address(tornadoHasher),
            10 ether, 16
          )
        );

        tornadoRouter = ITornadoProxy(
          deployArtifact("TornadoProxy", "TornadoProxy",
            abi.encode(
              address(0x0), address(this),
              [
                ITornadoProxy.Tornado(
                  ITornadoInstance(oneEthAnonymitySet),
                  ITornadoProxy.Instance(
                    false, IERC20(address(0x0)),
                    ITornadoProxy.InstanceState.ENABLED
                  )
                ),
                ITornadoProxy.Tornado(
                  ITornadoInstance(tenEthAnonymitySet),
                  ITornadoProxy.Instance(
                    false, IERC20(address(0x0)),
                    ITornadoProxy.InstanceState.ENABLED
                  )
                )
              ]
            )
          )
       );

      return [ oneEthAnonymitySet, tenEthAnonymitySet ];
    }

    function setUp() public {
        _aztecPreSetup();
        address[2] memory instances = _tornadoPreSetup();

        aztecTornadoBridge = new AztecTornadoBridge(
          address(rollupProcessor),
          address(tornadoRouter),
          instances[0],
          instances[1]
        );
    }

    function testAztecTornadoBridge() payable public {
      vm.deal(address(this), 1 ether);

      uint256 inputAmount = 1 ether;
      AztecTypes.AztecAsset memory uninitAsset;
      AztecTypes.AztecAsset memory inputAsset = AztecTypes.AztecAsset({
          id: 0,
          erc20Address: address(0x0),
          assetType: AztecTypes.AztecAssetType.ETH
      });

      uninitAsset.assetType = AztecTypes.AztecAssetType.NOT_USED;

      rollupProcessor.receiveEthFromBridge{ value: 1 ether }(1);
      rollupProcessor.convert(
          address(aztecTornadoBridge), inputAsset,
          uninitAsset, uninitAsset, uninitAsset,
          inputAmount, 1, uint64(0)
      );
    }

    function deployArtifact(
      string memory fileName,
      string memory contractName
    ) public returns (address) {
      string memory target = string(abi.encodePacked(fileName, ".sol:", contractName));
      bytes memory bytecode = abi.encodePacked(vm.getCode(target));

      return deployBytecode(bytecode);
    }

    function deployArtifact(
      string memory fileName,
      string memory contractName,
      bytes memory args
    ) public returns (address) {
      string memory target = string(abi.encodePacked(fileName, ".sol:", contractName));
      bytes memory bytecode = abi.encodePacked(vm.getCode(target), args);

      return deployBytecode(bytecode);
    }

    function deployBytecode(bytes memory bytecode) public returns (address deploymentAddress) {
      assembly {
        deploymentAddress := create(0, add(bytecode, 0x20), mload(bytecode))
      }
    }

}
