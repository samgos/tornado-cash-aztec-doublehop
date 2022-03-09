import { exec } from "child_process"

import { ethers } from "ethers"
import ganache from "ganache"

import path from "path"
import util from "util"
import fs from "fs"

import genContract from "circomlib/src/mimcsponge_gencontract.js"

const contractName = "AztecTornadoBridgeTest"
const targetName = contractName

const inputTarget = path.join(__dirname, "..", "src/test", `${targetName}.t.sol:${targetName}`)
const outputTarget = path.join(__dirname, "..",  `out/${targetName}.t.sol/${targetName}.json`)

const execute = util.promisify(exec)
const server = ganache.server({})
const port = 6666

const default_mnemonic = "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat"
const rpcEndpoint = `http://127.0.0.1:${port}`

async function startServer() {
  await execute(`ganache --port ${port} --wallet.mnemonic "${default_mnemonic}"`)
}

async function executeAndDeploy() {
  await Promise.all([
      startServer(), deployTestSuites()
  ])
}

async function deployTestSuites() {
  const provider = new ethers.providers.JsonRpcProvider(rpcEndpoint)
  const main = ethers.Wallet.fromMnemonic(default_mnemonic)
  const wallet = new ethers.Wallet(main.privateKey, provider)

  // CRead test contract artifact
  const testContract = JSON.parse(fs.readFileSync(outputTarget, "utf8"))
  const hasherContract = new ethers.ContractFactory(
    genContract.abi, genContract.createCode("mimcsponge", 220), wallet
  )

  const deployment = await hasherContract.deploy()

  const response = await execute(
    `forge create --rpc-url ${rpcEndpoint} `
     + `--constructor-args ${deployment.address} `
     + `--private-key ${wallet.privateKey} `
     + `--legacy ${inputTarget}`
  )

  const deploymentAddress = response.stdout.split('\n')[3].split(" ")[2]
  const contract = new ethers.Contract(deploymentAddress, testContract.abi, wallet)

  const tx1 = await contract.setUp({ gasLimit: 1000000 })
  const tx2 = await contract.testAztecTornadoBridge({ gasLimit: 2000000 })

  await tx1.wait()
  await tx2.wait()

  console.log('Done!')
}

executeAndDeploy()
