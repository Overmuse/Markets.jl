using Test, Markets, Dates

@testset "All tests" begin
    prices = rand(32)
    daily_close_market = Market(
        Daily(),
        Close(),
        collect(DateTime(2020, 1, 1):Day(1):DateTime(2020, 2, 1)),
        ["TEST"],
        Dict("TEST" => prices),
        Dict("TEST" => (dividends = [],))
    )
    @test get_clock(daily_close_market) == DateTime(2020,1,1,0,0,0)
    @test !is_open(daily_close_market)
    tick!(daily_close_market)
    @test is_open(daily_close_market)
    @test Markets.get_current(daily_close_market, "TEST") == prices[1]
    tick!(daily_close_market)
    @test !is_open(daily_close_market)
    tick!(daily_close_market)
    tick!(daily_close_market)
    @test get_clock(daily_close_market) == DateTime(2020,1,2,0,0,0)
    @test get_last(daily_close_market, "TEST") == prices[1]
    @test Markets.get_current(daily_close_market, "TEST") == prices[2]
    hist = @test_logs (:warn, r"Can only get") get_historical(daily_close_market, "TEST", 10)
    @test length(hist) == 1
    @test hist[] == prices[1]
end
