module stableswap::lp {
    use sui::coin::{Self};

    // LP Token representation
    public struct LP has drop {}

    /// Initializes the LP token for the pool.
    /// 
    /// # Arguments
    /// * `witness` - LP witness token
    /// * `ctx` - Transaction context
    /// 
    /// # Returns
    /// * Treasury capability for the LP token
    /// 
    /// # Effects
    /// * Creates a new LP token with specified metadata
    /// * Freezes the token metadata
    fun init(witness: LP, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(witness, 9, b"SSLP", b"Stableswap LP", b"Token representing LP shares in a stableswap pool", option::none(), ctx);
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }
 

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        init(LP{}, ctx);
    }
}