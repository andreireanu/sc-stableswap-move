module test_coins::zbtc {
    use sui::coin::{Self, TreasuryCap};

    public struct ZBTC has drop {}

    /// Initialize the zBTC coin
    fun init(witness: ZBTC, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"BTC",
            b"Z Bitcoin",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// Mint new zBTC coins
    public fun mint(treasury: &mut TreasuryCap<ZBTC>, amount: u64, ctx: &mut TxContext): coin::Coin<ZBTC> {
        coin::mint(treasury, amount, ctx)
    }
} 