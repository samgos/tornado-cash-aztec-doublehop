pragma solidity >=0.8.4 <0.8.11;

import "./interfaces/IDefiBridge.sol";
import "./interfaces/ITornadoProxy.sol";

contract AztecTornadoBridge {

  ITornadoProxy tornadoRouter;

  address public immutable rollupProcessor;

  address constant TORNADO_1ETH = 0x47CE0C6eD5B0Ce3d3A51fdb1C52DC66a7c3c2936;
  address constant TORNADO_10ETH = 0x910Cbd523D972eb0a6f4cAe4618aD62622b39DbF;

  uint256 constant MAXIMUM_DEPOSIT = 10 ether;
  uint256 constant MINIMUM_DEPOSIT = 1 ether;

  constructor(
    address rollupContract,
    address tornadoProxy
  ) public {
    tornadoRouter = ITornadoProxy(tornadoProxy);
    rollupProcessor = rollupContract;
  }

  function convert(
    AztecTypes.AztecAsset calldata inputAssetA,
    AztecTypes.AztecAsset calldata inputAssetB,
    AztecTypes.AztecAsset calldata outputAssetA,
    AztecTypes.AztecAsset calldata outputAssetB,
    uint256 inputValue,
    uint256 interactionNonce,
    uint64 auxData
  ) payable public returns (
    uint256 outputValueA,
    uint256 outputValueB,
    bool isAsync
  ) {
    require(msg.sender == rollupProcessor, "ExampleBridge: INVALID_CALLER");

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

    bytes32 commitment = bytes32(inputValue);
    uint256 decodedInputValue = uint256(auxData);

    require(
      msg.value == MINIMUM_DEPOSIT || msg.value == MAXIMUM_DEPOSIT,
      "AztecTornadoBridge: INSUFFICIENT_AMOUNT"
    );

    require(
      msg.value == decodedInputValue,
      "AztecTornadoBridge: AUX_AMOUNT_MISMATCH"
    );

    address anonymitySet = msg.value == MINIMUM_DEPOSIT ?
      TORNADO_1ETH : TORNADO_10ETH;
    bytes memory empty;

    tornadoRouter.deposit(
      ITornadoInstance(anonymitySet), commitment, empty
    );

    return(0, 0, false);
  }

}
