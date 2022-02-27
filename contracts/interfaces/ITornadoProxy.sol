pragma solidity 0.8.0;

interface ITornadoProxy {

  function deposit(
    ITornadoInstance _tornado,
    bytes32 _commitment,
    bytes calldata _encryptedNote
  ) external;

  function withdraw(
    ITornadoInstance _tornado,
    bytes calldata _proof,
    bytes32 _root,
    bytes32 _nullifierHash,
    address payable _recipient,
    address payable _relayer,
    uint256 _fee,
    uint256 _refund
  ) external;

}
