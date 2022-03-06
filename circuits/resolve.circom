include "./commitmentHasher.circom";

template AztecResolverWithdraw() {
    signal input nullifierHash;
    signal input withdrawalAddress;

    signal private input nullifier;
    signal private input secret;

    component hasher = CommitmentHasher();
    hasher.nullifier <== nullifier;
    hasher.secret <== secret;
    hasher.nullifierHash === nullifierHash;

    signal addressSquare;

    addressSquare <==
    withdrawalAddress * withdrawalAddress;
}

component main = AztecResolverWithdraw();
