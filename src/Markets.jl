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
struct Daily <: AbstractResolution end
struct Minutely <: AbstractResolution end
struct Tick <: AbstractResolution end

abstract type AbstractQuoteType end
struct OHLC <: AbstractQuoteType end
struct Close <: AbstractQuoteType end
struct BidAsk <: AbstractQuoteType end

abstract type MarketDataProvider end
struct AlphaVantage <: MarketDataProvider end

export Market, Daily, Minutely, Tick, OHLC, Close, BidAsk, tick!, get_clock, get_price, get_dividend, generate_market

struct Market{R, Q} <: AbstractMarket where {R <: AbstractResolution, Q <: AbstractQuoteType}
    resolution :: R
    quote_type :: Q
    state :: Base.RefValue{Int64}
    open :: Base.RefValue{Bool}
    timestamps :: Vector{DateTime}
    assets :: Vector{String}
    prices :: Dict{String, Vector{Float64}}
    events :: Dict{String, <:NamedTuple}
end

function generate_market(assets, range; warmup = 0)
    prices = Dict{String, Vector{Float64}}()
    events = Dict{String, NamedTuple}()
    dates = Dict{String, Vector{DateTime}}()
    #start_date = advancebdays(BusinessDays.USNYSE(), start_date, -warmup)
    @showprogress for asset in assets
        quotes = get_historical(asset, range)
        divs = get_dividends(asset, range)
        prices[asset] = getindex.(quotes, "close")
        dates[asset] = Date.(getindex.(quotes, "date"))
        events[asset] = (dividends = Dict(Date.(getindex.(divs, "paymentDate")) .=> getindex.(divs, "amount")),)
    end
    if !all(x -> x == first(values(dates)), values(dates))
        @warn "Missing data for at least one ticker"
    end
    Market(Daily(), Close(), Ref(warmup+1), Ref(true), first(values(dates)), assets, prices, events)
end

Market(R, Q, timestamps, assets, prices, events) = Market(R, Q, Ref(1), Ref(true), timestamps, assets, prices, events)

function tick!(m::AbstractMarket)
    if get_clock(m) != last(m.timestamps)
        if Date(m.timestamps[m.state[] + 1]) != get_clock(m)
            if is_open(m)
                m.open[] = false
            else
                m.open[] = true
                m.state[] += 1
            end
        else
            m.state += 1
        end
    end
    return nothing
end

is_open(m::AbstractMarket) = m.open[]
get_clock(m::AbstractMarket) = m.timestamps[m.state[]]

function _validate_market_query(m::AbstractMarket, symbol::String, d::DateTime)
    if symbol ∉ m.assets
        error("Unknown symbol $symbol")
    elseif d > get_clock(m)
        error("Tried to query future timestamps in market.")
    elseif d ∉ m.timestamps
        error("Timestamp $d not available in market.")
    end
end

function get_price(m::Market, symbol::String, side = nothing, d::DateTime = get_clock(m))
    _validate_market_query(m, symbol, d)
    return m.prices[symbol][d .== m.timestamps][]
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
    m.state[] = 1
    m.open[] = true
end

include("AlphaVantage.jl")

end # module
