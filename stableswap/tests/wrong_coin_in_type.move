#[test_only]
module stableswap::wrong_coin_in_type
{
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::test_scenario;
    use stableswap::stableswap::{Self, Pool, AdminCap};
    use stableswap::lp::{Self, LP};
    use stableswap::btc1::{Self, BTC1};
    use stableswap::btc2::{Self, BTC2};
    use stableswap::btc3::{Self, BTC3};
    use stableswap::btc4::{Self, BTC4};
    use stableswap::btc5::{Self, BTC5};
    use std::type_name;
    use sui::balance::{Self, Balance};
    use std::ascii::String;

    #[test, expected_failure(abort_code = ::stableswap::stableswap::EWrongCoinInType)]
    fun test_wrong_coin_in_type() {
        let owner = @0x0;
        let swapper = @0x1;

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
                100,  
                100, // 1% fee
                10000,  // 100% fee goes to admin 
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
            let mut btc3_treasury = test_scenario::take_from_sender<TreasuryCap<BTC3>>(&scenario);
            let mut btc4_treasury = test_scenario::take_from_sender<TreasuryCap<BTC4>>(&scenario);
            let mut btc5_treasury = test_scenario::take_from_sender<TreasuryCap<BTC5>>(&scenario);

            // Create deposit amounts vector  
            let mut values = vector::empty<u64>();
            vector::push_back(&mut values, 1_000_100_000);
            vector::push_back(&mut values, 1_000_300_000);
            vector::push_back(&mut values, 1_000_400_000);
            vector::push_back(&mut values, 1_000_500_000);

            // Initialize liquidity addition
            let mut liquidity = stableswap::init_add_liquidity(&mut pool, values, 0);

            let ctx = test_scenario::ctx(&mut scenario);

            // Add liquidity for each coin type
            let btc1_coin = coin::mint(&mut btc1_treasury, 1_000_100_000, ctx);
            stableswap::add_liquidity<BTC1>(option::some(btc1_coin), &mut liquidity, &mut pool, ctx);

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
            test_scenario::return_to_sender(&scenario, btc3_treasury);
            test_scenario::return_to_sender(&scenario, btc4_treasury);
            test_scenario::return_to_sender(&scenario, btc5_treasury);
            
            test_scenario::return_shared(pool);
        };

        // Sixth transaction - transfer BTC2 TreasuryCap to swapper
        test_scenario::next_tx(&mut scenario, owner);
        {
            let btc2_treasury = test_scenario::take_from_sender<TreasuryCap<BTC2>>(&scenario);
            transfer::public_transfer(btc2_treasury, swapper);
        };

        // Seventh transaction - exchange BTC2 for BTC3
        // Rate is 1_000_000 to 1_000_001 without accounting for fees
        test_scenario::next_tx(&mut scenario, swapper);
        {
            let mut pool = test_scenario::take_shared<Pool>(&scenario);

            // Get TreasuryCap for BTC2
            let mut btc2_treasury = test_scenario::take_from_sender<TreasuryCap<BTC2>>(&scenario);

            let ctx = test_scenario::ctx(&mut scenario);

            // Mint BTC2 coin for exchange
            let btc2_coin = coin::mint(&mut btc2_treasury, 1_000_000, ctx);

            // Exchange BTC2 for BTC3 with minimum output of 0 (no slippage protection for testing)
            let btc3_coin = stableswap::exchange_coin<BTC2, BTC3>(0, btc2_coin, &mut pool, ctx);
            assert!(coin::value<BTC3>(&btc3_coin) == 990_001, 0);

            // Assert values
            let values = stableswap::get_pool_values(&pool);
            assert!(vector::borrow(values, 0) == 1_099_851_988, 0);  // First coin value after fees
            assert!(vector::borrow(values, 1) == 1_001_138_007, 0);  // Second coin value after fees
            assert!(vector::borrow(values, 2) == 999_238_000, 0);    // Third coin value after fees
            assert!(vector::borrow(values, 3) == 1_000_337_994, 0);  // Fourth coin value after fees
            assert!(vector::borrow(values, 4) == 1_000_437_988, 0);  // Fifth coin value after fees

            let values = stableswap::get_pool_values(&pool);
            assert!(vector::borrow(values, 0) == 1_099_851_988, 0);  // BTC1 value
            assert!(vector::borrow(values, 1) == 1_001_138_007, 0);  // BTC2 value  
            assert!(vector::borrow(values, 2) == 999_238_000, 0);    // BTC3 value  
            assert!(vector::borrow(values, 3) == 1_000_337_994, 0);  // BTC4 value
            assert!(vector::borrow(values, 4) == 1_000_437_988, 0);  // BTC5 value

            // Assert new BTC3 fee balances
            let fee_balances = stableswap::get_pool_fee_balances(&pool);
            let btc3_fee_balance = fee_balances.borrow<String, Balance<BTC3>>(type_name::into_string(type_name::get<BTC3>()));
            assert!(balance::value(btc3_fee_balance) == 71_999, 0);  // BTC3 fee balance

            // Send BTC3 coin to the caller
            transfer::public_transfer(btc3_coin, swapper);
            
            // Return TreasuryCap objects
            test_scenario::return_to_sender(&scenario, btc2_treasury);
            
            test_scenario::return_shared(pool);
        };

