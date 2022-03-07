import { exec } from "child_process"

import fs from "fs"
import util from "util"
import path from "path"

const inputPath = path.join(__dirname, "..", "artifacts/circuits/")
const outputPath = path.join(__dirname, "..", "src/zkeys/")
const execute = util.promisify(exec)

async function buildVerifier() {
  const directory = await fs.promises.opendir(inputPath)

  await execute(`mkdir ${outputPath}`)

  for await(const circuit of directory) {
    const name = circuit.name.replace(".r1cs", "")
    const format = name.replace(/^\w/, (c) => c.toUpperCase())

    if(circuit.name.includes(".r1cs")) {
      await execute(`zkutil setup --circuit ${inputPath + circuit.name}`)
      await execute(`zkutil generate-verifier && mv Verifier.sol src/${format}Verifier.sol`)
      await execute(`zkutil export-keys --circuit ${inputPath + circuit.name}`)
      await execute(`mv verification_key.json ${outputPath + name}_verification_key.json`)
      await execute(`mv proving_key.json ${outputPath + name}_proving_key.json`)
    }
  }

}

buildVerifier()
