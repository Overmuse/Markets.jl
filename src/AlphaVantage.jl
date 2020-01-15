const AV_URL = "https://www.alphavantage.co/query"

function add_token!(params)
    merge!(params, Dict("apikey" => ENV["ALPHA_VANTAGE_KEY"]))
end

function alpha_vantage_get(params = Dict())
    add_token!(params)
    req = HTTP.get(AV_URL, query = params)
    CSV.read(req.body)
end

function _generate_market(::AlphaVantage, ::Minutely, asset::String)
    params = Dict(
        "function" => "TIME_SERIES_INTRADAY",
        "interval" => "1min",
        "symbol" => asset,
        "outputsize" => "full",
        "datatype" => "csv"
    )
    data = alpha_vantage_get(params)
    (timestamp = reverse(data.timestamp), close = reverse(data.close))
end

function generate_market(::AlphaVantage, ::Minutely, assets)
    data = map(assets) do asset
        _generate_market(AlphaVantage(), Minutely(), asset)
    end
    prices = Dict(map(zip(assets, data)) do (a, d)
        a => d.close
    end)
    timestamp = parse.(DateTime, data[1].timestamp, dateformat"Y-m-d H:M:S")
    Market(Minutely(), Close(), timestamp, assets, prices, Dict{String, NamedTuple}())
end
