-module(isea4h_tests).
-include_lib("eunit/include/eunit.hrl").

%% Round-trip encode/decode at origin
roundtrip_test() ->
    Locations = [
        {0.0, 0.0},
        {10.0, 20.0},
        {-30.0, 45.0},
        {120.0, -10.0},
        {0.0, 90.0}, % North Pole
        {0.0, -90.0} % South Pole
    ],
    lists:foreach(fun({Lon, Lat}) ->
        Res = 7,
        Code = isea4h:encode(Lon, Lat, Res),
        {DLon, DLat} = isea4h:decode(Code),
        MaxErr = 1.0,
        IsPole = abs(Lat) > 89.0,
        LonMatch = IsPole orelse abs(DLon - Lon) < MaxErr orelse abs(abs(DLon - Lon) - 360.0) < MaxErr,
        LatMatch = abs(DLat - Lat) < MaxErr,
        case LonMatch andalso LatMatch of
            true -> ok;
            false -> 
                io:format(user, "~nAt (~p, ~p) got (~p, ~p) code ~p~n", [Lon, Lat, DLon, DLat, Code]),
                ?assert(false)
        end
    end, Locations).

roundtrip_res_test() ->
    Lon = 10.0, Lat = 20.0,
    lists:foreach(fun(Res) ->
        Code = isea4h:encode(Lon, Lat, Res),
        {DLon, DLat} = isea4h:decode(Code),
        %% At Res 1, error can be large (half a face).
        MaxErr = 2.0 / math:pow(2.0, Res-5), %% Heuristic
        ActualMaxErr = lists:max([1.0, MaxErr]),
        case abs(DLon - Lon) < ActualMaxErr andalso abs(DLat - Lat) < ActualMaxErr of
            true -> ok;
            false -> 
                io:format(user, "~nAt res ~p got (~p, ~p) code ~p (MaxErr ~p)~n", [Res, DLon, DLat, Code, ActualMaxErr]),
                ?assert(false)
        end
    end, lists:seq(1, 12)).

%% encode/2 should default to resolution 7
default_res_test() ->
    Code = isea4h:encode(1.23, 4.56),
    [_,Digits] = string:split(binary_to_list(Code), "-"),
    ?assertEqual(7, length(Digits)).

%% parent should remove one digit at the end (or leave as-is for resolution 1)
parent_test() ->
    Code = isea4h:encode(10.0, 20.0, 6),
    Parent = isea4h:parent(Code),
    [_, Digits] = string:split(binary_to_list(Code), "-"),
    [_, Pdigits] = string:split(binary_to_list(Parent), "-"),
    ?assertEqual(length(Digits)-1, length(Pdigits)).

%% neighbors returns six binary neighbor codes
neighbors_test() ->
    Code = isea4h:encode(10.0, 20.0, 5),
    N = isea4h:neighbors(Code),
    ?assertEqual(6, length(N)),
    lists:foreach(fun(C) -> ?assert(is_binary(C)) end, N).

%% privacy_code returns codes of the expected length for each privacy level
privacy_test() ->
    [_,D1] = string:split(binary_to_list(isea4h:privacy_code(0.0,0.0, city)), "-"),
    [_,D2] = string:split(binary_to_list(isea4h:privacy_code(0.0,0.0, district)), "-"),
    [_,D3] = string:split(binary_to_list(isea4h:privacy_code(0.0,0.0, neighbourhood)), "-"),
    [_,D4] = string:split(binary_to_list(isea4h:privacy_code(0.0,0.0, block)), "-"),
    ?assertEqual(4, length(D1)),
    ?assertEqual(6, length(D2)),
    ?assertEqual(7, length(D3)),
    ?assertEqual(9, length(D4)).

%% ico_verts returns the expected number of vertices (12)
ico_test() ->
    V = isea4h:ico_verts(),
    ?assertEqual(12, length(V)).
