module stableswap::sbtc {
    use sui::coin::{Self, TreasuryCap};

    public struct SBTC has drop {}

    /// Initialize the sBTC coin
    fun init(witness: SBTC, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"sBTC",
            b"S Bitcoin",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, tx_context::sender(ctx));
    }

    /// Mint new sBTC coins
    public fun mint(treasury: &mut TreasuryCap<SBTC>, amount: u64, ctx: &mut TxContext): coin::Coin<SBTC> {
        coin::mint(treasury, amount, ctx)
    }
} 