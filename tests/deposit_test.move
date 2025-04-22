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
    use std::debug;
    use std::type_name;
    use sui::balance::{Self, Balance};
    use std::ascii::String;

    #[test]
    fun test_deposit() {
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
            
            // Assert values 
            let values = stableswap::get_pool_values(&pool);
            assert!(vector::borrow(values, 0) == 1_000_100_000, 0);  // First coin value after fees
            assert!(vector::borrow(values, 1) == 1_000_200_000, 0);  // Second coin value after fees
            assert!(vector::borrow(values, 2) == 1_000_300_000, 0);  // Third coin value after fees
            assert!(vector::borrow(values, 3) == 1_000_400_000, 0);  // Fourth coin value after fees
            assert!(vector::borrow(values, 4) == 1_000_500_000, 0);  // Fifth coin value after fees
            
            // Assert balances
            let balances = stableswap::get_pool_balances(&pool);
            let btc1_balance = balances.borrow<String, Balance<BTC1>>(type_name::into_string(type_name::get<BTC1>()));
            assert!(balance::value(btc1_balance) == 1_000_100_000, 0);  // BTC1 balance
            let btc2_balance = balances.borrow<String, Balance<BTC2>>(type_name::into_string(type_name::get<BTC2>()));
            assert!(balance::value(btc2_balance) == 1_000_200_000, 0);  // BTC2 balance
            let btc3_balance = balances.borrow<String, Balance<BTC3>>(type_name::into_string(type_name::get<BTC3>()));
            assert!(balance::value(btc3_balance) == 1_000_300_000, 0);  // BTC3 balance
            let btc4_balance = balances.borrow<String, Balance<BTC4>>(type_name::into_string(type_name::get<BTC4>()));
            assert!(balance::value(btc4_balance) == 1_000_400_000, 0);  // BTC4 balance
            let btc5_balance = balances.borrow<String, Balance<BTC5>>(type_name::into_string(type_name::get<BTC5>()));
            assert!(balance::value(btc5_balance) == 1_000_500_000, 0);  // BTC5 balance

            // Assert fee balances
            let fee_balances = stableswap::get_pool_fee_balances(&pool);
            let btc1_fee_balance = fee_balances.borrow<String, Balance<BTC1>>(type_name::into_string(type_name::get<BTC1>()));
            assert!(balance::value(btc1_fee_balance) == 0, 0);  // BTC1 fee balance
            let btc2_fee_balance = fee_balances.borrow<String, Balance<BTC2>>(type_name::into_string(type_name::get<BTC2>()));
            assert!(balance::value(btc2_fee_balance) == 0, 0);  // BTC2 fee balance
            let btc3_fee_balance = fee_balances.borrow<String, Balance<BTC3>>(type_name::into_string(type_name::get<BTC3>()));
            assert!(balance::value(btc3_fee_balance) == 0, 0);  // BTC3 fee balance
            let btc4_fee_balance = fee_balances.borrow<String, Balance<BTC4>>(type_name::into_string(type_name::get<BTC4>()));
            assert!(balance::value(btc4_fee_balance) == 0, 0);  // BTC4 fee balance
            let btc5_fee_balance = fee_balances.borrow<String, Balance<BTC5>>(type_name::into_string(type_name::get<BTC5>()));
            assert!(balance::value(btc5_fee_balance) == 0, 0);  // BTC5 fee balance
            
            // Verify LP supply  
            assert!(stableswap::get_pool_lp_supply(&pool) == 5001499999, 0);   
            
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

        // Fifth transaction - add additional liquidity
        test_scenario::next_tx(&mut scenario, owner);
        {
            let mut pool = test_scenario::take_shared<Pool>(&scenario);

            // Get TreasuryCap for each coin type
            let mut btc1_treasury = test_scenario::take_from_sender<TreasuryCap<BTC1>>(&scenario);

            // Create deposit amounts vector  
            let mut values = vector::empty<u64>();
            vector::push_back(&mut values, 100_000_000);
            vector::push_back(&mut values, 0);
            vector::push_back(&mut values, 0);
            vector::push_back(&mut values, 0);
            vector::push_back(&mut values, 0);
 
            // Initialize liquidity addition
            let mut liquidity = stableswap::init_add_liquidity(&mut pool, values, 0);

            let ctx = test_scenario::ctx(&mut scenario);

            // Add liquidity for each coin type
            let btc1_coin = coin::mint(&mut btc1_treasury, 100_000_000, ctx);
            stableswap::add_liquidity<BTC1>(option::some(btc1_coin), &mut liquidity, &mut pool, ctx);

            stableswap::add_liquidity<BTC2>(option::none(), &mut liquidity, &mut pool, ctx);
            
            stableswap::add_liquidity<BTC3>(option::none(), &mut liquidity, &mut pool, ctx);
            
            stableswap::add_liquidity<BTC4>(option::none(), &mut liquidity, &mut pool, ctx);
            
            stableswap::add_liquidity<BTC5>(option::none(), &mut liquidity, &mut pool, ctx);

            // Finish adding liquidity and get LP tokens
            let lp_coin = stableswap::finish_add_liquidity(liquidity, &mut pool, ctx);
            
            // Assert values
            let values = stableswap::get_pool_values(&pool);
            assert!(vector::borrow(values, 0) == 1_099_851_988, 0);  // First coin value after fees
            assert!(vector::borrow(values, 1) == 1_000_138_007, 0);  // Second coin value after fees
            assert!(vector::borrow(values, 2) == 1_000_238_001, 0);  // Third coin value after fees
            assert!(vector::borrow(values, 3) == 1_000_337_994, 0);  // Fourth coin value after fees
            assert!(vector::borrow(values, 4) == 1_000_437_988, 0);  // Fifth coin value after fees
            
            // Assert balances
            let balances = stableswap::get_pool_balances(&pool);
            let btc1_balance = balances.borrow<String, Balance<BTC1>>(type_name::into_string(type_name::get<BTC1>()));
            assert!(balance::value(btc1_balance) == 1_099_851_988, 0);  // BTC1 balance
            let btc2_balance = balances.borrow<String, Balance<BTC2>>(type_name::into_string(type_name::get<BTC2>()));
            assert!(balance::value(btc2_balance) == 1_000_138_007, 0);  // BTC2 balance
            let btc3_balance = balances.borrow<String, Balance<BTC3>>(type_name::into_string(type_name::get<BTC3>()));
            assert!(balance::value(btc3_balance) == 1_000_238_001, 0);  // BTC3 balance
            let btc4_balance = balances.borrow<String, Balance<BTC4>>(type_name::into_string(type_name::get<BTC4>()));
            assert!(balance::value(btc4_balance) == 1_000_337_994, 0);  // BTC4 balance
            let btc5_balance = balances.borrow<String, Balance<BTC5>>(type_name::into_string(type_name::get<BTC5>()));
            assert!(balance::value(btc5_balance) == 1_000_437_988, 0);  // BTC5 balance
            
            // Assert fee balances
            let fee_balances = stableswap::get_pool_fee_balances(&pool);
            let btc1_fee_balance = fee_balances.borrow<String, Balance<BTC1>>(type_name::into_string(type_name::get<BTC1>()));
            assert!(balance::value(btc1_fee_balance) == 248012, 0);  // BTC1 fee balance
            let btc2_fee_balance = fee_balances.borrow<String, Balance<BTC2>>(type_name::into_string(type_name::get<BTC2>()));
            assert!(balance::value(btc2_fee_balance) == 61993, 0);  // BTC2 fee balance
            let btc3_fee_balance = fee_balances.borrow<String, Balance<BTC3>>(type_name::into_string(type_name::get<BTC3>()));
            assert!(balance::value(btc3_fee_balance) == 61999, 0);  // BTC3 fee balance
            let btc4_fee_balance = fee_balances.borrow<String, Balance<BTC4>>(type_name::into_string(type_name::get<BTC4>()));
            assert!(balance::value(btc4_fee_balance) == 62006, 0);  // BTC4 fee balance
            let btc5_fee_balance = fee_balances.borrow<String, Balance<BTC5>>(type_name::into_string(type_name::get<BTC5>()));
            assert!(balance::value(btc5_fee_balance) == 62012, 0);  // BTC5 fee balance
            
            // Verify LP supply  
            assert!(stableswap::get_pool_lp_supply(&pool) == 5101003917, 0);  // LP supply after second deposit
            
            // Send LP coin to the caller
            transfer::public_transfer(lp_coin, owner);
            
            // Return TreasuryCap objects
            test_scenario::return_to_sender(&scenario, btc1_treasury);
            
            test_scenario::return_shared(pool);
        };

        test_scenario::end(scenario);
    }
}