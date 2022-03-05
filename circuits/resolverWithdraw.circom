import "./CommitmentHasher.circom";

template AztecResolverWithdraw() {
    signal public input nullifierHash;
    signal public input withdrawalAddress;

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
