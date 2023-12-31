function manual_const_gen(tree_model, tree_depth)
    
    "Data extraction from tree model"
 
    n_trees, n_feats, n_leaves, leaves, n_splits, splits, ordered_splits = extract_tree_model_info(tree_model, tree_depth)
    
    opt_model = direct_model(Gurobi.Optimizer(ENV))
    set_attribute(opt_model, "OutputFlag", 0)
    set_attribute(opt_model, "Presolve", 0)

    # Variable definitions as well as constraints (2g) and (2h)
    @variable(opt_model, x[feat = 1:n_feats, 1:n_splits[feat]], Bin) # indicator variable x_ij for feature i <= j:th split point (2g)
    @variable(opt_model, y[tree = 1:n_trees, 1:n_leaves[tree]] >= 0) # indicator variable y_tl for observation falling on leaf l of tree (2h)

    # Constraints (2f) and (2b) (constraint (2e) concerns only categorical variables)
    @constraint(opt_model, [i = 1:n_feats, j = 1:(n_splits[i]-1)], x[i,j] <= x[i, j+1]) # constraints regarding order of split points (2f)
    @constraint(opt_model, [tree = 1:n_trees], sum(y[tree, leaf] for leaf = 1:n_leaves[tree]) == 1) # observation must fall on exactly one leaf (2b)
    
    # Objective function (maximize / minimize forest prediction)
    @objective(opt_model, Min, tree_model.trees[1].pred[1] + sum(tree_model.trees[tree + 1].pred[leaves[tree][leaf]] * y[tree, leaf] for tree = 1:n_trees, leaf = 1:n_leaves[tree]))

    generated_constraints = 0
    added_constraint = true
    tree_counter = 0

    function check_violated(x_opt, y_opt)

        for tree in 1:n_trees

            tree_counter = tree

            current_node = 1 # start investigating from root
        
            while (current_node in leaves[tree]) == false # traverse from root until hitting a leaf
                
                # indices for leaves left/right from current node - indexing based on y vector convention
                right_leaves = children(current_node << 1 + 1, leaves[tree])
                left_leaves = children(current_node << 1, leaves[tree])

                # feature and split point index associated with current node
                current_feat, current_splitpoint_index = splits[tree, current_node]

                if isapprox(x_opt[current_feat, current_splitpoint_index], 1; atol = 1e-5) # node condition true - left side chosen...
                    if sum(y_opt[tree, right_leaves]) > 0.1 # ...but found from right

                        # Add constraint associated with current node (2d constraint)
                        @constraint(opt_model, sum(y[tree, right_leaves]) <= 1 - x[current_feat, current_splitpoint_index])
                        generated_constraints += 1
                        added_constraint = true
                        return

                    else # ...and found from left
                        current_node = current_node << 1 # check left child - continue search
                    end
                else # right side chosen...
                    if sum(y_opt[tree, left_leaves]) > 0.1 # ...but found from left
                        
                        # Add constraint associated with current node (2c constraint)
                        @constraint(opt_model, sum(y[tree, left_leaves]) <= x[current_feat, current_splitpoint_index])
                        generated_constraints += 1
                        added_constraint = true
                        return

                    else # ...and found from right
                        current_node = current_node << 1 + 1 # check right child - continue search
                    end
                end

            end
        end
    end

    while added_constraint

        optimize!(opt_model)

        x_opt = value.(opt_model[:x])
        y_opt = value.(opt_model[:y])

        added_constraint = false

        check_violated(x_opt, y_opt)
    end

    println("LAST TREE: $tree_counter, CONSTRAINT ADDED: $added_constraint")

    println("GENERATED CONSTRAINTS: $generated_constraints")

    return get_solution(n_feats, opt_model, n_splits, ordered_splits), objective_value(opt_model), opt_model

end