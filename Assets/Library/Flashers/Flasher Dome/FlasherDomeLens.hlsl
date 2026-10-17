// Flasher dome LENS INNER (2026-10-15 P6, Clear preset) - custom function for FlasherDomeLens.shadergraph (= FlasherDomeFrost without HDRP
// refraction, generator make_dome_frost_graph.py --lens). _LensEnv 0 = the plain frosted inner of FlasherDomeFrost.hlsl (no refraction).
// Per-flute ENVIRONMENT LENS (_LensEnv > 0): a real clear fluted dome is not see-through and not white - every flute is a cylindrical lens
// that shows a compressed, mirrored strip of the surroundings, with glints and dark bands where the ray is reflected inside (TIR).
// Per pixel of the NEAR wall: the view ray is refracted in at the smooth outer skin (IOR 1.49) and out through the inner flute, whose
// normal is the analytic rib normal of the current flute (procedural flute coordinates as FlasherDome.hlsl: theta = atan2(-z, -x),
// _FluteCount-fold, groove roots at 0 mod pitch, _ProfileMode 1 = ellipsoid hat). The exit ray samples the LIVE environment: the colour
// pyramid where it lands on the table plane (object y = 0) on screen, else the HDRP sky cubemap (the reflection fallback of every HDRP
// surface). The part reflected at the flute (Fresnel; 1 past the critical angle) goes back out through the skin and samples the
// environment in that direction; rays trapped by a second TIR read dark. Exact Fresnel weights both paths, so the TIR switch is
// continuous. The far wall's fragments go transparent (the near wall's lookup already looks through it).
// P7 (2026-10-16, Clear look-dev "plastic, not blown glass"), every knob defaults to off:
//  - _LensMilk: thickness-driven white scatter. Real acrylic scatters a little; where the plastic is THICK (flute ridge tips, the thick
//    base) the scattered room light wins over the clear lens image and the plastic reads white; the thin flanks stay clear. Path length
//    through the wall = mask thick_n (_DomeMasks R, mm, uv1 = the mask atlas, as the Glow layer) along the refracted view ray; the white
//    is the room irradiance (FD_RoomIrr of FlasherDome.hlsl: sky ambient probe + directional lights) x _LensMilkColor, so it follows the
//    room (grey room -> grey-white). x gain, y/z path (mm) where it starts/saturates, w crest sharpen (white only near the analytic rib
//    centre); _LensMilkShape x crest half-width (flute periods, Gaussian), y flank floor (scatter on the thin wall, x gain), z mask
//    channel (0 = thick_n, 1 = thick_h: the smoother hemisphere mean), w base fade height (m: the inner's alpha fades to 0 at the base
//    plane so its fluted base contour never draws a serrated edge).
//  - _LensFloorFill: x 0..1 replaces the sky fallback of DOWNWARD lookups (off screen, grazing) by the table near the dome (colour
//    pyramid at radius z (m) out along the ray's azimuth, mip y): the lower dome no longer goes dark where the lookup left the table.
//  - _ProfileMode 2 = FLAT PART (the half dome's tabs on this material): no flutes; the wall normal is the mesh normal, the view ray is
//    refracted in at the face and samples the table where it reaches the part's bottom (object y = 0); milk path = that distance (capped
//    at _LensGlow.w mm); _LensGlow (x nits at level 1, y root radius m, z falloff m) x _LensGlowColor = lamp light conducted out into
//    the tab, brightest at the root (the Red tabs' emissive map, analytic here).
// P8 (2026-10-16), every knob defaults to off (free z/w slots of existing vectors, no new properties):
//  - far-tab hide, flat part only: _LensParallax (unused by the flat part's lens) x, y = the dome's OUTER ellipsoid semi-axes (m,
//    horizontal / vertical, centre = object origin), z hide strength (0 = off), w edge softness (m). A tab fragment whose ray toward the
//    camera passes through the dome body is faded out: the Tabs renderer (transparent, queue 3000, no depth writes) is drawn after
//    the lens Inner (2998), so the far tab otherwise lies ON TOP of the dome body as a sharp pale shape; a real dome's flutes scramble
//    it beyond recognition (the colour pyramid the lens samples holds no transparents, so the far tab simply drops out of the body).
//  - _LensGlow x on the DOME (not only the flat part): lamp-lit milk, x nits at level 1 x _LensGlowColor x the milk weight (0 = off).
//  - _LensCrease z: crease strength applied AFTER the milk (the milk lerp otherwise paints over the groove-root crease); w its half-width
//    in flute periods (0 = _LensCrease.y). x/y (the pre-milk crease on the lens image) are unchanged.
#ifndef VPE_FLASHER_DOME_LENS
#define VPE_FLASHER_DOME_LENS
#define FD_LSQ(x) ((x) * (x))

