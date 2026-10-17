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
- **Another flute count or shape:** the optics are procedural in `_FluteCount` (default 36), but a few things are baked per
  mesh. The generator tools are in `Tools~/` (Unity ignores `~` folders, so nothing there is imported or compiled).
  1. **Mesh.** Model the dome in any DCC tool with N flutes:
     - the wall as one closed solid (outer shell + inner surface with flutes and cap, carrying the `UVMap` atlas): the mask
       bake ray-casts against this one mesh, so both surfaces must be in it. Split it into `Outer` and `Inner` only for the
       Unity export;
     - Unity object space: +Y up, origin at the centre of the base (the shader assumes the filament about 15.6 mm above it);
     - dimensions the shader assumes (the #89 mini-saucer dome): outer radius about 15.5 mm, wall about 2.2-2.4 mm,
       inner groove root radius 13.95 mm and flat radius 13.25 mm, grooves about +-1.25 deg wide at N = 36 (+-0.125 of the pitch);
     - groove roots at azimuth theta = 0 mod pitch, with theta = atan2(-z, -x) in Unity object space;
     - the inner surface needs an unwrapped atlas (no overlaps) as **UV1**, used to sample the masks (in Blender: UV layer `UVMap`).
  2. **Masks (about 1 min, Blender, CPU).** In Blender terms the dome axis is +Z and theta = atan2(y, x):
     `blender -b --factory-startup --python Tools~/bake_masks.py -- OUTDIR 1024 --blend dome.blend --object DomeWall --flutes N --cap-z 20 --name mydome`
     writes `mydome_masks.exr` (R thick_n, G thick_h, B phase, A flank), `mydome_parity.png`, `mydome_coverage.png` and previews.
     Import them as the Masks / Parity textures (sRGB off, no compression for the EXR) and assign them on the Glow and Outer
     materials. With `--flutes 36` on the original dome it reproduces the shipped `Masks.exr` / `Parity.png`.
  3. **Inner thickness map** (the Inner HDRP Lit material's `_ThicknessMap`, sampled with the Inner mesh's **UV0**; the shipped
     one is `* - Thickness.png`, 512 px, linear 8-bit grey, value = clamp(thickness / 3 mm, 0, 1)). The shipped map was baked in
     Unity by ray-casting from each texel along the interpolated inward vertex normal against the dome's MeshCollider (rays up
     to 6 mm, misses stored as 3 mm, 6 dilation passes), which reads near 0 mm over about half the inner surface. A map
     baked another way (e.g. a flat-normal ray cast to the opposite wall, or the masks' `thick_n` channel) comes out thicker
     overall, so retune the Inner material's `_ThicknessRemap` by eye against the Red preset rather than keeping (0, 0.1119).
  4. **Set `_FluteCount` = N** on the Glow and Outer materials (Outer's flute lines are procedural; Glow reads the masks).
     The groove width stays a fixed fraction (+-0.125) of the pitch.
  5. **Cookie.** The burst-light cookie is baked for 36 beams. Copy `Tools~/FlasherDomeCookie.cs` into an Editor folder of your
     project (it is an Editor script, so it must not sit in a runtime folder) and run
     `FlasherDomeCookie.MakeBoth(N, "Assets/MyDome/MyDome")`. It writes `... - Cookie Open.asset` and `... - Cookie Saucer.asset`;
     with N = 36 it reproduces the shipped cookies. Assign one to the `Source` light's Cookie slot.
  6. **Custom plastic colour:** `python3 Tools~/dome_colour.py 100 1400 1500` takes the absorption sigma (R G B, 1/m; Red shown), or
     `python3 Tools~/dome_colour.py --t R G B` takes the linear transmittance through the 2.4 mm wall. It prints `_DomeColor` for the
     Glow and Outer materials, the `Source` light colour, the Outer `_TransmittanceColor` and the Inner `_BaseColor` / `_TransmittanceColor`.
     The formula: T = exp(-sigma * 2.4 mm) per channel, and the red-tuned colours are remapped by how much light each channel leaks
     (see `FD_Remap` in `FlasherDome.hlsl`); the light colour is the 2900 K filament colour (1, 0.682, 0.403) times the red-tuned
     (1, 0.0127, 0.0028) leak, remapped the same way.
- **A hemisphere ("hat", e.g. Stern 550-5510 half dome):** set `_ProfileMode` = 1 on the Glow and Outer materials. Mode 0 (default)
  is the tall barrel + cap dome above, unchanged; mode 1 treats the wall as a sphere / ellipsoid with flutes along the meridians
  converging at the pole (the pole region plays the cap: rays, cap spot, X-beams). Mode-1 knobs, read only in mode 1:
  `_SphereY` (centre height; a vertical skirt below it), `_InnerR` / `_InnerRY` (inner groove-root semi-axes, horizontal /
  vertical), `_CapR` (radius that normalises the top-view cap terms), `_CapBlend` (barrel-to-cap blends on the wall normal's y:
  x..y for the ray/streak weights, z..w for the cap-face terms), `_OuterTh` (Outer's wall model: groove-root and flat thickness,
  mean thickness), `_GrooveHalf` (groove half-width in periods), `_FluteLen` (flute length along the meridian, for glints/needles),
  `_GlintBandY`, `_BarR0` (bars cut only inside this radius at the pole hub). `_FluteOffset` (rad, both modes, default 0, keep within -pi..pi) shifts
  the procedural flute coordinates only; the masks are not shifted, so keep the mesh's groove roots at theta = 0 instead.
  Bake the masks with `--inner sphere` (`--centre-z` = sphere centre height in mm) or, as the shipped Flasher Half Dome was,
  with the default axis rule and a low cap height (`--flutes 32 --cap-z 5`), and the cookie with
  `FlasherDomeCookie.MakeBoth(N, prefix, capWash: 0)` if the beams should continue to the zenith. Set `_OpticalLamp` to the real
  filament position (base plane = y 0). Keep every other value at the Red dome's (the Flasher Half Dome
  does): the in-game look carries over between domes of the same style. On a short part some tall-dome terms simply have no
  effect, e.g. `_ShoulderAlpha`, `_WallEdge`, `_BarShoulder` and `_GlintBand` (its band sits at `_GlintBandY` = 24.5 mm).

## Ambient glow

`_AmbientGlow` (Glow material, default 0 = off) adds the room light diffused through the plastic: emission = `_AmbientGlow` x the
sky ambient probe (all-directions average) + directional lights x the wall transmission from `_DomeColor` x a thickness/grazing mask.
It follows the room light and the HDRI exposure. 1 = a white diffuser.
`_AmbientShape` shapes it: x brightens the flute edges (mask phase near the groove root), y darkens the facet centres, z is the
rim/grazing gain, w the thickness contrast. The default (0, 0, 0.8, 0.45) is the plain form.

`_BBTemp` (Glow and Outer, default 0 = 2900 K) sets the filament temperature at level 1 for the dome's own emission. Lower it when
the preset's Source light is warmer than a 2900 K body, so the dome stays at least as warm as its spill while it cools.

## Clear plastic (lens inner, skin milk)

Knobs for a clear dome, all default off (every preset unchanged):

- `FlasherDomeLens.shadergraph` (+ `FlasherDomeLens.hlsl`) is an inner for a clear dome. Each flute acts as a cylinder lens that shows a
  strip of the live environment (colour pyramid on the table plane, else the HDRP sky), with Fresnel/TIR paths. `_LensEnv` 0 = the
  plain frosted inner. It takes the flute geometry of the Glow material (`_FluteCount`, `_FluteOffset`, `_ProfileMode`, `_SphereY`,
  `_InnerR`, `_InnerRY`) and its `_DomeMasks` (uv1).
  - `_LensMilk` (x gain, y/z path in mm where the white starts/saturates, w crest sharpen) with `_LensMilkShape` (x crest half-width in
    flute periods, y flank floor, z mask channel 0 thick_n .. 1 thick_h, w base fade height m) and `_LensMilkColor`: clear acrylic reads
    white where it is thick. The path through the wall (mask thickness along the refracted view ray) and a crest line at each rib
    centre mix the room light (sky ambient probe + directional lights) into the lens image. So the ridge tips go white, the thin
    flanks stay clear, and the white follows the room. The base fade (w) hides the fluted base contour of the inner.
  - `_LensParallax` (x outer radius in this renderer's object units, y outer vertical semi-axis (hat) / top plane (tall dome)) takes the
    flute coordinate where the view ray enters the outer skin. The scaled inner then agrees with the Outer's own flute lines; otherwise
    the groove line is doubled.
  - `_LensFloorFill` (x weight, y mip, z radius m): downward lookups that leave the screen or graze use the table near the dome instead
    of the sky's lower half (which darkened the lower dome).
  - `_ProfileMode` 2 = flat part (e.g. the half dome's `Tabs` on this graph). There are no flutes: the mesh normal refracts the view to
    the table under the part, the milk path is the distance to the part's bottom (capped at `_LensGlow.w` mm), and `_LensGlow`
    (x nits at level 1, y root radius m, z falloff m) x `_LensGlowColor` is the lamp light carried into the tab, brightest at the root.
- `_SkinMilk` (Outer only; Glow/Outer graphs and their Frost variants declare it) has x gain, y base band height m, z silhouette (grazing)
  gain and w mounting-tab gain. `_SkinFoot` (x rho min m, y top m, z side-face boost) sets the tab region of the tall dome's Outer mesh,
  and `_SkinMilkColor` the tint. Together they make the Outer skin milky where it is thick or seen edge-on: the base ring, the
  silhouette, and the full dome's tabs (part of the Outer mesh) with brighter side faces.
- Far-tab hide (all default off). Every Clear dome renderer is transparent without depth writes, and the tabs draw after the lens
  Inner, so the far tab otherwise lies on top of the dome body as a sharp shape. A real dome's flutes scramble it.
  - `_SkinFoot.w` (Outer, tall dome): strength. A tab fragment whose ray to the camera passes through the barrel (outer radius
    15.43 mm, up to 29.0 mm) loses its milk, line emission and alpha.
  - Flat part (`_ProfileMode` 2) on `FlasherDomeLens`: `_LensParallax` x, y = the dome's outer ellipsoid semi-axes (m, centre at the
    object origin), z = strength, w = edge softness (m).
- `_LensInterior` (x weight, 0 = off; y blur mip; z hot-core mip; w hot-core gain): opaque objects inside the dome (a bulb, a socket,
  a toy) show through the flutes. The transmitted ray is marched through the cavity against the camera depth (opaques only) and,
  where it passes behind an opaque surface, the colour pyramid is read there instead of the floor: refracted, blurred at mip y,
  with a blown-out core kept as max(blurred, w x mip z).
- `_LensCrease` z, w: a second crease applied after the milk (z strength, w half-width in flute periods, 0 = y). The milk otherwise
  paints over the groove-root crease.

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
| `FlasherDomeFrost.shadergraph` + `FlasherDomeFrost.hlsl` | Frosted inner for a clear dome: transparent, rough thin refraction (blurred see-through) when OFF, blends with the lamp level (`_FrostLitRamp`) to an opaque smooth darker wall when lit so the flute glow stays structured |
| `FlasherDomeOuterFrost.shadergraph` | `FlasherDomeOuter` without refraction, to sit over the frosted inner (a refractive Outer would overwrite it) |
| `FlasherDomeGlowFrost.shadergraph` | `FlasherDomeGlow` in the default transparent pass (sort priority -1), drawn crisp after the frosted inner |
| `FlasherDomeLens.shadergraph` + `FlasherDomeLens.hlsl` | Clear-dome inner: per-flute environment lens + thickness milk, flat-part mode for tabs (see "Clear plastic") |
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

Layer 0 is the HDRP default layer, which a table's GI lights normally use: with it, the unlit dome picks up a faint body colour (faint red on Red) and
bulb reflections from nearby GI, as a real dome does, and goes dark when the GI is off. Layer 1 is kept for a sun/room light
on that layer. If your GI lights use another layer, add it to the Inner, Glow and Outer renderers.

On your table, add layer 3 to every renderer that should receive flasher light: cabinet walls, back panel, plastics,
ramps, toys, posts and so on. Leave the playfield, ink overlay and inserts off layer 3 and light them with their own
mechanism. Otherwise the flash leaks under saucers and ramps.

This is a table-level choice, so the prefab does not set it on anything outside itself.

## Notes

- **Peak behaviour:** the shaders react to the lamp level alone.
  - Above level ~0.9 a short "peak flash" and a white-hot body term clip the dome cream-white with coloured edges (red edges on Red), like a
    camera at the moment a #89 fires.
  - Below that the body shows the plastic colour with warm hot bars on the flutes (deep red with yellow bars on Red).
  - Knobs on the Glow/Outer materials: `_PeakFlash` and `_WhiteHot`. Set either to 0 to turn that term off.
- **Tonemapping:** tuned under HDRP **Custom** tonemapping (per-channel filmic). ACES desaturates bright saturated colours (on Red it pulls the bright red toward salmon).
- **Filament:** `_OpticalLamp` on the Glow/Outer materials is the filament position in object space. Both materials use 0.0156 (tuned on Glow, whose mesh is scaled 1.065 in y, where it matches the `Source` light). Outer shares the value, so its filament sits ~0.9 mm lower; that is how the look was tuned.
