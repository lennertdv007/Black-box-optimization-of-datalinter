using CSV, DataFrames, Statistics

"""
dataset descriptors:

- type of each column
- amount of columns
- amount of rows
- amount of missing values in each column

--- For numeric columns ---
- mean of columns
- difference between min and max of columns
- standard deviation of columns
- amount of unique values in each column
- amount of same values in each column

--- For string columns ---
- unique values in each column
- mean length of each column
- amount of same values in each column

"""

function extract_metadata_from_csv(file_path::String)
    df = CSV.read(file_path, DataFrame)
    metadata = []

    for col in eachcol(df)
        col_name = propertynames(df)[findall(x -> df[!, x] === col, propertynames(df))[1]]
        col_type = eltype(col)
        n_missing = count(ismissing, col)

        col_metadata = Dict(
            :name => col_name,
            :type => string(col_type),
            :missing => n_missing
        )

        if eltype(col) <: Number
            col_metadata[:mean] = mean(skipmissing(col))
            col_metadata[:std] = std(skipmissing(col))
            col_metadata[:min] = minimum(skipmissing(col))
            col_metadata[:max] = maximum(skipmissing(col))
            col_metadata[:range] = col_metadata[:max] - col_metadata[:min]
            col_metadata[:unique_values] = length(unique(skipmissing(col)))
            col_metadata[:same_values] = countmap(skipmissing(col))
        elseif eltype(col) <: AbstractString
            col_metadata[:unique_values] = length(unique(skipmissing(col)))
            col_metadata[:mean_length] = mean(length.(skipmissing(col)))
            col_metadata[:same_values] = countmap(skipmissing(col))
        end

        push!(metadata, col_metadata)
    end

    return metadata
end

