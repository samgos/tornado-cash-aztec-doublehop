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

    AztecTornadoBridge aztecTornadoBridge;
    AztecResolver aztecResolver;

    RollupProcessor rollupProcessor;

    constructor(
      address bridge,
      address rollup,
      address resolver
    ) public {
      aztecResolver = AztecResolver(resolver);
      rollupProcessor = RollupProcessor(rollup);
      aztecTornadoBridge = AztecTornadoBridge(bridge);
    }

    function testDeposit(
      bytes32 commitment,
      uint256 interactionNonce,
      uint256 depositAmount
    ) payable public {
      vm.deal(address(this), depositAmount);

      uint256 inputAmount = depositAmount;
      AztecTypes.AztecAsset memory uninitAsset;
      AztecTypes.AztecAsset memory inputAsset = AztecTypes.AztecAsset({
          id: 1,
          erc20Address: address(0x0),
          assetType: AztecTypes.AztecAssetType.ETH
      });

      uninitAsset.assetType = AztecTypes.AztecAssetType.NOT_USED;

      rollupProcessor.receiveEthFromBridge{
        value: inputAmount
      }( interactionNonce );
      rollupProcessor.convert(
          address(aztecTornadoBridge),
          inputAsset,
          uninitAsset,
          uninitAsset,
          uninitAsset,
          inputAmount,
          interactionNonce,
          uint256(commitment)
      );
    }

}
