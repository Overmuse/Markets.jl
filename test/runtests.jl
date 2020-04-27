using Test, Markets, Dates

@testset "All tests" begin
    prices = Close.(rand(32))
    dates = collect(DateTime(2020, 1, 1):Day(1):DateTime(2020, 2, 1))

    daily_close_market = Market(
        Day(1),
        dates,
        ["TEST"],
        Dict("TEST" => Dict(d => p for (d, p) in zip(dates, prices))),
        Dict("TEST" => (dividends = [],))
    )
    @test get_clock(daily_close_market) == DateTime(2020,1,1,0,0,0)
    @test is_preopen(daily_close_market)
    tick!(daily_close_market)
    @test is_opening(daily_close_market)
    tick!(daily_close_market)
    @test is_open(daily_close_market)
    @test Markets.get_current(daily_close_market, "TEST") == get_close(prices[1])
    tick!(daily_close_market)
    @test is_closing(daily_close_market)
    tick!(daily_close_market)
    tick!(daily_close_market)
    @test get_clock(daily_close_market) == DateTime(2020,1,2,0,0,0)
    @test get_last(daily_close_market, "TEST") == get_close(prices[1])
    @test Markets.get_current(daily_close_market, "TEST") == get_close(prices[2])
    hist = @test_logs (:warn, r"Can only get") get_historical(daily_close_market, "TEST", 10)
    @test length(hist) == 1
    @test hist[] == prices[1]
    reset!(daily_close_market)
    @test get_clock(daily_close_market) == DateTime(2020,1,1,0,0,0)
end
