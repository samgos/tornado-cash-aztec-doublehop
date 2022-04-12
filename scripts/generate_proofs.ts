import fs from "fs"
import path from "path"
import rlp from "rlp"
import web3 from "web3"

import websnarkUtils from "websnark/src/utils"
import buildGroth16 from "websnark/src/groth16"
import MerkleTree from "fixed-merkle-tree"

import { ethers } from "ethers"
import { bigInt } from "snarkjs"
import { babyJub, pedersenHash } from "circomlib"
import { createHash, randomBytes } from "crypto"
import { stringifyBigInts } from "websnark/tools/stringifybigint"

const resolverArtifact = require( "../out/AztecResolver.sol/AztecResolver.json")
const verifierArtifact = require("../out/WithdrawVerifier.sol/Verifier.json")
const tornadoArtifact = require("../out/ETHTornado.sol/ETHTornado.json")
const hasherArtifact = require("../Hasher.json")

const resolverCircuit = require("../artifacts/circuits/resolve.json")
const withdrawCircuit = require("../artifacts/circuits/withdraw.json")

const withdrawProvingKey = "./artifacts/zkeys/withdraw_proving_key.bin"
const resolverProvingKey = "./artifacts/zkeys/resolve_proving_key.bin"

const resolverVerifierAddress = "0x22029e89e1d1f79d8e57c9af2fb9bf653bdf4be1"
const deploymentAddress = "0xf12b5dd4ead5f743c6baa640b0216200e89b60da"
const rollupAddress = "0x0ebe109b4ac5de65d63f7d7e5a856dcd77dc58fd"

const defaultRelayer = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57"
const destinationAddress = "0x000000000000000000000000000000000000"
const deploymentSalts = [
  999999,
  666666,
  333333,
  101010,
  111000,
  100000
];

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

