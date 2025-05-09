#[test_only]
module stableswap::btc4 {
    use sui::coin;

    public struct BTC4 has drop {}

    fun init(witness: BTC4, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"BTC4",
            b"Bitcoin 4",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }

    public fun init_for_testing(ctx: &mut TxContext) {
        init(BTC4 {}, ctx);
    }
} 