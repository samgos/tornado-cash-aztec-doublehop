pragma solidity 0.8.0;

import "./interfaces/IRollupProcessor.sol";
import "./interfaces/ITornadoProxy.sol";

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
    bytes calldata _withdrawProof,
    bytes calldata _resolveProof,
    bytes calldata _settlementProof,
    bytes32 _root,
    bytes32 _nullifierHash,
    address payable _recipient,
    address payable _relayer,
    address payable _payee,
    uint256 _fee,
    uint256 _refund
  ) public {
    require(_recipient == address(this) && _payee != address(0x0));
    require(!tornadoRouter.isSpent(_nullifierHash));
    require(
      snarkVerifier.verifyProof(
        _resolveProof, [ uint256(_nullifierHash), uint256(_payee) ]
      ), "Invalid resolution proof"
    );

    torandoRouter.withdraw(
      _withdrawProof, _root, _nullifierHash, _recipient, _relayer, _fee, _refund
    );

    require(tornadoRouter.isSpent(_nullifierHash));

    aztecProcessor.makePendingDeposit(
      0, address(this).balance, _payee, _settlementProof
    );
  }

}
