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

    // ======== Constants ========
    const A_PRECISION: u64 = 100;
    const N_COINS: u64 = 2;
    const FEE_DENOMINATOR: u64 = 10000000; // 10^7
    const PRECISION: u64 = 1000000000; // 10^9
    const MAX_ITERATIONS: u64 = 255;

    // ======== Errors ========
    const EInsufficientAmount: u64 = 0;
    const ESlippageExceeded: u64 = 1;
    const EZeroAmount: u64 = 2;
    const EInvalidCoin: u64 = 3;
    const EPoolKilled: u64 = 4;
    const EUnauthorized: u64 = 5;
    const ENoConvergence: u64 = 6;

    // ======== Pool Structure ========
    public struct Pool2Coins has key {
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
    public struct LPToken2Coins has key, store {
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
        let pool = Pool2Coins {
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


    fun get_d<CoinTypeA, CoinTypeB>(coin_a: &Balance<CoinTypeA>, coin_b: &Balance<CoinTypeB>, amp: u64): u64 {
        // Get balances
        let value_a = balance::value(coin_a);
        let value_b = balance::value(coin_b);

        let s = value_a + value_b;
        if (s == 0) {
            return 0
        };

        // Calculate Ann = A * n^n
        let ann = amp * N_COINS;

        // Initial guess for D using sum of balances
        let mut d = s;
        let mut d_prev;
        let mut d_p;

        // Newton's method
        let mut i = 0;
        while (i < MAX_ITERATIONS) {
            // Calculate D_P = D^(n+1) / (n^n * prod(x_i))
            d_p = d;

            if (value_a > 0) {
                d_p = (d_p * d) / (value_a * N_COINS);
            };
            if (value_b > 0) {
                d_p = (d_p * d) / (value_b * N_COINS);
            };

            // Store current d value before updating
            d_prev = d;

            // d = (Ann * S + D_P * n) * D / ((Ann - 1) * D + (n + 1) * D_P)
            let numerator = (ann * s + d_p * N_COINS) * d;
            let denominator = (ann - 1) * d + (N_COINS + 1) * d_p;
            d = numerator / denominator;

            // Check for convergence with precision of 1
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
