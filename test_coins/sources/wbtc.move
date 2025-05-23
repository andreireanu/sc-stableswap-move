module test_coins::wbtc {
    use sui::coin::{Self, TreasuryCap};

    public struct WBTC has drop {}

    /// Initialize the wBTC coin
    fun init(witness: WBTC, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"BTC",
            b"W Bitcoin",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// Mint new wBTC coins
    public fun mint(treasury: &mut TreasuryCap<WBTC>, amount: u64, ctx: &mut TxContext): coin::Coin<WBTC> {
        coin::mint(treasury, amount, ctx)
    }
} 