function generateCreate2Address(
  salt: number,
  bytecode: string,
  types: Array<string> = [],
  args: Array<string> = []
): string {
  return ethers.utils.getCreate2Address(
    deploymentAddress,
    toFixedHex(salt),
    ethers.utils.keccak256(
      args.length == 0 ? bytecode :
      `${bytecode}${encodeParam(types, args).slice(2)}`
    )
  )
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

async function generateProofsAndAddresses() {
  const groth16 = await buildGroth16()
  const contractArtifacts = new Array(3).fill(tornadoArtifact)
  const contractDenominations = [ "100.00", "10.00", "1.00" ]
  const contractTrees = new Array(3).fill(new MerkleTree(16))
  const contractParameters = []
  const contractAddresses = []

  const tornadoVerifierAddress = generateCreate2Address(
      deploymentSalts[4],
      verifierArtifact.bytecode.object
  )
  const resolverAddress = generateCreate2Address(
      deploymentSalts[3],
      resolverArtifact.bytecode.object,
      [ "address", "address" ],
      [
        ethers.utils.getAddress(rollupAddress),
        ethers.utils.getAddress(resolverVerifierAddress)
     ]
  )
  const hasherAddress = generateCreate2Address(
      deploymentSalts[5],
      hasherArtifact.bytecode.object
  )

  for(var x = 0; x < contractArtifacts.length; x++){
    contractAddresses[x] = generateCreate2Address(
        deploymentSalts[x],
        contractArtifacts[x].bytecode.object,
        [ "address", "address", "uint256", "uint32" ],
        [
          ethers.utils.getAddress(tornadoVerifierAddress),
          ethers.utils.getAddress(hasherAddress),
          ethers.utils.parseEther(contractDenominations[x]),
          toFixedHex(16, 16)
       ]
    )
    contractParameters[x] = {
      hop: generateCommitment(),
      withdrawal: generateCommitment(),
      proofs: []
    }

    contractTrees[x]
    .insert(contractParameters[x].hop.commitment)

    const treeLength = contractTrees[x].elements().length
    const resolverRoot = toFixedHex(contractTrees[x].root())

    contractParameters[x] = {
      resolverRoot,
      ...contractParameters[x],
      proofs: [
        await generateProof(
          withdrawCircuit,
          {
            ...contractTrees[x].path(treeLength - 1),
            ...contractParameters[x].hop,
            root: resolverRoot,
            relayer: defaultRelayer,
            recipient: resolverAddress
          },
          withdrawProvingKey,
          groth16
        ),
        await generateProof(
          resolverCircuit,
          {
            ...contractParameters[x].hop,
            recipient: destinationAddress
          },
          resolverProvingKey,
          groth16
        ),
        "0x0", // TODO: Aztec settlement proof,
        "0x0" // withdrawal proof
      ]
    }

    contractTrees[x]
    .insert(contractParameters[x].withdrawal.commitment)
    const withdrawalRoot = toFixedHex(contractTrees[x].root())

    contractParameters[x] = {
      withdrawalRoot,
      ...contractParameters[x]
    }

    contractParameters[x].proofs[3] = await generateProof(
      withdrawCircuit,
      {
        ...contractTrees[x].path(treeLength),
        ...contractParameters[x].withdrawal,
        root: withdrawalRoot,
        relayer: defaultRelayer,
        recipient: destinationAddress
      },
      withdrawProvingKey,
      groth16
    )
  }

  contractAddresses.push(resolverAddress)
  contractAddresses.push(tornadoVerifierAddress)
  contractAddresses.push(hasherAddress)

  return [
    contractAddresses, contractParameters
  ]
}

async function formatContractParameters(
  addresses: any, parameters: any
) {
  const targetPath = "./src/test/AztecTornadoBridge.t.sol"
  const solFileContents = fs.readFileSync(targetPath, "utf8")
  const splitContent = solFileContents.split('\n')

  splitContent[36] = " " + splitContent[36].slice(
    0, splitContent[36].length - 2
  ) + `${ethers.utils.getAddress(addresses[0])},`
  splitContent[37] = " " + splitContent[37].slice(
    0, splitContent[37].length - 2
  ) + `${ethers.utils.getAddress(addresses[1])},`
  splitContent[38] = " " + splitContent[38].slice(
    0, splitContent[38].length - 2
  ) + `${ethers.utils.getAddress(addresses[2])},`
  splitContent[39] = " " + splitContent[39].slice(
    0, splitContent[39].length - 2
  ) + `${ethers.utils.getAddress(addresses[3])},`
  splitContent[40] = " " + splitContent[40].slice(
    0, splitContent[40].length - 2
  ) + `${ethers.utils.getAddress(addresses[4])},`
  splitContent[41] = " " + splitContent[35].slice(
    0, splitContent[41].length - 2
  ) + `${ethers.utils.getAddress(addresses[5])}`

  splitContent[67] = " " + splitContent[67].slice(
    0, splitContent[67].length - 2
  ).replace('"', '')  + `${toFixedHex(parameters[0].hop.nullifierHash)},`
  splitContent[68] = " " + splitContent[68].slice(
    0, splitContent[68].length - 2
  ).replace('"', '')  + `${toFixedHex(parameters[0].withdrawal.nullifierHash)},`
  splitContent[69] = " " + splitContent[69].slice(
    0, splitContent[69].length - 2
  ).replace('"', '')  + `${parameters[0].resolverRoot},`
  splitContent[70] = " " + splitContent[70].slice(
    0, splitContent[70].length - 2
  ).replace('"', '') + `${parameters[0].withdrawalRoot},`

  splitContent[72] = " " + splitContent[72].slice(
    0, splitContent[72].length - 2
  ) + `${parameters[0].proofs[0]}",`
  splitContent[73] = " " + splitContent[73].slice(
    0, splitContent[73].length - 2
  ) + `${parameters[0].proofs[1]}",`
  splitContent[74] = " " + splitContent[74].slice(
    0, splitContent[74].length - 2
  ) + `${parameters[0].proofs[2]}",`
  splitContent[75] = " " + splitContent[75].slice(
    0, splitContent[75].length - 1
  ) + `${parameters[0].proofs[3]}"`

  fs.writeFileSync(targetPath, splitContent.join('\n'))

  console.log('Contract formatted!')
}

async function encodeParametersToContract(){
  const [ addresses, params ] = await generateProofsAndAddresses()

  formatContractParameters(addresses, params)
}

encodeParametersToContract()
