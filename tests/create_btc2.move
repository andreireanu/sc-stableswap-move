#[test_only]
module stableswap::btc2 {
    use sui::coin;

    public struct BTC2 has drop {}

    fun init(witness: BTC2, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            8,
            b"BTC2",
            b"Bitcoin 2",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }

    public fun init_for_testing(ctx: &mut TxContext) {
        init(BTC2 {}, ctx);
    }
} 