float FDL_Fresnel(float ci, float ct, float eta)   // unpolarised dielectric Fresnel, eta = n_incident / n_transmitted
{
    float rs = (eta * ci - ct) / max(eta * ci + ct, 1e-5);
    float rp = (ci - eta * ct) / max(ci + eta * ct, 1e-5);
    return saturate(0.5 * (rs * rs + rp * rp));
}
// I incident (unit), N unit normal facing against I; F = reflectance (1 at total internal reflection, then T = reflect(I, N))
float3 FDL_Refract(float3 I, float3 N, float eta, out float F)
{
    float ci = saturate(-dot(I, N));
    float k = 1.0 - eta * eta * (1.0 - ci * ci);
    if (k <= 0.0) { F = 1.0; return reflect(I, N); }
    float ct = sqrt(k);
    F = FDL_Fresnel(ci, ct, eta);
    return normalize(eta * I + (eta * ci - ct) * N);
}
// room irradiance (= FD_RoomIrr in FlasherDome.hlsl): sky ambient probe (all-directions average) + directional lights
float3 FDL_RoomIrr()
{
    float3 e = 0;
#if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_FORWARD)
    e = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) + float3(unity_SHBr.z, unity_SHBg.z, unity_SHBb.z) / 3.0;
    for (uint li = 0; li < _DirectionalLightCount; li++) e += _DirectionalLightDatas[li].color * _DirectionalLightDatas[li].diffuseDimmer * (0.5 / PI);
