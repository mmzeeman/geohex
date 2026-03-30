# Root Calculation for HexVeil (Aperture 3)

In the HexVeil Aperture 3 implementation, encoding involves an "extract digits" process that repeatedly divides axial coordinates by 3. Because we use a large offset (`Q_OFF`, `R_OFF`) to bring the entire Earth into a positive coordinate space, we must ensure that the `digits_to_axial` (decoding) process starts from the correct "root" cell.

If you change the number of levels (`MAX_LEVEL`) or the offsets, you must recalculate the root.

## How it works

The `extract_digits` function performes the following reduction at each step:

1.  Calculate `Digit = (Q - R) mod 3`.
2.  Subtract the digit's axial offset from `(Q, R)`.
3.  Perform the hierarchy transformation:
    - `PQ = (NQ - NR) div 3`
    - `PR = (NQ + 2*NR) div 3`

After `MAX_LEVEL` steps, the initial `(Q_OFF, R_OFF)` will have been reduced to a specific `(PQ, PR)` value. This value is your new root.

## Calculation Script

You can use the following Erlang script to find the root for any combination of offsets and levels.

```erlang
-module(find_root).
-export([main/1]).

main([LevelStr, QOffStr, ROffStr]) ->
    Level = list_to_integer(LevelStr),
    Q_OFF = list_to_integer(QOffStr),
    R_OFF = list_to_integer(ROffStr),
    {PQ, PR} = extract_root(Q_OFF, R_OFF, Level),
    io:format("Root for Level ~p, Offset {~p, ~p}: {~p, ~p}~n", 
              [Level, Q_OFF, R_OFF, PQ, PR]).

extract_root(Q, R, 0) -> {Q, R};
extract_root(Q, R, L) ->
    Digit = mod3(Q - R),
    {DQ, DR} = offset(Digit),
    NQ = Q - DQ,
    NR = R - DR,
    PQ = (NQ - NR) div 3,
    PR = (NQ + 2*NR) div 3,
    extract_root(PQ, PR, L-1).

offset(0) -> {0, 0};
offset(1) -> {1, 0};
offset(2) -> {0, 1}.

mod3(X) when X >= 0 -> X rem 3;
mod3(X) when X < 0 -> ((X rem 3) + 3) rem 3.
```

## How to run

1. Save the script as `find_root.erl`.
2. Compile and run:
   ```bash
   erlc find_root.erl
   erl -noshell -s find_root main 20 50000 50000 -s init stop
   ```

## Stable Root

For a given offset ratio (e.g., $Q_{off} = R_{off}$), as the number of levels increases, the root will eventually converge to a stable fixed point (e.g., `{1, -1}` for large offsets). If your `MAX_LEVEL` is high enough, you can use the stable root regardless of the exact offset value, as long as the offset is much larger than $3^{MAX\_LEVEL}$.
