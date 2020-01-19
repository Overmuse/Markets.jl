struct AlphaVantage <: MarketDataProvider end
const AV_URL = "https://www.alphavantage.co/query"

function add_token!(params)
    merge!(params, Dict("apikey" => ENV["ALPHA_VANTAGE_KEY"]))
end

function alpha_vantage_get(params = Dict())
    add_token!(params)
    req = HTTP.get(AV_URL, query = params)
    sort(CSV.read(req.body), :timestamp)
end

map_resolution(::Minutely) = "1min"
map_resolution(::Daily) = "daily"

extract_price_data(data, q::OHLC) = [(open = d.open, high = d.high, low = d.low, close = d.close) for d in eachrow(data)]
extract_price_data(data, q::Close) = data.close

function get_price_data(::AlphaVantage, r::IntradayResolution, q::AbstractQuoteType, asset::String)
    params = Dict(
        "function" => "TIME_SERIES_INTRADAY",
        "interval" => map_resolution(r),
        "symbol" => asset,
        "outputsize" => "full",
        "datatype" => "csv"
    )
    data = alpha_vantage_get(params)
    timestamp = parse.(DateTime, data.timestamp, dateformat"Y-m-d H:M:S")
    (timestamp = timestamp, price = extract_price_data(data, q))
end

function get_price_data(::AlphaVantage, r::Daily, q::AbstractQuoteType, asset::String)
    params = Dict(
        "function" => "TIME_SERIES_DAILY",
        "symbol" => asset,
        "outputsize" => "full",
        "datatype" => "csv"
    )
    data = alpha_vantage_get(params)
    (timestamp = convert.(DateTime, data.timestamp), price = extract_price_data(data, q))
end

function generate_market(::AlphaVantage, r::AbstractResolution, q::AbstractQuoteType, assets, warmup = 30)
    data = map(assets) do asset
        get_price_data(AlphaVantage(), r, q, asset)
    end
    prices = Dict(map(zip(assets, data)) do (a, d)
        a => d.price
    end)
    Market(r, q, Ref(warmup+1), Ref(PreOpen), data[1].timestamp, assets, prices, Dict{String, NamedTuple}())
end

function generate_market(::AlphaVantage, ::Minutely, q::AbstractQuoteType, assets, warmup = 30)
    data = map(assets) do asset
        get_price_data(AlphaVantage(), Minutely(), q, asset)
    end
    prices = Dict(map(zip(assets, data)) do (a, d)
        a => d.price
    end)
    Market(Minutely(), q, Ref(warmup+1), Ref(PreOpen), data[1].timestamp, assets, prices, Dict{String, NamedTuple}())
end
