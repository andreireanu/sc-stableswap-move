module stableswap::math {
    use std::debug;
    
    // ======== Constants ========
    const MAX_ITERATIONS: u64 = 255;

    // ======== Errors ========
    const EInvalidCoin: u64 = 1;
    const ENoConvergence: u64 = 2;
    const EInvalidCoinNo: u64 = 3;
    const EInvalidAdd: u64 = 4;

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
    public fun get_d(values: &vector<u64>, amp: u64, pool_n_coins: u64): u64 {
        let n_coins = values.length();
        assert!(n_coins == pool_n_coins, EInvalidCoinNo);

        // Calculate sum of all values
        let mut s: u256 = 0;
        let mut i = 0;
        let n_coins_u256 = n_coins as u256;
        while (i < n_coins) {
            s = s + (*values.borrow(i) as u256);
            i = i + 1;
        };

        if (s == 0) {
            return 0
        };

        // Calculate Ann = A * n^n
        let ann = (amp * n_coins.pow(n_coins as u8)) as u256;

        // Initial guess for D using sum of values
        let mut d = s;
        let mut d_prev: u256;
        let mut d_p : u256;

        // Newton's method
        i = 0;
        while (i < MAX_ITERATIONS) {
            // Calculate D_P = D^(n+1) / (n^n * prod(x_i))
            d_p = d;

            // Calculate product term for each balance
            let mut j = 0;
            while (j < n_coins) {
                let balance = *values.borrow(j);
                if (balance > 0) {
                    d_p = (d_p * d) / ((balance as u256) * n_coins_u256);
                };
                j = j + 1;
            };

            // Store current d value before updating
            d_prev = d;

            // d = (Ann * S + D_P * n) * D / ((Ann - 1) * D + (n + 1) * D_P)
            let numerator = (ann * s + d_p * n_coins_u256) * d;
            let denominator = (ann - 1) * d + (n_coins_u256 + 1) * d_p;
            d = numerator / denominator;

            // Check for convergence with precision of 1
            if (d > d_prev) {
                if (d - d_prev <= 1) {
                    let d_u64 = d.try_as_u64().extract();
                    return d_u64
                }
            } else {
                if (d_prev - d <= 1) {
                    let d_u64 = d.try_as_u64().extract();
                    return d_u64
                }
            };

            i = i + 1;
        };

        abort ENoConvergence
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
    public fun get_y(i: u64, j: u64, dx: u64, values: &vector<u64>, amp: u64, pool_n_coins: u64): u64 {
        // Input validation
        assert!(i != j, EInvalidCoin);
        assert!(j < pool_n_coins, EInvalidCoin);

        // Get D and calculate Ann
        let d = get_d(values, amp, pool_n_coins) as u256;
        let ann = (amp * pool_n_coins.pow(pool_n_coins as u8)) as u256;
        let pool_n_coins_u256 = pool_n_coins as u256;

        // Initialize variables
        let mut c = d;
        let mut s : u256 = 0;

        // Calculate S_ and c
        let mut k = 0;
        while (k < pool_n_coins) {
            let x_temp = if (k == i) {
                *values.borrow(k) + dx
            } else if (k != j) {
                *values.borrow(k)
            } else {
                k = k + 1;
                continue
            };
            let x_temp_u256 = x_temp as u256;
            s = s + x_temp_u256;
            c = (c * d) / (x_temp_u256 * pool_n_coins_u256);
            k = k + 1;
            
        };

        // Calculate c and b
        c = (c * d) / (ann * pool_n_coins_u256);
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
                    let y_u64 = y.try_as_u64().extract();   
                    return y_u64
                }
            } else {
                if (y_prev - y <= 1) {
                    let y_u64 = y.try_as_u64().extract();
                    return y_u64
                }
            };

            k = k + 1;
        };

        abort ENoConvergence
    }

    /// Calculates the sum of all values in a vector.
    /// 
    /// # Arguments
    /// * `values` - Vector of u64 values to sum
    /// 
    /// # Returns
    /// * The sum of all values in the vector
    public fun get_values_sum(values: &vector<u64>): u64 {
        let mut sum = 0;
        let length = values.length();
        let mut i = 0;
        while (i < length) {
            sum = sum + *values.borrow(i);
            i = i + 1;
        };
        sum
    }

    /// Adds corresponding elements from two vectors element-wise.
    /// 
    /// # Arguments
    /// * `values1` - First vector of u64 values
    /// * `values2` - Second vector of u64 values
    /// 
    /// # Returns
    /// * A new vector where each element is the sum of corresponding elements from the input vectors
    /// 
    /// # Aborts
    /// * If the input vectors have different lengths
    public fun add_values(values1: &vector<u64>, values2: &vector<u64>): vector<u64> {
        let length = values1.length();
        assert!(length == values2.length(), EInvalidAdd);
        let mut i = 0;
        let mut sum = vector::empty<u64>();
        while (i < length) {
            sum.push_back(*values1.borrow(i) + *values2.borrow(i));
            i = i + 1;
        };
        sum
    }

    /// Validates if a vector of values is suitable for the first deposit in a pool.
    /// 
    /// # Arguments
    /// * `values` - Vector of u64 values to validate
    /// 
    /// # Returns
    /// * `true` if all values are non-zero, `false` otherwise
    /// 
    /// # Note
    /// This is used to ensure the first deposit in a pool has non-zero values for all coins
    public fun valid_first_deposit(values: &vector<u64>): bool {
        let length = values.length();
        let mut i = 0;
        while (i < length) {
            if (*values.borrow(i) == 0) {
                return false
            };
            i = i + 1;
        };
        true
    }

    /// Creates a vector of zeros with the specified length.
    /// 
    /// # Arguments
    /// * `values` - Vector to fill with zeros
    /// * `length` - Desired length of the vector
    /// 
    /// # Returns
    /// * The input vector filled with zeros up to the specified length
    public fun empty_values(mut values: vector<u64>, length: u64): vector<u64> {
        let mut i = 0;
        while (i < length) {
            values.push_back(0);
            i = i + 1;
        };
        values
    }
} 