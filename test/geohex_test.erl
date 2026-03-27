%% Test suite for geohex.erl

-module(geohex_test).

-include_lib("eunit/include/eunit.h").

%% Test encode/decode round trips.
test_encode_decode_round_trip() ->
    %% Add your test cases here
    ?assertEqual(Expected, geohex:decode(geohex:encode(Input))).

%% Test display/parse round trips.
test_display_parse_round_trip() ->
    %% Add your test cases here
    ?assertEqual(Expected, geohex:parse(geohex:display(Input))).

%% Test coarsen consistency.
test_coarsen_consistency() ->
    %% Add your assertions related to coarsen consistency.
    ?assertEqual(Expected, geohex:coarsen(Input)).

%% Test are_nearby consistency.
test_are_nearby_consistency() ->
    %% Add your assertions related to are_nearby consistency.
    ?assertTrue(geohex:are_nearby(CellA, CellB)).

%% Test neighbor generation.
test_neighbor_generation() ->
    %% Add your assertions regarding neighbor cells.
    ?assertEqual(ExpectedNeighbors, geohex:get_neighbors(Cell)).

%% Test cell_bounds sanity checks.
test_cell_bounds_sanity() ->
    %% Add your sanity check assertions for cell bounds.
    ?assertEqual(ExpectedBounds, geohex:cell_bounds(Cell)).

%% Helper functions