#endif
    return max(e, 0.0);
}
// live environment along d (object space) from P: table (colour pyramid at the y = 0 plane hit, when on screen) or sky
float3 FDL_Env(float3 P, float3 d, float lod)
{
    float3 c = 0;
#if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_FORWARD)
    float3 dW = TransformObjectToWorldDir(d, true);
    c = SampleSkyTexture(dW, lod, 0).rgb;
    if (d.y < -1e-3) {
        // _LensFloorFill: a downward ray never sees the sky's lower half on a table - fall back to the table around the dome instead
        [branch] if (_LensFloorFill.x > 0.0) {
            float2 dn = normalize(d.xz + float2(1e-6, 0));
            float3 hF = TransformObjectToWorld(float3(dn.x, 0, dn.y) * max(_LensFloorFill.z, 0.005));   // the table out along the ray, near the dome
            float2 uvF = ComputeNormalizedDeviceCoordinates(hF, UNITY_MATRIX_VP);
            c = lerp(c, SampleCameraColor(saturate(uvF), _LensFloorFill.y) * GetInverseCurrentExposureMultiplier(), saturate(_LensFloorFill.x));
        }
        float3 H = P + d * (max(P.y, 0.0) / -d.y);
        // _LensFloor f: a hit inside the dome's own footprint (the mounting hole / socket of a real table) is mirrored out across the
        // base circle onto the table around it, radius rF + f (rF - r) (0 = the true hit, 1 = a plain mirror: the floor reads like the table)
        float rF = _ProfileMode > 0.5 ? _InnerR : 0.01395, rH = length(H.xz);
        if (rH < rF && _LensFloor > 0.0 && _ProfileMode < 1.5) H.xz *= (rF + (rF - rH) * _LensFloor) / max(rH, 1e-5);
        float3 hW = TransformObjectToWorld(H);
        float4 hC = TransformWorldToHClip(hW);
        if (hC.w > 0.0) {
            float2 uv = ComputeNormalizedDeviceCoordinates(hW, UNITY_MATRIX_VP);
            float2 e = min(uv, 1.0 - uv);
            float wT = saturate(min(e.x, e.y) / 0.03) * saturate(-d.y / 0.05);
            float3 tab = SampleCameraColor(saturate(uv), lod * _LensShape.z) * GetInverseCurrentExposureMultiplier();
            c = lerp(c, tab, wT);
        }
    }
#endif
    return c;
}
// flute lens of the dome wall; also returns the near-wall weight, the rib coordinate u (0 rib centre, +-0.5 groove roots), the refracted
// in-wall ray d1 and the smooth outer normal (for the milk path)
float3 FDL_Lens(float3 Position, float3 View, out float nearW, out float u, out float3 d1, out float3 nOut, out float rxz, out float aa)
{
    float3 v = normalize(View + float3(0, 1e-6, 0));
    // _LensParallax (P7): the flute coordinate is taken where the view ray ENTERS the outer skin (the Outer fragment of the same pixel,
    // whose procedural lines/glints use that azimuth), not at this inner point: the scaled inner and the outer shell then agree on
    // where a groove is on screen (else the crease and the Outer's groove line sit side by side = a doubled line). x outer radius
    // (this renderer's object units, 0 = off), y: mode 1 outer vertical semi-axis / mode 0 top plane height.
    float3 Pf = Position;
    [branch] if (_LensParallax.x > 0.0) {
        float t = 0.0;
        if (_ProfileMode > 0.5) {   // ellipsoid (Rx, Ry, Rx) about the origin: |(P + t v) / R| = 1, far root
            float3 sR = float3(1.0 / _LensParallax.x, 1.0 / max(_LensParallax.y, 1e-4), 1.0 / _LensParallax.x);
            float3 p0 = Position * sR, d0 = v * sR; float a = dot(d0, d0), b = dot(p0, d0), c = dot(p0, p0) - 1.0;
            t = max((-b + sqrt(max(b * b - a * c, 0.0))) / max(a, 1e-8), 0.0);
        } else {                    // barrel r = R (xz) up to the top plane
            float a = dot(v.xz, v.xz), b = dot(Position.xz, v.xz), c = dot(Position.xz, Position.xz) - _LensParallax.x * _LensParallax.x;
            t = max((-b + sqrt(max(b * b - a * c, 0.0))) / max(a, 1e-8), 0.0);
            if (v.y > 1e-4 && _LensParallax.y > 0.0) t = min(t, max((_LensParallax.y - Position.y) / v.y, 0.0));
        }
        Pf = Position + v * t;
    }
    float thetaP = atan2(-Pf.z, -Pf.x) - _FluteOffset; if (thetaP < 0.0) thetaP += 6.2831853;
    float pitch = 6.2831853 / max(_FluteCount, 1.0);
    u = frac(thetaP / pitch) - 0.5;                              // across the rib: 0 centre, +-0.5 at the groove roots
    rxz = length(Position.xz);
    float3 rad = normalize(float3(Position.x, 0, Position.z) + float3(1e-6, 0, 0));
    float3 tg = float3(-rad.z, 0, rad.x);                         // +theta
    float3 nB;
    if (_ProfileMode > 0.5) {
        float3 dS = Position - float3(0, min(Position.y, _SphereY), 0) + float3(1e-6, 0, 0);
        float iRx = max(_InnerR, 1e-4), iRy = max(_InnerRY, 1e-4);
        nOut = normalize(dS);                                     // smooth outer sphere
        nB = normalize(dS / float3(iRx * iRx, iRy * iRy, iRx * iRx));   // inner groove-root ellipsoid (outward)
    } else {
        float capW = smoothstep(0.0211, 0.0261, Position.y);      // tall dome: barrel -> cap (filament 15.6 mm + 5.5 .. 10.5 mm)
        nOut = normalize(lerp(rad, float3(0, 1, 0), capW));
        nB = nOut;
    }
    // rib (cylinder-lens) normal into the cavity: tilts toward -theta just past a root (= FlasherDome.hlsl flank convention);
    // sin(tilt) = sign(u) |2u|^shape sin(_LensShape.x): shape 1 = circular rib, < 1 = flatter centre / steeper edges (V-ish)
    float pp = (length(ddx(Position.xz)) + length(ddy(Position.xz))) / max(rxz, 1e-4) / pitch;   // flute periods per pixel
    aa = saturate(2.5 - pp);                                // flute periods per pixel 1.5 .. 2.5 (sub-pixel flutes): fade the lens toward the smooth wall
    float sa = sign(u) * pow(saturate(abs(2.0 * u)), max(_LensShape.y, 0.05)) * sin(radians(_LensShape.x)) * smoothstep(0.0015, 0.004, rxz) * aa;
    float3 nIn = normalize(-nB * sqrt(1.0 - sa * sa) + tg * sa);
    nearW = smoothstep(-0.02, 0.06, dot(v, nOut));               // near wall (seen from outside); the far wall is looked through
    float rWall = _ProfileMode > 0.5 ? _InnerR * 1.12 : 0.0156;   // the inner mesh's base flange / rim outside the wall: no lens (a flat disc)
    nearW *= 1.0 - smoothstep(rWall, rWall + 0.0006, rxz);
    // geometric face normal: horizontal faces below the cap (base flange, the tall dome's inner ledge ring) get no lens - they drew a flat disc
    float3 nG = cross(ddx(Position), ddy(Position));
    float yCap = _ProfileMode > 0.5 ? 0.0 : 0.020;               // the hat has no ledge; its pole region is near-horizontal and keeps the lens
    nearW *= 1.0 - smoothstep(0.85, 0.95, abs(nG.y) / max(length(nG), 1e-12)) * (1.0 - smoothstep(max(yCap, 0.001), max(yCap, 0.001) + 0.001, Position.y));
    float3 d0 = -v;
    float F1; d1 = FDL_Refract(d0, nOut, 1.0 / 1.49, F1);        // in at the smooth skin
    float F2; float3 d2 = FDL_Refract(d1, -nIn, 1.49, F2);        // out through the flute (F2 = 1 at TIR)
    float3 r2 = reflect(d1, nIn);                                 // reflected at the flute, back toward the skin
    float F3; float3 ro = FDL_Refract(r2, -nOut, 1.49, F3);       // out through the skin (F3 = 1: trapped in the wall -> dark)
    float lod = _FluteBlur;
    float3 eT = F2 < 0.999 ? FDL_Env(Position, d2, lod) : 0;
    float3 eR = F3 < 0.999 ? FDL_Env(Position, ro, lod) : 0;
    // trapped (TIR at the flute and again at the skin): guided along the wall to the base -> the table right under this wall point
    float3 eB = (_LensTrap > 0.0 && F2 * F3 > 0.001) ? FDL_Env(Position, float3(0, -1, 0), lod + 1.0) : 0;
    float3 E = (1.0 - F1) * ((1.0 - F2) * 0.92 * eT + _LensShape.w * F2 * (1.0 - F3) * eR + _LensTrap * F2 * F3 * eB);   // .92: far wall
    // _LensCrease (x strength, y half-width in flute periods): the groove root reads as a dark crease between the rods (the real V-groove
    // flanks are steep enough to send most rays into the wall); 0 = off
    float eRt = 0.5 - abs(u);                                     // 0 at the groove root
    E *= 1.0 - saturate(_LensCrease.x) * exp(-FD_LSQ(eRt / max(_LensCrease.y, 1e-3))) * smoothstep(0.0015, 0.004, rxz);
    // weak isotropic murk: the sky ambient probe (L0) diffused by the flute roughness
    float3 amb = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) + float3(unity_SHBr.z, unity_SHBg.z, unity_SHBb.z) / 3.0;
    return E + _FluteScatter * max(amb, 0.0);
}
// P8: 1 where the ray P -> camera (direction v, unit, object space) passes through the dome's outer ellipsoid (R, RY, R) about the
// origin, upper half only; P outside it. Soft over `soft` m at the silhouette and at the base plane.
float FDL_Behind(float3 P, float3 v, float R, float RY, float soft)
{
    float3 sR = float3(1.0 / max(R, 1e-4), 1.0 / max(RY, 1e-4), 1.0 / max(R, 1e-4));
    float3 p0 = P * sR, d0 = v * sR;
    float a = max(dot(d0, d0), 1e-8), b = dot(p0, d0);
    if (b >= 0.0) return 0.0;                                     // heading away from the dome (the near tab)
    float m = sqrt(max(dot(p0, p0) - b * b / a, 0.0));            // closest approach, unit-sphere space
    float yC = P.y + v.y * (-b / a);                              // height of that point (the dome is the y >= 0 half)
    float s = max(soft, 1e-5);
    return (1.0 - smoothstep(1.0 - s / max(R, 1e-4), 1.0, m)) * smoothstep(-s, s, yC);
}
// flat part (_ProfileMode 2, the tabs): parallel faces, so the transmitted ray leaves the bottom along the refracted in-part ray d1
float3 FDL_Flat(float3 Position, float3 View, float3 NormalOS, out float nearW, out float3 d1, out float3 nOut)
{
    float3 v = normalize(View + float3(0, 1e-6, 0));
    nOut = normalize(NormalOS + float3(0, 1e-6, 0));
    nearW = smoothstep(-0.02, 0.06, dot(v, nOut));
    float F1; d1 = FDL_Refract(-v, nOut, 1.0 / 1.49, F1);
    if (d1.y > -0.05) d1 = normalize(float3(d1.x, -0.05, d1.z));   // edge faces: the ray still ends on the table under the part
    return (1.0 - F1) * FDL_Env(Position, d1, _FluteBlur);
}

