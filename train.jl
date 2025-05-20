include("bb_optimization.jl")
include("data_descriptors.jl")
using .BB_Optimization
using .data_descriptors
using MLJ, MLJLinearModels
using JLD2
using DataFrames

# step 0: generate a lot of data
# step 1) make 2 vectors : 1 with the metadata and 1 with the configuration (as vector?) of the best pareto point (highest score)
# step 1.5) store the metadata and the configuration for later use (jld2, JSON, CSV, etc.)
# step 2) choose a model 
# step 3) train the model with the metadata and the configuration of the best pareto point
# step 4) finetune model
# step 5) use the model to predict the score of the other pareto points

metadataX = [] # vector of metadata(vector)
metadataY = [] # vector of config(Dict)

function save_metadata(x, y, path="train_data/metadata.jld2")
    JLD2.@save path metadataX = x metadataY = y
end

function load_metadata(path="train_data/metadata.jld2")
    JLD2.@load path metadataX metadataY
    return metadataX, metadataY
end

function generate_data()
    for (root, dirs, files) in walkdir("datasets/")
        for file in files
            if startswith(file, ".")
                continue  # skip hidden files like .DS_Store, .gitignore, etc.
            else
                println("Processing file: ", file)
                bp = BB_Optimization.bb_optimization_best_pareto(joinpath(root, file))
                md = data_descriptors.extract_metadata(joinpath(root, file))
                push!(metadataX, md) # metadata
                push!(metadataY, bp[4]) # params
            end
        end
    end
    println("metadataX: ", metadataX)
    println("metadataY: ", metadataY)
    save_metadata(metadataX, metadataY)
end

function train_model()
    X, y = load_metadata("train_data/metadata.jld2")

    model = LinearRegressor()
    mach = machine(model, X, y)
    fit!(mach)
    y_pred = predict(mach, X)  # Gives a vector of predictions
    println("Predictions: ", y_pred)

end
