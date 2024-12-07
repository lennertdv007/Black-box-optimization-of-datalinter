using Pkg
using DataFrames
Pkg.activate("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter")
Pkg.instantiate()

using DataLinter
#using Pkg; Pkg.add("BlackBoxOptim")

FILEPATH = "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/dataset_31_credit-g.arff"
CONFIG = DataLinter.Configuration.load_config("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter/CONFIG/default.toml")


LINTERS = CONFIG["linters"]
PARAMETERS = CONFIG["parameters"]

function print_config()
    for (linter, enabled) in LINTERS
        println("Linter: $linter")
        println("  Enabled: $enabled")
        linter_params = haskey(PARAMETERS, linter) ? PARAMETERS[linter] : Dict{String, Any}()
        println("  Parameters: $linter_params")
    end
end

function disable_all_linters() 
    for (value, key) in LINTERS
        LINTERS[value] = false
    end
end

function count_lint_error(output)
    for (linter, enabled) in LINTERS
        linters_true = 0
        linters_false = 0
        linters_nothing = 0
        for ((_linter,_), boo) in output
            if linter == String(_linter.name)
                if isnothing(boo)
                    linters_nothing += 1
                elseif boo
                    linters_true += 1
                else
                    linters_false += 1
                end
            end
        end
    print("Linter : ", linter," enabled=", enabled, " has found ", linters_true, " problems, ")
    print(linters_nothing, " times linter was not applicable, " )    
    println(linters_false, " times no problem was found")
    end
end

function run_datalinter()
    print("\n")
    println("Running datalinter on configuration : ")
    print_config()
    println("\n")
    #out = DataLinter.cli_linting_workflow("/Users/lennertdeville/Downloads/dataset_31_credit-g.arff", "", CONFIG)
    kb = DataLinter.kb_load("")
    ctx = DataLinter.DataInterface.build_data_context(FILEPATH)
    start_time = time()
    out = lint(ctx, kb; config=CONFIG, progress=false)
    elapsed_time = time() - start_time
    process_output(out; buffer=stdout, show_passing=false, show_stats=true, show_na=false)
    #println(out)
    println("Confguration took ", round(elapsed_time, digits=4), " seconds.")
    println("In that time, ", length(out), " problems were found.")
    print("\n")
    count_lint_error(out)
    return 1
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

