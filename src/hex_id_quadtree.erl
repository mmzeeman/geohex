%%--------------------------------------------------------------------
%% hex_id_quadtree.erl
%%
%% Global equal-area QUADTREE hierarchical ID.
%% - prefix = region hierarchy
%% - projection-agnostic
%% - invertible
%% - robust (no sinusoidal instabilities)
%%--------------------------------------------------------------------

-module(hex_id_quadtree).

-export([
    from_latlon/3,
    to_latlon/1,
    to_hex/2,
    parent/1,
    level/1
]).

%%--------------------------------------------------------------------
%% PUBLIC API
%%--------------------------------------------------------------------

%% @doc Encode lat/lon at Level to global quadtree ID.
from_latlon(LatDeg, LonDeg, Level) ->
    {X,Y} = hex_proj_laea:latlon_to_xy(LatDeg, LonDeg),

    %% Establish a global bounding box
    %% Assume X,Y roughly in [-R..+R], where R ~ 6.4e6
    Root = face_from_xy(X, Y),
    Digits = quad_digits(X, Y, Level),

    encode_path(Root, Digits).

%% @doc Decode quad_id to approximate lat/lon center.
to_latlon(Id) ->
    {Root, Digits} = decode_path(Id),
    {X, Y} = quad_center_xy(Root, Digits),
    hex_proj_laea:xy_to_latlon(X, Y).

%% @doc Convert quad_id -> hex cell #{level,q,r}
to_hex(Id, Level) ->
    {Lat, Lon} = to_latlon(Id),
    CellSize = hex_grid:cell_size(Level),
    {X, Y} = hex_proj_laea:latlon_to_xy(Lat, Lon),
    {Q, R} = hex_grid:xy_to_hex(X, Y, CellSize),
    #{level => Level, q => Q, r => R}.

%% @doc Parent prefix
parent(Id) ->
    {Root, Digits} = decode_path(Id),
    case Digits of
        [] -> Id;
        _  -> encode_path(Root, lists:sublist(Digits, length(Digits)-1))
    end.

%% @doc Return hierarchical level
level(Id) ->
    {_Root, Digits} = decode_path(Id),
    length(Digits).

%%--------------------------------------------------------------------
%% INTERNAL: Quad subdivision (simple and robust)
%%
%% We treat the global XY plane as:
%%
%%   root faces: N,S,E,W = ({+X},{-X},{+Y},{-Y})
%%
%% Then recursively:
%%   at each level:
%%     split region into 4 quadrants
%%     digit encodes quadrant (0..3):
%%
%%      0 | 1
%%     ---+---
%%      2 | 3
%%
%% Scaling is implicit via bounding box.
%%--------------------------------------------------------------------

%% Root selection: 4 global faces
face_from_xy(X, Y) ->
    if abs(X) >= abs(Y) ->
           if X >= 0 ->
                  $E;
              true ->
                  $W
           end;
       true ->
           if Y >= 0 ->
                  $N;
              true ->
                  $S
           end
    end.

%% Compute digits for Level levels
quad_digits(X, Y, Level) ->
    quad_digits_loop(X, Y, Level, hex_proj_laea:world_bbox()).

quad_digits_loop(_X, _Y, 0, _BBox) ->
    [];
quad_digits_loop(X, Y, L, {MinX, MaxX, MinY, MaxY}) ->
    MidX = (MinX + MaxX) / 2,
    MidY = (MinY + MaxY) / 2,

    Digit = case {X >= MidX, Y >= MidY} of
                {false, false} -> 0;
                {true,  false} -> 1;
                {false, true}  -> 2;
                {true, true}  -> 3
            end,

    NewBox = case Digit of
        0 -> {MinX, MidX, MinY, MidY};
        1 -> {MidX, MaxX, MinY, MidY};
        2 -> {MinX, MidX, MidY, MaxY};
        3 -> {MidX, MaxX, MidY, MaxY}
    end,

    [Digit | quad_digits_loop(X, Y, L-1, NewBox)].

%% Compute center XY of a cell from Root & Digits
quad_center_xy(Root,Digits) ->
    B0 = hex_proj_laea:world_bbox(),
    %% Root influences starting region
    RootBox = root_bbox(Root, B0),
    quad_center_loop(RootBox, Digits).

quad_center_loop({MinX, MaxX, MinY, MaxY},[]) ->
    {(MinX + MaxX) / 2, (MinY + MaxY) / 2};
quad_center_loop({MinX, MaxX, MinY, MaxY},[D | Ds]) ->
    MidX = (MinX + MaxX) / 2,
    MidY = (MinY + MaxY) / 2,

    Box = case D of
              0 -> {MinX, MidX, MinY, MidY};
              1 -> {MidX, MaxX, MinY, MidY};
              2 -> {MinX, MidX, MidY, MaxY};
              3 -> {MidX, MaxX, MidY, MaxY}
          end,
    quad_center_loop(Box, Ds).

%%--------------------------------------------------------------------
%% BOUNDING BOX LOGIC
%% For LAEA projected Earth radius ~6.37e6
%% Use symmetric global bounding box.
%%--------------------------------------------------------------------

root_bbox($N, {MinX, MaxX, _MinY, MaxY}) ->
    %% upper half
    {MinX, MaxX, 0, MaxY};
root_bbox($S, {MinX, MaxX, MinY, _MaxY}) ->
    {MinX, MaxX, MinY, 0};
root_bbox($E, {_MinX, MaxX, MinY, MaxY}) ->
    %% right half
    {0, MaxX, MinY, MaxY};
root_bbox($W, {MinX, _MaxX, MinY, MaxY}) ->
    {MinX, 0, MinY, MaxY}.

%%--------------------------------------------------------------------
%% PREFIX ENCODING / DECODING
%%--------------------------------------------------------------------

encode_path(Root, Digits) ->
    %% ID format: <<"Q", RootChar, Digit,...>>
    list_to_binary([$Q, Root] ++ [digit_char(D) || D <- Digits]).

decode_path(Bin) ->
    [$Q, Root | Digits] = binary_to_list(Bin),
    {Root, [digit_val(C) || C <- Digits]}.

digit_char(D)
  when D>=0, D=<3 ->
    $0 + D.

digit_val(C) ->
    C - $0.
