# Flasher Half Dome

A fluted hemisphere "hat" flasher (Stern 550-5510-xx "HAT - TRIMMED", e.g. Godzilla red -02 / yellow -06): OD 29.8 mm,
H 14.9 mm, 32 inner flutes along the meridians, two flat tabs (58.9 mm tip to tip). It is `Flasher Dome, Red` on a different
mesh: the same shaders (`FlasherDomeGlow` / `FlasherDomeOuter`, `FlasherDome.hlsl` in `../Flasher Dome/`, here with
`_ProfileMode` = 1) and the same material values, changed only where the mesh makes Red's value wrong (list below). See
`../Flasher Dome/README.md` for the layer stack, the light, rendering layers and the "Make another dome" steps.

## Use

1. **Mounting:** the hat sits UNDER the playfield plastic and pokes up through the hole, with its tabs screwed to the
   underside. The prefab origin is the base plane = the plastic's underside, +Y up through the hole. Place the prefab there,
   on the plastic's underside, not on top of it.
2. Map it in the **Lamp Manager** or **Coil Manager** like the full dome. The root `LightComponent` drives `_InsertLampLevel`
   on Glow and Outer, the emission of `Tabs`, and the `Source` light.
3. Same fade advice as the full dome (#89: about 0.015 s up, 0.03 s down).
4. Requirements as the full dome: HDRP Light Layers enabled, VPE `ThickerPlastic` diffusion profile, the two `_Generic`
   textures for Inner.

## Colours

`Flasher Half Dome, Red.prefab` is the base. `Flasher Half Dome, Yellow.prefab` is a prefab variant of it: material variants
(parent = the Red Glow/Outer/Inner/Tabs) that override only colour properties (`_DomeColor`, `_TransmittanceColor`,
`_BaseColor`/`_Color`, the Tabs emissive colour) plus the `Source` light colour, with the Yellow row of the Flasher Dome
README table. Other colours: same recipe with that table's values (or `Tools~/dome_colour.py` in `../Flasher Dome/`).

## Differences from Flasher Dome, Red (everything else is Red's value)

| Setting | Red | Half dome | Why |
|---|---|---|---|
| Meshes, masks, parity, Inner thickness map | dome48 | this part's mesh and bakes | the part |
| `_ProfileMode` | 0 | 1 | hemisphere wall, meridian flutes |
| `_FluteCount` | 36 | 32 | flute count |
| `_InnerR` / `_InnerRY` / `_CapR` | .01395 / .01395 / .0145 | .0132 / .01365 / .0128 | inner surface of this mesh |
| `_OuterTh` / `_GrooveHalf` / `_FluteLen` / `_BarR0` | tall-dome values | (.0017, .0025, .0033) / .41 / .019 / .003 | wall and flute profile of this mesh |
| `_OpticalLamp` | (0, .0156, 0) | (0, 0, 0) | the filament sits at the base plane |
| Dome node offset, Inner/Glow scale | +1.5 mm, (1.03, 1.065, 1.03) | 0, 1 | dome48 seat and fit; not needed here |
| `Source` position | at the filament, 18 mm up | 4 mm above the base | the filament is below the plastic; a light at the base plane only grazes the surroundings |
| Cookie | `Cookie Open` (36 beams) | `Cookie Base`: 32 beams, no cap wash, cut at the base plane (15 deg below the light, 8 deg soft) | flute count; flutes run to the pole; nothing lit below the plastic |
| `Tabs` renderer | tabs are part of Outer | separate renderer: Red's Inner material made Transparent, with a lamp-driven emissive mask brightest at the root | under the refractive Outer the tabs read black when off and carried flute lines when lit |
| Shader (mode 1 only) | - | the streak/bar gate uses the full miss distance of the view ray to the bulb; the pole cap spot shows in top views only | hemisphere geometry; mode 0 (the tall dome) is unchanged |

The light (85 lm, colour, range, contact shadows off, light layer 3), the peak (`_WhiteHot`, `_PeakFlash`, `_HeatPeak`),
the OFF glints/needles and all gains are Red's.

## What's in the folder

| File | What |
|---|---|
| `Flasher Half Dome, Red.prefab` | Dome (Inner + Glow + Outer + Tabs) + `Source` point light: the base prefab |
| `Flasher Half Dome, Yellow.prefab` (+ `... Yellow - *.mat`) | Yellow preset: prefab variant + material variants |
| `* - Inner.asset` / `* - Outer.asset` / `* - Tabs.asset` | inner fluted surface (UV0 = UV1 = mask atlas), smooth outer shell, the two tabs |
| `* - Glow.mat` / `* - Outer.mat` / `* - Inner.mat` / `* - Tabs.mat` | as the full dome, plus the Tabs plastic |
| `* - Masks.exr`, `* - Parity.png`, `* - Thickness.png`, `* - Tabs Emissive.png` | baked from the mesh: `bake_masks.py --flutes 32 --cap-z 5`, Inner thickness ray cast (README method), tab root glow mask |
| `* - Cookie Base.asset` | prefab cookie (above) |
| `* - Cookie Open.asset` | same beams without the cut, for a mount where the light should also reach below the base plane |
