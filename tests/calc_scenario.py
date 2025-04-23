import numpy as np
from scipy.optimize import fsolve
import math
from decimal import Decimal, getcontext

# Constants
FEE_DENOMINATOR = 10000
fee_rate = 100  # 1% fee

def calc_D(x_i_values, A, D_initial=None):
    """
    Calculate the D value for stable swap curve based on balances (x_i),
    amplification coefficient (A), and initial D guess.
    """
    from decimal import Decimal, getcontext, ROUND_DOWN
    getcontext().prec = 78  # u256 equivalent precision
    getcontext().rounding = ROUND_DOWN  # Match Move's integer division behavior
    
    # Convert inputs to Decimal and ensure they're integers
    x_i_values = [Decimal(str(int(val))) for val in x_i_values]
    A = Decimal(str(int(A)))
    n = Decimal(str(len(x_i_values)))
    
    # If no initial D provided, use sum of balances as estimate
    if D_initial is None:
        D_initial = sum(x_i_values)
    D_initial = Decimal(str(int(D_initial)))
    
    print(f"Calculating D with A={A}, n={n}")
    print(f"x_i = {x_i_values}")
    print(f"Initial D guess = {D_initial}")
    
    # Solve for D
    D_solution, _, success, _ = solve_for_D(A, n, x_i_values, D_initial)
    
    print(f"D solution = {D_solution}, Success: {'Yes' if success == 1 else 'No'}")
    print("-" * 40)
    
    if success != 1:
        raise ValueError("Failed to find D solution")
    
    return D_solution

def calculate_F(D, A, n, x_i):
    """
    Calculate F(D) using the formula: F(D) = A·D·n^n + D_p - A·S·n^n - D
    With numerical stability for large values
    """
    from decimal import Decimal
    
    # Calculate S = Σx_i
    S = sum(x_i)
    
    try:
        # Calculate D_p = D^(n+1)/(n^n·Πx_i)
        numerator = D ** (n + Decimal('1'))
        denominator = n ** n * math.prod(x_i)
        D_p = numerator / denominator
        
        # Calculate F(D) with the corrected formula
        F_D = A * D * n**n + D_p - A * S * n**n - D
        
        return F_D
    except (OverflowError, ValueError):
        # Use high precision calculation
        getcontext().prec = 78
        D_dec = D
        n_dec = n
        x_i_dec = x_i
        
        numerator = D_dec ** (n_dec + Decimal('1'))
        denominator = n_dec ** n_dec * math.prod(x_i_dec)
        D_p = numerator / denominator
        
        F_D = A * D * n**n + D_p - A * S * n**n - D
        return F_D

def calculate_F_prime(D, A, n, x_i):
    """
    Calculate F'(D) using the formula: F'(D) = A·n^n - 1 + ((n+1) / D) * D_p
    With numerical stability for large values
    """
    from decimal import Decimal
    
    if D == 0:
        return Decimal('inf')
    
    try:
        # Calculate D_p = D^(n+1)/(n^n·Πx_i)
        numerator = D ** (n + Decimal('1'))
        denominator = n ** n * math.prod(x_i)
        D_p = numerator / denominator
        
        # Calculate F'(D)
        F_prime = A * n**n - Decimal('1') + ((n + Decimal('1')) / D) * D_p
        
        return F_prime
    except (OverflowError, ValueError):
        # Use high precision calculation
        getcontext().prec = 78
        D_dec = D
        n_dec = n
        x_i_dec = x_i
        
        numerator = D_dec ** (n_dec + Decimal('1'))
        denominator = n_dec ** n_dec * math.prod(x_i_dec)
        D_p = numerator / denominator
        
        F_prime = A * n**n - Decimal('1') + ((n + Decimal('1')) / D) * D_p
        return F_prime

