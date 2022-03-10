import { exec } from "child_process"

import genContract from "circomlib/src/mimcsponge_gencontract.js"

import util from "util"
import fs from "fs"

const execute = util.promisify(exec)

function compileHasher() {
  fs.writeFileSync("Hasher.json", JSON.stringify({
     contractName: "Hasher",
     abi: genContract.abi,
     bytecode: {
       "object": genContract.createCode("mimcsponge", 220),
       sourceMap: "", // Necessary for forge to parse
     }
   })
  )
}

compileHasher()
