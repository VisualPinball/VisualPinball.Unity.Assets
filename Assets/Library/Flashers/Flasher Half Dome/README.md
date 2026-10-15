# Flasher Half Dome

A fluted hemisphere "hat" flasher (Stern 550-5510-xx "HAT - TRIMMED", e.g. Godzilla red -02): OD 29.8 mm, H 14.9 mm,
32 inner flutes along the meridians, two flat tabs. It uses the `Flasher Dome` shaders (`FlasherDomeGlow` /
`FlasherDomeOuter`, `FlasherDome.hlsl` in `../Flasher Dome/`) with `_ProfileMode` = 1. See that folder's README for the
layer stack, light, rendering layers and the "Make another dome" steps this folder was built with.

**Status:** first build; the look is not yet tuned against references.

- `Flasher Half Dome, Red.prefab`: same structure as `Flasher Dome, Red` (root `LightComponent`, `Dome` = Inner + Glow +
  Outer at scale 1, `Source` point light). Origin = centre of the hat base (plastic surface), +Y up. The `Source` light
  and `_OpticalLamp` sit at the base-plane centre.
- Materials are copies of the Red dome's with `_ProfileMode` 1, `_FluteCount` 32 and the hemisphere knobs (`_InnerR`
  .0132, `_InnerRY` .01365, `_CapR` .0128, `_OuterTh` (.0017, .0025, .0033), `_GrooveHalf` .41, `_FluteLen` .019,
  `_BarR0` .003). The tall-dome-only gates (`_ShoulderAlpha`, `_WallEdge`, `_RimDim`, `_XRoom`, `_CapXBeam`,
  `_GlintBand`, `_HotZone`) are 0.
- Inner mesh: UV1 = mask atlas, UV0 = the same atlas (thickness map). Masks baked with `bake_masks.py --flutes 32 --cap-z 5`.
  Thickness map baked like the Red one (ray cast along the inward normal into the shell + inner solid, value = d / 3 mm).
  Cookie: `FlasherDomeCookie.MakeBoth(32, prefix, capWash: 0)`; the prefab uses `Cookie Open`.
