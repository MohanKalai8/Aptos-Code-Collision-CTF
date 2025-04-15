## DonkeySwap Audit Report

Audit Report : [link](https://github.com/MohanKalai8/Aptos-Code-Collision-CTF/blob/main/DonkeySwap.md)

## Welcome Challenge Solution

Simple Move challenge requiring proper signer handling:

1. Set `challenger` address in Move.toml
2. Create solution module with test function
3. Call functions in sequence with correct signer:
```move
#[test(account = @challenge, challenger = @challenger, aptos_framework = @0x1)]
public entry fun solve(account: &signer, challenger: &signer) {
    welcome::initialize(challenger);
    welcome::solve(challenger);
    welcome::is_solved(challenger);
}
```

run 
```sh
aptos move test 
```

## Revela Challenge Solution
In this challenge they given the bytecode of the contract and we have to decompile it to get the original source code of the challenge contract. We can use the `revela` to decompile the move bytecode
You can install it with Aptos CLI
```sh
aptos update revela
```
Once we get the decompiled source code of the challenge, simply write a unit test to call the `get_flag()` function to get flag.


## Flash Loan
In `initialize`, they are creating the `JBZ` token with `1337` supply and they are minted and stored in challenger's primary_fungible_store.

Uing `flash_loan()` one can take flash loan and repay using the `repay()` function. However the main issue lies in the `repay()` function does not checking if the returned `FungibleAsset` matches the amount borrwed through `flash_loan`. This allows one can borrow all the funds from the contract, and return a `FungibleAsset` with amont `0`.


---

## SuperMario 16
The main goal of this challenge is to set `peach.kidnapped` to `false`.  
In the `initialize` function, they are creating the `browser` and `mario` resource groups with values `254` and `0`, respectively. To set `peach.kidnapped` to `false`, we need to ensure `mario.hp` >= `bowser.hp`.

In the `train_mario` function, we can't increment `mario.hp` by 128 times because it is a `u8`, and it will overflow. The main issue lies in the `set_hp` function, which has no access control. This means anyone can set any value to the `browser.hp` attribute.

### Attack Path
1. Call `set_hp` with `hp = 0`.
2. Call `battle()`. Since `mario.hp = 0` and `browser.hp = 0`, it will pass and set `peach.kidnapped` to `false`.

---

## SuperMario 32
This challenge is similar to the previous one. However, in this challenge, we need to satisfy the condition `mario.hp > browser.hp`.

### Attack Path
1. Call `set_hp` with `hp = 0`.
2. Call `train_mario` with `mario_obj = mario`.
3. Call `battle()`. Since `mario.hp = 2` and `browser.hp = 0`, it will pass and set `peach.kidnapped` to `false`.

---

## SuperMario 64
The difference between this and the previous challenge is that this one has access control on the `set_hp` function. Only the owner of the `browser` object can call it, so we can't directly change the value of `browser.hp`.

In the `battle` function, if `mario.hp == browser.hp`, it will burn the `mario` object we pass and give us the `mario` object that was created in the `initialize` function. This object belongs to the same owner as the `browser` object. We can then train the `mario` object until `browser.hp == mario.hp`. After that we call `battle()`,so now our `account` will have ownership of both the `mario` and `browser` objects.

### Attack Path
1. Get the `mario` object address by calling `start_game`.
2. Call `train_mario` 127 times.
3. Call `battle()`. Since `mario.hp = 128` and `browser.hp = 128`, it will burn the `mario` object we passed and give us the `mario` object that was created in the `initialize` function.
4. Now that we have ownership of both the `mario` and `browser` objects, call `set_hp` with `hp = 0` to set `browser.hp` to `0`.
5. Call `train_mario` with `mario_obj = mario` to set `mario.hp` to `2`.
6. Call `battle()`. Since `mario.hp = 2` and `browser.hp = 0`, it will pass and set `peach.kidnapped` to `false`.

## Zero Knowledge Bug
To solve this challenge we need to call prove() function atleast 3 times. With the exact value which is stored in the Knowledge object
We can obtain the Knowledge object using `get_knowledge()`, but since this struct does not belongs to us, we cannot directly read its internal fields. However, we can serialize the struct using the standard library's `bcs::to_bytes` and then deserialize it to extract the internal `u64` value.

## Simple Swap
In `initialize` two types of tokens APT and TokenB are created and 20 of each token are put into the pool. The main goal of this challenge is to zero out the balance of any token in the pool.

A `Faucet` is created, which contains 5 APT tokens for users and 8 APT tokens for the admin. Calling `claim` will distribute these tokens to the respective accounts.

The `swap` function requires that the input token amount be at least 6, but we only have 5 tokens. So, the first step is to we need to find a way to get more tokens.

As the shares minting logic in this pool is vulnerable to classic first deposit attack, This attack usually achieved by frontrunning admin deposit,we can first depositing small amount and denoting tokens and then backruning admin deposit.

Attack Path
1. Initial state
```
Admin: 8 APT
User: 5 APT
Vault: 0
```
2. User deposits 1 APT token
```
Admin: 8 APT
User: 4 APT, 1 share
Vault: 1 APT
```
3. User donates 4 APT
```
Admin: 8 APT
User: 0 APT
Vault: 5 APT
```
4. Admin deposits 8 APT : 
(8 * 1 / 5 = 1 LP)
```
Admin: 1 share 
User: 1 share
Vault: 13 APT
```
5. User converts his 1 shares back to APT by calling withdraw() function
1 * 13 / 2 = 6 APT
```
User: 6 APT
Admin: 1 share
Vault: 7 APT
```

The swap calculation is also wrong, as it uses `output_0 = input_1 * reserve_0 / reserve_1`, which results in draining the tokens from the pool.

Initially the pool has 20 APT and 20 TokenB.
```
swap1:
   attacker : 6 APT => gets 6 * 20 / 20 = 6 TokenB
   pool : 26 APT, 14 TokenB

swap2:
   attacker : 6 TokenB => 6 * 26 / 14 = 11 APT
   pool : 15 APT, 20 TokenB

swap3:
   attacker : 11 APT => 11 * 20 / 15 = 14 TokenB
   pool : 26 APT, 6 TokenB

swap4:
    attacker : 14 TokenB => 6 * 26 / 6 = 26 APT
    pool : 0 APT, 20 TokenB

