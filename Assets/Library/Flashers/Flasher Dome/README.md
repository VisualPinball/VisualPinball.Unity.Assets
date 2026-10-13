# Flasher Dome

A fluted flasher dome for the common Williams/Bally mini-saucer mount, as used on Attack from Mars (#89 bulb). It is
modelled on the real 36-flute dome ("dome48"): an outer shell, a fitted inner surface, and a burst light that throws the
36-beam pattern onto the surroundings. It is a template: the plastic colour is one material setting (`_DomeColor`), and
it ships as Red (the tuned original) plus Orange, Yellow, Olive, Green, Blue and Clear presets.

## Use

1. Drop `Flasher Dome, <Colour>.prefab` onto the table, on the flasher's saucer/base (the prefab origin is the dome base, +Y up).
2. Map it in the **Lamp Manager** or **Coil Manager** to the flasher's lamp/coil. The root carries a VPE `LightComponent`.
   It drives `_InsertLampLevel` on the Glow and Outer renderers (Inner is a static HDRP Lit surface) and the intensity of the `Source` light. No other script is needed.
3. Use fade times that match an incandescent #89 flasher, roughly 0.015 s up and 0.03 s down (VPE fade fields are in seconds; the prefab leaves them at 0). The look is tuned for a
   physical (PWM / bulb-model) level, so a plain on/off coil also works.

## Requirements

- HDRP **Light Layers** enabled in the HDRP asset (the default `HDRP.asset` has them off; VPE table projects normally have them on). The burst light and the dome renderers depend on them.
- VPE's `ThickerPlastic` diffusion profile registered in the HDRP global settings (Inner material).
- Inner also uses two textures from `_Generic/Tileable Textures` in this package, so copy those along if you move the folder out of the package.
- The prefab's `Source` light uses `Cookie Open` (no cut-off), which works on any mount. Use `Cookie Saucer` when the dome sits in a saucer: it cuts the light off below the saucer lip like the real part. On a flat surface it leaves a dark disc around the base.

## Colours

- **Pick a preset:** `Flasher Dome, Red.prefab` is the base. Orange, Yellow, Olive, Green, Blue and Clear are prefab
  variants of it. Each variant swaps in material variants (`Flasher Dome, <Colour> - Glow/Outer/Inner.mat`, parent = the
  Red material) and sets the `Source` light colour. Edit the Red prefab or materials and every colour follows.
- **Custom colour:** make a material variant of the Red Glow and Outer and set **Dome Colour** (`_DomeColor`) on both.
  This is the colour of the plastic held up to white light, i.e. its transmittance through the 2.4 mm wall. The shader
  turns it into an absorption coefficient (Beer–Lambert) and derives every term from it:
  - body glow: blackbody filament × `exp(-σ·thickness)`;
  - thin flute edges: closer to the filament colour;
  - hot bars, cores and peak: toward white.
  The red-tuned heat colours are remapped per channel by how much light each channel leaks, so Red is unchanged, Blue goes
  blue → cyan-white and Clear goes warm white. Nothing in the shader needs editing.
  For a custom colour also set:
  - the Inner (HDRP Lit) `_BaseColor`/`_TransmittanceColor`;
  - the Outer `_TransmittanceColor`;
  - the `Source` light colour.
  The presets' values come from the same model. The table and the script (`dome_colour.py`, which prints them for any
  colour) are in the "Make another dome" section.
- The per-term gains (`_BarNits`, `_WhiteHot`, `_HeatPeak`, `_PeakFlash`, ...) stay artistic knobs on the Glow/Outer materials.

| Preset | `_DomeColor` (sRGB) | σ (1/m, R G B) | Light colour |
|---|---|---|---|
| Red | (0.8996, 0.2052, 0.1804) | 100, 1400, 1500 | (1, 0.0127, 0.0028) |
| Orange | (0.9485, 0.6522, 0.1804) | 50, 400, 1500 | (1, 0.2177, 0.0022) |
| Yellow | (0.9688, 0.8530, 0.2052) | 30, 150, 1400 | (1, 0.4332, 0.0032) |
| Olive | (0.7666, 0.7266, 0.1804) | 250, 300, 1500 | (1, 0.5341, 0.0057) |
| Green | (0.2628, 0.8807, 0.3739) | 1200, 120, 900 | (0.0637, 1, 0.0504) |
| Blue | (0.2325, 0.5849, 0.9386) | 1300, 500, 60 | (0.0760, 0.5160, 1) |
| Clear | (0.9968, 0.9968, 0.9958) | 3, 3, 4 | (1, 0.6203, 0.3214) |

All presets keep the red light's 85 lm. A real blue or green dome passes fewer lumens of a #89's warm light, so lower
the intensity if it reads too strong.

## Make another dome

