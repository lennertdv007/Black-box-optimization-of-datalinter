using Pkg
using Plots
#using Gadfly
Pkg.activate("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter")
Pkg.instantiate()

using DataLinter
Pkg.add("BlackBoxOptim");
using BlackBoxOptim

FILEPATH = "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/dataset_indie.csv"
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

function disable_all_linters(config)
    for (value, key) in config["linters"]
        config["linters"][value] = false
    end
end

"""
Returns a dictionary with for each Linter a dictionary with for each error type the amount of errors found
"""
function count_lint_error(output)
    result_dict = Dict{String,Dict{String,Int}}()
    for ((linter, _), result) in output
        lname = String(linter.name)
        if !haskey(result_dict, lname)
            result_dict[lname] = Dict("info" => 0, "warning" => 0, "important" => 0, "experimental" => 0) # Initialize dict key with all 0 values
        end
        if isnothing(result)
        elseif result
            result_dict[lname][linter.warn_level] += 1
        end
    end
    return result_dict
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

function run_datalinter(conf, verbose=false)
    if verbose
        print("\n")
        println("Running datalinter on configuration : ")
        print_config(conf)
        println("\n")
    end
    kb = DataLinter.kb_load("")
    ctx = DataLinter.DataInterface.build_data_context(FILEPATH)
    start_time = time()
    out = lint(ctx, kb; config=conf, progress=false)
    elapsed_time = time() - start_time
    if verbose
        print("\n\n\n\n")
        println("Confguration took ", round(elapsed_time, digits=4), " seconds.")
        println("In that time, ", length(out), " problems were found.")
        print("\n\n\n\n")
    end
    lint_error = count_lint_error(out)
    s = score_lint_error(out)
    if verbose
        println("lint_error", lint_error)
        println("Score: ", s)
        print("\n\n\n\n")
    end
    return s
end

function time_datalinter(conf)
    kb = DataLinter.kb_load("")
    ctx = DataLinter.DataInterface.build_data_context(FILEPATH)
    start_time = time()
    out = lint(ctx, kb; config=conf, progress=false)
    elapsed_time = time() - start_time
    return elapsed_time
end

"""
function that maps the paramaters to a config for bboptimize
    current version has only parameters to enable or disable linters
"""
function params_to_config(params)
    config = Dict{String,Any}( # Initialize config 
        "parameters" => PARAMETERS,
        "linters" => Dict{String,Any}()
    )
    for (index, (key, value)) in enumerate(LINTERS)
        config["linters"][key] = Bool(params[index] > 0.5)
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

function plot_pareto(result, index)

    x = [time for (time, score, n_linters_enabled, params) in result]
    y = [score for (time, score, n_linters_enabled, params) in result]

    pl = plot(x, y, seriestype=:scatter)
    xlabel!("Time")
    ylabel!("score")
    plot!(pl)
    savefig(pl, "all_points_$index.png")

    pf = pareto_front(result)
    xp = [t for (t, s, _, _) in pf]
    yp = [s for (t, s, _, _) in pf]
    plp = plot(xp, yp, seriestype=:scatter)
    xlabel!("Time")
    ylabel!("score")
    plot!(plp)
    savefig(plp, "pareto_point_$index.png")
end

# TODO implement pareto_frontier self
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
        if !dominated
            push!(pf, p)
        end
    end
    return pf
end

function main(epsilon)

    result = []
    function linter_objective(params, time_weight=0.5)
        #println("params: ", params)
        # 1) construct a config for the datalinter which is a Dict
        config = params_to_config(params)
        # 2) run the linter with the config
        kb = DataLinter.kb_load("")
        ctx = DataLinter.DataInterface.build_data_context(FILEPATH)
        start_time = time()
        out = lint(ctx, kb; config=config, progress=false)
        # 3) calculate the data error indicator and the timing
        elapsed_time = time() - start_time
        score = score_lint_error(out)
        # score for linters that found nothing = 0, so this has no influence on the fitness function
        # maybe we should add a penalty for linters that found nothing? (score -= 1)?
        # 4) calculate the value of the fitness function (function that penalizes long timings and low errors)
        # bboptimize tries to minimize the fitness function

        # Q: Does the score need to be normalized? A: No

        # 5 return the value of the fitness function
        # look for bb fitness functions
        # save for each run time, score, n_linters_enabled and config
        # calculate the numbers of linters enabled
        n_linters_enabled = sum([config["linters"][linter] == true for linter in keys(config["linters"])])
        #println("fitness: ", fitness, " elapsed_time: ", elapsed_time, " score: ", score, " n_linters_enabled: ", n_linters_enabled, "\n")
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


    # TODO align time and score
    function bb_run(params; fitness_function=linter_objective) # function that runs objective and saves the results
        time, score, n_linters_enabled = fitness_function(params)
        push!(result, (time, score, n_linters_enabled, params)) # TODO add config
        #println("score : ", score, " time : ", time)
        return (1 / time, Float64(score)) # 1/time because we want to minimize time
    end

    weightedfitness(f) = f[1] * 0.3 + f[2] * 0.7

    # TODO experiment with the parameters
    # TODO search for publications about metadata : 1 vector of values that describe the dataset
    # TODO Try on different datasets
    res = bboptimize(bb_run;
        SearchRange=searchrange,
        Method=:borg_moea,
        NumDimensions=length(searchrange),
        FitnessScheme=ParetoFitnessScheme{2}(is_minimizing=false),
        MaxSteps=10000, # vary the steps
        ϵ=epsilon) # vary epsilon

    bs = best_candidate(res)
    bf = best_fitness(res)
    println("best candidate: ", bs, " with fitness: ", bf)
    println("best config: ", print_config(params_to_config(bs)))
    println("pareto frontier points", pareto_frontier(res))

    return res, result
end

function epsilon_loop()
    eps = collect(0.1:0.1:0.9)
    for (index, e) in enumerate(eps)
        res, result = main(e)
        plot_pareto(result, index)
    end
end
