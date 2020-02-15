struct PolygonData <: MarketDataProvider
end

function generate_market(::PolygonData, r, ::Type{Close}, tickers, start_date, end_date; warmup=0)
    data = map(tickers) do ticker
        Polygon.get_historical_range(ticker, start_date, end_date, 1, "day", adjusted=true)
    end
    prices = Dict(map(zip(tickers, data)) do (ticker, ticker_data)
        ticker => Dict(unix2datetime(x["t"]/1000) => Close(x["c"]) for x in ticker_data if x["c"] != 0)
    end)
    timestamps = intersect(keys.(values(prices))...) |> collect |> sort
    Market(r, timestamps, tickers, prices, Dict{String, NamedTuple}(), warmup)
end

function generate_market(api::PolygonData, r, ::Type{OHLCV}, tickers, start_date, end_date; warmup=0)
    creds = Polygon.get_credentials()
    data = map(tickers) do ticker
        Polygon.get_historical_range(creds, ticker, start_date, end_date, 1, "day", adjusted=true)
    end
    prices = Dict{String, Dict{DateTime, OHLCV}}()
    for (ticker, ticker_data) in zip(tickers, data)
        ticker_prices = Dict{DateTime, OHLCV}()
        for x in ticker_data
            if x["c"] != 0
                try
                    y = OHLCV(x["o"], x["h"], x["l"], x["c"], x["v"])
                    ticker_prices[unix2datetime(x["t"]/1000)] = y
                catch e
                    time = unix2datetime(x["t"]/1000)
                    @warn "Invalid data for ticker $ticker at time $time" e
                end
            end
        end
        prices[ticker] = ticker_prices
    end
    timestamps = intersect(keys.(values(prices))...) |> collect |> sort
    Market(r, timestamps, tickers, prices, Dict{String, NamedTuple}(), warmup)
end
