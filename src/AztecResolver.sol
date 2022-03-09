pragma solidity >=0.6.10 <=0.8.10;

import "./interfaces/IRollupProcessor.sol";
import "./interfaces/ITornadoProxy.sol";
import "./interfaces/IVerifier.sol";

contract AztecResolver {

  IRollupProcessor aztecProcessor;
  ITornadoProxy tornadoRouter;
  IVerifier snarkVerifier;

  address public immutable operator;

  constructor(
    address rollupProcessor,
    address governanceOperator,
    address proofVerifier,
    address tornadoProxy
  ) {
    aztecProcessor = IRollupProcessor(rollupProcessor);
    tornadoRouter = ITornadoProxy(tornadoProxy);
    snarkVerifier = IVerifier(proofVerifier);
    operator = governanceOperator;
  }

  function configureProcessor(address rollupProcessor) public {
    require(msg.sender == operator);

    aztecProcessor = IRollupProcessor(rollupProcessor);
  }

  function withdraw(
    bytes calldata withdrawalProof,
    bytes calldata resolverProof,
    bytes32 settlementProofHash,
    bytes32 root,
    bytes32 nullifierHash,
    address payable recipient,
    address payable relayer,
    address payee,
    address instance,
    uint256 fee,
    uint256 refund
  ) public {
    require(recipient == address(this) && payee != address(0x0));
    require(!ITornadoInstance(instance).isSpent(nullifierHash));
    require(
      snarkVerifier.verifyProof(
        resolverProof, [ uint256(nullifierHash), uint256(uint160(payee)) ]
      ), "Invalid resolver proof"
    );

    ITornadoInstance(instance).withdraw(
      withdrawalProof, root, nullifierHash, recipient, relayer, fee, refund
    );

    require(ITornadoInstance(instance).isSpent(nullifierHash));

    aztecProcessor.depositPendingFunds{ value: address(this).balance }(
      0, address(this).balance, payee, settlementProofHash
    );
  }

}
