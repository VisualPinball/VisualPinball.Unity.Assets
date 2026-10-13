# Flasher Dome, Red

A fluted red flasher dome for the common Williams/Bally mini-saucer mount, as used on Attack from Mars (#89 bulb). It is
modelled on the real 36-flute dome ("dome48"): an outer shell, a fitted inner surface, and a burst light that throws the
36-beam pattern onto the surroundings.

## Use

1. Drop `Flasher Dome, Red.prefab` onto the table, on the flasher's saucer/base (the prefab origin is the dome base, +Y up).
2. Map it in the **Lamp Manager** or **Coil Manager** to the flasher's lamp/coil. The root carries a VPE `LightComponent`.
   It drives `_InsertLampLevel` on the Glow and Outer renderers (Inner is a static HDRP Lit surface) and the intensity of the `Source` light. No other script is needed.
3. Use fade times that match an incandescent #89 flasher, roughly 0.015 s up and 0.03 s down (VPE fade fields are in seconds; the prefab leaves them at 0). The look is tuned for a
   physical (PWM / bulb-model) level, so a plain on/off coil also works.

## What's in the folder

| File | What |
|---|---|
| `Flasher Dome, Red.prefab` | Dome (Inner + Glow + Outer) + `Source` point light |
| `* - Outer.asset` | Outer shell mesh, smooth outer skin + mounting tab |
| `* - Inner.asset` | Inner surface: flutes, cap rays, inner wall (used by Inner and Glow, scaled 1.03/1.065/1.03) |
| `* - Inner.mat` | HDRP Lit, translucent, thickness map, VPE `ThickerPlastic` diffusion profile |
| `* - Glow.mat` | `FlasherDomeGlow` ShaderGraph: lit body glow, additive, PreRefraction queue |
| `* - Outer.mat` | `FlasherDomeOuter` ShaderGraph: refractive red shell, which also emits the bright flute lines, glints and the peak white-hot term |
| `FlasherDome.hlsl` | Shared custom function for both graphs (procedural 36-fold flute optics) |
| `* - Thickness.png`, `* - Emissive.png`, `* - Masks.exr`, `* - Parity.png` | Baked wall thickness, flute masks (`Emissive.png` sits on Inner's `_EmissiveColorMap` but Inner's emission is 0, so it is unused) |
| `* - Cookie.asset` | Burst-light cookie: 36 equal flute beams (floor .76) and the saucer-lip cut-off 16.7° below the filament |

## Light

- 85 lm, colour (1, .0127, .0028): measured red-dome spill (LuxCore).
- Range 1 m, no shadows, contact shadows off.
- `LightComponent` scales the intensity by the lamp level.

## Rendering layers (convention, set per table)

The `Source` light renders on **light layer 3 only** ("flash receivers"). The dome's own renderers are on layer 1, so they are
never lit by any burst light, their own or a neighbour's.

On your table, add layer 3 to every renderer that should receive flasher light: cabinet walls, back panel, plastics,
ramps, toys, posts and so on. Leave the playfield, ink overlay and inserts off layer 3 and light them with their own
mechanism. Otherwise the flash leaks under saucers and ramps.

This is a table-level choice, so the prefab does not set it on anything outside itself.

## Notes

- **Peak behaviour:** the shaders react to the lamp level alone.
  - Above level ~0.9 a short "peak flash" and a white-hot body term clip the dome cream-white with red edges, like a
    camera at the moment a #89 fires.
  - Below that it is deep red with yellow hot bars on the flutes.
  - Knobs on the Glow/Outer materials: `_PeakFlash` and `_WhiteHot`. Set either to 0 to turn that term off.
- **Tonemapping:** tuned under HDRP **Custom** tonemapping (per-channel filmic). ACES pulls the bright red toward salmon.
- **Filament:** `_OpticalLamp` on the Glow/Outer materials is the filament position in object space. Both materials use 0.0156 (tuned on Glow, whose mesh is scaled 1.065 in y, where it matches the `Source` light). Outer shares the value, so its filament sits ~0.9 mm lower; that is how the look was tuned.
