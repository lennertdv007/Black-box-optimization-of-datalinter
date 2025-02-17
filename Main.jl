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

function print_config()
    for (linter, enabled) in LINTERS
        println("Linter: $linter")
        println("  Enabled: $enabled")
        linter_params = haskey(PARAMETERS, linter) ? PARAMETERS[linter] : Dict{String,Any}()
        println("  Parameters: $linter_params")
    end
end

function disable_all_linters()
    for (value, key) in LINTERS
        LINTERS[value] = false
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
    "experimental" => 0,
    "true" => 0,
    "false" => 0,
    "nothing" => -1)

"""
Calculates the score of a lint error based on the amount of errors and the warning level
"""
function score_lint_error(lint_error)
    score = 0
    for (linter, error_dict) in lint_error
        for (error_type, count) in error_dict
            score += WARN_LEVEL_TO_NUM[error_type] * count
        end
    end
    return score
end

function run_datalinter()
    print("\n")
    println("Running datalinter on configuration : ")
    print_config()
    println("\n")
    kb = DataLinter.kb_load("")
    ctx = DataLinter.DataInterface.build_data_context(FILEPATH)
    start_time = time()
    out = lint(ctx, kb; config=CONFIG, progress=false)
    elapsed_time = time() - start_time
    print("\n\n\n\n")
    #process_output(out; buffer=stdout, show_passing=true, show_stats=true, show_na=true)
    #print("\n\n\n\n")
    #print("out: ", out)
    #print("\n\n\n\n")
    println("Confguration took ", round(elapsed_time, digits=4), " seconds.")
    println("In that time, ", length(out), " problems were found.")
    print("\n\n\n\n")
    lint_error = count_lint_error(out)
    print("\n\n\n\n")
    s = score_lint_error(lint_error)
    println("Score: ", s)
    print("\n\n\n\n")
    return s
end


function main()
    disable_all_linters()
    for (value, key) in LINTERS #loop to enable each linter sequentially
        run_datalinter()
        LINTERS[value] = true
    end
    run_datalinter()
end
main()

