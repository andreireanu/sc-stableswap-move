module stableswap::stableswap {
    use sui::balance;
    use sui::coin::{Self, Coin};
    use std::type_name;
    use sui::bag::{Self, Bag};
    use std::ascii::String;

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
    const EWrongCoinInType: u64 = 8;
    const EWrongCoinOutType: u64 = 9;

    // ======== Pool Structure ========
    public struct Pool has key {
        id: UID,
        types: vector<String>,
        balances: Bag,
        values: vector<u64>,
        n_coins: u64,
        lp_supply: u64,
        amp: u64,
        fee: u64,
        admin_fee: u64,
        is_locked: bool,
        is_killed: bool,
        owner: address,
    }

    public struct AdminCap has key {  
        id: UID
    }

    // LP Token representation
    public struct LPToken has key, store {
        id: UID,
        value: u64,
    }

    /// Creates a new StableSwap pool with the specified parameters.
    /// 
    /// # Arguments
    /// * `owner` - Address that will own the pool and receive admin fees
    /// * `amp` - Amplification coefficient for the StableSwap formula
    /// * `fee` - Trading fee 
    /// * `admin_fee` - Admin fee 
    /// * `ctx` - Transaction context
    /// 
    /// # Effects
    /// * Creates a new Pool object with empty balances and values
    /// * Makes the pool a shared object (accessible by all)
    /// * Creates and transfers an AdminCap to the sender
    public entry fun create_pool(
        owner: address,
        amp: u64,
        fee: u64,
        admin_fee: u64,
        ctx: &mut TxContext
    ) {
        let pool = Pool {
            id: object::new(ctx),
            types: vector::empty(),
            balances: bag::new(ctx),
            values: vector::empty(),
            n_coins: 0,
            lp_supply: 0,
            amp: amp,
            fee: fee,
            admin_fee: admin_fee,
            is_locked: false,
            is_killed: false,
            owner: owner,
        };
        transfer::share_object(pool);
        transfer::transfer(AdminCap {id: object::new(ctx)}, tx_context::sender(ctx));
    }

    /// Adds a new coin type to the pool.
    /// 
    /// # Arguments
    /// * `_` - AdminCap capability (unused but required for authorization)
    /// * `pool` - The pool to add the coin type to
    /// 
    /// # Type Parameters
    /// * `I` - Type of the coin to add
    /// 
    /// # Effects
    /// * Adds the coin type string to the pool's types vector
    /// * Initializes a zero balance for the coin in the pool's balances bag
    /// * Adds a zero value to the pool's values vector
    /// * Increments the pool's coin counter
    public entry fun add_type<I>(_ : &AdminCap, pool: &mut Pool) 
    {
        let type_str_t = type_name::into_string(type_name::get<I>());
        vector::push_back(&mut pool.types, type_str_t);
        bag::add(&mut pool.balances, type_str_t, balance::zero<I>());
        vector::push_back(&mut pool.values, 0);
        pool.n_coins = pool.n_coins + 1;
    }

    /// Locks the pool, preventing further modifications.
    /// 
    /// # Arguments
    /// * `_` - AdminCap capability (unused but required for authorization)
    /// * `pool` - The pool to lock
    /// 
    /// # Effects
    /// * Sets the pool's is_locked flag to true
    public entry fun lock_pool(_ : &AdminCap, pool: &mut Pool) 
    {
        pool.is_locked = true;
    }

    /// Exchange one coin type for another in the pool.
    /// 
    /// # Arguments
    /// * `min_dy` - Minimum amount of output coin to receive (slippage protection)
    /// * `dx_coin` - Input coin to exchange
    /// * `pool` - The pool to perform the exchange in
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `I` - Type of the input coin
    /// * `J` - Type of the output coin
    /// 
    /// # Returns
    /// * The output coin received from the exchange
    /// 
    /// # Aborts
    /// * If input coin type is not in the pool
    /// * If output coin type is not in the pool
    /// * If output amount is less than min_dy
    public fun exchange_coin<I, J>(
        min_dy: u64, 
        dx_coin: Coin<I>, 
        pool: &mut Pool, 
        ctx: &mut TxContext
    ): Coin<J>  {
        let type_str_i = type_name::into_string(type_name::get<I>());
        let (i_present, i_index) = vector::index_of(&pool.types, &type_str_i);
        assert!(i_present, EWrongCoinInType);
        let type_str_j = type_name::into_string(type_name::get<J>());
        let (j_present, j_index) = vector::index_of(&pool.types, &type_str_j);
        assert!(j_present, EWrongCoinOutType);  

        let dx = coin::value(&dx_coin);
        let y_new = exchange(i_index, j_index, dx, pool);
        let y_value = vector::borrow(&pool.values, j_index);
        let dy = *y_value - y_new;
        assert!(dy >= min_dy, ESlippageExceeded);

        increase_balance(pool, type_str_i, i_index, dx_coin); 
        let dy_coin = decrease_balance<J>(pool, type_str_j, j_index, dy, ctx); 

        dy_coin
    }

    /// Increase the balance of a specific coin type in the pool.
    /// 
    /// # Arguments
    /// * `pool` - The pool to update
    /// * `type_str_i` - String representation of the coin type
    /// * `i_index` - Index of the coin type in the pool's vectors
    /// * `dx_coin` - Coin to add to the pool
    /// 
    /// # Type Parameters
    /// * `I` - Type of the coin being added
    /// 
    /// # Effects
    /// * Updates the pool's values vector with the new balance
    /// * Adds the coin's balance to the pool's balances bag
    fun increase_balance<I>(pool: &mut Pool, type_str_i: String, i_index: u64, dx_coin: Coin<I>) {
        let dx_balance = coin::into_balance(dx_coin);
        let dx_value = balance::value(&dx_balance);
        let x_value = vector::borrow_mut(&mut pool.values, i_index);
        *x_value = *x_value + dx_value;
        let x_balance = bag::borrow_mut(&mut pool.balances, type_str_i);
        balance::join(x_balance, dx_balance);
    }

    /// Decrease the balance of a specific coin type in the pool and return it as a coin.
    /// 
    /// # Arguments
    /// * `pool` - The pool to update
    /// * `type_str_j` - String representation of the coin type
    /// * `j_index` - Index of the coin type in the pool's vectors
    /// * `dy` - Amount to decrease the balance by
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `J` - Type of the coin being removed
    /// 
    /// # Returns
    /// * A new coin containing the removed balance
    /// 
    /// # Effects
    /// * Updates the pool's values vector with the new balance
    /// * Removes the specified amount from the pool's balances bag
    fun decrease_balance<J>(pool: &mut Pool, type_str_j: String, j_index: u64, dy: u64, ctx: &mut TxContext): Coin<J> {
        let y_value = vector::borrow_mut(&mut pool.values, j_index);
        *y_value = *y_value - dy;
        let y_balance = bag::borrow_mut(&mut pool.balances, type_str_j);
        let dy_balance = balance::split<J>(y_balance, dy);
        coin::from_balance(dy_balance, ctx)
    }

    /// Calculate the output amount for a given input amount using the StableSwap formula.
    /// 
    /// # Arguments
    /// * `i` - Index of the input coin
    /// * `j` - Index of the output coin
    /// * `dx` - Input amount
    /// * `pool` - The pool to perform the calculation in
    /// 
    /// # Returns
    /// * The calculated output amount
    /// 
    /// # Aborts
    /// * If i equals j (same coin)
    /// * If i or j are out of bounds
    /// * If the Newton iteration does not converge
    fun exchange(i: u64, j: u64, dx: u64, pool: & Pool): u64 {
        let pool_n_coins = pool.n_coins;
        let amp = pool.amp;
        let pool_values = &pool.values;
        get_y(i, j, dx, pool_values, amp, pool_n_coins)
    }


    /// Calculates the output amount for a given input amount.
    /// * `i` - Index of the input coin
    /// * `j` - Index of the output coin
    /// * `x` - Input amount
    /// * `values` - Vector of current values
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
    fun get_y(i: u64, j: u64, dx: u64, values: &vector<u64>, amp: u64, pool_n_coins: u64): u64 {
        // Input validation
        assert!(i != j, EInvalidCoin);
        assert!(j < pool_n_coins, EInvalidCoin);
        assert!(i < pool_n_coins, EInvalidCoin);

        // Get D and calculate Ann
        let d = get_d(values, amp, pool_n_coins);
        let ann = amp * pool_n_coins;

        // Initialize variables
        let mut c = d;
        let mut s = 0;

        // Calculate S_ and c
        let mut k = 0;
        while (k < pool_n_coins) {
            let x_temp = if (k == i) {
                *vector::borrow(values, k) + dx
            } else if (k != j) {
                *vector::borrow(values, k)
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
    /// * `values` - Vector containing the values of all coins
    /// * `amp` - Amplification coefficient
    /// 
    /// # Returns
    /// * The invariant D that satisfies the StableSwap equation:
    ///   Ann * sum(x_i) + D = Ann * D + D^(n+1) / (n^n * prod(x_i))
    /// 
    /// # Aborts
    /// * If the Newton iteration does not converge within MAX_ITERATIONS
    fun get_d(values: &vector<u64>, amp: u64, pool_n_coins: u64): u64 {
        let n_coins = vector::length(values);
        assert!(n_coins == pool_n_coins, EInvalidCoinNo);

        // Calculate sum of all values
        let mut s = 0;
        let mut i = 0;
        while (i < n_coins) {
            s = s + *vector::borrow(values, i);
            i = i + 1;
        };

        if (s == 0) {
            return 0
        };

        // Calculate Ann = A * n^n
        let ann = amp * n_coins;

        // Initial guess for D using sum of values
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
                let balance = *vector::borrow(values, j);
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

 
}
