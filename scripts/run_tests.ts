import fs from "fs"
import path from "path"
import { expect } from "chai"

import genContract from "circomlib/src/mimcsponge_gencontract.js"
import websnarkUtils from "websnark/src/utils"
import buildGroth16 from "websnark/src/groth16"
import MerkleTree from "fixed-merkle-tree"

import { ethers } from "ethers"
import { bigInt } from "snarkjs"
import { babyJub, pedersenHash } from "circomlib"
import { createHash, randomBytes } from "crypto"
import { stringifyBigInts } from "websnark/tools/stringifybigint"

const withdrawVeriferArtifact = require("../out/WithdrawVerifier.sol/Verifier.json")
const resolverVerifierArtifact = require("../out/ResolveVerifier.sol/Verifier.json")
const resolverArtifact = require( "../out/AztecResolver.sol/AztecResolver.json")
const tornadoArtifact = require("../out/ETHTornado.sol/ETHTornado.json")
const rollupArtifact = require( "../out/RollupProcessor.sol/RollupProcessor.json")
const bridgeArtifact = require( "../out/AztecTornadoBridge.sol/AztecTornadoBridge.json")
const bridgeProxyArtifact = require("../out/DefiBridgeProxy.sol/DefiBridgeProxy.json")
const withdrawCircuit = require("../artifacts/circuits/withdraw.json")

const withdrawProvingKey = "./artifacts/zkeys/withdraw_proving_key.bin"
const resolverProvingKey = "./artifacts/zkeys/resolve_proving_key.bin"

const RPC_PRIVATE_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
const RPC_ENDPOINT = "http://127.0.0.1:8545"

const defaultRelayer = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57"
const destinationAddress = "0x000000000000000000000000000000000000"

const rbigInt = (n: number) => bigInt.leBuff2int(randomBytes(n))
const perdersen = (e: Buffer) => babyJub.unpackPoint(pedersenHash.hash(e))[0]
const toFixedHex = (number:any, length = 32) =>
  '0x' +
  bigInt(number)
    .toString(16)
    .padStart(length * 2, '0')

const encodeParam = (dataType: any, data: any) => {
  const abiCoder = ethers.utils.defaultAbiCoder
  return abiCoder.encode(dataType, data)
}

function generateCommitment() {
  const [ nullifier, secret ]  = [ rbigInt(31), rbigInt(31) ]
  const buffer = Buffer.concat([
      nullifier.leInt2Buff(31), secret.leInt2Buff(31)
  ])
  const nullifierHash = perdersen(nullifier.leInt2Buff(31))
  const commitment = perdersen(buffer)

  return {
    nullifierHash,
    commitment,
    nullifier,
    secret
  }
}

async function generateProof(
  circuit: any,
  input: any,
  proving_key: any,
  groth: any
) {
  const {
    nullifierHash, secret, nullifier, recipient
  } = input
  proving_key = fs.readFileSync(proving_key).buffer

  let formattedInputs

  if(circuit == withdrawCircuit) {
    formattedInputs = stringifyBigInts({
      pathElements: input.pathElements,
      pathIndices: input.pathIndices,
      relayer: input.relayer,
      root: input.root,
      refund: bigInt(0),
      fee: bigInt(1e17),
      nullifierHash,
      recipient,
      nullifier,
      secret
    })
  } else {
    formattedInputs = stringifyBigInts({
      withdrawalAddress: recipient,
      nullifierHash,
      nullifier,
      secret
    })
  }

  const e = await websnarkUtils.genWitnessAndProve(
    groth, formattedInputs, circuit, proving_key
  )

  return toFixedHex(websnarkUtils.toSolidityInput(e).proof)
}

async function createAndDeploy(abi, bytecode, signer, args) {
  const factory = new ethers.ContractFactory(abi, bytecode, signer);
  return await factory.deploy(...args)
}

describe("AztecTornadoBridge", () => {
  let tornadoInstances = [];
  let aztecTornadoBridge;
  let resolverVerifier;
  let withdrawVerifer;
  let rollupProcessor;
  let resolver;
  let provider;
  let hasher;
  let wallet;

  before(() => {
    provider = new ethers.providers.JsonRpcProvider(RPC_ENDPOINT);
    wallet = new ethers.Wallet(RPC_PRIVATE_KEY, provider);
  })

  it("Deployments", async() => {
    resolverVerifier = await createAndDeploy(
      resolverVerifierArtifact.abi,
      resolverVerifierArtifact.bytecode.object,
      wallet, []
    );
    withdrawVerifer = await createAndDeploy(
      withdrawVeriferArtifact.abi,
      withdrawVeriferArtifact.bytecode.object,
      wallet, []
    );
    hasher = await createAndDeploy(
        genContract.abi,
        genContract.createCode("mimcsponge", 220),
        wallet, []
    );

    tornadoInstances[2] = await createAndDeploy(
        tornadoArtifact.abi,
        tornadoArtifact.bytecode.object,
        wallet, [
          hasher.address,
          withdrawVerifer.address,
          ethers.utils.parseEther("100.00"),
          toFixedHex(16, 2)
        ]
    );

    tornadoInstances[1] = await createAndDeploy(
        tornadoArtifact.abi,
        tornadoArtifact.bytecode.object,
        wallet, [
          hasher.address,
          withdrawVerifer.address,
          ethers.utils.parseEther("10.00"),
          toFixedHex(16, 2)
        ]
    );

    tornadoInstances[0] = await createAndDeploy(
        tornadoArtifact.abi,
        tornadoArtifact.bytecode.object,
        wallet, [
          hasher.address,
          withdrawVerifer.address,
          ethers.utils.parseEther("1.00"),
          toFixedHex(16, 2)
        ]
    );

    const bridgeProxy = await createAndDeploy(
      bridgeProxyArtifact.abi,
      bridgeProxyArtifact.bytecode.object, wallet, []
    )

    rollupProcessor = await createAndDeploy(
      rollupArtifact.abi,
      rollupArtifact.bytecode.object, wallet, [
        bridgeProxy.address
      ]
    );

    aztecTornadoBridge = await createAndDeploy(
      bridgeArtifact.abi,
      bridgeArtifact.bytecode.object,
      wallet, [
        tornadoInstances[2].address,
        tornadoInstances[1].address,
        tornadoInstances[0].address,
        rollupProcessor.address
      ]
    );

    resolver = await createAndDeploy(
      resolverArtifact.abi,
      resolverArtifact.bytecode.object,
      wallet, [
        rollupProcessor.address,
        resolverVerifier.address
      ]
    );

  })

})
