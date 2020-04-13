struct PolygonData <: MarketDataProvider
end

function generate_data(::PolygonData, r, q, assets, start_date, end_date)
    unit = lowercase(string(typeof(r)))
    amount = r.value
    data = map(assets) do asset
        vcat(DataFrame.(Polygon.get_historical_range(Polygon.get_credentials(), asset, start_date, end_date, amount, unit, adjusted=true))...)
    end
    rename!.(data, Dict(
        "c" => "close",
        "h" => "high",
        "l" => "low",
        "o" => "open",
        "v" => "volume") |> Ref
    )
    Dict(asset => Dict(unix2datetime(x.t/1000) => extract_price_data(x, q) for x in eachrow(d)) for (asset, d) in zip(assets, data))
end
