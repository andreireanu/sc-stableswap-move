#[test_only]
module stableswap::btc5 {
    use sui::coin;

    public struct BTC5 has drop {}

    fun init(witness: BTC5, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"BTC5",
            b"Bitcoin 5",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }

    public fun init_for_testing(ctx: &mut TxContext) {
        init(BTC5 {}, ctx);
    }
} 