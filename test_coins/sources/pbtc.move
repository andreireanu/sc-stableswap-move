module test_coins::pbtc {
    use sui::coin::{Self, TreasuryCap};

    public struct PBTC has drop {}

    /// Initialize the pBTC coin
    fun init(witness: PBTC, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"BTC",
            b"P Bitcoin",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// Mint new pBTC coins
    public fun mint(treasury: &mut TreasuryCap<PBTC>, amount: u64, ctx: &mut TxContext): coin::Coin<PBTC> {
        coin::mint(treasury, amount, ctx)
    }
} 