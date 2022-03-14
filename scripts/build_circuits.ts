import { exec } from "child_process"

import path from "path"
import util from "util"
import fs from "fs"

const outputPath = path.join(__dirname, "..", "artifacts/circuits/")
const inputPath = path.join(__dirname, "..", "circuits/")

const execute = util.promisify(exec)

async function buildCircuits() {
  const directory = await fs.promises.opendir(inputPath)

  await execute("mkdir artifacts")
  await execute(`mkdir ${outputPath}`)

  for await(const circuit of directory) {
    const target = inputPath + circuit.name
    const name = circuit.name.replace(".circom", "")
    const motherboard = fs.readFileSync(target).toString()
    const shouldCompile = motherboard.includes("component main")

    if(shouldCompile) {
      await execute(
        `circom -v -f ${inputPath + circuit.name} `
        + `-o ${outputPath + name}.json `
      )
    }
  }
}

buildCircuits()
