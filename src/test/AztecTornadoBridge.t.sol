// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { Vm } from "./Vm.sol";

import { DefiBridgeProxy } from "../aztec/DefiBridgeProxy.sol";
import { RollupProcessor } from "../aztec/RollupProcessor.sol";
import { AztecTypes } from "../aztec/AztecTypes.sol";

import { AztecTornadoBridge } from "../AztecTornadoBridge.sol";
import { AztecResolver } from "../AztecResolver.sol";

import { IERC20 } from "@openzeppelin/contracts/v4/token/ERC20/IERC20.sol";
import { ITornadoInstance } from "../interfaces/ITornadoInstance.sol";
import { IVerifier } from "../interfaces/IVerifier.sol";
import { IHasher } from "../interfaces/IHasher.sol";

import  "ds-test/test.sol";

contract AztecTornadoBridgeTest is DSTest {

    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    uint256 constant relayerFee = 1000 wei;
    uint256 constant relayerRefund  = 0;

    uint256[6] deploymentSalts = [
      uint256(999999), /// 100 ETH
      uint256(666666), /// 10 ETH
      uint256(333333), ///  1 ETH
      uint256(101010), /// resolver
      uint256(111000), /// verifier
      uint256(100000)  /// hasher
    ];

    address[6] deploymentAddresses = [
      0xc250e9B5AA63a212fEACA89080ab6af7A9872f73,
      0xE9F5e35a27f8B032831d5DE18506A9eFC0cFc3CD,
      0x84482049c0144f47d33F8179813bcB32fc2F8999,
      0xB67eab9Bd395fDDA58e6d061a1d1d6D6caF656A5,
      0x47Ee36f715C0A11Bae4c3837f46324AfB0893BE9,
     0x643541D6f82cb9DEbea9dA2b09eb11ca32DeC4c5
    ];

    struct Doublehop {
      bytes32 resolverNullifierHash;
      bytes32 withdrawalNulliferHash;
      bytes32 withdrawalRoot;
      bytes32 resolverRoot;
      string[4] proofs;
      /// [0] = withdrawal
      /// [1] = resolver
      /// [2] = settlement
      /// [3] = withdrawal
    }

    DefiBridgeProxy defiBridgeProxy;
    RollupProcessor rollupProcessor;

    AztecTornadoBridge aztecTornadoBridge;
    AztecResolver aztecResolver;

    IHasher tornadoHasher;
    IVerifier tornadoVerifier;
    IVerifier resolverVerifier;

    function _aztecPreSetup() internal {
      defiBridgeProxy = new DefiBridgeProxy();
      rollupProcessor = new RollupProcessor(address(defiBridgeProxy));
    }

    function _tornadoPreSetup() internal returns (address[6] memory){
      resolverVerifier = IVerifier(deployArtifact("ResolveVerifier", "Verifier"));
      tornadoVerifier = IVerifier(
        deployArtifactAt("WithdrawVerifier", "Verifier", deploymentSalts[4])
      );
      tornadoHasher = IHasher(
        deployPreCompiledArtifactAt("./Hasher.json", deploymentSalts[5])
      );
      address oneHundredEthPool = deployArtifactAt("ETHTornado", "ETHTornado",
        abi.encode(
          address(tornadoVerifier),
          address(tornadoHasher),
          100 ether,
          uint32(16)
        ), deploymentSalts[0]
      );
      address tenEthPool = deployArtifactAt("ETHTornado", "ETHTornado",
        abi.encode(
          address(tornadoVerifier),
          address(tornadoHasher),
          10 ether,
          uint32(16)
        ), deploymentSalts[1]
      );
      address oneEthPool = deployArtifactAt("ETHTornado", "ETHTornado",
        abi.encode(
          address(tornadoVerifier),
          address(tornadoHasher),
          1 ether,
          uint32(16)
        ), deploymentSalts[2]
      );
      address tornadoResolver = deployArtifactAt("AztecResolver", "AztecResolver",
        abi.encode(
          address(rollupProcessor),
          address(resolverVerifier)
        ), deploymentSalts[3]
      );

      return [
        oneHundredEthPool,
        tenEthPool,
        oneEthPool,
        address(tornadoResolver),
        address(tornadoVerifier),
        address(tornadoHasher)
      ];
    }

    function setUp() public {
      emit log_address(address(this));

      _aztecPreSetup();
      address[6] memory deployments = _tornadoPreSetup();

      aztecTornadoBridge = new AztecTornadoBridge(
        deployments[0],
        deployments[1],
        deployments[2],
        address(rollupProcessor)
      );
    }

    function testAztecTornadoBridge() payable public {
      vm.deal(address(this), 1 ether);

      uint256 inputAmount = 1 ether;
      uint256 interactionNonce = uint256(1);
      uint256 noteCommitment = uint256(42);
      AztecTypes.AztecAsset memory uninitAsset;
      AztecTypes.AztecAsset memory inputAsset = AztecTypes.AztecAsset({
          id: 1,
          erc20Address: address(0x0),
          assetType: AztecTypes.AztecAssetType.ETH
      });

      uninitAsset.assetType = AztecTypes.AztecAssetType.NOT_USED;

      rollupProcessor.receiveEthFromBridge{
        value: 1 ether
      }( interactionNonce );
      rollupProcessor.convert(
          address(aztecTornadoBridge),
          inputAsset,
          uninitAsset,
          uninitAsset,
          uninitAsset,
          inputAmount,
          interactionNonce,
          noteCommitment
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

    function deployArtifactAt(
      string memory fileName,
      string memory contractName,
      uint256 salt
    ) public returns (address) {
      string memory target = string(abi.encodePacked(fileName, ".sol:", contractName));

      return deployCreateTwo(vm.getCode(target), salt);
    }

    function deployArtifactAt(
      string memory fileName,
      string memory contractName,
      bytes memory args,
      uint256 salt
    ) public returns (address) {
      string memory target = string(abi.encodePacked(fileName, ".sol:", contractName));
      bytes memory bytecode = abi.encodePacked(
          vm.getCode(target),
          args
      );

      return deployCreateTwo(bytecode, salt);
    }

    function deployPreCompiledArtifactAt(
      string memory filePath,
      uint256 salt
    ) public returns (address) {
      bytes memory bytecode = vm.getCode(filePath);

      return deployCreateTwo(bytecode, salt);
    }

    function deployBytecode(bytes memory bytecode) public returns (address deploymentAddress) {
      assembly {
        deploymentAddress := create(callvalue(), add(bytecode, 0x20), mload(bytecode))
      }
    }

    function deployCreateTwo(bytes memory bytecode, uint256 salt) public returns (address deploymentAddress) {
      assembly {
        deploymentAddress := create2(callvalue(), add(bytecode, 0x20), mload(bytecode), salt)
      }
    }

}
