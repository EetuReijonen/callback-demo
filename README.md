## Code for showing issue with LazyConstraintCallback

The problem can be seen in "OPTIMIZATION" section of *main.jl* where first *callback_const_gen* and then *manual_const_gen* are called.

*callback_const_gen* only adds 150 constraints, whereas *manual_const_gen* adds 451. Because of this, *callback_const_gen* doesn't achieve the true optimal solution, but rather one where not all necessary constraints have been added (all added constraints are satisfied).

Inside *callback_const_gen*, when *split_constraint_callback* is called the last time, it adds a constraint, as can be seen from the console output. However, the last call of *split_constraint_callback* should not find any more violated constraints. If a lazy constraint was added, then the solver should reoptimize the problem and then call the callback function again. Only after not adding any more constraints should the callback function not be called again.

Besides using MathOptInterface callback, these two methods should be equal and produce the same solution.

