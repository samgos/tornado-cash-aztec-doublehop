#!/bin/bash -e
# Fetch ptau ceremony data
curl "https://hermez.s3-eu-west-1.amazonaws.com/powersOfTau28_hez_final_20.ptau" --output artifacts/zkeys/ptau28_hez_final.ptau
# Verify the ceremony
npx snarkjs powersoftau verify artifacts/zkeys/ptau28_hez_final.ptau
# Generate zkeys
npx snarkjs groth16 setup artifacts/circuits/resolverWithdraw.r1cs artifacts/zkeys/ptau28_hez_final.ptau artifacts/zkeys/resolverWithdraw.zkey
# Export verification key
npx snarkjs zkey export verificationkey artifacts/zkeys/resolverWithdraw.zkey artifacts/zkeys/verification_key.json
# Create verifier contract
npx snarkjs zkey export solidityverifier artifacts/zkeys/resolverWithdraw.zkey src/Verifier.sol
# TODO copy verifying key to groth16 verification contract
