abstract type DatasetName end
name(dn::DatasetName) = lowercasefirst(String(nameof(typeof(dn))))
"""
    dict = Dict{String, DatasetName}()

Dictionary storing name of dataset as key (e.g. `"iris"`) and
struct with the same name as value (e.g. `Iris()`)
"""
dict = Dict{String, DatasetName}()
DsName(dn::DatasetName) = push!(dict, name(dn) => dn)
function preprocess(dn::DatasetName) end

"""
    function call_dataset(dataset)

Call script based on the provided argument `dataset` dataset.jl, which is located in 
./src/data subfolder. Registrate dataset using `DataDeps` package.
Download the dataset and create a csv file, see [`preprocess?`](@ref)).
"""
function call_dataset(dataset)
    pathToDsScript = joinpath(datasets_dir, "$dataset.jl")
    if !isfile(pathToDsScript)
        @error """No dataset $dataset found. Check for mistakes or create $dataset.jl"""
        throw(DatasetNotFoundErr("No dataset $dataset.jl found."))
    end
    include(pathToDsScript)
    dsName = get(dict, dataset, false)
    if dsName == false
        @error """Dataset $dataset not registered in dictionary dict"""
    end
    registering_dataset(dsName)
    @datadep_str dataset
end


"""
    registering_dataset(dsName::DatasetName)

Create a registration block for DataDeps package. 
"""
function registering_dataset(dsName::DatasetName)
    register(DataDep(
        name(dsName),
        """
            Dataset: $(name(dsName))
            Website: $(url(dsName))
        """,
        url(dsName),
        checksum(dsName),
        post_fetch_method = preprocess(dsName)
    ))
end

"""
    preprocess(path, name, header_names, target_col, categorical_cols, kwargs...)

Create csv file containing data from dataset in "standard" format.

The format can be described as - columns represents attributes, rows instances,
attributes in a row are separated by comma. First row of file is header, name of columns
can be passed in `header_names`, if not names `Column 1` are created.
Last column contains target values and is named Target, if `target_col` is provided
and has value within bounds. `categorical_cols` if provided prepend "Categ-" 
at the beginning of column name.
"""
function preprocess(
    path::String,
    name::String;
    header_names::Union{Vector{String}, Vector{Symbol}, Int} = 0,
    target_col::Int = 0,
    categorical_cols::Union{Int, UnitRange{Int}, Array{Int,1}} = 1:0, 
    kwargs...
)
    df = CSV.File(
        path, 
        header = header_names,
        missingstrings = ["", "NA", "?", "*", "#DIV/0!"],
        truestrings = ["T", "t", "TRUE", "true", "y", "yes"],
        falsestrings = ["F", "f", "FALSE", "false", "n", "no"],
        kwargs...
        ) |> DataFrame   
        
        
    last_col_index = ncol(df)

    for i in categorical_cols
        rename!(df, i => "Categ-"*names(df)[i])
    end

    #move target column to last position if not there already
    if target_col > 0 && target_col < last_col_index
        df.target = df[!,target_col]
        df = df[!,1:end .!=target_col]
    end
    if target_col == last_col_index
        rename!(df, last_col_index => "Target")
    end
    
    path_for_save = joinpath(dirname(path), "data-"*name*".csv")
    println(path_for_save)
    CSV.write(path_for_save, df, delim=',', writeheader=true)

end