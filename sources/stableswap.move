module stableswap::stableswap {
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap};
    use std::type_name;
    use sui::bag::{Self, Bag};
    use std::ascii::String;

    // ======== Constants ========
    const MAX_ITERATIONS: u64 = 255;
    const FEE_DENOMINATOR: u64 = 10000;

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
    const EWrongLiquidityCoin: u64 = 10;
    const EUnlockedPool: u64 = 11;
    const ELockedPool: u64 = 12;
    const ETokenAlreadyAdded: u64 = 13;
    const EInvalidFirstDeposit: u64 = 14;
    const EAlreadyAddedCoin: u64 = 15;
    const EInvalidAdd: u64 = 16;
    const EInvalidDeposit: u64 = 17;
    const EInvalidMinMintAmount: u64 = 18;
    const EInvalidValue: u64 = 19;

    // ======== Pool Structure ========
    public struct Pool has key {
        id: UID,
        types: vector<String>,
        balances: Bag,
        values: vector<u64>,
        n_coins: u64,
        lp_supply: u64,
        lp_treasury: TreasuryCap<LP>,
        amp: u64,
        fee: u64,
        admin_fee: u64,
        admin_fee_balances: Bag,
        is_locked: bool,
        is_killed: bool,
        owner: address,
    }

    public struct AdminCap has key {  
        id: UID
    }

    // LP Token representation
    public struct LP has drop {}


    // Structure to store liquidity while adding
    public struct Liquidity {         
        values: vector<u64>,
        admin_fees: vector<u64>,
        types: vector<String>,
        mint_amount: u64,
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
        let lp_treasury = init_lp(LP {}, ctx);
        let pool = Pool {
            id: object::new(ctx),
            types: vector::empty(),
            balances: bag::new(ctx),
            values: vector::empty(),
            n_coins: 0,
            lp_supply: 0,
            lp_treasury: lp_treasury,
            amp: amp,
            fee: fee,  // General fee
            admin_fee: admin_fee,    // Fee out of the general fee   
            admin_fee_balances: bag::new(ctx),
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
        assert!(!pool.is_locked, ELockedPool);
        let type_str_i = type_name::into_string(type_name::get<I>());
        assert!(!vector::contains(&mut pool.types, &type_str_i), ELockedPool);
        vector::push_back(&mut pool.types, type_str_i);
        bag::add(&mut pool.balances, type_str_i, balance::zero<I>());
        vector::push_back(&mut pool.values, 0);
        bag::add(&mut pool.admin_fee_balances, type_str_i, balance::zero<I>());
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
        assert!(!pool.is_locked, ELockedPool);
        pool.is_locked = true;
    }

    /// Initialize the liquidity addition process.
    /// 
    /// # Arguments
    /// * `pool` - The pool to add liquidity to
    /// * `amounts` - Vector of amounts for each coin type
    /// * `ctx` - Transaction context
    /// 
    /// # Aborts
    /// * If pool is not locked
    /// * If the number of amounts doesn't match the number of coins in the pool
    public fun init_add_liquidity(
        pool: &mut Pool,
        values: vector<u64>,
        min_mint_amount: u64,
        ctx: &mut TxContext
    ): Liquidity {
        assert!(pool.is_locked, EUnlockedPool);
        assert!(vector::length(&values) == pool.n_coins, EInvalidCoinNo);
        
        let n_coins = pool.n_coins;
        let fee =  pool.fee;
        let amp = pool.amp;
        let admin_fee = pool.admin_fee;
        let token_supply = get_values_sum(&pool.values);
        let fees = fee * n_coins / (4 * (n_coins - 1 )); // TODO: Check how this is derived

        let mut d0: u64 = 0;
        if (token_supply > 0) {
            d0 = get_d(&pool.values, amp, n_coins);
        } else {
            assert! (valid_first_deposit(&values), EInvalidFirstDeposit);
        };

        let mut new_values = add_values(&values, &pool.values);
        let d1 = get_d(&new_values, amp, n_coins);
        assert!(d1 > d0, EInvalidDeposit);
        
        let mut d2 = d1; 
        let mut ideal_value: u64 = 0; 
        let mut total_fees = vector::empty<u64>();
        let mut admin_fees = vector::empty<u64>();

        if (token_supply > 0) {
            let mut i = 0;
            while (i < n_coins) {
                let old_value = *vector::borrow(&pool.values, i);
                let mut new_value = *vector::borrow(&new_values, i);
                let ideal_value = (d1 * old_value) / d0;
                let difference = if (ideal_value > new_value) {
                    ideal_value - new_value
                } else {
                    new_value - ideal_value
                };
                let total_fee = fee * difference / FEE_DENOMINATOR;
                let fee =  total_fee * admin_fee  / FEE_DENOMINATOR;
                *vector::borrow_mut<u64>(&mut pool.values, i) = new_value - fee; 
                *vector::borrow_mut<u64>(&mut new_values, i) = new_value - total_fee; 
                vector::push_back(&mut total_fees, total_fee);
                vector::push_back(&mut admin_fees, fee);
                i = i + 1;
            };
            d2 = get_d(&new_values, amp, n_coins);
        } else {
            total_fees = empty_values(total_fees, n_coins);
            admin_fees = empty_values(admin_fees, n_coins);

            let mut i = 0;
            while (i < n_coins) {
                *vector::borrow_mut<u64>(&mut pool.values, i) = *vector::borrow(&new_values, i); 
                i = i + 1;
            };
        };

        let mint_amount = if (token_supply == 0) {
            d1
        } else {
            (d2 - d0) * token_supply / d0
        };

        assert! (mint_amount > min_mint_amount, EInvalidMinMintAmount);

        // TODO: Emit event with total fees 

        Liquidity {
            values,
            admin_fees: admin_fees,
            types: vector::empty(),
            mint_amount: mint_amount,
        }
    }

    public fun add_liquidity<I>(mut dx_coin_option: Option<Coin<I>>, liquidity: &mut Liquidity, pool: &mut Pool, ctx: &mut TxContext): &mut Liquidity {
        assert!(pool.is_locked, EUnlockedPool);
        let type_str_i = type_name::into_string(type_name::get<I>());
        let (i_present, i_index) = vector::index_of(&pool.types, &type_str_i);
        assert!(i_present, EWrongLiquidityCoin);
        assert!(!vector::contains(&liquidity.types, &type_str_i), ETokenAlreadyAdded);
        vector::push_back(&mut liquidity.types, type_str_i);

        let mut dx_coin = option::extract(&mut dx_coin_option);
        if (coin::value(&dx_coin) > 0) {
            let dx_value = coin::value(&dx_coin);
            let x_balance = bag::borrow_mut<String, Balance<I>>(&mut pool.balances, type_str_i);
            let x_value = balance::value(x_balance);

            let mut i_value = *vector::borrow(&pool.values, i_index);
            let mut i_fee = *vector::borrow(&liquidity.admin_fees, i_index);
            
            assert!(i_value + i_fee == x_value + dx_value, EInvalidDeposit);

            let fee_coin = coin::split<I>(&mut dx_coin, i_fee, ctx);
            let dx_balance = coin::into_balance(dx_coin);
            let fee_balance = coin::into_balance(fee_coin);
            balance::join(x_balance, dx_balance);
            let admin_fee_balance = bag::borrow_mut<String, Balance<I>>(&mut pool.admin_fee_balances, type_str_i);
            balance::join(admin_fee_balance, fee_balance);
        } else {
            assert!(*vector::borrow(&liquidity.values, i_index) == 0, EInvalidValue);
            coin::destroy_zero(dx_coin);
        };

        option::destroy_none(dx_coin_option);
        liquidity
    }

    public fun finish_add_liquidity(liquidity: Liquidity, pool: &mut Pool, ctx: &mut TxContext): Coin<LP> {
        let Liquidity { values, admin_fees, types, mint_amount } = liquidity;
        assert!(vector::length(&types) == pool.n_coins, EInvalidCoinNo);
        
        let coin = coin::mint(&mut pool.lp_treasury, mint_amount, ctx);
        pool.lp_supply = pool.lp_supply + mint_amount;
        
        coin
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
        assert!(pool.is_locked, EUnlockedPool);
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

        // TO DO: Extract fees from dy

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


    fun init_lp(witness: LP, ctx: &mut TxContext): TreasuryCap<LP> {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"SSLP", b"Stableswap LP", b"Token representing LP shares in a stableswap pool", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        treasury
    }

    fun get_values_sum(values: &vector<u64>): u64 {
        let mut sum = 0;
        let length = vector::length(values);
        let mut i = 0;
        while (i < length) {
            sum = sum + *vector::borrow(values, i);
            i = i + 1;
        };
        sum
    }

    fun add_values(values1: &vector<u64>, values2: &vector<u64>): vector<u64> {
        let length = vector::length(values1);
        assert!(length == vector::length(values2), EInvalidAdd);
        let mut i = 0;
        let mut sum = vector::empty<u64>();
        while (i < length) {
            vector::push_back(&mut sum, *vector::borrow(values1, i) + *vector::borrow(values2, i));
            i = i + 1;
        };
        sum
    }

    fun valid_first_deposit(values: &vector<u64>): bool {
        let length = vector::length(values);
        let mut i = 0;
        while (i < length) {
            if (*vector::borrow(values, i) == 0) {
                return false
            };
            i = i + 1;
        };
        true
    }

    fun empty_values(mut values: vector<u64>, length: u64): vector<u64> {
        let mut i = 0;
        while (i < length) {
            vector::push_back(&mut values, 0);
            i = i + 1;
        };
        values
    }

}
