using Pkg
using DataFrames
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
            result_dict[lname] = Dict("true" => 0, "false" => 0, "nothing" => 0, "info" => 0, "warning" => 0, "important" => 0, "experimental" => 0) # Initialize dict key with all 0 values
        end
        if isnothing(result)
            result_dict[lname]["nothing"] += 1
        elseif result
            result_dict[lname]["true"] += 1
            result_dict[lname][linter.warn_level] += 1
        else
            result_dict[lname]["false"] += 1
        end
    end
    #println("Error count: ", result_dict)
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
function score_lint_error(lint_error)
    score = 0
    for (linter, error_dict) in lint_error
        for (error_type, count) in error_dict
            score += get(WARN_LEVEL_TO_NUM, error_type, 0) * count
            #score += WARN_LEVEL_TO_NUM[error_type] * count
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
    #process_output(out; buffer=stdout, show_passing=true, show_stats=true, show_na=true)
    #print("\n\n\n\n")
    #print("out: ", out)
    #print("\n\n\n\n")
    println("Confguration took ", round(elapsed_time, digits=4), " seconds.")
    println("In that time, ", length(out), " problems were found.")
    lint_error = count_lint_error(out)
    print("\n\n\n\n")
    s = score_lint_error(lint_error)
    println("Score: ", s)
    print("\n\n\n\n")
    return s
end

"""
function that maps the paramaters to a config for bboptimize
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

    function objective(params)
        # 1) construct a config for the datalinter which is a temp toml file 
        config = params_to_config(params)
        # 2) run the linter with the config
        kb = DataLinter.kb_load("")
        ctx = DataLinter.DataInterface.build_data_context(FILEPATH)
        start_time = time()
        out = lint(ctx, kb; config=config, progress=false)
        # 2.2) delete config
        # 3) calculate the data error indicator and the timing
        elapsed_time = time() - start_time
        lint_error = count_lint_error(out)
        # 4) calculate the value of the fitness function (function that penalizes long timings and low errors)
        s = score_lint_error(lint_error)
        # 5 return the value of the fitness function
        return float(1 / s) + elapsed_time #ERROR: LoadError: ArgumentError: The supplied fitness function does NOT return the expected fitness type Float64 when called with a potential solution it returned 96 of type Int64 so we cannot optimize it!
    end # 1/s because bboptimize looks to minimize the fitness function

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

    res = bboptimize(objective; searchrange=searchrange, NumDimensions=length(searchrange), MaxSteps=700)

    bs = best_candidate(res)
    bf = best_fitness(res)
    println("best candidate: ", bs, " with fitness: ", bf, " = ", 1 / bf)
    println("best config: ", print_config(params_to_config(bs)))
end
main()

