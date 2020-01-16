module Markets

using HTTP
using CSV
using Dates

import TradingBase: AbstractOrder, get_last, get_historical

export
    Market,
    Daily,
    Minutely,
    Tick,
    OHLC,
    Close,
    BidAsk,
    tick!,
    get_clock,
    get_last,
    get_historical,
    generate_market

include("market.jl")
include("AlphaVantage.jl")

end # module
