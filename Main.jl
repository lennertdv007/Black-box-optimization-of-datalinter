using Pkg
#using DataFrames
Pkg.activate("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter")
Pkg.instantiate()

using DataLinter
Pkg.add("BlackBoxOptim");
using BlackBoxOptim

FILEPATH = "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/dataset_31_credit-g.arff"
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

function run_datalinter(conf)
    print("\n")
    println("Running datalinter on configuration : ")
    print_config(conf)
    println("\n")
    kb = DataLinter.kb_load("")
    ctx = DataLinter.DataInterface.build_data_context(FILEPATH)
    start_time = time()
    out = lint(ctx, kb; config=conf, progress=false)
    elapsed_time = time() - start_time
    print("\n\n\n\n")
    println("Confguration took ", round(elapsed_time, digits=4), " seconds.")
    println("In that time, ", length(out), " problems were found.")
    lint_error = count_lint_error(out)
    print("\n\n\n\n")
    s = score_lint_error(out)
    println("lint_error", lint_error)
    println("Score: ", s)
    print("\n\n\n\n")
    return s
end

"""
function that maps the paramaters to a config for bboptimize
    current version has only parameters to enable or disable linters
"""
function params_to_config(params)
    config = Dict{String,Any}( # Initialize config empty
        "parameters" => Dict{String,Any}(),
        "linters" => PARAMETERS # For now, don't touch the parameters
    )
    for (index, (value, key)) in enumerate(LINTERS)
        config["linters"][value] = params[index] > 0.5
    end
    return config
end

function main()

    function objective(params, time_weight=0.5)
        println("params: ", params)
        # 1) construct a config for the datalinter which is a temp toml file 
        config = params_to_config(params)
        # 2) run the linter with the config
        kb = DataLinter.kb_load("")
        ctx = DataLinter.DataInterface.build_data_context(FILEPATH)
        start_time = time()
        out = lint(ctx, kb; config=config, progress=false)
        # 3) calculate the data error indicator and the timing
        elapsed_time = time() - start_time
        s = score_lint_error(out)
        # score for linters that found nothing = 0, so this has no influence on the fitness function
        # maybe we should add a penalty for linters that found nothing? (score -= 1)?
        # 4) calculate the value of the fitness function (function that penalizes long timings and low errors)
        # bboptimize tries to minimize the fitness function

        fitness::Float64 = (elapsed_time * time_weight) + 1 / s
        normalized_fitness = (fitness - 1) / fitness
        # does the time_weight make sense?
        # does the fitness function need to be normalized?

        #fitness::Float64 = 1 / s
        # problem with this fitness function that it will just enable all the linters that have a score > 0

        # 5 return the value of the fitness function
        return normalized_fitness
    end

    # How can we use discrete values for the searchrange?
    # If not possible can we use a step size for the parameters?
    # If not possible can we use a different optimizer?
    searchrange = [
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1),
        (0, 1)]


    res = bboptimize(objective; searchrange=searchrange, NumDimensions=length(searchrange), StepRange=0.1, MaxSteps=1000)

    bs = best_candidate(res)
    bf = best_fitness(res)
    println("best candidate: ", bs, " with fitness: ", bf)
    println("best config: ", print_config(params_to_config(bs)))

    enable_all_param = [1 for i in 1:length(LINTERS)]
    x = run_datalinter(params_to_config(enable_all_param))
end
main()

