#[test_only]
module stableswap::btc3 {
    use sui::coin;

    public struct BTC3 has drop {}

    fun init(witness: BTC3, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"BTC3",
            b"Bitcoin 3",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }

    public fun init_for_testing(ctx: &mut TxContext) {
        init(BTC3 {}, ctx);
    }
} 