import numpy as np
from scipy.optimize import fsolve
import math

def calculate_F(D, A, n, x_i):
    """
    Calculate F(D) using the corrected formula: F(D) = A·D·n^n + D_p - A·S·n^n - D
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
            from decimal import Decimal, getcontext
            getcontext().prec = 50  # Set precision
            D_dec = Decimal(D)
            n_dec = Decimal(n)
            x_i_dec = [Decimal(x) for x in x_i]
            
            numerator = D_dec ** (n_dec + Decimal('1'))
            denominator = n_dec ** n_dec * Decimal(math.prod(x_i_dec))
            D_p = float(numerator / denominator)
    
    # Calculate F(D) with the corrected formula
    F_D = A * D * n**n + D_p - A * S * n**n - D
    
    return F_D

def calculate_F_prime(D, A, n, x_i):
    """
    Calculate F'(D) using the corrected formula: F'(D) = A·n^n - 1 + ((n+1) / D) * D_p
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
        from decimal import Decimal, getcontext
        getcontext().prec = 50  # Set precision
        D_dec = Decimal(D)
        n_dec = Decimal(n)
        x_i_dec = [Decimal(x) for x in x_i]
        
        numerator = D_dec ** (n_dec + Decimal('1'))
        denominator = n_dec ** n_dec * Decimal(math.prod(x_i_dec))
        D_p = float(numerator / denominator)
    
    # Calculate F'(D) with the corrected formula
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

def main():
    # Example with large values
    A = 100.0
    n = 5
    x_i = [100_100_000_000, 100_200_000_000, 100_300_000_000, 100_400_000_000, 100_500_000_000]

    # Initial D can be sum of x_i, which is often close to the solution
    D_initial = sum(x_i)
    
    print(f"Starting calculation with parameters:")
    print(f"A = {A}")
    print(f"n = {n}")
    print(f"x_i = {x_i}")
    print(f"Initial D = {D_initial}")
    print("-" * 50)
    
    # Solve for D
    D_solution, info, ier, mesg = solve_for_D(A, n, x_i, D_initial)
    
    if D_solution is not None:
        # Calculate F(D) at the solution
        try:
            F_D_solution = calculate_F(D_solution, A, n, x_i)
            
            print(f"Solution:")
            print(f"D = {D_solution}")
            print(f"F(D) = {F_D_solution}")
            print("-" * 50)
            
            print("Solution information:")
            print(f"Success: {'Yes' if ier == 1 else 'No'}")
            if ier != 1:
                print(f"Message: {mesg}")
            if info is not None:
                print(f"Function evaluations: {info.get('nfev', 'N/A')}")
                if 'njev' in info:
                    print(f"Jacobian evaluations: {info['njev']}")
        except Exception as e:
            print(f"Error calculating F(D) at solution: {e}")
    else:
        print("Failed to find solution.")

if __name__ == "__main__":
    main()