def F_wrapper(D, A, n, x_i):
    """
    Wrapper function for fsolve that handles scalar or array inputs
    """
    # Ensure D is treated as scalar for our calculations
    D_scalar = D[0] if hasattr(D, "__len__") else D
    D_scalar = Decimal(str(D_scalar))
    return float(calculate_F(D_scalar, A, n, x_i))

def F_prime_wrapper(D, A, n, x_i):
    """
    Wrapper function for the derivative for fsolve
    """
    # Ensure D is treated as scalar for our calculations
    D_scalar = D[0] if hasattr(D, "__len__") else D
    D_scalar = Decimal(str(D_scalar))
    # Return as 1x1 array for fsolve
    return np.array([float(calculate_F_prime(D_scalar, A, n, x_i))])

def solve_for_D(A, n, x_i, D_initial=Decimal('1.0')):
    """
    Solve for D using scipy.optimize.fsolve with improved numerical stability
    """
    # Prepare the initial guess
    D0 = np.array([float(D_initial)])
    
    # Solve using fsolve
    try:
        D_solution, infodict, ier, mesg = fsolve(
            F_wrapper, 
            D0, 
            args=(A, n, x_i), 
            fprime=F_prime_wrapper if D_initial != 0 else None,
            full_output=True,
            xtol=1e-8,  # More lenient tolerance
            maxfev=2000,  # More iterations
            factor=0.1  # Smaller step size
        )
        
        # Calculate the function value at the solution
        f_val = F_wrapper(D_solution, A, n, x_i)
        print(f"Function value at solution: {f_val}")
        
        # Convert back to Decimal
        D_solution_dec = Decimal(str(D_solution[0]))
        
        # If the function value is close enough to zero, consider it a success
        if abs(f_val) < 1e-6:
            return D_solution_dec, infodict, 1, "Success"
            
        return D_solution_dec, infodict, ier, mesg
        
    except Exception as e:
        print(f"Error in fsolve: {e}")
        return None, None, 0, str(e)

