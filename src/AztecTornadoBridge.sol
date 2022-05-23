pragma solidity >=0.6.10 <=0.8.10;
pragma experimental ABIEncoderV2;

import { IDefiBridge } from "./interfaces/IDefiBridge.sol";
import { ITornadoInstance } from "./interfaces/ITornadoInstance.sol";
import { IRollupProcessor } from "./interfaces/IRollupProcessor.sol";

import { AztecTypes } from "./aztec/AztecTypes.sol";

contract AztecTornadoBridge is IDefiBridge {

  address public immutable rollupProcessor;

  uint256 constant MAXIMUM_DEPOSIT = 10 ether;
  uint256 constant MINIMUM_DEPOSIT = 1 ether;

  address TORNADO_1ETH;
  address TORNADO_10ETH;
  address TORNADO_100ETH;

  constructor(
    address oneHundredEthAnonymitySet,
    address tenEthAnonymitySet,
    address oneEthAnonymitySet,
    address rollupContract
  ) {
    TORNADO_100ETH = oneHundredEthAnonymitySet;
    TORNADO_10ETH = tenEthAnonymitySet;
    TORNADO_1ETH = oneEthAnonymitySet;
    rollupProcessor = rollupContract;
  }

  function convert(
    AztecTypes.AztecAsset calldata inputAssetA,
    AztecTypes.AztecAsset calldata inputAssetB,
    AztecTypes.AztecAsset calldata outputAssetA,
    AztecTypes.AztecAsset calldata outputAssetB,
    uint256 inputValue,
    uint256 interactionNonce,
    uint256 auxData,
    address rollupBeneficiary
  ) payable public override returns (
    uint256 outputValueA,
    uint256 outputValueB,
    bool isAsync
  ) {
    require(msg.sender == rollupProcessor, "AztecTornadoBridge: INVALID_CALLER");

    require(
      inputAssetA.assetType == AztecTypes.AztecAssetType.ETH,
      "AztecTornadoBridge: INPUT_ASSET_NOT_ETH"
    );

    require(
      outputAssetA.assetType == AztecTypes.AztecAssetType.NOT_USED,
      "AztecTornadoBridge: OUTPUT_ASSET_A_ASSIGNED"
    );

    require(
      inputAssetB.assetType == AztecTypes.AztecAssetType.NOT_USED,
      "AztecTornadoBridge: INPUT_ASSET_B_ASSIGNED"
    );

    require(
      outputAssetB.assetType == AztecTypes.AztecAssetType.NOT_USED,
      "AztecTornadoBridge: OUTPUT_ASSET_B_ASSIGNED"
    );

    uint256 depositValue = IRollupProcessor(rollupProcessor)
    .getEthPaymentsSlot(interactionNonce);

    ITornadoInstance(getInstance(depositValue)).deposit{
      value: depositValue
    }( bytes32(auxData) );

    return(depositValue, 0, false);
  }

  function finalise(
    AztecTypes.AztecAsset calldata inputAssetA,
    AztecTypes.AztecAsset calldata inputAssetB,
    AztecTypes.AztecAsset calldata outputAssetA,
    AztecTypes.AztecAsset calldata outputAssetB,
    uint256 interactionNonce,
    uint64 auxData
  ) external payable override returns (uint256, uint256, bool) {
    require(false);
  }

  function getInstance(uint256 value) public view returns (address) {
    if(value == 1 ether) {
      return TORNADO_1ETH;
    } else if(value == 10 ether){
      return TORNADO_10ETH;
    } else if(value == 100 ether) {
      return TORNADO_100ETH;
    } else {
      revert();
    }
  }

}
