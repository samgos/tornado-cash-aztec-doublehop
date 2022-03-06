import { exec } from "child_process"

import path from "path"
import util from "util"
import fs from "fs"

import genContract from "circomlib/src/mimcsponge_gencontract.js"

const outputPath = path.join(__dirname, "..", "out/Hasher.sol", "Hasher.json")
const execute = util.promisify(exec)

async function compileHasher() {
  const contract = {
    contractName: "Hasher",
    abi: genContract.abi,
    bytecode: genContract.createCode("mimcsponge", 220),
  }

  await execute("mkdir out && mkdir out/Hasher.sol")
  fs.writeFileSync(outputPath, JSON.stringify(contract))
}

compileHasher()
