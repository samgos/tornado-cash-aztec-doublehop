import path from "path"
import { expect } from "chai"
import { ethers } from "ethers"

import genContract from "circomlib/src/mimcsponge_gencontract.js"
import buildGroth16 from "websnark/src/groth16"
import MerkleTree from "fixed-merkle-tree"

import { toFixedHex, perdersen, genProof, encodeParam, genCommitment } from "./utils.ts"

const withdrawVeriferArtifact = require("../out/WithdrawVerifier.sol/Verifier.json")
const resolverVerifierArtifact = require("../out/ResolveVerifier.sol/Verifier.json")
const resolverArtifact = require( "../out/AztecResolver.sol/AztecResolver.json")
const tornadoArtifact = require("../out/ETHTornado.sol/ETHTornado.json")
const rollupArtifact = require( "../out/RollupProcessor.sol/RollupProcessor.json")
const bridgeArtifact = require( "../out/AztecTornadoBridge.sol/AztecTornadoBridge.json")
const testArtifact = require( "../out/AztecTornadoBridge.t.sol/AztecTornadoBridgeTest.json")
const bridgeProxyArtifact = require("../out/DefiBridgeProxy.sol/DefiBridgeProxy.json")
const withdrawCircuit = require("../artifacts/circuits/withdraw.json")
const resolveCircuit = require("../artifacts/circuits/resolve.json")

const withdrawProvingKey = "./artifacts/zkeys/withdraw_proving_key.bin"
const resolverProvingKey = "./artifacts/zkeys/resolve_proving_key.bin"

const RPC_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
const RPC_ENDPOINT = "http://127.0.0.1:8545"

const destinationAddress = "0x0000000000000000000000000000000000000000"

async function deploy(artifact, signer, args) {
  const factory = new ethers.ContractFactory(
    artifact.abi, artifact.bytecode.object,
    signer
  )
  return await factory.deploy(...args)
}

describe("AztecTornadoBridge", () => {
  let tornadoInstances = [];
  let aztecTornadoBridge;
  let resolverVerifier;
  let withdrawVerifer;
  let commitmentTree;
  let rollupProcessor;
  let testContract;
  let resolver;
  let provider;
  let groth16;
  let hasher;
  let wallet;
  let secret;

  before(async() => {
    commitmentTree = new MerkleTree(16)
    groth16 = await buildGroth16()
    secret = genCommitment()

    provider = new ethers.providers.JsonRpcProvider(RPC_ENDPOINT);
    wallet = new ethers.Wallet(RPC_PRIVATE_KEY, provider);
  })

  it("Deployments", async() => {
    resolverVerifier = await deploy(resolverVerifierArtifact, wallet, []);
    withdrawVerifer = await deploy(withdrawVeriferArtifact, wallet, []);
    hasher = await deploy(
        { abi: genContract.abi,
          bytecode: {
            object: genContract.createCode("mimcsponge", 220)
          }
        }, wallet, []
    );

    tornadoInstances[2] = await deploy(
        tornadoArtifact, wallet, [
          hasher.address, withdrawVerifer.address,
          ethers.utils.parseEther("100.00"),
          toFixedHex(16, 2)
        ]
    );
    tornadoInstances[1] = await deploy(
        tornadoArtifact, wallet, [
          hasher.address, withdrawVerifer.address,
          ethers.utils.parseEther("10.00"),
          toFixedHex(16, 2)
        ]
    );
    tornadoInstances[0] = await deploy(
        tornadoArtifact, wallet, [
          hasher.address, withdrawVerifer.address,
          ethers.utils.parseEther("1.00"),
          toFixedHex(16, 2)
        ]
    );

    const bridgeProxy = await deploy(bridgeProxyArtifact, wallet, [])

    rollupProcessor = await deploy(
      rollupArtifact, wallet, [ bridgeProxy.address ]
    );

    aztecTornadoBridge = await deploy(
      bridgeArtifact, wallet, [
        tornadoInstances[2].address,
        tornadoInstances[1].address,
        tornadoInstances[0].address,
        rollupProcessor.address
      ]
    );

    resolver = await deploy(
      resolverArtifact, wallet, [
        rollupProcessor.address,
        resolverVerifier.address
      ]
    );

    testContract = await deploy(
      testArtifact, wallet, [
        aztecTornadoBridge.address,
        rollupProcessor.address,
        resolver.address
      ]
    );
  })

  it("Can deposit to tornado from L2", async() => {
    await testContract.testCaseOne(
      toFixedHex(secret.commitment), {
      from: wallet.address,
      gasLimit: 6000000,
    });

    commitmentTree.insert(secret.commitment);
  })

  it("Can withdraw from tornado to L2", async() => {
    const treeLength = commitmentTree.elements().length
    const currentRoot = commitmentTree.root()

    const withdrawalProof = await genProof(
      withdrawCircuit, {
        ...commitmentTree.path(treeLength - 1),
        ...secret,
        root: currentRoot,
        relayer: wallet.address,
        recipient: resolver.address
      },
      withdrawProvingKey,
      groth16
    )
    const resolverProof = await genProof(
      resolveCircuit, {
        ...secret,
        recipient: wallet.address
      },
      resolverProvingKey,
      groth16
    )

    await resolver.withdraw(
      [ withdrawalProof, resolverProof ],
      toFixedHex(0),
      toFixedHex(currentRoot),
      toFixedHex(secret.nullifierHash),
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

})
