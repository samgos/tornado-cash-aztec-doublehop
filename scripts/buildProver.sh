#!/bin/bash -e

# dependencies
sudo apt install build-essential
sudo apt-get install libgmp-dev
sudo apt-get install libsodium-dev
sudo apt-get install nasm

git add submodule https://github.com/iden3/rapidsnark
git submodule update
npx task createFieldSources
npx task buildProver
