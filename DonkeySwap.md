This is a shadow audit of DonkeySwap which was created by the Zellic team.

You can find the report for zellic audit : [link](https://www.zellic.io/blog/top-10-aptos-move-bugs/)

source code with tests : [link](https://github.com/Zellic/DonkeySwap)



The Move language is designed to make it difficult to write bugs and does its job relatively well. There are certain bug classes that it completely eliminates. But as is the case with everything, it’s not impossible — and smart contract bugs almost always have the potential for negative financial impact.

## DonkeySwap
An intentionally vulnerable, Coin-swapping protocol for Aptos.

It's basically an AMM that uses an oracle for pricing, and LP coins minted represent the USD value of liquidity deposits/withdrawals. Featuring support for limit swap orders!

The purpose of this repository is to demonstrate common vulnerabilities we see in Aptos Move protocols.

### 1. Missing Generic Types checking
Generic types are another form of user input that must be checked for validity. When using generics types, we need to check 
   - the type is valid/whitelisted type
   - the type is expected type.

Function `cancel_order` Does not check BaseCoinType Generic Type.

#### `Description:`
The `cancel_order` function does not assert the input `BaseCoinType` generic type matches the `base_type` TypeInfo 

#### `Impact:`
An attacker could pottentially drain liquidity from the AMM by placing swap order and cancelling the order - passing incorrect coin type.

```rust
##[test(admin=@donkeyswap, user=@0x2222)]
fun WHEN_exploit_lack_of_type_checking(admin: &signer, user: &signer) acquires CoinCapability {
    let (my_usdc, order_id) = setup_with_limit_swap(admin, user, 1000000000000000);

    // let's say the admin deposits some ZEL

    mint<ZEL>(my_usdc, address_of(admin));
    let _admin_order_id = market::limit_swap<ZEL, USDC>(admin, my_usdc, 1000000000000000);

    // now, let's try stealing from the admin

    assert!(coin::balance<USDC>(address_of(user)) == 0, ERR_UNEXPECTED_BALANCE);
    assert!(coin::balance<ZEL>(address_of(user)) == 0, ERR_UNEXPECTED_BALANCE);

    market::cancel_order<ZEL>(user, order_id); // ZEL is not the right coin type!

    assert!(coin::balance<USDC>(address_of(user)) == 0, ERR_UNEXPECTED_BALANCE);
    assert!(coin::balance<ZEL>(address_of(user)) == my_usdc, ERR_UNEXPECTED_BALANCE); // received ZEL?
}
```

In setup admin adds liquidity of `1000_0000` USDC and `100_000000` ZEL and user places limit_swap with `10_0000` USDC

#### Attack path:
1. After setup, admin places limit_swap<ZEL, USDC> with `1000000000000000`
2. Now users calls `cancel_order()` with incorrect coin type. i.e. ZEL instead of USDC
3. Now as there is no generic CoinType check in cancel_order, user will get ZEL as base Type instead of USDC

#### Recommendation: 
To fix this issue add the following check in the cancel order
```rust
assert!(order.base_type == type_info::type_of<BaseCoinType>(), ERR_ORDER_WRONG_COIN_TYPE);
```

### 2.Unbounded Execution
Unbounded execution, also known as gas griefing, is a DoS attack that exists when users can add iterations to the looping code shared by multiple users.

#### Description: 
In the function `get_order_by_id()` the loop iterates over every open order and could potentially be blocking by registering many orders.

This function is used in many parts of the code like `cancel_order` and `fulfill_order`

#### Impact 
Because each of these functions is called by multiple users, an attacker could potentially block the execution of these functions by registering many orders.

It will block all users from cancelling or fulfilling limit orders, which locks the funds permanently in the protocol

#### Recommendation: 
Avoid looping over every order and instead limiting the no.of iterations each loop

### 3. Missing Access Control
Accepting an &signer parameter is not sufficient for access control. Be sure to assert that the signer is the expected account.

#### Description: 
The `cancel_order` function does not check if the user is the owner of the order.

#### Impact: 
An attacker could potentially cancel any order by providing the order id.

```rust
##[test(admin=@donkeyswap, user=@0x2222)]
fun WHEN_exploit_improper_access_control(admin: &signer, user: &signer) acquires CoinCapability {
    setup_with_liquidity(admin, user);

    // let's say the admin deposits some USDC

    let my_usdc = 1000000000000000;
    mint<USDC>(my_usdc, address_of(admin));
    let order_id = market::limit_swap<USDC, ZEL>(admin, my_usdc, 1000000000000000);

    // now, let's try stealing USDC from the admin

    assert!(coin::balance<USDC>(address_of(user)) == 0, ERR_UNEXPECTED_BALANCE);
    assert!(coin::balance<ZEL>(address_of(user)) == 0, ERR_UNEXPECTED_BALANCE);

    market::cancel_order<USDC>(user, order_id); // order owned by admin, but signer is user!

    assert!(coin::balance<USDC>(address_of(user)) == my_usdc, ERR_UNEXPECTED_BALANCE);
    assert!(coin::balance<ZEL>(address_of(user)) == 0, ERR_UNEXPECTED_BALANCE); // received ZEL?
}
```

Attack path:
1. Admin sets up the liquidity
2. Admin places limit_swap<USDC, ZEL> with `1000000000000000`
3. User will call cancel_order() with order_id corresponds to the admin order
4. As there is no access control check, user will be able to cancel the admin order potentially draining the liquidity.
5. This way the attacker can drain liquidity from the AMM by cancelling all the orders.

#### Recommendation: 
Add a check to ensure the user is the owner of the order before cancelling it.

```rust
assert!(order.user_address == address_of(user), ERR_PERMISSION_DENIED);
```

### 4. Price Oracle Manipulation
An attacker can manipulate the price of an asset in the pool by a sandwich attack. Usually by front-running and back-running the users swap.

#### Description: 
DonkeySwap natively uses the liquidity ratio of tokens in a pair as a price oracle for determiing the liquidity token to send or receive for deposits and withdrawals.

#### Impact: 
An attacker can drain the pool by manipulate the ratio of tokens.

#### Recommendation: 
Use at least one external price oracle to determine the price of the asset. so that the attacker cannot manipulate the price of the asset.

### 5. Arithmetic Precision Errors

Rounding Error Enables Protocol Fee ByPass

#### Description:
DonkeySwap calculates the appropriate protocol fees by taking a percentage of the order size in the following function:

```rust
public fun calculate_protocol_fees(
    size: u64
): (u64) {
    return size * PROTOCOL_FEE_BPS / 10000
}
```

If the (size * PROTOCOL_FEE_BPS) < 10000, the fee will round down to 0. so we can easily bypass the fee by setting the size to a very small value.

The below PoC demonstrates protocol fee bypass by placing order with max amount we can bypass the fee.
PoC : 
```rust
##[test(admin=@donkeyswap, user=@0x2222)]
fun WHEN_exploit_fees_rounding_down(admin: &signer, user: &signer) acquires CoinCapability {
    setup_with_liquidity(admin, user);

    let max_exploit_amount = (10000 / market::get_protocol_fees_bps()) - 1;
    assert!(market::calculate_protocol_fees(max_exploit_amount) == 0, ERR_UNEXPECTED_PROTOCOL_FEES);

    let my_usdc = max_exploit_amount;
    mint<USDC>(my_usdc, address_of(user));

    assert!(coin::balance<USDC>(address_of(user)) == my_usdc, ERR_UNEXPECTED_BALANCE);
    assert!(coin::balance<ZEL>(address_of(user)) == 0, ERR_UNEXPECTED_BALANCE);

    let output = market::swap<USDC, ZEL>(user, my_usdc);

    assert!(coin::balance<USDC>(address_of(user)) == 0, ERR_UNEXPECTED_BALANCE);
    assert!(coin::balance<ZEL>(address_of(user)) == output, ERR_UNEXPECTED_BALANCE);
    assert!(output > 0, ERR_UNEXPECTED_BALANCE);

    assert!(market::get_protocol_fees<USDC>() == 0, ERR_UNEXPECTED_PROTOCOL_FEES);
    assert!(market::get_protocol_fees<ZEL>() == 0, ERR_UNEXPECTED_PROTOCOL_FEES); // no fees collected
}
```
#### Impact:
Users can bypass fees when removing liquidity, swapping, or limit swapping by placing multiple small orders.

### 6. Missing Account Registration Check for Coin 
The aptos_framework::coin module requires that a CoinStore exists on the target account when calling coin::deposit or coin::withdraw, so the account must be registered first with coin::register beforehand:

```rust
public fun register<CoinType>(account: &signer) {
    let account_addr = signer::address_of(account);
    // Short-circuit and do nothing if account is already registered for CoinType.
    if (is_account_registered<CoinType>(account_addr)) {
        return
    };
        // [...]
}
```

#### Description:
The execute_limit_order function does not check whether the account that will receive the quote coin is registered for the coin.

#### Impact:
The execute_limit_order function is called by execute_order which is called by fulfill_order and add_liquidity. If an attacker were to create a fullfill order that targets an account that is not registered for the quote coin, it will not possible to swap or add liquidity.

```rust
##[test(admin=@donkeyswap, user=@0x2222, attacker=@0x3333)]
##[expected_failure(abort_code=393221, location=coin)] // ECOIN_STORE_NOT_PUBLISHED
fun WHEN_exploit_lack_of_account_registered_check(admin: &signer, user: &signer, attacker: &signer) acquires CoinCapability {
    account::create_account_for_test(address_of(attacker));
    setup(admin, user);
    assert!(!coin::is_account_registered<ZEL>(address_of(attacker)), ERR_UNEXPECTED_ACCOUNT);

    // create limit order from attacker's account
    let my_usdc = 10_0000; // $10 USDC
    mint<USDC>(my_usdc, address_of(attacker));
    market::limit_swap<USDC, ZEL>(user, my_usdc, 0);

    // try to add liquidity from user's account, which tries to fulfill the order
    mint<USDC>(my_usdc, address_of(user));
    market::add_liquidity<USDC>(user, my_usdc); // this should abort
}
```

Here user trying to add USDC into the pool, but he is not registered for the quote coin, so the transaction will abort.

#### Recommendation:
Add the following two lines to the limit_swap function to forcefully register the accounts:
```rust
coin::register<BaseCoinType>(user);
coin::register<QuoteCoinType>(user);
```

'Note:` The coin::register function automatically skips registration if the account is already registered for the coin.

### 7. Arithmetic Errors:
 It is important to be aware that custom data sizes may have different overflow/underflow behavior from the built-in unsigned integer types.

#### Description:
An attacker could place an order with a size large enough to cuae an overflow abort in the following places:

- calculate_lp_coin_amount_internal:
```rust
size * get_usd_value_internal(order_store, type)
```

- calculate_protocol_fees:
```rust
size * PROTOCOL_FEE_BPS / 10000
```

#### Impact:
Because add_liquidity always attempts to fulfill orders, if a calculation overflows when fulfilling the order, the add_liquidity request will fail.

#### Recommendation:
Cast operands to u128 before multiplication and ensure that coins that can reasonably cause overflow do not get whitelisted.

### 8. Improper Resource Management
#### Description:
DonkeySwap stores Order resources in a global OrderStore under the module account `@donkeyswap`, violating the Aptos Move best practices for data ownership.
```rust
struct OrderStore has key {
    current_id: u64,
    orders: vector<Order>,
    locked: Table<TypeInfo, u64>,
    liquidity: Table<TypeInfo, u64>,
    decimals: Table<TypeInfo, u8>
}
```

#### Impact:
- Ownership Ambiguity: Orders lack clear association with individual users, making them vulnerable to unintended modifications.
- Scalability Risks: A large global order vector can lead to gas exhaustion, impacting all users. In contrast, user-specific storage would isolate such issues to the individual causing them.

#### Recommendation:
Store Order resources within user accounts to ensure ownership clarity, improve scalability, and mitigate risks associated with global storage.

### 9. Business Logic Flaws
Business logic flaws are common issues in Move-based protocols, arising from design weaknesses rather than coding errors. These include misaligned incentives, centralization risks, and logic errors like double spending. Such flaws are highly context-dependent and can significantly impact protocol functionality.

#### Description:
DonkeySwap does not incentivize users to provide liquidity to its AMM, leaving no motivation for users to contribute to the protocol's liquidity pools.

#### Impact:
Without incentives, the protocol is unlikely to attract liquidity providers, leading to insufficient liquidity and rendering the AMM ineffective.

#### Recommendation:
Incorporate a fee structure to reward liquidity providers for supporting the protocol and encourage user participation.

### 10. Use of Incorrect Standard Function

#### Description:
In the `fulfill_orders` function, the protocol attempts to borrow an Order from an Option after extracting it, leading to a runtime abort since the Order is no longer present in the Option.

```rust
let order_option = get_next_order(&mut orders);
if (option::is_none(&order_option)) {
    break
};
let status = execute_order<CoinType>(order_store, &option::extract(&mut order_option));
if (status == 0) {
    vector::push_back(&mut successful_order_ids, option::borrow(&mut order_option).id);
};
```

#### Impact:
If any limit order is successfully fulfilled during the fulfill_orders call, the transaction aborts. This can prevent users from adding liquidity and disrupt protocol operations.

#### Recommendation:
Refactor the function to extract the Order once or borrow it twice without extracting. Additionally, ensure comprehensive test coverage to catch such issues.




