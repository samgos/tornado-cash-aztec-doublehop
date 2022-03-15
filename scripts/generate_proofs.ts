import fs from "fs"
import path from "path"
import rlp from "rlp"

import websnarkUtils from "websnark/src/utils"
import buildGroth16 from "websnark/src/groth16"
import MerkleTree from "fixed-merkle-tree"

import { ethers } from "ethers"
import { bigInt } from "snarkjs"
import { babyJub, pedersenHash } from "circomlib"
import { createHash, randomBytes } from "crypto"
import { stringifyBigInts } from "websnark/tools/stringifybigint"

const resolverArtifact = require( "../out/AztecResolver.sol/AztecResolver.json")
const tornadoArtifact = require("../out/ETHTornado.sol/ETHTornado.json")

const resolverCircuit = require("../artifacts/circuits/resolve.json")
const withdrawCircuit = require("../artifacts/circuits/withdraw.json")

const withdrawProvingKey = "./artifacts/zkeys/withdraw_proving_key.bin"
const resolverProvingKey = "./artifacts/zkeys/resolve_proving_key.bin"

const deploymentAddress = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57"
const defaultRelayer = "0x627306090abaB3A6e1400e9345bC60c78a8BEf57"
const destinationAddress = "0x000000000000000000000000000000000000"
const deploymentSalts = [
  "0x999", "0x666", "0x333", "0x111"
]

const rbigInt = (n: number) => bigInt.leBuff2int(randomBytes(n))
const perdersen = (e: Buffer) => babyJub.unpackPoint(pedersenHash.hash(e))[0]

function generateCreate2Address(
  issuingAddress: string,
  salt: string,
  bytecode: string
): string {
  return `0x${createHash("sha3-256")
    .update(
      `0x${[
          "ff",
          issuingAddress,
          salt,
          ethers.utils.keccak256(bytecode)
        ].map((x) => x.replace(/0x/, ""))
     .join("")}`
    )
    .digest('hex').slice(-40)}`
    .toLowerCase()
}

function generateFactoryAddress(
  issuingAddress: string,
  nonce: number
): string {
  const rlpCipher = rlp.encode([ issuingAddress, nonce ])
  const rawAddress = ethers.utils.keccak256(rlpCipher)

  return `0x${rawAddress.slice(-40).toLowerCase()}`
}

function generateCommitment() {
  const nullifier = rbigInt(31)
  const secret = rbigInt(31)
  const buffer = Buffer.concat([
      nullifier.leInt2Buff(31),
      secret.leInt2Buff(31)
  ])

  const nullifierHash = perdersen(
    nullifier.leInt2Buff(31)
  )
  const commitment = perdersen(
    buffer
  )

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

  const fee = "0x000"
  const refund = fee

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

  return websnarkUtils.toSolidityInput(e).proof
}

async function generateProofsAndAddresses() {
  const groth16 = await buildGroth16()
  const factoryAddress = generateFactoryAddress(deploymentAddress, 0)

  const contractArtifacts = new Array(3).fill(tornadoArtifact)
  const contractTrees = new Array(3).fill(new MerkleTree(16))
  const contractParameters = []
  const contractAddresses = []

  const resolverAddress = generateCreate2Address(
      factoryAddress,
      deploymentSalts[3],
      resolverArtifact.bytecode.object
  )

  for(var x = 0; x < contractArtifacts.length; x++){
    contractAddresses[x] = generateCreate2Address(
        factoryAddress,
        deploymentSalts[x],
        contractArtifacts[x].bytecode.object
    )
    contractParameters[x] = {
      hop: generateCommitment(),
      withdrawal: generateCommitment(),
      proofs: []
    }

    contractTrees[x]
    .insert(contractParameters[x].hop.commitment)

    const treeLength = contractTrees[x].elements().length
    const resolverRoot = contractTrees[x].root()

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
    const withdrawalRoot = contractTrees[x].root()

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

  splitContent[41] = " " + splitContent[41].slice(
    0, splitContent[41].length - 2
  ) + `${addresses[0]},`
  splitContent[42] = " " + splitContent[42].slice(
    0, splitContent[42].length - 2
  ) + `${addresses[1]},`
  splitContent[43] = " " + splitContent[43].slice(
    0, splitContent[43].length - 2
  ) + `${addresses[2]},`
  splitContent[44] = " " + splitContent[44].slice(
    0, splitContent[44].length - 2
  ) + `${addresses[3]}`

  splitContent[70] = " " + splitContent[70].slice(
    0, splitContent[70].length - 2
  ) + `${parameters[0].hop.nullifierHash}",`
  splitContent[71] = " " + splitContent[71].slice(
    0, splitContent[71].length - 2
  ) + `${parameters[0].withdrawal.nullifierHash}",`
  splitContent[72] = " " + splitContent[72].slice(
    0, splitContent[72].length - 2
  ) + `${parameters[0].resolverRoot}",`
  splitContent[73] = " " + splitContent[73].slice(
    0, splitContent[73].length - 2
  ) + `${parameters[0].withdrawalRoot}",`
  splitContent[75] = " " + splitContent[75].slice(
    0, splitContent[75].length - 2
  ) + `${parameters[0].proofs[0]}",`
  splitContent[76] = " " + splitContent[76].slice(
    0, splitContent[76].length - 2
  ) + `${parameters[0].proofs[1]}",`
  splitContent[76] = " " + splitContent[76].slice(
    0, splitContent[76].length - 2
  ) + `${parameters[0].proofs[2]}",`
  splitContent[77] = " " + splitContent[77].slice(
    0, splitContent[77].length - 2
  ) + `${parameters[0].proofs[3]}",`

  fs.writeFileSync(targetPath, splitContent.join('\n'))

  console.log('Contract formatted!')
}

async function encodeParametersToContract(){
  const [ addresses, params ] = await generateProofsAndAddresses()

  formatContractParameters(addresses, params)
}

encodeParametersToContract()
