pragma solidity 0.8.0;

import "./interfaces/IRollupProcessor.sol";
import "./interfaces/ITornadoProxy.sol";
import "./interfaces/IVerifier.sol";

contract AztecResolver {

  IRollupProcessor aztecProcessor;
  ITornadoProxy torandoRouter;
  IVerifier snarkVerifier;

  address public immutable operator;

  constructor(
    address rollupProcessor,
    address governanceOperator,
    address proofVerifier,
    address tornadoProxy,
  ) {
    aztecProcessor = IRollupProcessor(rollupProcessor);
    tornadoRouter = ITornadoProxy(tornadoProxy);
    snarkVerifier = IVerifier(proofVerifier);
    operator = governanceOperator;
  }

  function configureProcessor(address rollupProcessor) public {
    require(msg.sender == governanceOperator);

    aztecProcessor = IRollupProcessor(rollupProcessor);
  }

  function withdraw(
    bytes calldata withdrawalProof,
    bytes calldata resolverProof,
    bytes calldata settlementProof,
    bytes32 root,
    bytes32 nullifierHash,
    address payable recipient,
    address payable relayer,
    address payable payee,
    uint256 fee,
    uint256 refund
  ) public {
    require(recipient == address(this) && payee != address(0x0));
    require(!tornadoRouter.isSpent(nullifierHash));
    require(
      snarkVerifier.verifyProof(
        resolveProof, [ uint256(nullifierHash), uint256(payee) ]
      ), "Invalid resolution proof"
    );

    torandoRouter.withdraw(
      withdrawalProof, root, nullifierHash, recipient, relayer, fee, refund
    );

    require(tornadoRouter.isSpent(nullifierHash));

    aztecProcessor.makePendingDeposit(
      0, address(this).balance, payee, settlementProof
    );
  }

}
