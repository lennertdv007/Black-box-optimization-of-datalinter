using MLJ
Pkg.add("MLJ")
# step 0: generate a lot of data
# step 1) make 2 vectors : 1 with the metadata and 1 with the configuration of the best pareto point (highest score)
# step 2) choose a model 
# step 3) train the model with the metadata and the configuration of the best pareto point
# step 4) finetune model
# step 5) use the model to predict the score of the other pareto points