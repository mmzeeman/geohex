%%--------------------------------------------------------------------
%% hex_grid.erl
%%
%% Projection-agnostic hex grid engine for axial coordinates.
%% - Converts planar XY <-> axial hex (Q,R)
%% - Computes neighbors and distances in hex space
%%
%% Intended to be used together with a projection module (e.g.
%% hex_proj_sinusoidal, hex_proj_leexarax) and a level->cell_size
%% mapping module.
%%
%%--------------------------------------------------------------------

-module(hex_grid).

-export([
    %% conversions
    xy_to_hex/3,
    hex_to_xy/3,
    hex_round/2,

    %% topology
    neighbors/1,
    neighbor/2,
    distance/2,
    cell_size/1
]).

%% Types
-type coord() :: {integer(), integer()}.      %% axial (Q,R)
-type fcoord() :: {float(), float()}.
-type dir() :: 0 | 1 | 2 | 3 | 4 | 5.

%% Axial directions for pointy-top hexes
%% Index: 0..5
-define(DIRS,
        [
            { 1,  0},  %% 0: E
            { 1, -1},  %% 1: NE
            { 0, -1},  %% 2: NW
            {-1,  0},  %% 3: W
            {-1,  1},  %% 4: SW
            { 0,  1}   %% 5: SE
        ]).

-define(BASE,1.7320508075688772). % math:sqrt(3.0).
-define(MAX_LEVEL, 31).
-define(MIN_LEVEL, 9).

%%====================================================================
%% API: XY <-> axial hex
%%====================================================================

%% @doc Convert planar XY coordinates to axial hex (Q,R) at given cell size.
%%
%% X, Y: coordinates in projection space (e.g. sinusoidal, Lee–Xarax, etc.)
%% CellSize: effective scale factor for hex (controls size of cell)
%%
%% Returns axial integer coordinates representing the hex that covers (X,Y).
-spec xy_to_hex(float(), float(), float()) -> coord().
xy_to_hex(X, Y, CellSize)
when is_number(X), is_number(Y), is_number(CellSize), CellSize > 0.0 ->
    %% Continuous axial coordinates
    Qf = (math:sqrt(3)/3 * X - 1.0/3 * Y) / CellSize,
    Rf = (2.0/3 * Y) / CellSize,
    hex_round(Qf, Rf).

%% @doc Convert axial hex (Q,R) to planar XY coordinates for cell center.
%%
%% Returns XY of the center of the hex in projection space.
-spec hex_to_xy(integer(), integer(), float()) -> fcoord().
hex_to_xy(Q, R, CellSize)
when is_integer(Q), is_integer(R),
     is_number(CellSize), CellSize > 0.0 ->
    X = CellSize * math:sqrt(3) * (Q + R/2),
    Y = CellSize * (3.0/2 * R),
    {X, Y}.

%% @doc Round continuous axial coordinates (Qf,Rf) to nearest integer hex.
%%
%% Uses standard axial->cube rounding algorithm.
-spec hex_round(float(), float()) -> coord().
hex_round(Qf, Rf)
  when is_number(Qf), is_number(Rf) ->
    Xf = Qf,
    Zf = Rf,
    Yf = -Xf - Zf,

    Q = erlang:round(Qf),
    R = erlang:round(Rf),
    X = Q,
    Z = R,
    Y = -X - Z,

    Dx = abs(Xf - X),
    Dy = abs(Yf - Y),
    Dz = abs(Zf - Z),

    if Dx > Dy, Dx > Dz ->
           {-Y - Z, Z};      %% Adjust Q
       Dy > Dz ->
           {X, Z};           %% Adjust S, keep Q and R
       true ->
           {X, -X - Y}       %% Adjust R
    end.


%%====================================================================
%% API: neighbors and distance
%%====================================================================

%% @doc Return the 6 immediate axial neighbors of hex (Q,R).
-spec neighbors(coord()) -> [coord()].
neighbors({Q, R}) ->
    [ {Q + DQ, R + DR} || {DQ, DR} <- ?DIRS ].

%% @doc Return specific neighbor in direction Dir (0..5).
-spec neighbor(coord(), dir()) -> coord().
neighbor({Q, R}, Dir) when Dir >= 0, Dir =< 5 ->
    {DQ, DR} = lists:nth(Dir + 1, ?DIRS),
    {Q + DQ, R + DR}.

%% @doc Distance between two hexes (in number of hex steps).
%% Requires hexes to be at the same level (same grid scale).
-spec distance(coord(), coord()) -> non_neg_integer().
distance({Q1, R1}, {Q2, R2}) ->
    {X1, Y1, Z1} = axial_to_cube(Q1, R1),
    {X2, Y2, Z2} = axial_to_cube(Q2, R2),
    Dx = abs(X1 - X2),
    Dy = abs(Y1 - Y2),
    Dz = abs(Z1 - Z2),
    max3(Dx, Dy, Dz).

-spec cell_size(non_neg_integer()) -> float().
cell_size(Level) ->
    ?BASE * math:pow(math:sqrt(3), (?MAX_LEVEL - Level)).

%%====================================================================
%% Internal helpers
%%====================================================================

axial_to_cube(Q, R) ->
    X = Q,
    Z = R,
    Y = -X - Z,
    {X, Y, Z}.

max3(A, B, C) when A >= B, A >= C -> A;
max3(_A, B, C) when B >= C       -> B;
max3(_A, _B, C)                  -> C.
