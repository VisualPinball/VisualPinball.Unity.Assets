# Flasher Half Dome

A fluted hemisphere "hat" flasher (Stern 550-5510-xx "HAT - TRIMMED", e.g. Godzilla red -02): OD 29.8 mm, H 14.9 mm,
32 inner flutes along the meridians, two flat tabs. It uses the `Flasher Dome` shaders (`FlasherDomeGlow` /
`FlasherDomeOuter`, `FlasherDome.hlsl` in `../Flasher Dome/`) with `_ProfileMode` = 1. See that folder's README for the
layer stack, light, rendering layers and the "Make another dome" steps this folder was built with.

**Status:** tuned in 4 rounds against LuxCore references (5 poses x levels 0/.4/.7/1); a broad soft filament fan (vs crisp flute streaks) and the top-view disc are still open.

- `Flasher Half Dome, Red.prefab`: same structure as `Flasher Dome, Red` (root `LightComponent`, `Dome` = Inner + Glow +
  Outer + Tabs at scale 1, `Source` point light). Origin = centre of the hat base (plastic surface), +Y up. The `Source` light
  and `_OpticalLamp` sit at the base-plane centre.
- Materials are copies of the Red dome's with `_ProfileMode` 1, `_FluteCount` 32 and the hemisphere knobs (`_InnerR`
  .0132, `_InnerRY` .01365, `_CapR` .0128, `_OuterTh` (.0017, .0025, .0033), `_GrooveHalf` .41, `_FluteLen` .019,
  `_BarR0` .003). The tall-dome-only gates (`_ShoulderAlpha`, `_WallEdge`, `_RimDim`, `_XRoom`, `_CapXBeam`,
  `_GlintBand`, `_HotZone`) are 0.
- Inner mesh: UV1 = mask atlas, UV0 = the same atlas (thickness map). Masks baked with `bake_masks.py --flutes 32 --cap-z 5`.
  Thickness map baked like the Red one (ray cast along the inward normal into the shell + inner solid, value = d / 3 mm).
  Cookie: `FlasherDomeCookie.MakeBoth(32, prefix, capWash: 0)`; the prefab uses `Cookie Open`.
- **Tabs** are their own renderer (`* - Tabs.asset/.mat`): HDRP Lit, Transparent + Translucent red plastic with an emissive mask
  (`* - Tabs Emissive.png`, brightest at the dome root). Transparent so VPE's `LightComponent` drives its emission with the lamp
  level and keeps it visible when off; the Outer shell (flute lines, refraction) no longer covers the tabs.
- **Light:** `Source` sits 4 mm above the base (the dome emits from its whole wall), 25 lm, `Cookie Saucer` regenerated for the
  hat: 32 beams, floor .45, cut 15 deg below the light (= the base plane seen from there), so the beams land on the board around it.
- **Look notes (mode 1):** the lit look is the streak term (the filament image through the wall), gated by the whole miss
  distance of the refracted view ray to the bulb (`_PeakHeight`, `_CoreFloor` 0) and faded toward the pole by `_CapBlend` /
  `_CapRays`; no white-hot peak (`_WhiteHot` 0): the LuxCore hat stays deep red at full power.
