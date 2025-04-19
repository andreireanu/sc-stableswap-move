#[test_only]
module stableswap::deposit_test
{
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::{Self, TxContext};
    use sui::test_scenario::{Self, Scenario};
    use sui::object;
    use std::option;
    use std::vector;
    use stableswap::stableswap::{Self, Pool, AdminCap, AddLiquidity};
    use stableswap::lp::{Self, LP};
    use stableswap::btc1::{Self, BTC1};
    use stableswap::btc2::{Self, BTC2};
    use stableswap::btc3::{Self, BTC3};
    use stableswap::btc4::{Self, BTC4};
    use stableswap::btc5::{Self, BTC5};

    #[test]
    fun test_deposit() {
        let owner = @0x0;

        let mut scenario = test_scenario::begin(owner);

        // Initialize the pool
        test_scenario::next_tx(&mut scenario, owner);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            stableswap::init_for_testing(ctx);
            lp::init_for_testing(ctx);
        };

        // Create the pool  
        test_scenario::next_tx(&mut scenario, owner);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let lp_treasury = test_scenario::take_from_sender<TreasuryCap<LP>>(&scenario);
            let ctx = test_scenario::ctx(&mut scenario);
            
            stableswap::create_pool(
                &admin_cap,
                owner,
                100, // amp
                0,   // fee (0.04%)
                0,  // admin_fee (50% of fee)
                lp_treasury,
                ctx
            );
            
            test_scenario::return_to_sender(&scenario, admin_cap);
        };
        
        // Initialize all BTC types
        test_scenario::next_tx(&mut scenario, owner);
        {
            let ctx = test_scenario::ctx(&mut scenario);
            btc1::init_for_testing(ctx);
            btc2::init_for_testing(ctx);
            btc3::init_for_testing(ctx);
            btc4::init_for_testing(ctx);
            btc5::init_for_testing(ctx);
        };
        
        // Third transaction - add types and lock pool
        test_scenario::next_tx(&mut scenario, owner);
        {
            let admin_cap = test_scenario::take_from_sender<AdminCap>(&scenario);
            let mut pool = test_scenario::take_shared<Pool>(&scenario);

            stableswap::add_type<BTC1>(&admin_cap, &mut pool);
            stableswap::add_type<BTC2>(&admin_cap, &mut pool);
            stableswap::add_type<BTC3>(&admin_cap, &mut pool);
            stableswap::add_type<BTC4>(&admin_cap, &mut pool);
            stableswap::add_type<BTC5>(&admin_cap, &mut pool);
            stableswap::lock_pool(&admin_cap, &mut pool);

            test_scenario::return_to_sender(&scenario, admin_cap);
            test_scenario::return_shared(pool);
        };

        // Fourth transaction - add initial liquidity
        test_scenario::next_tx(&mut scenario, owner);
        {
            let mut pool = test_scenario::take_shared<Pool>(&scenario);

            // Get TreasuryCap for each coin type
            let mut btc1_treasury = test_scenario::take_from_sender<TreasuryCap<BTC1>>(&scenario);
            let mut btc2_treasury = test_scenario::take_from_sender<TreasuryCap<BTC2>>(&scenario);
            let mut btc3_treasury = test_scenario::take_from_sender<TreasuryCap<BTC3>>(&scenario);
            let mut btc4_treasury = test_scenario::take_from_sender<TreasuryCap<BTC4>>(&scenario);
            let mut btc5_treasury = test_scenario::take_from_sender<TreasuryCap<BTC5>>(&scenario);

            // Create deposit amounts vector  
            let mut values = vector::empty<u64>();
            vector::push_back(&mut values, 1_000_100_000);
            vector::push_back(&mut values, 1_000_200_000);
            vector::push_back(&mut values, 1_000_300_000);
            vector::push_back(&mut values, 1_000_400_000);
            vector::push_back(&mut values, 1_000_500_000);

            // Print pool state before initialization
            // stableswap::debug_pool_state(&pool);0

            // Initialize liquidity addition
            let mut liquidity = stableswap::init_add_liquidity(&mut pool, values, 0);

            let ctx = test_scenario::ctx(&mut scenario);

            // Add liquidity for each coin type
            let btc1_coin = coin::mint(&mut btc1_treasury, 1_000_100_000, ctx);
            stableswap::add_liquidity<BTC1>(option::some(btc1_coin), &mut liquidity, &mut pool, ctx);

            let btc2_coin = coin::mint(&mut btc2_treasury, 1_000_200_000, ctx);
            stableswap::add_liquidity<BTC2>(option::some(btc2_coin), &mut liquidity, &mut pool, ctx);

            let btc3_coin = coin::mint(&mut btc3_treasury, 1_000_300_000, ctx);
            stableswap::add_liquidity<BTC3>(option::some(btc3_coin), &mut liquidity, &mut pool, ctx);

            let btc4_coin = coin::mint(&mut btc4_treasury, 1_000_400_000, ctx);
            stableswap::add_liquidity<BTC4>(option::some(btc4_coin), &mut liquidity, &mut pool, ctx);

            let btc5_coin = coin::mint(&mut btc5_treasury, 1_000_500_000, ctx);
            stableswap::add_liquidity<BTC5>(option::some(btc5_coin), &mut liquidity, &mut pool, ctx);

            // Finish adding liquidity and get LP tokens
            let lp_coin = stableswap::finish_add_liquidity(liquidity, &mut pool, ctx);
            
            // Send LP coin to the caller
            transfer::public_transfer(lp_coin, owner);
            
            // Return TreasuryCap objects
            test_scenario::return_to_sender(&scenario, btc1_treasury);
            test_scenario::return_to_sender(&scenario, btc2_treasury);
            test_scenario::return_to_sender(&scenario, btc3_treasury);
            test_scenario::return_to_sender(&scenario, btc4_treasury);
            test_scenario::return_to_sender(&scenario, btc5_treasury);
            
            test_scenario::return_shared(pool);
        };
        
        test_scenario::end(scenario);
    }
}