        // Eighth transaction - remove liquidity
        test_scenario::next_tx(&mut scenario, owner);
        {
            let mut pool = test_scenario::take_shared<Pool>(&scenario);
            let last_lp_coin = test_scenario::take_from_sender<Coin<LP>>(&scenario);
            let mut lp_coin = test_scenario::take_from_sender<Coin<LP>>(&scenario);
            transfer::public_transfer(last_lp_coin, owner);
            let ctx = test_scenario::ctx(&mut scenario);

            // Split 1_000_000_000 LP tokens for removal
            let remove_lp = coin::split(&mut lp_coin, 1_000_000_000, ctx);
            
            // Initialize remove liquidity with 1_000_000_000 LP tokens
            let mut remove_liquidity = stableswap::init_remove_liquidity( remove_lp);

            // Remove liquidity for each token type
            let btc1_coin = stableswap::remove_liquidity<BTC1>(&mut remove_liquidity, &mut pool, ctx);
            let btc2_coin = stableswap::remove_liquidity<BTC2>(&mut remove_liquidity, &mut pool, ctx);
            let btc3_coin = stableswap::remove_liquidity<BTC3>(&mut remove_liquidity, &mut pool, ctx);
            let btc4_coin = stableswap::remove_liquidity<BTC4>(&mut remove_liquidity, &mut pool, ctx);
            let btc5_coin = stableswap::remove_liquidity<BTC5>(&mut remove_liquidity, &mut pool, ctx);

            // Finish remove liquidity
            stableswap::finish_remove_liquidity(remove_liquidity, &mut pool, ctx);

            // Assert the received amounts
            assert!(coin::value(&btc1_coin) == 215_614_809, 0);
            assert!(coin::value(&btc2_coin) == 196_262_936, 0);
            assert!(coin::value(&btc3_coin) == 195_890_459, 0);
            assert!(coin::value(&btc4_coin) == 196_106_101, 0);
            assert!(coin::value(&btc5_coin) == 196_125_704, 0);

            // Assert values
            let values = stableswap::get_pool_values(&pool);
            assert!(vector::borrow(values, 0) == 884_237_179, 0);   
            assert!(vector::borrow(values, 1) == 804_875_071, 0);  
            assert!(vector::borrow(values, 2) == 803_347_541, 0);  
            assert!(vector::borrow(values, 3) == 804_231_893, 0);   
            assert!(vector::borrow(values, 4) == 804_312_284, 0);  

            // Assert balances
            let balances = stableswap::get_pool_balances(&pool);
            let btc1_balance = balances.borrow<String, Balance<BTC1>>(type_name::into_string(type_name::get<BTC1>()));
            assert!(balance::value(btc1_balance) == 884_237_179, 0);  // BTC1 balance
            let btc2_balance = balances.borrow<String, Balance<BTC2>>(type_name::into_string(type_name::get<BTC2>()));
            assert!(balance::value(btc2_balance) == 804_875_071, 0);  // BTC2 balance
            let btc3_balance = balances.borrow<String, Balance<BTC3>>(type_name::into_string(type_name::get<BTC3>()));
            assert!(balance::value(btc3_balance) == 803_347_541, 0);  // BTC3 balance
            let btc4_balance = balances.borrow<String, Balance<BTC4>>(type_name::into_string(type_name::get<BTC4>()));
            assert!(balance::value(btc4_balance) == 804_231_893, 0);  // BTC4 balance
            let btc5_balance = balances.borrow<String, Balance<BTC5>>(type_name::into_string(type_name::get<BTC5>()));
            assert!(balance::value(btc5_balance) == 804_312_284, 0);  // BTC5 balance

            // Verify LP supply  
            assert!(stableswap::get_pool_lp_supply(&pool) == 4_101_003_917, 0);  // LP supply after remove liquidity

            // Transfer coins back to owner
            transfer::public_transfer(btc1_coin, owner);
            transfer::public_transfer(btc2_coin, owner);
            transfer::public_transfer(btc3_coin, owner);
            transfer::public_transfer(btc4_coin, owner);
            transfer::public_transfer(btc5_coin, owner);

            // Return remaining LP tokens to owner
            transfer::public_transfer(lp_coin, owner);
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }
}