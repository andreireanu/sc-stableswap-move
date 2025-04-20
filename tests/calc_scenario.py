import numpy as np
from scipy.optimize import fsolve
import math
from decimal import Decimal, getcontext

def calc_D(x_i_values, A, D_initial=None):
    """
    Calculate the D value for stable swap curve based on balances (x_i),
    amplification coefficient (A), and initial D guess.
    """
    n = len(x_i_values)
    
    # If no initial D provided, use sum of balances as estimate
    if D_initial is None:
        D_initial = sum(x_i_values)
    
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
    # Calculate S = Σx_i
    S = sum(x_i)
    
    # Calculate D_p = D^(n+1)/(n^n·Πx_i) using logarithms for numerical stability
    try:
        # Using logarithms to avoid overflow
        log_numerator = (n+1) * math.log(D)
        log_denominator = n * math.log(n) + sum(math.log(x) for x in x_i)
        D_p = math.exp(log_numerator - log_denominator)
    except (OverflowError, ValueError):
        # Fallback for extreme values
        if D == 0:
            D_p = 0
        else:
            # Use high precision calculation
            getcontext().prec = 50  # Set precision
            D_dec = Decimal(D)
            n_dec = Decimal(n)
            x_i_dec = [Decimal(x) for x in x_i]
            
            numerator = D_dec ** (n_dec + Decimal('1'))
            denominator = n_dec ** n_dec * math.prod(x_i_dec)
            D_p = float(numerator / denominator)
    
    # Calculate F(D) with the corrected formula
    F_D = A * D * n**n + D_p - A * S * n**n - D
    
    return F_D

def calculate_F_prime(D, A, n, x_i):
    """
    Calculate F'(D) using the formula: F'(D) = A·n^n - 1 + ((n+1) / D) * D_p
    With numerical stability for large values
    """
    if D == 0:
        return float('inf')
    
    # Calculate D_p = D^(n+1)/(n^n·Πx_i) using logarithms for numerical stability
    try:
        # Using logarithms to avoid overflow
        log_numerator = (n+1) * math.log(D)
        log_denominator = n * math.log(n) + sum(math.log(x) for x in x_i)
        D_p = math.exp(log_numerator - log_denominator)
    except (OverflowError, ValueError):
        # Fallback for extreme values
        # Use high precision calculation
        getcontext().prec = 50  # Set precision
        D_dec = Decimal(D)
        n_dec = Decimal(n)
        x_i_dec = [Decimal(x) for x in x_i]
        
        numerator = D_dec ** (n_dec + Decimal('1'))
        denominator = n_dec ** n_dec * math.prod(x_i_dec)
        D_p = float(numerator / denominator)
    
    # Calculate F'(D) with the formula
    F_prime = A * n**n - 1 + ((n+1) / D) * D_p
    
    return F_prime

def F_wrapper(D, A, n, x_i):
    """
    Wrapper function for fsolve that handles scalar or array inputs
    """
    # Ensure D is treated as scalar for our calculations
    D_scalar = D[0] if hasattr(D, "__len__") else D
    return calculate_F(D_scalar, A, n, x_i)

def F_prime_wrapper(D, A, n, x_i):
    """
    Wrapper function for the derivative for fsolve
    """
    # Ensure D is treated as scalar for our calculations
    D_scalar = D[0] if hasattr(D, "__len__") else D
    # Return as 1x1 array for fsolve
    return np.array([calculate_F_prime(D_scalar, A, n, x_i)])

def solve_for_D(A, n, x_i, D_initial=1.0):
    """
    Solve for D using scipy.optimize.fsolve with improved numerical stability
    """
    # Prepare the initial guess
    D0 = np.array([D_initial])
    
    # Solve using fsolve
    try:
        D_solution, infodict, ier, mesg = fsolve(
            F_wrapper, 
            D0, 
            args=(A, n, x_i), 
            fprime=F_prime_wrapper if D_initial != 0 else None,
            full_output=True,
            xtol=1e-12  # Increased precision
        )
        return D_solution[0], infodict, ier, mesg
    except (OverflowError, FloatingPointError) as e:
        print(f"Error in fsolve: {e}")
        print("Trying alternative method...")
        
        # Try with a different initial value that might be closer to solution
        # A good estimate could be the sum of x_i values
        D_estimate = sum(x_i)
        print(f"Using new initial value: {D_estimate}")
        try:
            D_solution, infodict, ier, mesg = fsolve(
                F_wrapper, 
                np.array([D_estimate]), 
                args=(A, n, x_i), 
                fprime=None,  # Don't use analytical derivative for stability
                full_output=True,
                xtol=1e-12
            )
            return D_solution[0], infodict, ier, mesg
        except Exception as e2:
            print(f"Alternative method also failed: {e2}")
            return None, None, 0, str(e2)

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
    FEE_DENOMINATOR = 10000
    fees = [(d * fee) // FEE_DENOMINATOR for d in diffs]
    print(f"Fees: {fees}")
    
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

def main():
    # Example with your specific values
    A = 100.0  # Using A=100 from your example
    fee_rate = 100  # Using 4 for 0.04%
    
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

if __name__ == "__main__":
    main()