struct EODData <: MarketDataProvider
end

function generate_market(::EODData, ::Minutely, ::Close, warmup = 0; path = "/Users/sebastianrollen/data/NYSE/")
    data_path = path * "1min/"
    files = sort(data_path .* readdir(data_path))
    data = reduce(vcat, @showprogress map(files) do file
        CSV.read(file, dateformat = "d-u-Y H:M")
    end)
    sort!(data, (:Symbol, :Date))
    assets = unique(data.Symbol)
    timestamps = sort(unique(data.Date))
    prices = Dict{String, Vector{Float64}}()
    @showprogress for x in groupby(data, :Symbol)
        push!(prices, unique(x.Symbol)[] => x.Close)
    end
    Market(Minutely(), Close(), timestamps, assets, prices, Dict{String, NamedTuple}())
end
