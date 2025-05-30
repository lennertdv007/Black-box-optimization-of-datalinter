module BB_Optimization
export bb_optimization_best_pareto, bb_optimization, run_linter_on_1_lint, plot_only_results

using Pkg
using Plots
using Colors
Pkg.activate("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter")
#Pkg.instantiate()

using DataLinter
using BlackBoxOptim

FILEPATH = "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/freMTPL2freq.csv"
CONFIG = DataLinter.Configuration.load_config("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter/CONFIG/default.toml")

LINTERS = CONFIG["linters"]
PARAMETERS = CONFIG["parameters"]

function print_config(config)
    for (linter, enabled) in config["linters"]
        println("Linter: $linter")
        println("  Enabled: $enabled")
        p = config["parameters"]
        linter_params = haskey(p, linter) ? p[linter] : Dict{String,Any}()
        println("  Parameters: $linter_params")
    end
end

"""
Weights for each warning level used for the final score calculation
"""
const WARN_LEVEL_TO_NUM = Dict("info" => 1,
    "warning" => 3,
    "important" => 5,
    "experimental" => 0)

"""
Calculates the score of a lint error based on the amount of errors and the warning level
"""
function score_lint_error(lint_out)
    score = 0
    for ((linter, _), result) in lint_out
        if !isnothing(result)
            score += get(WARN_LEVEL_TO_NUM, linter.warn_level, 0)
        end
    end
    return score
end

function run_datalinter(conf, verbose=false, file=FILEPATH)
    if verbose
        print("\n")
        println("Running datalinter on configuration : ")
        print_config(conf)
        println("\n")
    end
    kb = DataLinter.kb_load("")
    ctx = DataLinter.DataInterface.build_data_context(file)
    start_time = time()
    out = lint(ctx, kb; config=conf, progress=false)
    elapsed_time = time() - start_time
    if verbose
        print("\n\n\n\n")
        println("Confguration took ", round(elapsed_time, digits=4), " seconds.")
        println("In that time, ", length(out), " problems were found.")
        print("\n\n\n\n")
    end
    s = score_lint_error(out)
    if verbose
        println("Score: ", s)
        print("\n\n\n\n")
    end
    return s, elapsed_time
end

"""
function that maps the paramaters to a config(Dict) for bb_optimize
"""
function params_to_config(params)
    config = Dict{String,Any}( # Initialize config 
        "parameters" => PARAMETERS,
        "linters" => Dict{String,Any}()
    )
    for (index, (key, value)) in enumerate(LINTERS)
        config["linters"][key] = Bool(params[index] > 0.5) # Float64 to Bool
    end
    index = 16
    for (key, value) in PARAMETERS
        if (length(value) == 0)
            config["parameters"][key] = Dict{String,Any}()
        else
            for (pkey, pvalue) in value
                if !(pkey == "zipcodes" || pkey == "unused_slot")
                    config["parameters"][key][pkey] = params[index]
                    index += 1
                end
            end
        end
    end
    return config
end

"""
function that calculates the pareto front points from list of points
    result = [(time, score, n_linters_enabled, params)]
    returns a list of pareto points
"""
function pareto_front(result)
    pf = []
    for p in result # p = (time, score, n_linters_enabled, params)
        dominated = false
        for q in result
            # highest score for each time is pareto point
            # same score and higher time is filtered
            if (q[1] <= p[1]) && (q[2] >= p[2]) && ((q[1] < p[1]) || (q[2] > p[2]))
                dominated = true
                break
            end
        end
        if !dominated # if not dominated, means that not found a point that is better => pareto point
            push!(pf, p)
        end
    end
    return pf
end

"""
function that extracts the best pareto point from the pareto front
    pareto_points = [(time, score, n_linters_enabled, params)]
    returns the best pareto point
    
    Will be extended with arguments for the best pareto point
"""
function extract_best_pareto(pareto_points)
    best = pareto_points[1]
    for p in pareto_points
        if p[2] > best[2] # higher score is better
            best = p
        end
    end
    return best
end

function plot_results(result, index)

    x = [time for (time, _, _, _) in result]
    y = [score for (_, score, _, _) in result]

    pl = plot(x, y, seriestype=:scatter, label="results", color=:blue, xscale=:log10)

    xlabel!("Time (log scale)")
    ylabel!("Score")
    savefig(pl, "plots/plot_$index.png")

end

"""
function to plot the result and the pareto front
    result = [(time, score, n_linters_enabled, params)]
    index = for the filename
    plot the pareto front of the result
"""
function plot_pareto(result, index)

    x = [time for (time, _, _, _) in result]
    y = [score for (_, score, _, _) in result]

    pf = pareto_front(result)
    xp = [t for (t, _, _, _) in pf]
    yp = [s for (_, s, _, _) in pf]

    pl = plot(x, y, seriestype=:scatter, label="All Points", color=:blue, xscale=:log10)
    plot!(pl, xp, yp, seriestype=:scatter, label="Pareto Front", color=:red)

    xlabel!("Time (log scale)")
    ylabel!("Score")
    savefig(pl, "plots/pareto_plot_$index.png")

