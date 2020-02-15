abstract type AbstractMarket <: SimulatedMarketDataProvider end
struct Tick; end

abstract type MarketDataProvider end

@enum MarketState PreOpen Opening Open Closing Closed

struct Market{R, P} <: AbstractMarket where {R <: Union{Period, Tick}, P <: AbstractMarketDataAggregate}
    resolution :: R
    tick_state :: Base.RefValue{Int}
    market_state :: Base.RefValue{MarketState}
    start_state :: Int
    timestamps :: Vector{DateTime}
    assets :: Vector{String}
    prices :: Dict{String, Dict{DateTime, P}}
    events :: Dict{String, <:NamedTuple}
end

Market(R, timestamps, assets, prices, events, warmup = 0) = Market(R, Ref(warmup+1), Ref(PreOpen), warmup+1, timestamps, assets, prices, events)

function tick!(m::AbstractMarket)
    if get_clock(m) != last(m.timestamps)
        if Date(m.timestamps[m.tick_state[] + 1]) != Date(get_clock(m))
            if is_preopen(m)
                m.market_state[] = Opening
            elseif is_opening(m)
                m.market_state[] = Open
            elseif is_open(m)
                m.market_state[] = Closing
            elseif is_closing(m)
                m.market_state[] = Closed
            elseif is_closed(m)
                m.tick_state[] += 1
                m.market_state[] = PreOpen
            else
                error("invalid market state")
            end
        else
            if is_preopen(m)
                m.market_state[] = Opening
            elseif is_opening(m)
                m.market_state[] = Open
            else
                # Open
                m.tick_state[] += 1
            end
        end
    end
    return nothing
end

is_preopen(m::AbstractMarket) = m.market_state[] == PreOpen
is_opening(m::AbstractMarket) = m.market_state[] == Opening
is_open(m::AbstractMarket) = m.market_state[] == Open
is_closing(m::AbstractMarket) = m.market_state[] == Closing
is_closed(m::AbstractMarket) = m.market_state[] == Closed
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

function get_current(m::Market{<:Any, Close{T}}, symbol::String) where T
    price = get(m.prices[symbol], get_clock(m), missing)
    return ismissing(price) ? missing : get_close(price)
end

function get_current(m::Market{<:Any, <:Union{OHLC, OHLCV}}, symbol::String)
    prices = get(m.prices[symbol], get_clock(m), nothing)
    if is_open(m) || m.market_state[] == Closed
        return get_close(prices)
    else
        return prices.open
    end
end

function get_last(m::Market{<:Any, Close}, symbol::String)
    prices = m.prices[symbol]
    for i in (m.tick_state[]-1):-1:1
        time = m.timestamps[i]
        if time in keys(prices)
            return get_close(prices[time])
        end
    end
    @warn "No pricing data found for ticker $symbol"
    return missing
end

function get_last(m::Market{<:Any, <:Union{OHLC, OHLCV}}, symbol::String)
    if is_preopen(m) || is_opening(m)
        prices = m.prices[symbol]
        for i in (m.tick_state[]-1):-1:1
            time = m.timestamps[i]
            if time in keys(prices)
                return get_close(prices[time])
            end
        end
        @warn "No pricing data found for ticker $symbol"
        return missing
    elseif is_open(m)
        prices = get(m.prices[symbol], get_clock(m), nothing)
        return prices.open
    elseif is_closing(m) || is_closed(m)
        prices = get(m.prices[symbol], get_clock(m), nothing)
        return get_close(prices)
    else
        error("Invalid market state")
    end
end

function get_historical(m::Market, symbol::String, i)
    lookback = min(i, m.tick_state[]-1)
    if lookback < i
        @warn "Can only get $lookback day(s) of market data. $i was asked for."
    end
    range = (m.tick_state[]-lookback):(m.tick_state[]-1)
    [get(m.prices[symbol], m.timestamps[r], missing) for r in range]
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
    m.tick_state[] = m.start_state
    m.market_state[] = PreOpen
end

function warmup!(m::AbstractMarket, i)
    m.tick_state[] = i+1
end
