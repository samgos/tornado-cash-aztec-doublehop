pragma solidity >=0.8.4 <0.8.11;

interface IVerifier {
  function verifyProof(bytes memory _proof, uint256[6] memory _input) external returns (bool);
}
