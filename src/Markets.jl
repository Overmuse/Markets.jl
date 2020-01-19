module Markets

using HTTP
using CSV
using Dates
using ProgressMeter: @showprogress
using DataFrames: groupby

import TradingBase: AbstractOrder, get_last, get_historical

export
    Market,
    Tick,
    OHLC,
    Close,
    BidAsk,
    tick!,
    get_clock,
    get_last,
    get_historical,
    generate_market

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
end # module
