struct EODData <: MarketDataProvider
end

function generate_data(::EODData, r, q, assets, start_date, end_date; path = "/Users/sebastianrollen/data/NYSE/")
    data_path = path * RESOLUTION_MAPPING[r]
    files = joinpath.(data_path, readdir(data_path))
    file_dates = Date.(getindex.(files, findfirst.(r"\d{8}", files)), "yyyymmdd")
    file_mask = map(x -> x >= start_date && x <= end_date, file_dates)
    files = files[file_mask]
    data_progress = Progress(length(files))
    data = mapreduce(vcat, files) do file
        next!(data_progress)
        CSV.read(file, dateformat = "d-u-Y H:M", header = [:symbol, :date, :open, :high, :low, :close, :volume], skipto=2)
    end
    sort!(data, (:symbol, :date))
    filter!(x -> x.symbol in assets, data)
    symbols = data.symbol |> unique
    groups = collect(groupby(data, :symbol))
    Dict(asset => Dict(x.date => extract_price_data(x, q) for x in eachrow(d)) for (asset, d) in zip(symbols, groups))
end
