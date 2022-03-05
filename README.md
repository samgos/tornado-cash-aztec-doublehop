# Aztec Network - Tornado.Cash Doublehop Specification

This document concerns the prospect of "doublehopping" between the two privacy solutions, Aztec network a zk roll-up and Tornado.cash a coin-joining protocol.
This concept is still in it's infancy and is a work in progress.

_Doublehop: a extension of mix networks, where an obfuscated identity is relayed to a set of equal or greater in entropy_

While one of these solutions is catered to composability due to the nature of it's premise, the latter operates independently and will require some remodeling to suit this concept. Upon integrating successfully, there is the possibility of executing multiple cycles to this concept as both protocols have either entry or exit points with regards to the transactional flow.

![](https://i.imgur.com/dFdxxOo.png)

## Aztec - Tornado.cash

Upon depositing ETH to the Aztec bridge and retaining sufficient confirmations to retrieve an active zkETH balance, a target anonymity set is chosen by inputting the associated tornado instance address located on Ethereum main-net and a note is generated. Then using the Aztec connect SDK, a withdrawal proof is generated and called to the `AztecTornadoBridge` for execution by the `rollupProcessor`. The bridge then deposits to the `TornadoProxy`, and then has the user has the preference to withdraw on L1 to their own preference.

## Tornado.cash - Aztec

An individual deposits ETH to an anonymity set of their desired denomination. After waiting sufficient time for subsequent deposits to provide a veil of anonymity, they generate a withdrawal proof for processing by the `AztecResolver`. Which masks the withdraw logic but specifies the resolver as the recipent, to delegatecall the withdrawal to the `TornadoProxy`. In the process also verifying further ownership of the note in question via a "recursive" proof to avoid tampering of the actual desired withdrawal address. Once the withdrawal is processed, the `rollupProcessor` is deposited to specifying `depositorAddress` as their true withdrawal address. From here the user interacts with Aztec as they normally would from the address.
