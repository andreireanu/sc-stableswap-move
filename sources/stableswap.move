module stableswap::stableswap {
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::math;
    use sui::table::{Self, Table};
    use std::vector;
    use std::option::{Self, Option};

    // Define structs for different coin types
    public struct CoinA has store {}
    public struct CoinB has store {}
    public struct CoinC has store {}
    public struct CoinD has store {}

    // ======== Constants ========
    const N_COINS: u64 = 4; // Number of coins in the pool
    const A_PRECISION: u64 = 100; // Amplification coefficient precision
    const FEE_DENOMINATOR: u64 = 10000000; // 10^7
    const PRECISION: u64 = 1000000000; // 10^9

    // ======== Errors ========
    const EInsufficientAmount: u64 = 0;
    const ESlippageExceeded: u64 = 1;
    const EZeroAmount: u64 = 2;
    const EInvalidCoin: u64 = 3;
    const EPoolKilled: u64 = 4;
    const EUnauthorized: u64 = 5;
    const ENoConvergence: u64 = 6;

    // ======== Pool Structure ========
    public struct Pool4Coins has key {
        id: UID,
        balanceA: Balance<CoinA>,
        balanceB: Balance<CoinB>,
        n_coins: u64,
        lp_supply: u64,
        amp: u64,
        fee: u64,
        admin_fee: u64,
        is_killed: bool,
        owner: address,
    }

    // LP Token representation
    public struct LPToken4Coins has key, store {
        id: UID,
        value: u64,
    }

    // ======== Pool Creation ========
    public entry fun create_pool(
        owner: address,
        amp: u64,
        fee: u64,
        admin_fee: u64,
        ctx: &mut TxContext
    ) {
        let pool = Pool4Coins {
            id: object::new(ctx),
            balanceA: balance::zero<CoinA>(),
            balanceB: balance::zero<CoinB>(),
            n_coins: 2,
            lp_supply: 0,
            amp: amp,
            fee: fee,
            admin_fee: admin_fee,
            is_killed: false,
            owner: owner,
        };
        transfer::share_object(pool);
    }

    // public entry fun add_liquidity<CoinTypeA, CoinTypeB>(
    //     pool: &mut Pool<CoinTypeA, CoinTypeB>,
    //     coin_a: Coin<CoinTypeA>,
    //     coin_b: Coin<CoinTypeB>,
    //     min_mint_amount: u64,
    //     ctx: &mut TxContext
    // ) {
    //     assert!(!pool.is_killed, EPoolKilled);

    //     let d0 = get_D(&pool.coin_a, &pool.coin_b, pool.amp);

    //     let token_supply = pool.lp_supply;
    //     if (token_supply == 0) {
    //         assert!(coin::value<CoinTypeA>(&coin_a) > 0 && coin::value<CoinTypeB>(&coin_b) > 0, EInsufficientAmount);
    //     };

    //     balance::join(&mut pool.coin_a, coin::into_balance(coin_a));
    //     balance::join(&mut pool.coin_b, coin::into_balance(coin_b));

    //     let d1 = get_D(&pool.coin_a, &pool.coin_b, pool.amp);

    //     assert!(d1 > d0, EInsufficientAmount);

    //     // Calculate fees and mint amount
    //     let mint_amount = if (token_supply > 0) {
    //         token_supply * (d1 - d0) / d0
    //     } else {
    //         d1
    //     };

    //     assert!(mint_amount >= min_mint_amount, ESlippageExceeded);

    //     // Mint LP tokens
    //     let lp_token = LPToken<CoinTypeA, CoinTypeB> {
    //         id: object::new(ctx),
    //         value: mint_amount,
    //     };
    //     pool.lp_supply = pool.lp_supply + mint_amount;
    //     transfer::public_transfer(lp_token, tx_context::sender(ctx));

    // }


    fun get_D<CoinTypeA, CoinTypeB>(coin_a: &Balance<CoinTypeA>, coin_b: &Balance<CoinTypeB>, amp: u64): u64 {
        // Get balances from the pool's coin balances
        let balance_a = balance::value(coin_a);
        let balance_b = balance::value(coin_b);
        let n_coins = N_COINS;

        // Calculate sum of all balances
        let sum = balance_a + balance_b;

        if (sum == 0) {
            return 0
        };

        let mut d: u64 = sum;
        let ann: u64 = amp * n_coins;

        // Newton's method iterations
        let mut i = 0;
        while (i < 255) {
            let d_prev = d;
            let mut d_prod = d;

            // Calculate D_prod = D^(n+1) / (n^n * prod(x_i))
            // For coin_a
            d_prod = d_prod * d / (balance_a * n_coins);
            // For coin_b
            d_prod = d_prod * d / (balance_b * n_coins);

            // D = (Ann * sum + D_prod * n_coins) * D / ((Ann - A_PRECISION) * D + (n_coins + 1) * D_prod)
            d = (ann * sum / A_PRECISION + d_prod * n_coins) * d /
                ((ann - A_PRECISION) * d / A_PRECISION + (n_coins + 1) * d_prod);

            // Check for convergence
            if (d > d_prev) {
                if (d - d_prev <= 1) {
                    return d
                }
            } else {
                if (d_prev - d <= 1) {
                    return d
                }
            };

            i = i + 1;
        };

        abort ENoConvergence
    }


}
