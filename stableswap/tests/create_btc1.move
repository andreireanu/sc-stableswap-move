#[test_only]
module stableswap::btc1 {
    use sui::coin;

    public struct BTC1 has drop {}

    fun init(witness: BTC1, ctx: &mut TxContext) {
        let (treasury, metadata) = coin::create_currency(
            witness,
            9,
            b"BTC1",
            b"Bitcoin 1",
            b"",
            option::none(),
            ctx
        );
        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury, ctx.sender())
    }

    public fun init_for_testing(ctx: &mut TxContext) {
        init(BTC1 {}, ctx);
    }
} 