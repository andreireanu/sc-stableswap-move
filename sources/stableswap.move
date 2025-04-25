module stableswap::stableswap {

    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin, TreasuryCap};
    use std::type_name;
    use sui::bag::{Self, Bag};
    use std::ascii::String;
    use stableswap::lp::LP;
    use stableswap::math::{get_d, get_y, get_values_sum, add_values, valid_first_deposit, empty_values};
    use std::debug;

    // ======== Constants ========
    const FEE_DENOMINATOR: u64 = 10000;

    // ======== Errors ========
    const ESlippageExceeded: u64 = 1;
    const EWrongCoinInType: u64 = 2;
    const EWrongCoinOutType: u64 = 3;
    const EWrongLiquidityCoin: u64 = 4;
    const EUnlockedPool: u64 = 5;
    const ELockedPool: u64 = 6;
    const EInvalidFirstDeposit: u64 = 7;
    const EAlreadyAddedCoin: u64 = 8;
    const EInvalidDeposit: u64 = 9;
    const EInvalidMinMintAmount: u64 = 10;
    const EInvalidCoinNumber: u64 = 11;

    // ======== Pool Structure ========
    public struct Pool has key {
        id: UID,
        types: vector<String>,
        balances: Bag,
        values: vector<u64>,
        lp_supply: u64,
        lp_treasury: TreasuryCap<LP>,
        amp: u64,
        fee: u64,
        admin_fee: u64,
        fee_balances: Bag,
        is_locked: bool,
        is_killed: bool,
        owner: address,
    }

    public struct AdminCap has key, store {  
        id: UID
    }

    // Structure to store liquidity while adding
    public struct AddLiquidity {         
        values: vector<u64>,
        admin_fees: vector<u64>,
        types: vector<String>,
        mint_amount: u64,
    }

    // Structure to store liquidity while removing
    public struct RemoveLiquidity {         
        balance: Balance<LP>,
        types: vector<String>,
    }

    /// Initializes the stableswap module by creating and transferring an AdminCap to the sender.
    /// 
    /// # Arguments
    /// * `ctx` - Transaction context
    /// 
    /// # Effects
    /// * Creates a new AdminCap object
    /// * Transfers the AdminCap to the transaction sender
    fun init (ctx: &mut TxContext) {
        transfer::public_transfer(AdminCap {id: object::new(ctx)}, tx_context::sender(ctx));
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
        _ : &AdminCap,
        owner: address,
        amp: u64,
        fee: u64,
        admin_fee: u64,
        lp_treasury: TreasuryCap<LP>,
        ctx: &mut TxContext
    ) {
        let pool = Pool {
            id: object::new(ctx),
            types: vector::empty(),
            balances: bag::new(ctx),
            values: vector::empty(),
            lp_supply: 0,
            lp_treasury: lp_treasury,
            amp: amp,
            fee: fee,  // General fee
            admin_fee: admin_fee,    // Fee out of the general fee   
            fee_balances: bag::new(ctx),
            is_locked: false,
            is_killed: false,
            owner: owner,
        };
        transfer::share_object(pool);
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
        assert!(!pool.types.contains(&type_str_i) , EAlreadyAddedCoin);
        pool.types.push_back(type_str_i);
        pool.balances.add(type_str_i, balance::zero<I>());
        pool.values.push_back(0);
        pool.fee_balances.add(type_str_i, balance::zero<I>());
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
    ): AddLiquidity {
        assert!(pool.is_locked, EUnlockedPool);
        
        let n_coins = vector::length(&pool.types);
        assert!(vector::length(&values) == n_coins, EInvalidCoinNumber);

        let amp = pool.amp;
        let admin_fee = pool.admin_fee;
        let token_supply = get_values_sum(&pool.values);
        let fee = pool.fee * n_coins / (4 * (n_coins - 1 )); // TODO: Check how this is derived

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
        let mut _total_fees = vector::empty<u64>();
        let mut admin_fees = vector::empty<u64>();

        if (token_supply > 0) {
            let mut i = 0;
            while (i < n_coins) {
                let old_value = *pool.values.borrow(i);
                let new_value = *new_values.borrow(i);
                let ideal_value = (d1 * old_value) / d0;
                let difference = if (ideal_value > new_value) {
                    ideal_value - new_value
                } else {
                    new_value - ideal_value
                };
                let total_fee_val = fee * difference / FEE_DENOMINATOR;
                let admin_fee_val =  total_fee_val * admin_fee  / FEE_DENOMINATOR;
                // We deduct the fee from the pool value to add to the admin fee
                // The total fee is only removed for calculating the new D2 
                // so the difference between total_fee and fee increases LP value
                *pool.values.borrow_mut(i) = new_value - admin_fee_val; 
                *new_values.borrow_mut(i) = new_value - total_fee_val; 
                _total_fees.push_back(total_fee_val);
                admin_fees.push_back(admin_fee_val);
                i = i + 1;
            };
            d2 = get_d(&new_values, amp, n_coins);
        } else {
            _total_fees = empty_values(_total_fees, n_coins);
            admin_fees = empty_values(admin_fees, n_coins);

            let mut i = 0;
            while (i < n_coins) {
                *pool.values.borrow_mut(i) = *new_values.borrow(i); 
                i = i + 1;
            };
        };

        let mint_amount = if (token_supply == 0) {
            d1
        } else {
            (d2 - d0) * token_supply / d0
        };

        assert! (mint_amount > min_mint_amount, EInvalidMinMintAmount);

        AddLiquidity {
            values,
            admin_fees: admin_fees,
            types: vector::empty(),
            mint_amount: mint_amount,
        }

    }

    /// Adds liquidity for a specific coin type to the pool.
    /// 
    /// # Arguments
    /// * `dx_coin_option` - Optional coin to add to the pool
    /// * `liquidity` - Current liquidity state
    /// * `pool` - The pool to add liquidity to
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `I` - Type of the coin being added
    /// 
    /// # Returns
    /// * Updated liquidity state
    /// 
    /// # Aborts
    /// * If pool is not locked
    /// * If coin type is not in the pool
    /// * If coin type is already added in this liquidity operation
    /// * If deposit amount doesn't match expected value
    public fun add_liquidity<I>(mut dx_coin_option: Option<Coin<I>>, liquidity: &mut AddLiquidity, pool: &mut Pool, ctx: &mut TxContext): &mut AddLiquidity {
        assert!(pool.is_locked, EUnlockedPool);
        let type_str_i = type_name::into_string(type_name::get<I>());
        let (i_present, i_index) = vector::index_of(&pool.types, &type_str_i); 
        assert!(i_present, EWrongLiquidityCoin);
        assert!(!vector::contains(&liquidity.types, &type_str_i), EAlreadyAddedCoin);
        liquidity.types.push_back(type_str_i);

        let dx_coin = if (option::is_none(&dx_coin_option)) {
            coin::zero<I>(ctx)
        } else {
            option::extract(&mut dx_coin_option)
        };
        let i_fee = *liquidity.admin_fees.borrow(i_index);

        
        let dx_value = coin::value(&dx_coin);
        assert!(liquidity.values.borrow(i_index) == dx_value, EInvalidDeposit);

        let x_balance = pool.balances.borrow_mut(type_str_i);
        let x_value = balance::value(x_balance);

        let i_value = *pool.values.borrow(i_index);
        assert!(i_value + i_fee == x_value + dx_value, EInvalidDeposit);

        let dx_balance = coin::into_balance(dx_coin);
        let fee_balance = x_balance.split<I>(i_fee);
        balance::join(x_balance, dx_balance);
        let fee_balances = pool.fee_balances.borrow_mut(type_str_i);
        balance::join(fee_balances, fee_balance);
 
        option::destroy_none(dx_coin_option);
        liquidity
    }

    /// Finalizes the liquidity addition process and mints LP tokens.
    /// 
    /// # Arguments
    /// * `liquidity` - Final liquidity state
    /// * `pool` - The pool to add liquidity to
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// * Newly minted LP tokens
    /// 
    /// # Aborts
    /// * If the number of coin types doesn't match the pool's types
    public fun finish_add_liquidity(liquidity: AddLiquidity, pool: &mut Pool, ctx: &mut TxContext): Coin<LP> {
        let AddLiquidity { values: _, admin_fees: _, types, mint_amount } = liquidity;
        assert!(types.length() == pool.types.length(), EInvalidCoinNumber);

        let coin = coin::mint(&mut pool.lp_treasury, mint_amount, ctx);
        pool.lp_supply = pool.lp_supply + mint_amount;

        coin
    }

    /// Initializes the liquidity removal process.
    /// 
    /// # Arguments
    /// * `lp_coin` - LP tokens to remove
    /// 
    /// # Returns
    /// * Initialized RemoveLiquidity state
    public fun init_remove_liquidity(lp_coin: Coin<LP>): RemoveLiquidity  {
        let lp_balance = coin::into_balance(lp_coin);
        let remove_liquidity = RemoveLiquidity { balance: lp_balance, types: vector::empty()};
        remove_liquidity
    }

    /// Removes liquidity for a specific coin type from the pool.
    /// 
    /// # Arguments
    /// * `liquidity` - Current liquidity removal state
    /// * `pool` - The pool to remove liquidity from
    /// * `ctx` - Transaction context
    /// 
    /// # Type Parameters
    /// * `I` - Type of the coin to remove
    /// 
    /// # Returns
    /// * Tuple containing the removed coin and updated liquidity state
    /// 
    /// # Aborts
    /// * If coin type is not in the pool
    /// * If coin type is already removed in this operation
    public fun remove_liquidity<I>(mut liquidity: RemoveLiquidity, pool: &mut Pool, ctx: &mut TxContext): (Coin<I>, RemoveLiquidity) {
        let lp_value = liquidity.balance.value();
        let type_str_i = type_name::into_string(type_name::get<I>());
        let (i_present, i_index) = vector::index_of(&pool.types, &type_str_i); 
        assert!(i_present, EWrongLiquidityCoin);
        assert!(!vector::contains(&liquidity.types, &type_str_i), EAlreadyAddedCoin);
        liquidity.types.push_back(type_str_i);

        let i_value = *pool.values.borrow(i_index);
        let return_value = i_value * lp_value / pool.lp_supply;

        let i_coin =  pool.balances.borrow_mut(type_str_i);
        let return_balance = balance::split<I>( i_coin, return_value);
        let return_coin = coin::from_balance(return_balance, ctx);
        (return_coin, liquidity)
    }

    /// Finalizes the liquidity removal process and burns LP tokens.
    /// 
    /// # Arguments
    /// * `liquidity` - Final liquidity removal state
    /// * `pool` - The pool to remove liquidity from
    /// * `ctx` - Transaction context
    /// 
    /// # Effects
    /// * Burns LP tokens
    /// * Updates pool's LP supply
    public fun finish_remove_liquidity(liquidity: RemoveLiquidity, pool: &mut Pool, ctx: &mut TxContext)  {
        let RemoveLiquidity { balance, types: _ } = liquidity;
        let value = balance.value();
        coin::burn(&mut pool.lp_treasury, coin::from_balance(balance, ctx));
        pool.lp_supply = pool.lp_supply - value;
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
        let (i_present, i_index) = pool.types.index_of(&type_str_i);
        assert!(i_present, EWrongCoinInType);
        let type_str_j = type_name::into_string(type_name::get<J>());
        let (j_present, j_index) = pool.types.index_of(&type_str_j);
        assert!(j_present, EWrongCoinOutType);  

        let dx = coin::value(&dx_coin);
        let y_new = exchange(i_index, j_index, dx, pool);
        let y_value = pool.values.borrow(j_index);
        let dy = *y_value - y_new;
        assert!(dy >= min_dy, ESlippageExceeded);

        increase_balance(pool, type_str_i, i_index, dx_coin); 
        let mut dy_coin = decrease_balance<J>(pool, type_str_j, j_index, dy, ctx); 
        
        let dy_value = coin::value(&dy_coin);
        let fee = dy_value * pool.fee / FEE_DENOMINATOR;
        let dy_fee_coin = coin::split<J>(&mut dy_coin, fee, ctx);
        let fee_balances = pool.fee_balances.borrow_mut(type_str_j);
        balance::join(fee_balances, coin::into_balance(dy_fee_coin));

        // TODO: Emit event with fee, dy_fee
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
        let x_value = pool.values.borrow_mut(i_index);
        *x_value = *x_value + dx_value;
        let x_balance = pool.balances.borrow_mut(type_str_i);
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
        let y_value = pool.values.borrow_mut(j_index);
        *y_value = *y_value - dy;
        let y_balance = pool.balances.borrow_mut(type_str_j);
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
        let pool_n_coins = pool.types.length();
        let amp = pool.amp;
        let pool_values = &pool.values;
        get_y(i, j, dx, pool_values, amp, pool_n_coins)
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun debug_pool_values(pool: &Pool) {
        debug::print(&pool.values);
    }

    #[test_only]
    public fun debug_pool_types(pool: &Pool) {
        debug::print(&pool.types);
    }

    #[test_only]
    public fun debug_pool_amp(pool: &Pool) {
        debug::print(&pool.amp);
    }

    #[test_only]
    public fun debug_pool_lp_supply(pool: &Pool) {
        debug::print(&pool.lp_supply);
    }

    #[test_only]
    public fun debug_pool_state(pool: &Pool) {
        debug::print(&pool.values);
        debug::print(&pool.types);
        debug::print(&pool.amp);
        debug::print(&pool.lp_supply);
        debug::print(&pool.is_locked);
        debug::print(&pool.is_killed);
    }

    #[test_only]
    public fun get_pool_values(pool: &Pool): &vector<u64> {
        &pool.values
    }

    #[test_only]
    public fun get_pool_balances(pool: &Pool): &Bag {
        &pool.balances
    }

    #[test_only]
    public fun get_pool_fee_balances(pool: &Pool): &Bag {
        &pool.fee_balances
    }

    #[test_only]
    public fun get_pool_lp_supply(pool: &Pool): u64 {
        pool.lp_supply
    }

}