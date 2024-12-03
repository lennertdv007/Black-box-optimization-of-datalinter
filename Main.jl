push!(LOAD_PATH, "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter")

using DataLinter
#using Pkg; Pkg.add("BlackBoxOptim")

filepath = "/Users/lennertdeville/Downloads/dataset_31_credit-g.arff"

configs_used = []

config = DataLinter.Configuration.load_config("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter/config/default.toml")

linters = config["linters"]
parameters = config["parameters"]


function print_used_linter()
    for (k,v) in config["linters"]
        println("Linter ", k, " is ", v, " typeof(v) = ", typeof(v))
    end
end    

function print_config()
    for (linter, enabled) in linters
        println("Linter: $linter")
        println("  Enabled: $enabled")
        
        # Get the corresponding parameters dictionary
        linter_params = haskey(parameters, linter) ? parameters[linter] : Dict{String, Any}()
        println("  Parameters: $linter_params")
    end
end

function exclude_all_linters()
    for (value, key) in linters
        linters[value] = false
    end
    return 1
end


function run_datalinter()
    print("\n")
    print("Running datalinter on configuration : ")
    print_config()
    println("\n")
    #out = DataLinter.cli_linting_workflow("/Users/lennertdeville/Downloads/dataset_31_credit-g.arff", "", config)
    kb = DataLinter.kb_load("")
    ctx = DataLinter.DataInterface.build_data_context(filepath)
    out = lint(ctx, kb; config, buffer=stdout, show_stats=true, show_passing=false, show_na=false)
    push!(configs_used,config)
    print("\n")
    return 1
end

exclude_all_linters()

for (value, key) in linters
    run_datalinter()
    linters[value] = true
end

run_datalinter()