#### SC StableSwap Move

##### get_d (StableCoin version):

![Get D Image](calculus/get_d_v1.jpg)


##### get_d (StableSwap3Pool version) -> This is the one we use  
This calculates the liquidity variable d for the pool:

![Get D Image](calculus/get_d_v2.png)


##### get_y  
This calculates token out amount when token in amount is inserted in the pool

![Get Y Image](calculus/get_y.png)

##### add_liquidity  
This is done by calling *init_add_liquidity* using the coin values to be added, then adding the actual coins using *add_liquidity* and minting the LPs using *finish_add_liquidity*


#### Testing: 
Testing includes a python script that validates test scenario calculations using an alternative method of applying Newton's method (*fsolve* from the *scipy* lib)

#### References:
StableSwap paper:           https://curve.fi/files/stableswap-paper.pdf \
2 token pool graphics:      https://www.desmos.com/calculator/gpzwdnmaib \
Explanation video:          https://www.youtube.com/watch?v=w_zjZfkwva0 \
Curve contract:             https://github.com/curvefi/curve-contract/blob/master/contracts/pools/3pool/StableSwap3Pool.vy 