void FlasherDomeLens_float(float3 Position, float3 View, float3 NormalOS, float2 UV, UnityTexture2D Masks,
    out float3 BaseColor, out float Smoothness, out float Alpha, out float3 Emission)
{
    float w = smoothstep(_FrostLitRamp.x, max(_FrostLitRamp.y, _FrostLitRamp.x + 1e-4), saturate(_InsertLampLevel));
    BaseColor = lerp(_FrostColor.rgb, _FrostLitColor.rgb, w);
    Alpha = lerp(_FrostColor.a, _FrostLitColor.a, w);
    Smoothness = lerp(_FrostSmooth, _FrostLitSmooth, w);
    Emission = 0;
    [branch] if (_LensEnv > 0.0) {
        float nearW, u = 0, rxz = 0, aa = 1; float3 d1, nOut; float3 E;
        bool flat = _ProfileMode > 1.5;
        if (flat) E = FDL_Flat(Position, View, NormalOS, nearW, d1, nOut);
        else E = FDL_Lens(Position, View, nearW, u, d1, nOut, rxz, aa);
        Emission = _LensEnv * lerp(1.0, _LensLitK, w) * E;   // HDRP scales transparent emission by Alpha
        // P7 milk: path through the plastic along the refracted view ray (mm) -> white scatter of the room light
        float Wm = 0.0;   // P8: the milk weight, reused by the lamp-lit milk below
        [branch] if (_LensMilk.x > 0.0) {
            float pathMM;
            if (flat) pathMM = min(max(Position.y, 0.0) / max(-d1.y, 0.05) * 1000.0, _LensGlow.w);
            else {
                // max(mip 0, mip 2): mip 2 fills the bake's pin-hole misses (dots at mip 0), mip 0 keeps the atlas seams (mip 2 bleeds there)
                float4 mk = max(SAMPLE_TEXTURE2D_LOD(Masks.tex, Masks.samplerstate, UV, 0.0), SAMPLE_TEXTURE2D_LOD(Masks.tex, Masks.samplerstate, UV, 2.0));
                pathMM = lerp(mk.r, mk.g, saturate(_LensMilkShape.z)) / max(dot(d1, -nOut), 0.2);
            }
            float wT = smoothstep(_LensMilk.y, max(_LensMilk.z, _LensMilk.y + 1e-3), pathMM);
            // crest line: Gaussian across the rib, fading to its period average where the flutes go sub-pixel
            float cw = max(_LensMilkShape.x, 1e-3);
            float crest = flat ? 1.0 : lerp(min(cw * 1.7725, 1.0), exp(-FD_LSQ(u / cw)), aa);
            float W = saturate(_LensMilk.x * (wT * lerp(1.0, crest, saturate(_LensMilk.w)) + _LensMilkShape.y));
            Emission = lerp(Emission, _LensMilkColor.rgb * FDL_RoomIrr(), W);
            Wm = W;
        }
        // P8 lamp-lit milk (dome, not the flat part): the thick plastic that scatters the room light also scatters the bulb light,
        // linear in the lamp level, so the milky body glows with the bulb through the whole cool-down (the glow terms are steep at low
        // levels). _LensGlow.x nits at level 1 (0 = off, the default) x _LensGlowColor x the milk weight; y/z/w stay flat-part only.
        [branch] if (!flat && _LensGlow.x > 0.0) Emission += saturate(_InsertLampLevel) * _LensGlow.x * _LensGlowColor.rgb * Wm;
        // P8 crease after the milk (z strength, w half-width in flute periods; 0 = y), faded with the sub-pixel lens (aa)
        [branch] if (!flat && _LensCrease.z > 0.0) {
            float cwP = _LensCrease.w > 0.0 ? _LensCrease.w : _LensCrease.y;
            Emission *= 1.0 - saturate(_LensCrease.z) * exp(-FD_LSQ((0.5 - abs(u)) / max(cwP, 1e-3))) * smoothstep(0.0015, 0.004, rxz) * aa;
        }
        // P7 flat part: lamp light conducted out into the tab, brightest at the root
        [branch] if (flat && _LensGlow.x > 0.0)
            Emission += saturate(_InsertLampLevel) * _LensGlow.x * _LensGlowColor.rgb * exp(-max(length(Position.xz) - _LensGlow.y, 0.0) / max(_LensGlow.z, 1e-4));
        Alpha *= nearW;
        // P8 far-tab hide (flat part): faded where the dome body stands between the tab and the camera
        [branch] if (flat && _LensParallax.z > 0.0)
            Alpha *= 1.0 - saturate(_LensParallax.z) * FDL_Behind(Position, normalize(View + float3(0, 1e-6, 0)), _LensParallax.x, _LensParallax.y, _LensParallax.w);
        // P7: the inner's fluted base contour fades out over the bottom _LensMilkShape.w (m) - no serrated edge at the base
        if (!flat && _LensMilkShape.w > 0.0) Alpha *= smoothstep(0.0, _LensMilkShape.w, Position.y);
    }
}
#endif
