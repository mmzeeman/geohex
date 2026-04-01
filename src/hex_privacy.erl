-module(hex_privacy).

-export([
    latlon_to_hex/3,
    hex_to_latlon/1,
    coarsen/2,
    prefix_code/1
]).

%% Depends on the projection used.
-define(MAX_LEVEL, 31).
-define(MIN_LEVEL, 1).

%% ===========
%% Public API
%% ===========

%% Convert Lat/Lon → hex cell map #{level,q,r}
-spec latlon_to_hex(float(), float(), integer()) -> map().
latlon_to_hex(LatDeg, LonDeg, Level) 
  when Level >= ?MIN_LEVEL, Level =< ?MAX_LEVEL ->
    %{X, Y} = hex_proj_lambert_cylindrical_equal_area:latlon_to_xy(LatDeg, LonDeg),
    %{X, Y} = hex_proj_sinusoidal:latlon_to_xy(LatDeg, LonDeg),
    {X, Y} = hex_proj_laea:latlon_to_xy(LatDeg, LonDeg),
    CellSize = hex_grid:cell_size(Level),
    {Q, R} = hex_grid:xy_to_hex(X, Y, CellSize),
    #{ level => Level, q => Q, r => R }.

%% Convert hex cell → approximate Lat/Lon
-spec hex_to_latlon(map()) -> {float(), float()}.
hex_to_latlon(#{ level := Level, q := Q, r := R }) ->
    CellSize = hex_grid:cell_size(Level),
    {X, Y} = hex_grid:hex_to_xy(Q, R, CellSize),
    %hex_proj_lambert_cylindrical_equal_area:xy_to_latlon(X, Y).
    %hex_proj_sinusoidal:xy_to_latlon(X, Y).
    hex_proj_laea:xy_to_latlon(X, Y).

-spec coarsen(map(), integer()) -> map().
coarsen(#{ level := Level }=Hex, NewLevel)
    when Level > NewLevel andalso Level >= ?MIN_LEVEL, Level =< ?MAX_LEVEL ->
    {LatDeg, LonDeg} = hex_to_latlon(Hex),
    latlon_to_hex(LatDeg, LonDeg, NewLevel).


%% DB-friendly hierarchical prefix code
-spec prefix_code(map()) -> binary().
prefix_code(#{ level := L, q := Q, r := R }) ->
    Qs = signed_base36(Q, 6),
    Rs = signed_base36(R, 6),
    list_to_binary(
      io_lib:format("H~2..0B_Q~s_R~s", [L, Qs, Rs])
    ).

%% Signed fixed‑width base‑36
signed_base36(N, Width) ->
    Sign = if N < 0 -> $-; true -> $+ end,
    Abs = abs(N),
    Str = integer_to_base36(Abs),
    Padded = pad_left(Str, Width),
    [Sign | Padded].

integer_to_base36(N) when N < 36 ->
    [digit(N)];
integer_to_base36(N) ->
    integer_to_base36(N div 36) ++ [digit(N rem 36)].

digit(D) when D < 10 -> $0 + D;
digit(D) -> $A + (D - 10).

pad_left(Str, Width) ->
    Len = length(Str),
    if Len >= Width ->
            Str;
       true ->
            lists:duplicate(Width - Len, $0) ++ Str
    end.
