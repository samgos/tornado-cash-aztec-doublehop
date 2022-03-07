## Tornado.Cash - Aztec Doublehop

A "doublehop" strategy using two on-chain privacy solutions, Aztec network a zero-knowledge rollup and Tornado.cash a privacy protocol. This concept is still in it's infancy and is a work in progress.

_Doublehop: a extension of mix networks, where an obfuscated identity is relayed to a set of equal or greater in entropy_

There is the possibility of executing multiple cycles to this concept as both protocols have either entry or exit points with regards to the transactional flow, expontentially increasing the achieved entropy with each cycle.

</br>
<center>
    <figure>
        <img src="https://i.imgur.com/dFdxxOo.png">
    </figure>
    <figcaption></figcaption>
</center>
</br>

Given the constraints of relaying properitary information for execution with Aztec's `rollupProcessor` and the need for a `bytes32` parameter representing a valid commitment to an anonymity set. This implementation only facilliates deposits and withdrawals in 1 ETH and 10 ETH denominations.


## Aztec - Tornado.Cash

Requirements:

* A generated note to retain ownership of the deposit
* A valid withdrawal proof to withdraw from the rollup

Upon depositing ETH to the rollup and retaining sufficient confirmations to retrieve an active L2 balance, a target anonymity set is chosen by inputting the associated tornado instance address located on L1 and a note is securely generated. Then using the Aztec connect SDK, a withdrawal proof is generated and called to the `AztecTornadoBridge` for execution by the `rollupProcessor`. The bridge then deposits to the `TornadoProxy`, and then has the user has the preference to withdraw on L1 to their own preference.

## Tornado.Cash - Aztec

Requirements:

* A valid withdrawal proof of an unspent note from an anonymity set
* A valid settlement proof to deposit to the rollup
* A valid resolver proof to show succinct ownership of the note and the recipent   

An individual deposits ETH to an anonymity set of their desired denomination. After waiting a sufficient period, they generate a withdrawal proof for processing by a relayer via the `AztecResolver`. Which masks the withdraw logic but specifies the resolver as the recipent, and requires a succinct proof to avoid tampering of the recipent address. Once the withdrawal is processed, the `rollupProcessor` is deposited to specifying `depositorAddress` as the recipent. From here the deposit can be used on L2 freely.
