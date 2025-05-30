### SUI Dust Converter

#### Split coins
```bash
sui client split-coin --coin-id 0xda282f3ca36264400bb942b75c3b1bb84903b11e45e773e470a677ddc8c122bd --amounts 100000000 --gas-budget 100000000
 ```


#### DEVNET:

#### Publish
```bash
sui client publish --gas-budget 500000000
 ```

Deploy transaction: https://suiscan.xyz/testnet/tx/HJDgbje9TuLKVMtvT8EwBgaTCHt1g5uLqwfc23g3p8MP  

# PACKAGE:     0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107
# LP_TOKEN:     
# ADMIN_CAP:    
# UPGRADE_CAP:  


AMOUNT=1000
TREASURY_CAP=0x0adc7df470cd23a4755788400834aa17de73d8b9d5ed6dcc6e8f7b1a23d40c6f

# MINT:
 
sui client ptb \
  --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::rbtc::mint "" @0xbe501423d023fa3963996937a8a7b23686d022daaa5c5ab4e84c9d776950a13b 1000_00_000_000 \
  --assign rbtc \
  --transfer-objects "[rbtc]" @0x6c237e258d430176aeaaccd207fa7075b06ca9224a47fe90f3c7797426da6a4e

sui client ptb \
  --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::sbtc::mint "" @0xa842be62efc4258e7ee5d6faba43a632fc1b587a6b8cd13053ca5bd5c2646746 1000_00_000_000 \
  --assign sbtc \
  --transfer-objects "[sbtc]" @0x6c237e258d430176aeaaccd207fa7075b06ca9224a47fe90f3c7797426da6a4e

sui client ptb \
  --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::wbtc::mint "" @0x373c91bcc8d387191f30c2ea65a11509df0803b841e9cca62637e22bb3b7f672 1000_00_000_000 \
  --assign wbtc \
  --transfer-objects "[wbtc]" @0x6c237e258d430176aeaaccd207fa7075b06ca9224a47fe90f3c7797426da6a4e

sui client ptb \
  --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::zbtc::mint "" @0x09a98f572b2d6a97e06cadbb5acbd509dde9bc22804af893166d96b3dc4583d6 1000_00_000_000 \
  --assign zbtc \
  --transfer-objects "[zbtc]" @0x6c237e258d430176aeaaccd207fa7075b06ca9224a47fe90f3c7797426da6a4e

sui client ptb \
  --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::pbtc::mint "" @0x2d1a5027d00c7b267d36ba187d96eb71c4c86af7806f6de8ac831d5d15c1ffba 1000_00_000_000 \
  --assign pbtc \
  --transfer-objects "[pbtc]" @0x6c237e258d430176aeaaccd207fa7075b06ca9224a47fe90f3c7797426da6a4e 


# CREATE POOL:

sui client ptb \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::create_pool" "" @0x7d191f1193617e396206ab03abd66b4de97b906fbfc581d39f5638be38721d3d @0x6c237e258d430176aeaaccd207fa7075b06ca9224a47fe90f3c7797426da6a4e 100 1 50000 @0xabd2d57de45c60f31c24e36e7d1dd43f41e2ac2a0ff40986700cda44f08c4b9d

# ADD TYPES AND LOCK

POOL_ID=0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7

sui client ptb \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_type" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::pbtc::PBTC>" \
  @0x7d191f1193617e396206ab03abd66b4de97b906fbfc581d39f5638be38721d3d \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_type" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::rbtc::RBTC>" \
  @0x7d191f1193617e396206ab03abd66b4de97b906fbfc581d39f5638be38721d3d \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
    --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_type" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::sbtc::SBTC>" \
  @0x7d191f1193617e396206ab03abd66b4de97b906fbfc581d39f5638be38721d3d \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
    --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_type" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::wbtc::WBTC>" \
  @0x7d191f1193617e396206ab03abd66b4de97b906fbfc581d39f5638be38721d3d \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
    --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_type" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::zbtc::ZBTC>" \
  @0x7d191f1193617e396206ab03abd66b4de97b906fbfc581d39f5638be38721d3d \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
    --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::lock_pool" \
  @0x7d191f1193617e396206ab03abd66b4de97b906fbfc581d39f5638be38721d3d \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7



# ADD INITIAL LIQUIDITY
# COIN ORDER: PBTC, RBTC, SBTC, WBTC, ZBTC
 
sui client ptb \
  --make-move-vec '<u64>' '[1000100000,1000200000,1000300000,1000400000,1000500000]' \
  --assign values \
  --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::init_add_liquidity \
    @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
    values \
    0 \
  --assign liquidity \
  --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::pbtc::mint "" @0x2d1a5027d00c7b267d36ba187d96eb71c4c86af7806f6de8ac831d5d15c1ffba 1000100000 \
  --assign pbtc_coin \
  --move-call std::option::some '<0x2::coin::Coin<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::pbtc::PBTC>>' pbtc_coin \
  --assign pbtc_coin_option \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_liquidity" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::pbtc::PBTC>" \
  pbtc_coin_option \
  liquidity \
   @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
    --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::rbtc::mint "" @0xbe501423d023fa3963996937a8a7b23686d022daaa5c5ab4e84c9d776950a13b 1000200000 \
  --assign rbtc_coin \
  --move-call std::option::some '<0x2::coin::Coin<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::rbtc::RBTC>>' rbtc_coin \
  --assign rbtc_coin_option \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_liquidity" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::rbtc::RBTC>" \
  rbtc_coin_option \
  liquidity \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
  --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::sbtc::mint "" @0xa842be62efc4258e7ee5d6faba43a632fc1b587a6b8cd13053ca5bd5c2646746 1000300000 \
  --assign sbtc_coin \
  --move-call std::option::some '<0x2::coin::Coin<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::sbtc::SBTC>>' sbtc_coin \
  --assign sbtc_coin_option \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_liquidity" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::sbtc::SBTC>" \
  sbtc_coin_option \
  liquidity \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
    --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::wbtc::mint "" @0x373c91bcc8d387191f30c2ea65a11509df0803b841e9cca62637e22bb3b7f672 1000400000 \
  --assign wbtc_coin \
  --move-call std::option::some '<0x2::coin::Coin<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::wbtc::WBTC>>' wbtc_coin \
  --assign wbtc_coin_option \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_liquidity" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::wbtc::WBTC>" \
  wbtc_coin_option \
  liquidity \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
   --move-call 0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::zbtc::mint "" @0x09a98f572b2d6a97e06cadbb5acbd509dde9bc22804af893166d96b3dc4583d6 1000500000 \
  --assign zbtc_coin \
  --move-call std::option::some '<0x2::coin::Coin<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::zbtc::ZBTC>>' zbtc_coin \
  --assign zbtc_coin_option \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::add_liquidity" \
  "<0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::zbtc::ZBTC>" \
  zbtc_coin_option \
  liquidity \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
  --move-call "0x6c7d963552509229f5aa01b71c8c8955f3bcce63aaba1d67e54fa6b405e17107::stableswap::finish_add_liquidity" "" \
  liquidity \
  @0xf8b02701191d052d49a807ec0ed90e0febe487c3f60d818e6ab5e04c83c9b7a7 \
  --assign lp_coin \
  --transfer-objects "[lp_coin]" @0x6c237e258d430176aeaaccd207fa7075b06ca9224a47fe90f3c7797426da6a4e