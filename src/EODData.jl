struct EODData <: MarketDataProvider
end

function generate_market(::EODData, r::TimePeriod, ::Type{Close}, warmup = 0; path = "/Users/sebastianrollen/data/NYSE/")
    data_path = path * RESOLUTION_MAPPING[r]
    files = joinpath.(data_path, readdir(data_path))
    data = reduce(vcat, @showprogress map(files) do file
        CSV.read(file, dateformat = "d-u-Y H:M")
    end)
    sort!(data, (:Symbol, :Date))
    assets = unique(data.Symbol)
    timestamps = sort(unique(data.Date))
    prices = Dict{String, Dict{DateTime, Float64}}()
    @showprogress for x in groupby(data, :Symbol)
        prices[unique(x.Symbol)[]] = Dict(d => Close(c) for (d, c) in zip(x.Date, x.Close))
    end
    Market(r, Close, timestamps, assets, prices, Dict{String, NamedTuple}())
end
