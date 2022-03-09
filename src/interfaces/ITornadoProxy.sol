pragma solidity >=0.8.4 <0.8.11;

import "@openzeppelin/contracts/v4/token/ERC20/IERC20.sol";
import "./ITornadoInstance.sol";

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
  ) external payable;

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
