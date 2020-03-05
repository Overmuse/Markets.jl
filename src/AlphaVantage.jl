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

function get_price_data(::AlphaVantage, r::TimePeriod, q::Type{<:AbstractMarketDataAggregate}, asset::String, start_date, end_date)
    params = Dict(
        "function" => "TIME_SERIES_INTRADAY",
        "interval" => RESOLUTION_MAPPING[r],
        "symbol" => asset,
        "outputsize" => "full",
        "datatype" => "csv"
    )
    data = alpha_vantage_get(params)
    filter!(x -> Date(x.timestamp[1:10]) >= start_date && Date(x.timestamp[1:10]) <= end_date, data)
    df = dateformat"yyyy-mm-dd HH:MM:SS"
    Dict(parse(DateTime, x.timestamp, df) => extract_price_data(x, q) for x in eachrow(data))
end

function get_price_data(::AlphaVantage, r::DatePeriod, q::Type{<:AbstractMarketDataAggregate}, asset::String, start_date, end_date)
    params = Dict(
        "function" => "TIME_SERIES_DAILY",
        "symbol" => asset,
        "outputsize" => "full",
        "datatype" => "csv"
    )
    data = alpha_vantage_get(params)
    filter!(x -> x.timestamp >= start_date && x.timestamp <= end_date, data)
    Dict(x.timestamp+Time(0) => extract_price_data(x, q) for x in eachrow(data))
end

function generate_data(::AlphaVantage, r, q, assets, start_date, end_date)
    p = Progress(length(assets))
    Dict(asset => get_price_data(AlphaVantage(), r, q, asset, start_date, end_date) for asset in assets)
end