end

function bb_optimization(file=FILEPATH)

    result = []
    """
    function that runs the linter and returns the time, score and n_linters_enabled
    """
    function linter_objective(params)
        # 1) construct a config for the datalinter which is a Dict
        config = params_to_config(params)
        # 2) run the linter with the config
        kb = DataLinter.kb_load("") # put this outside this scope?
        ctx = DataLinter.DataInterface.build_data_context(file) # put this outside this scope?
        start_time = time()
        out = lint(ctx, kb; config=config, progress=false)
        # 3) calculate the data error indicator and the timing
        elapsed_time = time() - start_time
        score = score_lint_error(out)
        n_linters_enabled = sum([config["linters"][linter] == true for linter in keys(config["linters"])])
        # 5 return the value of the fitness function
        return elapsed_time, score, n_linters_enabled
    end

    searchrange = [
        (0, 1), # uncommon_signs
        (0, 1), # enum_detector
        (0, 1), # empty_example
        (0, 1), # negative_values
        (0, 1), # tokenizable_string
        (0, 1), # number_as_string
        (0, 1), # int_as_float
        (0, 1), # long_tailed_distrib
        (0, 1), # uncommon_list_lengths
        (0, 1), # datetime_as_string
        (0, 1), # duplicate_examples
        (0, 1), # many_missing_values
        (0, 1), # large_outliers
        (0, 1), # circular_domain
        (0, 1), # zipcodes_as_values
        (1, 10), # distinct_max_limit (enum_detector)
        (0, 0.1), # distinct_ratio (enum_detector)
        (0, 10), # min_tokens (tokenizable_string)
        (0, 1), # match_perc (number_as_string)
        (1, 10), # zscore_multiplier (long_tailed_distrib)
        (0, 0.1), # drop_proportion (long_tailed_distrib)
        (0, 1), # match_perc (datetime_as_string)  
        (0, 1), # threshold (many_missing_values)
        (0, 100), # tukey_fences_k (large_outliers)
        (0, 1)] # match_perc (zipcodes_as_values)

    """
    function that runs objective and saves the results (wrapper function for bb_run)
    """
    function bb_run(params; fitness_function=linter_objective)
        time, score, n_linters_enabled = fitness_function(params)
        push!(result, (time, score, n_linters_enabled, params))
        return (1 / time, Float64(score)) # 1/time because we want to minimize time
    end

    res = bboptimize(bb_run;
        SearchRange=searchrange,
        Method=:borg_moea,
        NumDimensions=length(searchrange),
        FitnessScheme=ParetoFitnessScheme{2}(is_minimizing=false),
        MaxSteps=1000,
        ϵ=[0.01, 10])
    return result
end

"""
Function that runs the bb_optimization and returns the best pareto point [(time, score, n_linters_enabled, params)]
    file = path to the csv file
    returns the best pareto point
"""
function bb_optimization_best_pareto(file)
    result = bb_optimization(file)
    # extract the best pareto point
    pareto_points = pareto_front(result)
    best_pareto = extract_best_pareto(pareto_points)
    return best_pareto
end

function disable_all_linters(config)
    for (value, key) in config["linters"]
        config["linters"][value] = false
    end
end

function enable_all_linters(config)
    for (value, key) in config["linters"]
        config["linters"][value] = true
    end
end

function plot_lints(result, index)

    y = [score for (score, _) in result]
    x = [time for (_, time) in result]

    # Generate a distinct color for each point
    colors = distinguishable_colors(length(result))

    pl = plot(xlabel="Time ", ylabel="Score")

    #"""
    for i in 1:length(result)
        xi = x[i]
        yi = y[i]
        scatter!(pl, [xi], [yi], label="Linter $i", color=colors[i])
    end
    #"""

    savefig(pl, "plots/plot_1_lint_example_$index.png")
end

function run_linter_on_1_lint()
    index = 1
    for (root, dirs, files) in walkdir("datasets/")
        for file in files
            if startswith(file, ".")
                continue  # skip hidden files like .DS_Store, .gitignore, etc.
            else
                lint_result = []
                for (value, key) in LINTERS #loop to enable each linter sequentially
                    disable_all_linters(CONFIG)
                    LINTERS[value] = true
                    s, t = run_datalinter(CONFIG, false, joinpath(root, file))
                    push!(lint_result, (s, t))
                end
                plot_lints(lint_result, index)
                index += 1
            end
        end
    end
end

function plot_only_results()
    index = 1
    for (root, dirs, files) in walkdir("datasets/")
        for file in files
            if startswith(file, ".")
                continue  # skip hidden files like .DS_Store, .gitignore, etc.
            else
                result = bb_optimization(joinpath(root, file))
                # extract the best pareto point
                plot_pareto(result, index)
                index += 1
            end
        end
    end
end

end # module bb_Optimization
