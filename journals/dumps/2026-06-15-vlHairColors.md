# Raw dump: `vlHairColors` - 2026-06-15

Source: `log.txt` after running `vlHairColors` in the developer console.

```
[ValleyLife] ---- hair color palette ----
   1 : r=nil g=nil b=nil
   2 : r=nil g=nil b=nil
   3 : r=nil g=nil b=nil
   4 : r=nil g=nil b=nil
   5 : r=nil g=nil b=nil
   6 : r=nil g=nil b=nil
   7 : r=nil g=nil b=nil
   8 : r=nil g=nil b=nil
   9 : r=nil g=nil b=nil
  10 : r=nil g=nil b=nil
  11 : r=nil g=nil b=nil
  12 : r=nil g=nil b=nil
  13 : r=nil g=nil b=nil
  14 : r=nil g=nil b=nil
  15 : r=nil g=nil b=nil
  16 : r=nil g=nil b=nil
  17 : r=nil g=nil b=nil
  18 : r=nil g=nil b=nil
  19 : r=nil g=nil b=nil
  20 : r=nil g=nil b=nil
  21 : r=nil g=nil b=nil
  22 : r=nil g=nil b=nil
  23 : r=nil g=nil b=nil
  24 : r=nil g=nil b=nil
[ValleyLife] ---- end hair color palette ----
```

## Takeaways

- The palette has **24 entries** (so valid hair `color` indices are **1–24**).
- The RGB values printed `nil`: the entries are **not** plain `{r,g,b}` tables,
  so the first reader version couldn't decode them. The structure is something
  else (packed Color / userdata / different keys). The dump command needs to
  introspect the entry type/keys (TODO, then re-run for real RGB values).
- Until RGB is readable, find grey visually with the live cycler:
  `vlHairColor henryk <1..24>`.
- Note: Henryk was previously set to `color = 22`, which renders **white**, so
  grey is likely a slightly lower index - try the high-teens / low-20s first.
