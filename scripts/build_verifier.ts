import { exec } from "child_process"

import fs from "fs"
import util from "util"
import path from "path"

const inputPath = path.join(__dirname, "..", "artifacts/circuits/")
const execute = util.promisify(exec)

async function buildVerifier() {
  const directory = await fs.promises.opendir(inputPath)

  for await(const circuit of directory) {
    const name = circuit.name.replace(".r1cs", "")

    if(circuit.name.includes(".r1cs")) {
      await execute(`zkutil setup --circuit ${inputPath + circuit.name}`)
      await execute(`zkutil generate-verifier && mv Verifier.sol src/${name}Verifier.sol`)
      await execute(`zkutil export-keys --circuit ${inputPath + circuit.name}`)
      await execute(`mv verification_key.json src/zk/${name}_verification_key.json`)
      await execute(`mv proving_key.json src/zk/${name}_proving_key.json`)
    }
  }

}

buildVerifier()
