// Flasher dome FROSTED INNER (2026-10-15, Clear preset) - custom function for FlasherDomeFrost.shadergraph.
// OFF the inner wall is a rough, part-transparent refractive surface: the colour pyramid behind it (table, Glow layer) is seen blurred,
// the wall itself reads frosty white. When the lamp fires it blends to an opaque, darker, smooth wall, so the lit flute structure
// (the Glow layer, queued after this Inner on the Clear Glow material) is not blurred into a milky blob and the burst-lit table behind
// the dome does not wash through it. _InsertLampLevel comes from VPE's LightComponent (the _EmissiveColor hook makes it collect us).
#ifndef VPE_FLASHER_DOME_FROST
#define VPE_FLASHER_DOME_FROST
void FlasherDomeFrost_float(float3 Position, out float3 BaseColor, out float Smoothness, out float Alpha)
{
    float w = smoothstep(_FrostLitRamp.x, max(_FrostLitRamp.y, _FrostLitRamp.x + 1e-4), saturate(_InsertLampLevel));
    BaseColor = lerp(_FrostColor.rgb, _FrostLitColor.rgb, w);
    Alpha = lerp(_FrostColor.a, _FrostLitColor.a, w);
    Smoothness = lerp(_FrostSmooth, _FrostLitSmooth, w);
}
#endif
