struct PolygonData <: MarketDataProvider
end

function generate_market(::PolygonData, r, ::Type{Close}, tickers, start_date, end_date)
    data = map(tickers) do ticker
        Polygon.get_historical_range(ticker, start_date, end_date, 1, "day", adjusted=true)
    end
    prices = Dict(map(zip(tickers, data)) do (ticker, ticker_data)
        ticker => Dict(unix2datetime(x["t"]/1000) => Close(x["c"]) for x in ticker_data if x["c"] != 0)
    end)
    timestamps = intersect(keys.(values(prices))...) |> collect |> sort
    Market(r, Close, timestamps, tickers, prices, Dict{String, NamedTuple}())
end

function generate_market(::PolygonData, r, ::Type{OHLCV}, tickers, start_date, end_date)
    data = map(tickers) do ticker
        Polygon.get_historical_range(ticker, start_date, end_date, 1, "day", adjusted=true)
    end
    prices = Dict(map(zip(tickers, data)) do (ticker, ticker_data)
        ticker => Dict(unix2datetime(x["t"]/1000) => OHLCV(
            x["o"], x["h"], x["l"], x["c"], x["v"]) for x in ticker_data if x["c"] != 0)
    end)
    timestamps = intersect(keys.(values(prices))...) |> collect |> sort
    Market(r, OHLCV, timestamps, tickers, prices, Dict{String, NamedTuple}())
end
