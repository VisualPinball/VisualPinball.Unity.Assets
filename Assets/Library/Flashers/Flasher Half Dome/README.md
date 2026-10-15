# Flasher Half Dome

A fluted hemisphere "hat" flasher (Stern 550-5510-xx "HAT - TRIMMED", e.g. Godzilla red -02): OD 29.8 mm, H 14.9 mm,
32 inner flutes along the meridians, two flat tabs. It uses the `Flasher Dome` shaders (`FlasherDomeGlow` /
`FlasherDomeOuter`, `FlasherDome.hlsl` in `../Flasher Dome/`) with `_ProfileMode` = 1. See that folder's README for the
layer stack, light, rendering layers and the "Make another dome" steps this folder was built with.

**Status:** materials are EXACTLY `Flasher Dome, Red`'s; only mesh-driven values differ (radii/profile, 32 flutes, filament at the base centre, baked masks/thickness, 32-beam cookie). Burst-light position and the lit look are open for review.

- `Flasher Half Dome, Red.prefab`: same structure as `Flasher Dome, Red` (root `LightComponent`, `Dome` = Inner + Glow +
  Outer + Tabs at scale 1, `Source` point light). Origin = centre of the hat base (plastic surface), +Y up.
- Materials are the Red dome's values with only the mesh-driven ones changed: `_ProfileMode` 1, `_FluteCount` 32, `_InnerR` .0132,
  `_InnerRY` .01365, `_CapR` .0128, `_OuterTh` (.0017, .0025, .0033), `_GrooveHalf` .41, `_FluteLen` .019, `_BarR0` .003,
  `_OpticalLamp` 0 and this mesh's masks/thickness map. Everything else (peak, glints, gains, light 85 lm) is Red's.
- Inner mesh: UV1 = mask atlas, UV0 = the same atlas (thickness map). Masks baked with `bake_masks.py --flutes 32 --cap-z 5`.
  Thickness map baked like the Red one (ray cast along the inward normal into the shell + inner solid, value = d / 3 mm).
  Cookie: `FlasherDomeCookie.MakeBoth(32, prefix, capWash: 0)`; the prefab uses `Cookie Open` (`Cookie Saucer` = a base-plane cut variant).
- **Tabs** are their own renderer (`* - Tabs.asset/.mat`): HDRP Lit, Transparent + Translucent red plastic with an emissive mask
  (`* - Tabs Emissive.png`, brightest at the dome root). Transparent so VPE's `LightComponent` drives its emission with the lamp
  level and keeps it visible when off; the Outer shell (flute lines, refraction) no longer covers the tabs.
- **Light:** Red's `Source` light (85 lm, colour, range, contact shadows off) at the filament (base-plane centre), `Cookie Open`
  regenerated for 32 beams with no cap wash.
