push!(LOAD_PATH, "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter")
using DataLinter


config = DataLinter.Configuration.load_config("/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter/config/default.toml")

println(config)
println("\n\n")

out = DataLinter.cli_linting_workflow("/Users/lennertdeville/Downloads/dataset_31_credit-g.arff", "", "/Users/lennertdeville/Desktop/vub/3e_bach/bachelorproef/DataLinter/config/default.toml")
println(out)