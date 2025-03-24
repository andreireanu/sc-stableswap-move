module stableswap::stableswap {
    use sui::object::{Self, UID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::vector;

    // Define structs for different coin types
    public struct CoinA has store {}
    public struct CoinB has store {}

    // ======== Constants ========
    const MAX_ITERATIONS: u64 = 255;

    // ======== Errors ========
    const EInsufficientAmount: u64 = 0;
    const ESlippageExceeded: u64 = 1;
    const EZeroAmount: u64 = 2;
    const EInvalidCoin: u64 = 3;
    const EPoolKilled: u64 = 4;
    const EUnauthorized: u64 = 5;
    const ENoConvergence: u64 = 6;
    const EInvalidCoinNo: u64 = 7;

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


    /// Calculates the output amount for a given input amount.
    /// * `i` - Index of the input coin
    /// * `j` - Index of the output coin
    /// * `x` - Input amount
    /// * `balances` - Vector of current balances
    /// * `amp` - Amplification coefficient
    /// * `pool_n_coins` - Number of coins in the pool
    /// 
    /// # Returns
    /// * The output amount y that satisfies the StableSwap equation
    /// 
    /// # Aborts
    /// * If i equals j (same coin)
    /// * If i or j are out of bounds
    /// * If the Newton iteration does not converge
    fun get_y(i: u64, j: u64, x: u64, balances: &vector<u64>, amp: u64, pool_n_coins: u64): u64 {
        // Input validation
        assert!(i != j, EInvalidCoin);
        assert!(j < pool_n_coins, EInvalidCoin);
        assert!(i < pool_n_coins, EInvalidCoin);

        // Get D and calculate Ann
        let d = get_d(balances, amp, pool_n_coins);
        let ann = amp * pool_n_coins;

        // Initialize variables
        let mut c = d;
        let mut s = 0;

        // Calculate S_ and c
        let mut k = 0;
        while (k < pool_n_coins) {
            let x_temp = if (k == i) {
                x
            } else if (k != j) {
                *vector::borrow(balances, k)
            } else {
                k = k + 1;
                continue
            };
            s = s + x_temp;
            c = (c * d) / (x_temp * pool_n_coins);
            k = k + 1;
        };

        // Calculate c and b
        c = (c * d) / (ann * pool_n_coins);
        let b = s + d / ann;

        // Newton's method for finding y
        let mut y = d;
        let mut y_prev;
        let mut k = 0;
        while (k < MAX_ITERATIONS) {
            y_prev = y;
            y = (y * y + c) / (2 * y + b - d);

            // Check for convergence
            if (y > y_prev) {
                if (y - y_prev <= 1) {
                    return y
                }
            } else {
                if (y_prev - y <= 1) {
                    return y
                }
            };

            k = k + 1;
        };

        abort ENoConvergence
    }

    /// Calculates the StableSwap invariant D.
    /// * `balances` - Vector containing the balances of all coins
    /// * `amp` - Amplification coefficient
    /// 
    /// # Returns
    /// * The invariant D that satisfies the StableSwap equation:
    ///   Ann * sum(x_i) + D = Ann * D + D^(n+1) / (n^n * prod(x_i))
    /// 
    /// # Aborts
    /// * If the Newton iteration does not converge within MAX_ITERATIONS
    fun get_d(balances: &vector<u64>, amp: u64, pool_n_coins: u64): u64 {
        let n_coins = vector::length(balances);
        assert!(n_coins == pool_n_coins, EInvalidCoinNo);

        // Calculate sum of all balances
        let mut s = 0;
        let mut i = 0;
        while (i < n_coins) {
            s = s + *vector::borrow(balances, i);
            i = i + 1;
        };

        if (s == 0) {
            return 0
        };

        // Calculate Ann = A * n^n
        let ann = amp * n_coins;

        // Initial guess for D using sum of balances
        let mut d = s;
        let mut d_prev;
        let mut d_p;

        // Newton's method
        i = 0;
        while (i < MAX_ITERATIONS) {
            // Calculate D_P = D^(n+1) / (n^n * prod(x_i))
            d_p = d;

            // Calculate product term for each balance
            let mut j = 0;
            while (j < n_coins) {
                let balance = *vector::borrow(balances, j);
                if (balance > 0) {
                    d_p = (d_p * d) / (balance * n_coins);
                };
                j = j + 1;
            };

            // Store current d value before updating
            d_prev = d;

            // d = (Ann * S + D_P * n) * D / ((Ann - 1) * D + (n + 1) * D_P)
            let numerator = (ann * s + d_p * n_coins) * d;
            let denominator = (ann - 1) * d + (n_coins + 1) * d_p;
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

    /// Returns a vector containing the balances of both coins in the pool.
    /// * `pool` - Reference to the pool
    /// 
    /// # Returns
    /// * A vector of u64 containing [balanceA, balanceB]
    public fun get_balances(pool: &Pool2Coins): vector<u64> {
        let mut balances = vector::empty<u64>();
        vector::push_back(&mut balances, balance::value(&pool.balanceA));
        vector::push_back(&mut balances, balance::value(&pool.balanceB));
        balances
    }
}
