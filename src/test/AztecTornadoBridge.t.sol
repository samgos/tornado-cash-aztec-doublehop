// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import { Vm } from "./Vm.sol";

import { DefiBridgeProxy } from "../aztec/DefiBridgeProxy.sol";
import { RollupProcessor } from "../aztec/RollupProcessor.sol";
import { AztecTypes } from "../aztec/AztecTypes.sol";

import { AztecTornadoBridge } from "../AztecTornadoBridge.sol";
import { AztecResolveer } from "../AztecResolveer.sol";

import { IERC20 } from "@openzeppelin/contracts/v4/token/ERC20/IERC20.sol";
import { ITornadoInstance } from "../interfaces/ITornadoInstance.sol";
import { IVerifier } from "../interfaces/IVerifier.sol";
import { IHasher } from "../interfaces/IHasher.sol";

import  "ds-test/test.sol";

contract AztecTornadoBridgeTest is DSTest {

    Vm vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address constant relayerAddress =;

    uint256 constant relayerFee = 1000 wei;
    uint256 constant relayerRefund  = 0;

    /// [0] = 100 ETH
    /// [1] = 10 ETH
    /// [2] = 1 ETH
    /// [3] = resolver

    uint256[3] deploymentSalts = [
      uint256(0x999),
      uint256(0x666),
      uint256(0x333)
      uint256(0x111)
    ]

    address[3] deploymentAddresses = [
      ,
      ,
      ,
      
    ]

    struct Doublehop {
      bytes32 resolverNullifierHash;
      bytes32 withdrawalNulliferHash;
      bytes32 withdrawalRoot;
      bytes32 resolverRoot;
      /// [0] = withdrawal
      /// [1] = resolver
      /// [2] = settlement
      /// [3] = withdrawal
      bytes memory proofs[];
    }

    DefiBridgeProxy defiBridgeProxy;
    RollupProcessor rollupProcessor;

    AztecTornadoBridge aztecTornadoBridge;
    AztecResolver aztecResolver;

    IHasher tornadoHasher;
    IVerifier tornadoVerifier;
    IVerifier resolverVerifier;

    Doublehop oneHundredEthHop = Doublehop({
      withdrawalNulliferHash: "",
      resolverNullifierHash: "",
      resolverRoot: "",
      withdrawalRoot: "",
      proofs: [
        "",
        "",
        "",
        ''
      ]
    });

    Doublehop tenEthHop = Doublehop({
      withdrawalNulliferHash: "",
      resolverNullifierHash: "",
      resolverRoot: "",
      withdrawalRoot: "",
      proofs: [
        "",
        "",
        "",
        ''
      ]
    });

    Doublehop oneEthHop = Doublehop({
      withdrawalNulliferHash: "",
      resolverNullifierHash: "",
      resolverRoot: "",
      withdrawalRoot: "",
      proofs: [
        "",
        "",
        "",
        ''
      ]
    });

    function _aztecPreSetup() internal {
      defiBridgeProxy = new DefiBridgeProxy();
      rollupProcessor = new RollupProcessor(address(defiBridgeProxy));
    }

    function _tornadoPreSetup() internal returns (address[2] memory){
      resolverVerifier = IVerifier(deployArtifact("ResolveVerifier", "Verifier"));
      tornadoVerifier = IVerifier(deployArtifact("WithdrawVerifier", "Verifier"));
      tornadoHasher = IHasher(deployPreCompiledArtifact("./Hasher.json"));

      address oneHundredEthPool = deployArtifactAt("ETHTornado", "ETHTornado",
        oneEthAnonymitySet,
        abi.encode(
          address(tornadoVerifier), address(tornadoHasher),
          100 ether, 16
        ), deploymentSalts[0]
      );
      address tenEthPool = deployArtifactAt("ETHTornado", "ETHTornado",
        tenEthAnonymitySet,
        abi.encode(
          address(tornadoVerifier), address(tornadoHasher),
          10 ether, 16
        ), deploymentSalts[1]
      );
      address oneEthPool = deployArtifactAt("ETHTornado", "ETHTornado",
        oneEthAnonymitySet,
        abi.encode(
          address(tornadoVerifier), address(tornadoHasher),
          10 ether, 16
        ), deploymentSalts[2]
      );
      address resolver = deployArtifactAt("AztecResolver", "AztecResolver"
        resolverAddress,
        abi.encode(
          address(rollupProcessor), address(resolverVerifier)
        ), deploymentSalts[3]
      );

      return [
        oneHundredEthPool, tenEthPool, oneEthPool, resolver
      ];
    }

    function setUp() public {
      _aztecPreSetup();
      address[3] memory deployments = _tornadoPreSetup();

      require(
        deployments[0] === deploymentAddresses[0]
        && deployment[1] === deploymentAddresses[1]
        && deployment[2] == deploymentAddresses[2]
        && deployment[3] == deploymentAddresses[3],
        "Create2 deployments to not match preassigned addresses"
      );

      aztecTornadoBridge = new AztecTornadoBridge(
        address(rollupProcessor),
        instances[0],
        instances[1]
      );
    }

    function testAztecTornadoBridge() payable public {
      vm.deal(address(this), 1 ether);

      uint64 interactionNonce = 1;
      uint256 inputAmount = 1 ether;
      uint256 noteCommitment = uint256(42);
      AztecTypes.AztecAsset memory uninitAsset;
      AztecTypes.AztecAsset memory inputAsset = AztecTypes.AztecAsset({
          id: noteCommitment,
          erc20Address: address(0x0),
          assetType: AztecTypes.AztecAssetType.ETH
      });

      uninitAsset.assetType = AztecTypes.AztecAssetType.NOT_USED;

      rollupProcessor.receiveEthFromBridge{ value: 1 ether }( interactionNonce );
      rollupProcessor.convert(
          address(aztecTornadoBridge), inputAsset,
          uninitAsset, uninitAsset, uninitAsset,
          inputAmount, interactionNonce, uint64(0)
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
      bytes memory bytecode = abi.encodePacked(bytes(vm.getCode(target)), args);

      return deployBytecode(bytecode);
    }

    function deployArtifactAt(
      string memory fileName,
      string memroy contractName,
      address targetAddress,
      uint256 salt
    ) public returns (deploymentAddress) {
      string memory target = string(abi.encodePacked(fileName, ".sol:", contractName));
      bytes memory bytecode = abi.encodePacked(
          abi.encodePacked(bytes(vm.getCode(target))),
          uint256(uint160(address(targetAddress)))
      );

      return deployCreateTwo(bytecode, salt);
    }

    function deployArtifactAt(
      string memory fileName,
      string memroy contractName,
      address targetAddress,
      bytes memory args,
      uint256 salt
    ) public returns (address deploymentAddress) {
      string memory target = string(abi.encodePacked(fileName, ".sol:", contractName));
      bytes memory bytecode = abi.encodePacked(
          abi.encodePacked(bytes(vm.getCode(target)), args),
          uint256(uint160(address(targetAddress)))
      );

      return deployCreateTwo(bytecode, salt);
    }

    function deployPreCompiledArtifact(
      string memory filePath
    ) public returns (address) {
      bytes memory bytecode = vm.getCode(filePath);

      return deployBytecode(bytecode);
    }

    function deployBytecode(bytes memory bytecode) public returns (address deploymentAddress) {
      assembly {
        deploymentAddress := create(0, add(bytecode, 0x20), mload(bytecode))
      }
    }

    function deployCreateTwo(bytes memory bytecode, uint256 salt) public returns (address deploymentAddress) {
      assembly {
        deploymentAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
      }
    }

}