def calculate_imbalance_fees(x_i_initial, dx_i, A, fee_rate):
    """
    Calculate imbalance fees for adding dx_i to the pool with balances x_i_initial
    
    Parameters:
    - x_i_initial: Initial balances vector
    - dx_i: Vector of amounts to add (can include zeros for tokens not being added)
    - A: Amplification coefficient
    - fee_rate: Fee rate (e.g., 4 for 0.04%)
    
    Returns:
    - Dictionary with results including fees, adjusted balances, and D values
    """
    print("\n" + "="*60)
    print(f"CALCULATING IMBALANCE FEES:")
    print(f"Initial balances (x_i): {x_i_initial}")
    print(f"Adding amounts (dx_i): {dx_i}")
    print(f"Amplification coefficient (A): {A}")
    print(f"Fee rate: {fee_rate}")
    print("="*60 + "\n")
    
    # Ensure x_i and dx_i have the same length
    if len(x_i_initial) != len(dx_i):
        raise ValueError("x_i_initial and dx_i must have the same length")
    
    # Calculate initial balances after adding dx_i (before fees)
    x_i_after_add = [b + d for b, d in zip(x_i_initial, dx_i)]
    print(f"Balances after adding dx_i (before fees): {x_i_after_add}")
    
    # Calculate D values
    print("\nCalculating D0 for initial balances:")
    D0 = calc_D(x_i_initial, A)
    
    print("\nCalculating D1 for balances after add (before fees):")
    D1 = calc_D(x_i_after_add, A, D0)  # Use D0 as initial guess
    
    # Calculate balanced position (what balances would be if the pool remained balanced)
    i_bals = [(D1 * b) // D0 for b in x_i_initial]  # Use integer division
    print(f"\nBalanced position (i_bals): {i_bals}")
    
    # Calculate imbalance (difference between actual and balanced positions)
    diffs = [abs(b - bi) for b, bi in zip(x_i_after_add, i_bals)]  # Use absolute difference
    print(f"Differences: {diffs}")
    
    # Calculate fee using Move contract formula: fee = pool.fee * n_coins / (4 * (n_coins - 1))
    n_coins = len(x_i_initial)
    fee = (fee_rate * n_coins) // (4 * (n_coins - 1))
    print(f"Calculated fee: {fee}")
    
    # Calculate fees using integer arithmetic to match Move contract
    fees = [(d * fee) // FEE_DENOMINATOR for d in diffs]
    print(f"FEES: {fees}")
    
    # Calculate final balances after fees
    x_i_final = [b - f for b, f in zip(x_i_after_add, fees)]
    print(f"FINAL BALANCES AFTER FEES: {x_i_final}")
    
    # Calculate final D
    print("\nCalculating D2 for final balances (after fees):")
    D2 = calc_D(x_i_final, A, D1)  # Use D1 as initial guess
    
    print("\nSUMMARY:")
    print(f"D0 (initial): {D0}")
    print(f"D1 (after add, before fees): {D1}")
    print(f"D2 (final, after fees): {D2}")
    
    return {
        "D_initial": D0,
        "D_after_add": D1,
        "D_final": D2,
        "balances_initial": x_i_initial,
        "balances_after_add": x_i_after_add,
        "balanced_position": i_bals,
        "imbalance": diffs,
        "fees": fees,
        "balances_final": x_i_final
    }

def get_y(i, j, dx, x, amp, n):
    """
    Calculate the output amount for a given input amount using the StableSwap formula.
    Using fsolve with the exact StableSwap function.
    """
    from decimal import Decimal, getcontext
    from scipy.optimize import fsolve
    import numpy as np
    getcontext().prec = 78  # u256 equivalent precision
    
    # Convert inputs to Decimal and ensure they're integers
    x = [Decimal(str(int(val))) for val in x]
    dx = Decimal(str(int(dx)))
    amp = Decimal(str(int(amp)))
    n = Decimal(str(int(n)))
    ann = amp * n**n  # Calculate ann exactly like Move
    
    # Calculate D with the current x array
    d = Decimal(str(int(calc_D(x, amp, D_initial=sum(x)))))
    
    # Initialize c and s
    c = d
    s = Decimal('0')
    
    # Calculate S and c
    for k in range(len(x)):
        if k == i:
            x_temp = x[k] + dx
        elif k != j:
            x_temp = x[k]
        else:
            continue
        s += x_temp
        c = Decimal(str(int((c * d) / (x_temp * n))))
    
    # Calculate final c
    c = Decimal(str(int((c * d) / (ann * n))))
    
    def f(y):
        """
        The StableSwap function to solve:
        f(y) = A * (n ** n) * (y ** 2) + y * (A * S * (n ** n) + d - A * d * (n ** n)) - c * A * (n ** n)
        """
        y = Decimal(str(y[0]))
        term1 = ann * y * y
        term2 = y * (ann * s + d - ann * d)
        term3 = c * ann
        return np.array([float(term1 + term2 - term3)])
    
    def fprime(y):
        """
        Derivative of the StableSwap function:
        f'(y) = 2 * A * (n ** n) * y + (A * S * (n ** n) + d - A * d * (n ** n))
        """
        y = Decimal(str(y[0]))
        term1 = 2 * ann * y
        term2 = ann * s + d - ann * d
        return np.array([[float(term1 + term2)]])
    
    # Initial guess
    y0 = np.array([float(d)])
    
    # Solve using fsolve
    y_sol = fsolve(f, y0, fprime=fprime, xtol=1e-8)[0]
    
    return int(y_sol)

def exchange(i, j, dx, x, amp, n):
    """
    Calculate the output amount for a given input amount using the StableSwap formula.
    Direct port of the Move code.
    """
    # Get the new balance of token j
    y = get_y(i, j, dx, x, amp, n)
    print(f"NEW y: {y}")
    
    # Calculate dy = x[j] - y
    dy = int(x[j] - y)
    
    # Calculate and remove fee from dy
    print(f"fee_rate: {fee_rate}")
    fee = (dy * fee_rate) // FEE_DENOMINATOR
    dy = dy - fee
    
    print(f"Fee removed: {fee}")
    return dy

def calculate_remove_liquidity(x, lp_supply, remove_lp):
    """
    Calculate the return amounts when removing liquidity.
    
    Args:
        x: List of current pool balances [btc1, btc2, btc3, btc4, btc5]
        lp_supply: Total LP token supply
        remove_lp: Amount of LP tokens to remove
        
    Returns:
        List of return amounts [btc1_return, btc2_return, btc3_return, btc4_return, btc5_return]
    """
    returns = []
    for value in x:
        coin_return = value * remove_lp // lp_supply
        returns.append(coin_return)
    

    return returns

def calculate_remaining_balances(x, returns):
    """
    Calculate the remaining balances after removing liquidity.
    
    Args:
        x: List of current pool balances [btc1, btc2, btc3, btc4, btc5]
        returns: List of return amounts [btc1_return, btc2_return, ...]
        
    Returns:
        List of remaining balances [btc1_remaining, btc2_remaining, ...]
    """
    remaining = []
    for initial, ret in zip(x, returns):
        remaining.append(initial - ret)
    
    return remaining

def main():
    # Example with your specific values
    A = 100.0  # Using A=100 from your example
    fee_rate = 100  #  
    
    # Large values test case
    x_i_initial = [1_000_100_000, 1_000_200_000, 1_000_300_000, 1_000_400_000, 1_000_500_000]
    dx_i = [100_000_000, 0, 0, 0, 0]  # Adding tokens to only the first position
    
    print("\nTEST CASE: Large Values")
    try:
        results = calculate_imbalance_fees(x_i_initial, dx_i, A, fee_rate)
        
        # Formatted summary (more concise)
        print("\n" + "="*60)
        print("FINAL RESULTS SUMMARY:")
        print("-"*60)
        print(f"Initial D value: {results['D_initial']}")
        print(f"D value after adding tokens: {results['D_after_add']}")
        print(f"Final D value after fees: {results['D_final']}")
        print("-"*60)
        print(f"Total imbalance fees collected: {sum(results['fees'])}")
        print("="*60)
        
    except Exception as e:
        print(f"Error with large values: {e}")
        import traceback
        traceback.print_exc()

    # Calculate exchange scenario
    print("\nExchange Scenario:")
    print("-----------------")
    x = [1_099_851_988, 1_000_138_007, 1_000_238_001, 1_000_337_994, 1_000_437_988]
    dx = 1_000_000
    i = 1  # BTC2 index
    j = 2  # BTC3 index
    amp = 100
    n = 5

    dy = exchange(i, j, dx, x, amp, n)
    print(f"Input amount: {dx}")
    print(f"Output amount: {dy}")
    print(f"New BTC2 balance: {x[i] + dx}")
    print(f"New BTC3 balance: {x[j] - dy}")

    # Pool values before removal
    x = [1_099_851_988, 1_001_138_007, 999_238_000, 1_000_337_994, 1_000_437_988]
    lp_supply = 5_101_003_917
    remove_lp = 1_000_000_000

    # Calculate remove liquidity returns
    returns = calculate_remove_liquidity(x, lp_supply, remove_lp)

    print("\nRemove Liquidity Transaction")
    print("----------------------------------------------------")
    print(f"LP tokens to remove: {remove_lp}")
    print(f"Total LP supply: {lp_supply}")
    print(f"Remaining LP supply: {lp_supply - remove_lp}")
    for i, ret in enumerate(returns, 1):
        print(f"BTC{i} return: {ret}")
    
    # Calculate remaining balances
    remaining = calculate_remaining_balances(x, returns)

    print("\nRemaining Balances After Remove")
    print("----------------------------------------------------")
    for i, rem in enumerate(remaining, 1):
        print(f"BTC{i} remaining: {rem}")

if __name__ == "__main__":
    main()