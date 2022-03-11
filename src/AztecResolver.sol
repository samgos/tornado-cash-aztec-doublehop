pragma solidity >=0.6.10 <=0.8.10;

import "./interfaces/IRollupProcessor.sol";
import "./interfaces/ITornadoInstance.sol";
import "./interfaces/IVerifier.sol";

contract AztecResolver {

  IRollupProcessor aztecProcessor;
  IVerifier snarkVerifier;

  constructor(
    address rollupProcessor,
    address proofVerifier
  ) {
    aztecProcessor = IRollupProcessor(rollupProcessor);
    snarkVerifier = IVerifier(proofVerifier);
  }

  function withdraw(
    bytes[2] calldata proofs,
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
        proofs[1], [ uint256(nullifierHash), uint256(uint160(payee)) ]
      ), "Invalid resolver proof"
    );

    ITornadoInstance(instance).withdraw(
      proofs[0], root, nullifierHash, recipient, relayer, fee, refund
    );

    require(ITornadoInstance(instance).isSpent(nullifierHash));

    aztecProcessor.depositPendingFunds{ value: address(this).balance }(
      1, address(this).balance, payee, settlementProofHash
    );
  }

}