- **Another colour:** pick a preset, or follow "Custom colour" above.
- **Another flute count or shape:** the optics are procedural in `_FluteCount` (default 36), but three things are baked
  per mesh:
  1. **Mesh.** Model the dome:
     - outer shell + inner surface (flutes and cap rays);
     - the inner surface needs the mask atlas as UV channel 1 (Blender UV layer `UVMap`);
     - dome axis up, groove roots at azimuth 0 mod the pitch;
     - dome48 template: `params.py` / `build.py` in the AttackFromMars `blender/hardware/flashers/dome48/` folder.
  2. **Masks (≈1 min, Blender, CPU):**
     `blender -b --factory-startup --python bake_masks.py -- OUTDIR 1024 --flutes N --blend dome.blend --object Dome --cap-z 20`
     writes `<name>_masks.exr` (thick_n, thick_h, phase, flank) + `<name>_parity.png`. Use them as `Masks.exr` / `Parity.png`
     (import them like the existing ones: sRGB off, settings in the `.meta`). With `--flutes 36` on dome48 it reproduces the
     shipped `Masks.exr` / `Parity.png` exactly.
  3. **Set `_FluteCount` = N** on the Glow and Outer materials (Outer's flute lines are procedural; Glow reads the masks).
     The groove width stays a fixed fraction (±0.125) of the pitch.
  4. **Cookie:** the burst-light cookie is baked for 36 beams. Regenerate it with
     `FlasherDomeCookie.MakeBoth(N, "<folder>/<name>")`, an editor script. It writes Cookie Open + Cookie Saucer, and with
     N = 36 reproduces the shipped cookies exactly.
  5. **Inner thickness map:** a Unity ray-cast through the new mesh (AFM-VPE `AFMDomeWW.Build`).
  - Tools (`bake_masks.py`, `FlasherDomeCookie.cs`, `dome_colour.py`) live outside this package with the build recipe
    (pinball-rebuild `recipes/flasher-dome-tools/`), because this repo has no tools folder convention. Ask if you want
    them added here.

## What's in the folder

| File | What |
|---|---|
| `Flasher Dome, Red.prefab` | Dome (Inner + Glow + Outer) + `Source` point light: the base prefab |
| `Flasher Dome, <Colour>.prefab` | Prefab variants of Red: Orange, Yellow, Olive, Green, Blue, Clear (materials + light colour) |
| `Flasher Dome, <Colour> - Glow/Outer/Inner.mat` | Material variants of the Red materials (only the colour properties overridden) |
| `* - Outer.asset` | Outer shell mesh, smooth outer skin + mounting tab |
| `* - Inner.asset` | Inner surface: flutes, cap rays, inner wall (used by Inner and Glow, scaled 1.03/1.065/1.03) |
| `* - Inner.mat` | HDRP Lit, translucent, thickness map, VPE `ThickerPlastic` diffusion profile |
| `* - Glow.mat` | `FlasherDomeGlow` ShaderGraph: lit body glow, additive, PreRefraction queue |
| `* - Outer.mat` | `FlasherDomeOuter` ShaderGraph: refractive shell (colour from `_DomeColor` + `_TransmittanceColor`), which also emits the bright flute lines, glints and the peak white-hot term |
| `FlasherDome.hlsl` | Shared custom function for both graphs (procedural `_FluteCount`-fold flute optics, colour model) |
| `* - Thickness.png`, `* - Emissive.png`, `* - Masks.exr`, `* - Parity.png` | Baked wall thickness, flute masks (`Emissive.png` sits on Inner's `_EmissiveColorMap` but Inner's emission is 0, so it is unused) |
| `* - Cookie Open.asset` | Burst-light cookie (prefab default): 36 equal flute beams (floor .76), no cut-off |
| `* - Cookie Saucer.asset` | Same beams plus the saucer-lip cut-off 16.7° below the filament (8° soft edge), for saucer-mounted domes |

## Light

- 85 lm, colour (1, .0127, .0028) on Red: measured red-dome spill (LuxCore). The other presets use the same model
  (filament × the plastic's leak, remapped from the measured red value); see the table under Colours.
- Range 1 m, no shadows, contact shadows off.
- Cookie: `Cookie Open` by default. Swap in `Cookie Saucer` on the `Source` light (HDRP light > Emission > Cookie) when the dome sits in a saucer: the saucer lip blocks the light below 16.7° under the filament, and the cookie reproduces that.
- `LightComponent` scales the intensity by the lamp level.

## Rendering layers (convention, set per table)

The `Source` light renders on **light layer 3 only** ("flash receivers"). The dome's own renderers are on layers **0 + 1**
(mask 3) and never on layer 3, so they are never lit by any burst light, their own or a neighbour's.

Layer 0 is the HDRP default layer, which a table's GI lights normally use: with it, the unlit dome picks up a faint red body and
bulb reflections from nearby GI, as a real dome does, and goes dark when the GI is off. Layer 1 is kept for a sun/room light
on that layer. If your GI lights use another layer, add it to the Inner, Glow and Outer renderers.

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
