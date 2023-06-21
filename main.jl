current_dir =  @__DIR__
cd(current_dir)

using Pkg
Pkg.activate(".")
Pkg.instantiate()

using EvoTrees
using Random
using Statistics
using JuMP
using Gurobi
include("manual_const_gen.jl")
include("callback_const_gen.jl")
include("util.jl")

const ENV = Gurobi.Env()

"DATA GENERATION"

Random.seed!(1)
n_feats = 5
data = randn(1000, n_feats)
data = data[shuffle(1:end), :]

split::Int = floor(0.75 * length(data[:, 1]))

x_train = data[1:split, :];
y_train = Array{Float64}(undef, length(x_train[:, 1]));
[y_train[i] = sqrt(sum(x_train[i, :].^2)) for i in 1:length(y_train)];

x_test = data[split+1:end, :];
y_test = Array{Float64}(undef, length(x_test[:, 1]));
[y_test[i] = sqrt(sum(x_test[i, :].^2)) for i in 1:length(y_test)];

"TREE MODEL CONFIGURATION AND TRAINING"

config = EvoTreeRegressor(nrounds=200, max_depth=5, T=Float64, loss=:linear);
model = fit_evotree(config; x_train, y_train);

pred_train = EvoTrees.predict(model, x_train)
pred_test = EvoTrees.predict(model, x_test)

"OPTIMIZATION"

x_call, sol_call, m_call = callback_const_gen(model, 5);
x_manual, sol_manual, m_manual = manual_const_gen(model, 5);

"CHECKING THE SOLUTION"

EvoTrees.predict(model, reshape([mean(x_call[n]) for n in 1:n_feats], 1, n_feats))[1]
EvoTrees.predict(model, reshape([mean(x_manual[n]) for n in 1:n_feats], 1, n_feats))[1]

sol_call
sol_manual