module stableswap::rbtc {
    use sui::coin::{Self, TreasuryCap};

    public struct RBTC has drop {}

    /// Initialize the rBTC coin
    fun init(witness: RBTC, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"BTC",
            b"R Bitcoin",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// Mint new rBTC coins
    public fun mint(treasury: &mut TreasuryCap<RBTC>, amount: u64, ctx: &mut TxContext): coin::Coin<RBTC> {
        coin::mint(treasury, amount, ctx)
    }
} 