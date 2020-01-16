module Markets

using HTTP
using CSV

import BusinessDays: BusinessDays, advancebdays
using Dates
import ProgressMeter: @showprogress
import TradingBase: AbstractOrder
import IEX: get_historical, get_dividends

abstract type AbstractMarket end
abstract type AbstractResolution end
abstract type IntradayResolution <: AbstractResolution end
struct Daily <: AbstractResolution end
struct Minutely <: IntradayResolution end
struct Tick <: IntradayResolution end

abstract type AbstractQuoteType end
struct OHLC <: AbstractQuoteType end
struct Close <: AbstractQuoteType end
struct BidAsk <: AbstractQuoteType end

abstract type MarketDataProvider end
struct AlphaVantage <: MarketDataProvider end

export Market, Daily, Minutely, Tick, OHLC, Close, BidAsk, tick!, get_clock, get_price, get_dividend, generate_market

@enum MarketState PreOpen Open Closed

struct Market{R, Q, P} <: AbstractMarket where {R <: AbstractResolution, Q <: AbstractQuoteType, P}
    resolution :: R
    quote_type :: Q
    tick_state :: Base.RefValue{Int}
    market_state :: Base.RefValue{MarketState}
    timestamps :: Vector{DateTime}
    assets :: Vector{String}
    prices :: Dict{String, P}
    events :: Dict{String, <:NamedTuple}
end

Market(R, Q, timestamps, assets, prices, events) = Market(R, Q, Ref(1), Ref(PreOpen), timestamps, assets, prices, events)

function tick!(m::AbstractMarket)
    if get_clock(m) != last(m.timestamps)
        if Date(m.timestamps[m.tick_state[] + 1]) != Date(get_clock(m))
            if is_open(m)
                m.market_state[] = Closed
            elseif m.market_state[] == PreOpen
                m.market_state[] = Open
            else
                m.tick_state[] += 1
                m.market_state[] = PreOpen
            end
        else
            if m.market_state[] == PreOpen
                m.market_state[] = Open
            else
                m.tick_state[] += 1
            end
        end
    end
    return nothing
end

is_open(m::AbstractMarket) = m.market_state[] == Open
get_clock(m::AbstractMarket) = m.timestamps[m.tick_state[]]

function _validate_market_query(m::AbstractMarket, symbol::String, d::DateTime)
    if symbol ∉ m.assets
        error("Unknown symbol $symbol")
    elseif d > get_clock(m)
        error("Tried to query future timestamps in market.")
    elseif d ∉ m.timestamps
        error("Timestamp $d not available in market.")
    end
end

function get_current(m::Market, symbol::String)
    price_quote = m.prices[symbol][get_clock(m) .== m.timestamps][]
end

function get_last(m::Market, symbol::String, d = get_clock(m))
    _validate_market_query(m, symbol, d)
    price_quote = m.prices[symbol][findlast(d .> m.timestamps)][]
end

function get_historical(m::Market, symbol::String, i)
    range = (m.tick_state[]-1-i):(m.tick_state[]-1)
    price_quote = m.prices[symbol][range]
end

function get_dividend(m::AbstractMarket, symbol::String, d::DateTime)
    _validate_market_query(m, symbol, d)
    divs = m.events[symbol].dividends
    if d in keys(divs)
        return divs[date]
    else
        return nothing
    end
end

function reset!(m::AbstractMarket)
    m.tick_state[] = 1
    m.market_state[] = PreOpen
end

include("AlphaVantage.jl")

end # module
