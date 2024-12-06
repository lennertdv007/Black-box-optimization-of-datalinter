push!(LOAD_PATH, "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter")

using DataLinter
#using Pkg; Pkg.add("BlackBoxOptim")

filepath = "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/dataset_31_credit-g.arff"
config = DataLinter.Configuration.load_config("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter/config/default.toml")

configs_used = []

linters = config["linters"]
parameters = config["parameters"]

function print_config()
    for (linter, enabled) in linters
        println("Linter: $linter")
        println("  Enabled: $enabled")
        linter_params = haskey(parameters, linter) ? parameters[linter] : Dict{String, Any}()
        println("  Parameters: $linter_params")
    end
end

function disable_all_linters() 
    for (value, key) in linters
        linters[value] = false
    end
    return 1
end

function count_lint_error(output)
    for (linter, enabled) in linters
        linters_true = 0
        linters_false = 0
        linters_nothing = 0
        for (linterCore, boo) in output
            if linter == String(linterCore[1].name)
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
    #out = DataLinter.cli_linting_workflow("/Users/lennertdeville/Downloads/dataset_31_credit-g.arff", "", config)
    start_time = time()
    kb = DataLinter.kb_load("")
    ctx = DataLinter.DataInterface.build_data_context(filepath)
    out = lint(ctx, kb; config, buffer=stdout, show_stats=true, show_passing=false, show_na=false)
    elapsed_time = time() - start_time
    push!(configs_used,config)
    #println(out)
    println("Confguration took ", round(elapsed_time, digits=4), " seconds.")
    println("In that time, ", length(out), " problems were found.")
    print("\n")
    count_lint_error(out)
    return 1
end

disable_all_linters()

for (value, key) in linters #loop to enable each linter sequentially
    run_datalinter()
    linters[value] = true
end

run_datalinter()
