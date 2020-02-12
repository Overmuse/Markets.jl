module Markets

using HTTP
using CSV
using Dates
using ProgressMeter: @showprogress
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

include("market.jl")
include("AlphaVantage.jl")
include("EODData.jl")
include("Polygon.jl")
end # module
