import fs from "fs"

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
  provingKeyPath: any,
  groth: any
) {
  const proving_key = fs.readFileSync(provingKeyPath).buffer
  const formattedInputs = stringifyBigInts(input)
  const e = await websnarkUtils.genWitnessAndProve(
    groth, formattedInputs, circuit, proving_key
  )

  return toFixedHex(websnarkUtils.toSolidityInput(e).proof)
}
