module data_descriptors
export extract_metadata

using CSV, DataFrames, Statistics

"""
Fixed length vector
dataset descriptors:

- amount of columns
- amount of rows
- amount of missing values
- amount of unique values
- amount of duplicated rows
- amount of numeric columns
- amount of categorical columns
- amount of boolean columns

"""

function extract_metadata(file_path::String)
    df = CSV.read(file_path, DataFrame)
    metadata = []

    n_columns = ncol(df)
    n_rows = nrow(df)
    n_missing = sum(count(ismissing, col) for col in eachcol(df))
    n_unique = sum(length(unique(skipmissing(col))) for col in eachcol(df))
    n_duplicated_rows = nrow(df) - nrow(unique(df))
    n_numeric = count(col -> eltype(col) <: Real && !(eltype(col) <: Bool), eachcol(df))
    n_categorical = count(col -> eltype(col) <: AbstractString, eachcol(df))
    n_boolean = count(col -> eltype(col) <: Bool, eachcol(df))

    metadata = Vector{Int64}()
    append!(metadata, [
        n_columns,
        n_rows,
        n_missing,
        n_unique,
        n_duplicated_rows,
        n_numeric,
        n_categorical,
        n_boolean
    ])

    return metadata
end
end # module

