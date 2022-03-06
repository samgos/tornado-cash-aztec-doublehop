pragma solidity >=0.8.4 <0.8.11;

import "@openzeppelin/contracts/v4/token/ERC20/IERC20.sol";

interface ITornadoInstance {
  function token() external view returns (address);

  function denomination() external view returns (uint256);

  function deposit(bytes32 commitment) external payable;

  function isSpent(bytes32 _nullifierHash) external view returns (bool);

  function withdraw(
    bytes calldata proof,
    bytes32 root,
    bytes32 nullifierHash,
    address payable recipient,
    address payable relayer,
    uint256 fee,
    uint256 refund
  ) external payable;
}

interface ITornadoProxy {

  enum InstanceState { DISABLED, ENABLED, MINEABLE }

  struct Instance {
    bool isERC20;
    IERC20 token;
    InstanceState state;
   }

  struct Tornado {
    ITornadoInstance addr;
    Instance instance;
   }

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
