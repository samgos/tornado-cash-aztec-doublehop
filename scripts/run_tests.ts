import { expect } from "chai"
import { ethers } from "ethers"
import { bigInt } from "snarkjs"

import genContract from "circomlib/src/mimcsponge_gencontract.js"
import buildGroth16 from "websnark/src/groth16"
import MerkleTree from "fixed-merkle-tree"

import { toFixedHex, perdersen, genProof, encodeParam, genCommitment } from "./utils.ts"

import {
  PATH_RESOLVER_PROVING_KEY, PATH_RESOLVER, PATH_RESOLVER_CIRCUIT, PATH_RESOLVER_VERIFIER,
  PATH_WITHDRAW_PROVING_KEY, PATH_WITHDRAW_CIRCUIT, PATH_WITHDRAW_VERIFIER,
  PATH_BRIDGE_IMPL, PATH_BRIDGE_TEST, PATH_BRIDGE_PROXY,
  PATH_ROLLUP_PROCESSOR, PATH_TORNADO_INSTANCE,
  RPC_ENDPOINT, RPC_PRIVATE_KEY,
  ZERO_ADDRESS
} from "./constants.ts"


async function deploy(artifact, signer, args) {
  const factory = new ethers.ContractFactory(
    artifact.abi, artifact.bytecode.object,
    signer
  )
  return await factory.deploy(...args)
}

describe("AztecTornadoBridge", () => {
  let tornadoInstances = [ "1.00", "10.00", "100.00" ];
  let aztecTornadoBridge;
  let commitmentTree;
  let testContract;
  let resolver;
  let provider;
  let groth16;
  let wallet;
  let confidental;

  before(async() => {
    confidental = genCommitment()
    groth16 = await buildGroth16()
    commitmentTree = new MerkleTree(16)

    provider = new ethers.providers.JsonRpcProvider(RPC_ENDPOINT)
    wallet = new ethers.Wallet(RPC_PRIVATE_KEY, provider)
  })

  it("Deployments", async() => {
    const resolverVerifier = await deploy(PATH_RESOLVER_VERIFIER, wallet, [])
    const withdrawVerifer = await deploy(PATH_WITHDRAW_VERIFIER, wallet, [])
    const hasher = await deploy(
        { abi: genContract.abi,
          bytecode: {
            object: genContract.createCode("mimcsponge", 220)
          }
        }, wallet, []
    )

    const bridgeProxy = await deploy(PATH_BRIDGE_PROXY, wallet, [])
    const rollupProcessor = await deploy(
      PATH_ROLLUP_PROCESSOR, wallet, [ bridgeProxy.address ]
    );

    for(var x = 0; x < tornadoInstances.length; x++) {
      tornadoInstances[x] = await deploy(
        PATH_TORNADO_INSTANCE, wallet, [
          hasher.address, withdrawVerifer.address,
          ethers.utils.parseEther(tornadoInstances[x]),
          toFixedHex(16, 2)
        ]
      )
    }

    aztecTornadoBridge = await deploy(
      PATH_BRIDGE_IMPL, wallet, [
        tornadoInstances[2].address,
        tornadoInstances[1].address,
        tornadoInstances[0].address,
        rollupProcessor.address
      ]
    );

    resolver = await deploy(
      PATH_RESOLVER, wallet, [
        rollupProcessor.address,
        resolverVerifier.address
      ]
    );

    testContract = await deploy(
      PATH_BRIDGE_TEST, wallet, [
        aztecTornadoBridge.address,
        rollupProcessor.address,
        resolver.address
      ]
    );
  })

  it("Can deposit to tornado from L2", async() => {
    await testContract.testDeposit(
      toFixedHex(confidental.commitment),
      toFixedHex(1),
      ethers.utils.parseEther("1.00"), {
        from: wallet.address,
        gasLimit: 6000000,
    });

    commitmentTree.insert(confidental.commitment);
  })

  it("Can withdraw from tornado to L2", async() => {
    const treeLength = commitmentTree.elements().length
    const currentRoot = commitmentTree.root()

    const withdrawalProof = await genProof(
      PATH_WITHDRAW_CIRCUIT, {
        ...commitmentTree.path(treeLength - 1),
        nullifierHash: confidental.nullifierHash,
        nullifier: confidental.nullifier,
        secret: confidental.secret,
        relayer: wallet.address,
        recipient: resolver.address,
        root: currentRoot,
        refund: bigInt(0),
        fee: bigInt(1e17)
      },
      PATH_WITHDRAW_PROVING_KEY,
      groth16
    )
    const resolverProof = await genProof(
      PATH_RESOLVER_CIRCUIT, {
        nullifierHash: confidental.nullifierHash,
        nullifier: confidental.nullifier,
        secret: confidental.secret,
        withdrawalAddress: wallet.address
      },
      PATH_RESOLVER_PROVING_KEY,
      groth16
    )

    await resolver.withdraw(
      [ withdrawalProof, resolverProof ],
      toFixedHex(0),
      toFixedHex(currentRoot),
      toFixedHex(confidental.nullifierHash),
      toFixedHex(resolver.address, 20),
      toFixedHex(wallet.address, 20),
      toFixedHex(destinationAddress, 20),
      toFixedHex(tornadoInstances[0].address, 20),
      ethers.utils.parseEther("0.01"),
      ethers.utils.parseEther("0.00"), {
        from: wallet.address,
        gasLimit: 6000000,
      })
  })

  it('should throw on spent nullifierHashes', async() => {})

  it('should throw on spent nonces', async() => { })

  it('should throw on address tampering', async() => { })

})
