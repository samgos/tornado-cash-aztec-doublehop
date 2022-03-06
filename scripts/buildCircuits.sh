#!/bin/bash -e
mkdir -p artifacts/circuits
if [ "$2" = "large" ]; then
  npx circom -v -f -r artifacts/circuits/$1.r1cs -c artifacts/circuits/$1.cpp -s artifacts/circuits/$1.sym circuits/$1.circom
else
  npx circom -v -f -r artifacts/circuits/$1.r1cs -w artifacts/circuits/$1.wasm -s artifacts/circuits/$1.sym circuits/$1.circom
fi
