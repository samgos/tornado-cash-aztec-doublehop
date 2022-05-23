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

    Doublehop oneHundredEthHop = Doublehop({
       withdrawalNulliferHash: 0x049dbad3c14a924a2b4d9e08d0dbd331a48b8914136d8e690432e585fc94d5c3,
       resolverNullifierHash: 0x1c2d9f78496d0977ca823265b2bf3da652747cf005b7cc8e321df27fdaecb21e,
       resolverRoot: 0x0c4a27a119f3b5fb191a05a1bda5d526148ff0f884fcd0dff9e788777eea125a,
       withdrawalRoot: 0x12fede313163cc00a8772a8f4fa180a235e1d504f5940eed928f5a8961bc357a,
      proofs: [
         "0x27d2f6132306ca8d57b9548f27b7a1c0bddb40f67d10f5ae68224d9683d4789910e26b4b8b74c4737c1d888721a7d85b8efabc1322fdc42371e831275b1bc51002980ee7010fd7de32f938b6933931b08256fa929f090ad14f4ee7adaa3aa1b4201a2cb6fa7e98f8e691f97625c4d0047cb0615857bd5804dc2c184c355d62332e9244a941d576a1a832abf80f4d4dd814d86296c46fee8810cdf506186fa80716ab4ffc6dc98ad00466d1b904c1ae206b706c78000f4cc02b0612cc2e5229f4149eedbc260eb689928f03c12a36c4924b813cd6a17a2e7ff233266fcb7fef6724f94e5ff66cec1446f16794b025392f4c6dadc384c7ab05dc2b185c100266af",
         "0x22ca0df74d4058e6d7d5595523d4b750e99f816300a4cf2c7bd86cb11bf66e070037df14bfa1d6844ae0dcb08d849e8148a48ac20c510a3182187b7fd3ce76272f5f5911fff40c71b167d666d3cfeb85c96e712479f4dade6aaa08a01c8485e315c26e45c17bbba0bf3272f110041bd2ed54410d137db2908f98e02c8ed414942035a7164b560159928f3692fa7197c90ca2956df199f8716b85828867f7c7c017704d615079ff18db611d2ed09e2c6a6268bac726e4fce47bd62a977eb15ecb1a856a307ef807c6bed7536efaf4ce2084dd5c5557be5a880bd6ca431f577634229f971bd8047c6ae3338d2ded9f5c1b7d1e71d418e8412bc9b5c46afda02e6c",
         "0x0",
         "0x10db822ac672018b8547c2ee6abf43b87f558040d11edbd032190e72e4b87c20ffab9fd538ef69aa6d25f3619b0ef16d30615ae7173495535f0d5307729739907841b3ba27941ffcddf6da5a69aeb1158865edce6d0c127e9fbee897a81f9a503856b753859669d54b37a3d883b547ee4dd7ad7aaf82db3e9e591a2731eb8a119f6fa2d7963d3878aed432ab163b2e9c03de59d35820a795d7506542af8acb7041039c1a865d4cb69c709a352fa1d8c0206b1a1f702fef4cc6fbf66878ca698098e7026da9f17139a905e21771b4cc3a80f8bb8e37813b42adf1287c7a8a1b809605e21e61ec43fd8bd8038fdbdcd20b3811de19866dce1edc0a888c6b87a39"
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
        ""
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
