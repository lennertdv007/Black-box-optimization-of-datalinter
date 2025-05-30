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
# steps 6) Make 3 models: for speed, balanced and high scores.

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

DecisionTreeClassifier = MLJ.@load DecisionTreeClassifier pkg = DecisionTree

function train_model()

    X, Y = load_metadata()

    unique_configs = Dict{Vector{Float64},Symbol}()
    labels = Symbol[]

    for cfg in Y
        cfg_key = deepcopy(cfg)
        if !haskey(unique_configs, cfg_key)
            label = Symbol('a' + length(unique_configs))
            unique_configs[cfg_key] = label
        end
        push!(labels, unique_configs[cfg_key])
    end

    label_to_config = Dict(v => k for (k, v) in unique_configs)

    feature_names = ["f$i" for i in 1:8]
    X_matrix = reduce(vcat, [x_row' for x_row in X])
    X_df = DataFrame(X_matrix, feature_names)
    Y_labels = categorical(string.(labels))


    model = DecisionTreeClassifier()
    mach = machine(model, X_df, Y_labels)
    fit!(mach)
    #save model
    JLD2.@save "models/model1.jld2" mach label_to_config
end

function predict_config(x)
    mach, label_to_config = JLD2.@load "models/model1.jld2"
    x_df = DataFrame([x'], feature_names)
    probs = predict(mach, x_df)[1]
    top_label = argmax(probs)
    return label_to_config[top_label]
end

