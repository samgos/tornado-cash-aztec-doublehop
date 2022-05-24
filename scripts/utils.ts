import fs from "fs"

const withdrawCircuit = require("../artifacts/circuits/withdraw.json")

import { bigInt } from "snarkjs"
import { babyJub, pedersenHash } from "circomlib"
import { createHash, randomBytes } from "crypto"
import { stringifyBigInts } from "websnark/tools/stringifybigint"
import websnarkUtils from "websnark/src/utils"

export const rbigInt = (n: number) => bigInt.leBuff2int(randomBytes(n))
export const perdersen = (e: Buffer) => babyJub.unpackPoint(pedersenHash.hash(e))[0]
export const toFixedHex = (number:any, length = 32) =>
  '0x' +
  bigInt(number)
    .toString(16)
    .padStart(length * 2, '0')

export const encodeParam = (dataType: any, data: any) => {
  const abiCoder = ethers.utils.defaultAbiCoder
  return abiCoder.encode(dataType, data)
}

export function genCommitment() {
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

export async function genProof(
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
