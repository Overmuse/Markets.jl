module Markets

using HTTP
using CSV
using DataFrames
using Dates
using ProgressMeter: Progress, next!
using DataFrames: groupby
using Polygon

import TradingBase:
    AbstractMarketDataAggregate,
    AbstractOrder,
    Close,
    OHLC,
    OHLCV,
    SimulatedMarketDataProvider,
    get_clock,
    get_close,
    get_last,
    get_historical,
    is_preopen,
    is_opening,
    is_open,
    is_closing,
    is_closed

export
    # Re-exports
    Close,
    OHLC,
    OHLCV,
    get_close,

    Market,
    Tick,
    BidAsk,
    tick!,
    get_clock,
    get_last,
    get_historical,
    generate_market,
    is_preopen,
    is_opening,
    is_open,
    is_closing,
    is_closed,
    reset!,
    warmup!

const RESOLUTION_MAPPING = Dict(
    Minute(1)  => "1min",
    Minute(5)  => "5min",
    Minute(10) => "10min",
    Minute(15) => "15min",
    Minute(30) => "30min",
    Minute(60) => "60min"
)

extract_price_data(x, q::Type{<:OHLCV}) = OHLCV(x.open, x.high, x.low, x.close, x.volume)
extract_price_data(x, q::Type{<:OHLC})  = OHLC(x.open, x.high, x.low, x.close)
extract_price_data(x, q::Type{<:Close}) = Close(x.close)

function _relevant_dates(dates, method = :fill_forward)
    if method == :fill_forward || method == :retain
        return sort(unique(reduce(vcat, dates)))
    elseif method == :remove
        return sort(collect(reduce(intersect, dates)))
    else
        error("Can only handle :fill_forward, :retain and :remove")
    end
end

_fill_forward(x::Close) = x
_fill_forward(x::OHLC) = OHLC(x.close, x.close, x.close, x.close)
_fill_forward(x::OHLCV) = OHLCV(x.close, x.close, x.close, x.close, 0)
_fill_forward(x::Missing) = missing

function preprocess_data(dates, data::Vector{T}, relevant_dates, method = :fill_forward) where T
    processed_data = Dict{DateTime, Union{T, Missing}}()
    for (i, date) in enumerate(relevant_dates)
        if date in dates
            processed_data[date] = data[date .== dates][]
        elseif method == :fill_forward
            if i == 1
                processed_data[date] = missing
            else
                processed_data[date] = _fill_forward(processed_data[relevant_dates[i-1]])
            end
        elseif method == :retain
            processed_data[date] = missing
        elseif method == :remove
            nothing
        end
    end
    return processed_data
end

abstract type MarketDataProvider end

function extract_timestamps(data, missing_data_handling)
    timestamps = _relevant_dates(collect.(keys.(values(data))), missing_data_handling)
end

function process_prices(timestamps, data, missing_data_handling)
    assets = keys(data)
    data_type = eltype(eltype(data).parameters[2]).parameters[2]
    processed_data = Dict{String, Dict{DateTime, Union{data_type, Missing}}}()
    for asset in assets
        processed_data[asset] = Dict{DateTime, Union{data_type, Missing}}()
        available_timestamps = keys(data[asset])
        if all(x -> x in available_timestamps, timestamps)
            processed_data[asset] = data[asset]
        else
            for (i, date) in enumerate(timestamps)
                if date in available_timestamps
                    processed_data[asset][date] = data[asset][date]
                elseif missing_data_handling == :fill_forward
                    if i == 1
                        processed_data[asset][date] = missing
                    else
                        processed_data[asset][date] = _fill_forward(processed_data[asset][timestamps[i-1]])
                    end
                elseif missing_data_handling == :retain
                    processed_data[asset][date] = missing
                elseif missing_data_handling == :remove
                    nothing
                end
            end
        end
    end
    processed_data
end

function generate_market(m::MarketDataProvider, r, q, assets, start_date, end_date; warmup = 0, missing_data_handling = :fill_forward)
    data = generate_data(m, r, q, assets, start_date, end_date)
    timestamps = extract_timestamps(data, missing_data_handling)
    prices = process_prices(timestamps, data, missing_data_handling)
    Market(r, timestamps, assets, prices, Dict{String, NamedTuple}(), warmup)
end

include("market.jl")
include("AlphaVantage.jl")
include("EODData.jl")
include("Polygon.jl")
end # module
