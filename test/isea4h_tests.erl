-module(isea4h_tests).
-include_lib("eunit/include/eunit.hrl").

%% Round-trip encode/decode at origin
roundtrip_test() ->
    Locations = [
        {0.0, 0.0},
        {20.0, 10.0},
        {45.0, -30.0},
        {-10.0, 120.0},
        {90.0, 0.0}, % North Pole
        {-90.0, 0.0} % South Pole
    ],
    lists:foreach(fun({Lat, Lon}) ->
        Res = 7,
        Code = isea4h:encode({Lat, Lon}, Res),
        {DLat, DLon} = isea4h:decode(Code),
        MaxErr = 1.0,
        IsPole = abs(Lat) > 89.0,
        LonMatch = IsPole orelse abs(DLon - Lon) < MaxErr orelse abs(abs(DLon - Lon) - 360.0) < MaxErr,
        LatMatch = abs(DLat - Lat) < MaxErr,
        case LonMatch andalso LatMatch of
            true -> ok;
            false -> 
                io:format(user, "~nAt (~p, ~p) got (~p, ~p) code ~p~n", [Lat, Lon, DLat, DLon, Code]),
                ?assert(false)
        end
    end, Locations).

roundtrip_res_test() ->
    Lat = 20.0, Lon = 10.0,
    lists:foreach(fun(Res) ->
        Code = isea4h:encode({Lat, Lon}, Res),
        {DLat, DLon} = isea4h:decode(Code),
        %% At Res 1, error can be large (half a face).
        MaxErr = 2.0 / math:pow(2.0, Res-5), %% Heuristic
        ActualMaxErr = lists:max([1.0, MaxErr]),
        case abs(DLon - Lon) < ActualMaxErr andalso abs(DLat - Lat) < ActualMaxErr of
            true -> ok;
            false -> 
                io:format(user, "~nAt res ~p got (~p, ~p) code ~p (MaxErr ~p)~n", [Res, DLat, DLon, Code, ActualMaxErr]),
                ?assert(false)
        end
    end, lists:seq(1, 12)).

%% encode/2 should default to resolution 7
default_res_test() ->
    Code = isea4h:encode({4.56, 1.23}),
    [_,Digits] = string:split(binary_to_list(Code), "-"),
    ?assertEqual(7, length(Digits)).

%% parent should remove one digit at the end (or leave as-is for resolution 1)
parent_test() ->
    Code = isea4h:encode({20.0, 10.0}, 6),
    Parent = isea4h:parent(Code),
    [_, Digits] = string:split(binary_to_list(Code), "-"),
    [_, Pdigits] = string:split(binary_to_list(Parent), "-"),
    ?assertEqual(length(Digits)-1, length(Pdigits)).

%% neighbors returns six binary neighbor codes
neighbors_test() ->
    Code = isea4h:encode({20.0, 10.0}, 5),
    N = isea4h:neighbors(Code),
    ?assertEqual(6, length(N)),
    lists:foreach(fun(C) -> ?assert(is_binary(C)) end, N).

%% ico_verts returns the expected number of vertices (12)
ico_test() ->
    V = isea4h:ico_verts(),
    ?assertEqual(12, length(V)).

%% Verify the specific Lon/Lat of the icosahedron vertices
ico_coords_test() ->
    %% We need to reach into the internal to_xyz/decode logic or just verify the Verts list.
    %% Since ico_verts() returns XYZ, let's convert them back to Lon/Lat for verification.
    D2R = math:pi() / 180.0,
    Verts = isea4h:ico_verts(),
    Coords = [begin
                R = math:sqrt(X*X + Y*Y + Z*Z),
                Lat = math:asin(Z/R) / D2R,
                Lon = math:atan2(Y, X) / D2R,
                {Lon, Lat}
              end || {X, Y, Z} <- Verts],
    
    %% Expected Structure:
    %% 0: North Pole (90)
    %% 1-5: Upper Ring (~26.56 lat, 0, 72, 144, 216, 288 lon)
    %% 6-10: Lower Ring (~ -26.56 lat, 36, 108, 180, 252, 324 lon)
    %% 11: South Pole (-90)
    
    {_, NP_Lat} = lists:nth(1, Coords),
    ?assert(abs(NP_Lat - 90.0) < 0.0001),
    
    UpperRing = lists:sublist(Coords, 2, 5),
    lists:foreach(fun({_Lon, Lat}) ->
        ?assert(abs(Lat - 26.56505) < 0.001)
    end, UpperRing),
    
    LowerRing = lists:sublist(Coords, 7, 5),
    lists:foreach(fun({_Lon, Lat}) ->
        ?assert(abs(Lat + 26.56505) < 0.001)
    end, LowerRing),
    
    {_, SP_Lat} = lists:nth(12, Coords),
    ?assert(abs(SP_Lat + 90.0) < 0.0001),
    
    %% Check longitudes of upper ring (0, 72, 144, 216, 288)
    ExpectedUpperLon = [0.0, 72.0, 144.0, -144.0, -72.0], %% atan2 returns -180..180
    ActualUpperLon = [L || {L, _} <- UpperRing],
    lists:zipwith(fun(E, A) -> ?assert(abs(E - A) < 0.0001) end, ExpectedUpperLon, ActualUpperLon),
    
    ok.

%% Test that all 20 face centers are unique and project near zero
face_centres_test() ->
    Centres = isea4h:face_centres(),
    ?assertEqual(20, length(Centres)),
    
    %% For each center, encode it and verify the face ID
    lists:foreach(fun({I, {X, Y, Z}}) ->
                          %% Convert XYZ center back to Lon/Lat for encoding
                          D2R = math:pi() / 180.0,
                          R = math:sqrt(X*X + Y*Y + Z*Z),
                          Lat = math:asin(Z/R) / D2R,
                          Lon = math:atan2(Y, X) / D2R,

                          <<FaceBin:1/binary, $-, DigitsBin/binary>> = isea4h:encode({Lat, Lon}, 7),
                          ?assertEqual(I, binary_to_integer(FaceBin, 20), 
                                       io_lib:format("Center of face ~p encoded to face ~s", [I, FaceBin])),
        
                          %% At center (Q=0, R=0), with Off=1 bsl (Res-1), 
                          %% the first digit should be (1<<Bit)*2 + (1<<Bit) = 3.
                          %% Subsequent digits should be 0.
                          ?assertEqual(<<"3000000">>, DigitsBin, io_lib:format("Center of face ~p produced digits ~s", [I, DigitsBin]))
                    
                  end,
                  lists:zip(lists:seq(0, 19), Centres)),
    ok.
