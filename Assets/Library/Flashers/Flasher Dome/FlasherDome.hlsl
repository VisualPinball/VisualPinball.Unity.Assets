// Flasher dome (fluted #89 mini-saucer dome) - shared custom function for FlasherDomeGlow / FlasherDomeOuter.
// Additive emission on the dome's inner surface (uv1 = inner-surface atlas), driven by _InsertLampLevel.
// Masks (geometry only, no radiance baked):
//   _DomeMasks  R thick_n mm (along the inward normal), G thick_h mm (hemisphere mean), B phase in the flute (0 groove root,
//               0.5 flat centre), A flank 0..1 (-1 left / +1 right tangential tilt of the inner facet)
//   _DomeParity flute index parity (alternate-flute zebra)
// Frame: Blender theta = atan2(-z, -x); the mask's +flank tilts toward Unity (-z, 0, x).
// Shape profile (2026-10-14, half-dome "hat" port): _ProfileMode 0 = the tall barrel + cap dome (dome48). Every mode-0 line is
// the shipped code verbatim; mode-1 code only ever OVERRIDES a value after the old line computed it (if (FD_SPH) x = ...;) or
// takes an if/else whose else is the old text, so a material without the new properties (defaults, mode 0) renders exactly as
// before. _ProfileMode 1 = sphere (hemisphere hat): centre (0, _SphereY, 0), a vertical cylinder below it (skirt), continuous
// wall normal nS, flutes along the meridians to the pole (the pole = the cap: rays = the converging flutes), cap blends on nS.y.
// The inner (groove-root) surface may be an ellipsoid: _InnerR horizontal, _InnerRY vertical semi-axis (= _InnerR for a sphere).
// Mode-1-only knobs (_SphereY, _InnerR, _InnerRY, _CapR, _CapBlend, _OuterTh, _GrooveHalf, _FluteLen, _GlintBandY, _BarR0) default to the
// tall dome's own literal (where one exists) but are not read in mode 0. _FluteOffset is read in both modes (default 0 = exact).
#ifndef VPE_FLASHER_DOME
#define VPE_FLASHER_DOME

#define FD_SQ(x) ((x) * (x))

// ---- Colour template (2026-10-12) ------------------------------------------------------------------------------------
// _DomeColor = the plastic's linear transmittance through the nominal 2.4 mm dome48 wall (what you see when you hold the
// dome up to white light). It sets the absorption sigma = -ln(_DomeColor) / 2.4 mm (Beer-Lambert), which every body /
// transmission term uses live (bb(T) * exp(-sigma * thickness)). Red = sigma (100, 1400, 1500)/m = T (.7866, .0347, .0273). It is a Color
// property: the picker shows the transmitted colour (sRGB), the shader gets linear T.
// The red-tuned "heat" colours (yellow-hot bars, cream cores, halo, cap spot, white-hot peak, ...) are re-expressed for
// another plastic by FD_Remap: each one is read as a tone curve "a channel that leaks q of the light shows at C", anchored
// on the red dome's own leaks (q_G, q_B) and applied per channel to the new plastic's leaks - channel-symmetric, continuous,
// and exact for the red preset. Colours that include the filament (absolute) use leak = bb(2900 K) x T; filters that
// multiply bb or an environment use leak = T.
#define FD_WALL_NOM 0.0024
static const float3 FD_RED_T = float3(0.7866279, 0.03473526, 0.02732372);   // exp(-(100, 1400, 1500)/m * 2.4 mm)
static const float3 FD_BB2900 = float3(1.0, 0.68167863, 0.40318515);

float FD_Max3(float3 c) { return max(c.r, max(c.g, c.b)); }
float3 FD_Norm(float3 c) { return c / max(FD_Max3(c), 1e-6); }
float3 FD_Sigma() { return -log(max(_DomeColor.rgb, 1e-5)) / FD_WALL_NOM; }
// red-tuned colour C (C.r = 1) -> the same stage for the plastic whose per-channel leak (max 1) is q; qRef = the red leak
float3 FD_Remap(float3 C, float3 q, float3 qRef)
{
    float xg = log(qRef.g), xb = log(qRef.b), yg = log(max(C.g, 1e-6)), yb = log(max(C.b, 1e-6));
    yb = min(yb, yg);                                           // a user colour with B > G would flip the sign of the extension slope
    float3 x = log(max(q, 1e-6));
    float3 yHi = yg * x / xg;                                   // (ln q_G, ln C_G) .. (0, 0)
    float3 yLo = yg + (x - xg) * ((yb - yg) / (xb - xg));       // through the G and B anchors, extended below
    return exp(float3(x.r >= xg ? yHi.r : yLo.r, x.g >= xg ? yHi.g : yLo.g, x.b >= xg ? yHi.b : yLo.b));
}
float3 FD_Filter(float3 C) { return FD_Remap(C, FD_Norm(_DomeColor.rgb), FD_Norm(FD_RED_T)); }
float3 FD_Abs(float3 C) { return FD_Remap(C, FD_Norm(FD_BB2900 * _DomeColor.rgb), FD_Norm(FD_BB2900 * FD_RED_T)); }
// peak-only terms (white-hot body, hot zone): same remap, rescaled to the red version's luminance, so the peak exposure (and
// the visible ribs) carries over; without it a broad-spectrum plastic (clear/blue/green) clips to a flat white blob
float FD_Y(float3 c) { return dot(c, float3(0.2126, 0.7152, 0.0722)); }
float3 FD_AbsY(float3 C) { float3 c = FD_Abs(C); return c * (FD_Y(C) / max(FD_Y(c), 1e-6)); }

#define FD_SPH (_ProfileMode > 0.5)
// ridge glints, needles, cap-ray glints (r08): one text, expanded twice (old literals / mode-1 knobs)
#define FD_RIDGE_NEEDLE_CAP(FD_YC, FD_HH, FD_EDGE) \
            /* D (r08 judge): ONE edge per flute (random flank), segments 15-60 % of the height, tapered, view-sliding */ \
            if (_RidgeNits > 0.0 && edgeSide == (hF0 < 0.5 ? 0.0 : 1.0)) { \
                float ridgeId = fluteIdx * 2.0 + edgeSide; \
                float dE = (abs(eP) - FD_EDGE) / 0.022; \
                float acrossR = exp(-dE * dE); \
                float Lseg = FD_HH * lerp(0.15, 0.6, hF1) * max(_RidgeLen, 0.05); \
                float cellLen = Lseg * 1.7; \
                float zc = FD_YC / cellLen + hF3 * 7.0 + viewShift; \
                float cI = floor(zc), cFz = frac(zc); \
                float hc = frac(sin((cI + ridgeId * 17.0) * 12.9898) * 43758.5453), hc2 = frac(sin((cI + ridgeId * 17.0) * 78.233) * 24634.6345); \
                float u = (cFz - 0.5) / (0.5 / 1.7); \
                float taper = exp(-2.5 * u * u) * (abs(u) < 1.3 ? 1.0 : 0.0); \
                float hot = lerp(0.3, 1.0, FD_SQ(hc2)); \
                float3 rCol = lerp(tint, FD_Filter(float3(1.0, 0.55, 0.4)) * FD_Max3(tint), 0.25 * taper); \
                g += _RidgeNits * (hc < 0.45 ? 1.0 : 0.0) * taper * acrossR * hot * max(Fr, 0.2) * rCol * (1.0 - capW) * ledge * facing; \
            } \
            /* E (Ben): NEEDLES - sparse (<= 1 edge per flute, fraction _NeedleDensity), 50-100 % of the barrel height, very thin, */ \
            /* LINEAR taper to sharp points, hot core; the bright part slides along the needle with the view, fades when the flank */ \
            /* turns away. Never both flanks of one flute. */ \
            if (_NeedleNits > 0.0 && hF2 < _NeedleDensity && edgeSide == (hF1 < 0.5 ? 1.0 : 0.0)) { \
                float dN = (abs(eP) - FD_EDGE) / max(_NeedleWidth, 0.002); \
                float acrossN = exp(-dN * dN); \
                float Ln = FD_HH * lerp(0.5, 1.0, hF3) * max(_NeedleLen, 0.05); \
                float y0 = 0.0015 + (FD_HH - min(Ln, FD_HH)) * hF0; \
                float mid = y0 + 0.5 * Ln; \
                float lin = saturate(1.0 - abs(FD_YC - mid) / (0.5 * Ln));               /* linear taper -> sharp tips */ \
                float hcN = mid + _NeedleSlide * 0.5 * Ln * clamp(viewShift - 1.6 * 0.7, -1.0, 1.0); \
                float slide = exp(-FD_SQ((FD_YC - hcN) / (0.3 * Ln))); \
                float br = lerp(0.35, 1.0, frac(sin(fluteIdx * 5.13 + 1.1) * 43758.5453)); \
                float3 nCol = lerp(tint, FD_Filter(float3(1.0, 0.6, 0.45)) * FD_Max3(tint), 0.4 * lin * lin * slide); \
                g += _NeedleNits * lin * lerp(0.3, 1.0, slide) * acrossN * br * max(Fr, 0.2) * nCol * lerp(1.0, 0.3, capW) * ledge * facing; \
            } \
            /* cap rays (r08 judge: cap read like a line drawing): a few short tapered glints along the ray edges, coordinate = radius */ \
            if (_CapGlintNits > 0.0 && capW > 0.01) { \
                float rr = length(Position.xz); \
                float dE = (abs(eP) - FD_EDGE) / 0.03; \
                float acrossC = exp(-dE * dE); \
                float rayId = fluteIdx * 2.0 + edgeSide + 500.0; \
                float hcA = frac(sin(rayId * 33.1) * 43758.5453), hcB = frac(sin(rayId * 71.9) * 24634.6345); \
                float Lc = lerp(0.002, 0.006, hcB); \
                float rc = 0.004 + 0.009 * frac(hcA * 7.3 + 0.35 * viewShift);              /* slides with view */ \
                float uc = (rr - rc) / (0.5 * Lc); \
                float tc = saturate(1.0 - abs(uc)); \
                g += _CapGlintNits * (hcA < 0.35 ? 1.0 : 0.0) * tc * tc * acrossC * max(Fr, 0.2) * tint * capW * facing; \
            }

// _AmbientGlow helper (2026-10-15): isotropic room irradiance / pi at the dome, in nits for a white diffuser = the sky ambient probe's
// L0 term (the renderer's SH, what HDRP Lit uses for ambient; L0 = the average over all directions: light diffused through the wall
// comes from every side) + each directional light's diffuse irradiance / (2 pi) (it leaves both faces). Forward pass only (0 elsewhere).
// (SampleBakedGI here instead moved 1 Red pixel by 1 LSB at _AmbientGlow 0; the direct SH read keeps the presets bit-identical.)
float3 FD_RoomIrr()
{
    float3 e = 0;
#if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_FORWARD)
    e = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) + float3(unity_SHBr.z, unity_SHBg.z, unity_SHBb.z) / 3.0;
    for (uint li = 0; li < _DirectionalLightCount; li++) e += _DirectionalLightDatas[li].color * _DirectionalLightDatas[li].diffuseDimmer * (0.5 / PI);
#endif
    return max(e, 0.0);
}

// P8: 1 where the ray P -> camera (v, unit, object space) passes through the vertical barrel rho < R below yTop (P outside it), soft
// over `soft` m at the silhouette and at the top
float FD_BehindBarrel(float3 P, float3 v, float R, float yTop, float soft)
{
    float a = dot(v.xz, v.xz), b = dot(P.xz, v.xz);
    if (a < 1e-6 || b >= 0.0) return 0.0;                         // straight down/up, or heading away from the dome (the near tabs)
    float m2 = max(dot(P.xz, P.xz) - b * b / a, 0.0);             // closest approach to the axis, squared (xz)
    float side = 1.0 - smoothstep(R - soft, R, sqrt(m2));
    float y1 = P.y + v.y * (-b - sqrt(max((R * R - m2) * a, 0.0))) / a;   // height where the ray enters the barrel
    return side * (1.0 - smoothstep(yTop - soft, yTop, y1));
}
void FlasherDomeGlow_float(float3 Position, float3 View, float3 NormalOS, float3 TangentOS, float3 BitangentOS, float2 UV,
    UnityTexture2D Masks, UnityTexture2D Parity,
    out float3 BaseColor, out float3 NormalTS, out float3 Emission, out float Alpha)
{
    // r8b, DOME-BAKE.md 3.3 (physically motivated, all live):
    //  glow    = level * bb(T(level)) * exp(-sigma * thick_h) * k_glow * (r0/r)^2 from the filament  - every texel emits
    //            (rough-flute scattering: the "whole dome lights, no dark bands" term)
    //  streaks = the view ray refracted in at the smooth outer skin and out through the inner facet (normal rebuilt from
    //            `flank`), compared with the direction to the filament: lobe exp(-(angle/w)^2), w from flute roughness
    //  colour  = blackbody at T(level) (2900 K full, ~2550 K at 40 %, ~2000 K tail) times red-acrylic Beer-Lambert
    //            sigma from _DomeColor (red: (100, 1400, 1500)/m); white only where intensity clips (tonemap), as in the LuxCore renders
    BaseColor = 0;
    float3 v = normalize(View + float3(0, 1e-6, 0));
    float4 m = SAMPLE_TEXTURE2D(Masks.tex, Masks.samplerstate, UV);
    float par = SAMPLE_TEXTURE2D(Parity.tex, Parity.samplerstate, UV).r;
    float lvl = saturate(_InsertLampLevel);
    float thN = m.r * 0.001, thH = min(m.g, 4.7) * 0.001;      // m
    float flank = m.a * 2.0 - 1.0;
    // r05: flute coordinates from object-space position (_FluteCount flutes, default 36 = 10 deg pitch, groove roots at theta = 0 mod 10 deg in the
    // Blender convention theta = atan2(-z, -x); inner mesh: grooves +-1.25 deg wide, r 13.95 mm at the root, flats r 13.25 mm,
    // the facet just past a root tilts its inward normal toward -tg, the one before it toward +tg)
    // r09 (Fable consult item 1): ONE opaque shell. _GlowPart 4 = shell mode: the view ray is refracted in at the smooth outer
    // skin (IOR 1.49) and marched through the ~2.2 mm wall; every interior quantity (flute phase/flank/parity) is evaluated
    // at that parallax point P_in, so the interior lenses and slides like the real wall without HDRP refraction.
    float3 Nshell = normalize(NormalOS + float3(0, 1e-6, 0));
    float3 VrIn = refract(-v, Nshell, 1.0 / 1.49);
    if (dot(VrIn, VrIn) < 1e-4) VrIn = -Nshell;
    VrIn = normalize(VrIn);
    if (_GlowPart > 3.5) Position = Position + VrIn * (_Wall / max(dot(-VrIn, Nshell), 0.2));
    float thetaP = atan2(-Position.z, -Position.x) - _FluteOffset; if (thetaP < 0.0) thetaP += 6.2831853;   // _FluteOffset (rad, 0 = roots at theta 0; x - 0 is exact)
    float pitchF = 6.2831853 / max(_FluteCount, 1.0);            // flute pitch (rad); 36 -> 0.17453293
    float fluteF = thetaP / pitchF;                              // in flute periods
    float fluteIdx = floor(fluteF);
    float eP = frac(fluteF + 0.5) - 0.5;                         // signed offset from the nearest groove root (periods)
    // r16: shoulder mask on the Outer mesh (before the projection below): top views see the lit playfield spill refracted
    // through the shoulder as a bright rim (diag: rim drops .24 -> .10 with the S18 Source light off; glow/lines/glints/
    // light-layers on base+saucer change nothing). The real thick curved shoulder shows dark there -> raise the Outer's
    // alpha toward a deep-red surface on the shoulder when lit (lvl-gated: OFF unchanged)
    // r17 (judge: r16's hard gate drew a pale ring across the cap at 45/orb1): 3 mm feathered ramps, cap rim only
    // r18 (judge): cap only - the 21.5-25.5 mm ramp dimmed the strip under the cap rim where the ref shows the bulb at 45
    float shoulderM = smoothstep(0.0235, 0.0270, Position.y) * smoothstep(0.0120, 0.0150, length(Position.xz));   // r23: a little wider (top views only)
    shoulderM = max(shoulderM, _WallEdge * smoothstep(0.0150, 0.0158, length(Position.xz)));   // r25: the barrel's outer wall seen edge-on from above (refracts the lit saucer collar into a thin ring)
    float yRaw = Position.y, rRaw = length(Position.xz);   // r18: unprojected (Outer) height/radius for the shoulder bars
    if (_GlowPart > 1.5) {
        // Outer ShaderGraph path: the Outer's uv0 is not the mask atlas -> everything procedural, geometry projected onto the
        // inner surface (r 13.95 mm barrel, cap underside 27.3 mm) so the streak maths sees the facet it would refract through
        float rxz = length(Position.xz);
        if (FD_SPH) {
            // sphere: project (from the centre; horizontally on the skirt below it) onto the inner groove-root ellipsoid, points
            // already inside stay (as the old min(r, 13.95 mm))
            float3 cP = float3(0, min(Position.y, _SphereY), 0); float3 dP = Position - cP;
            float lP = length(dP / float3(max(_InnerR, 1e-4), max(_InnerRY, 1e-4), max(_InnerR, 1e-4)));
            Position = cP + dP / max(lP, 1.0);
            float gh = max(_GrooveHalf, 1e-3);
            float inGroove = abs(eP) < gh ? 1.0 : 0.0;
            flank = -sign(eP) * inGroove * smoothstep(0.0015, 0.004, rxz);   // pole: azimuth undefined (flutes converge)
            thN = lerp(_OuterTh.x, _OuterTh.y, saturate(abs(eP) / gh));
            thH = _OuterTh.z;
        } else {
        Position.xz *= min(rxz, 0.01395) / max(rxz, 1e-5);
        Position.y = min(Position.y, 0.0273);
        float inGroove = abs(eP) < 0.125 ? 1.0 : 0.0;
        flank = -sign(eP) * inGroove * smoothstep(0.0015, 0.004, rxz);   // no flank at the cap centre (azimuth undefined)
        thN = lerp(0.00205, 0.00275, saturate(abs(eP) / 0.125));
        thH = 0.0038;
        }
        m.b = frac(fluteF);                                     // phase: 0 groove root, 0.5 flat centre
        par = fmod(fluteIdx, 2.0);
    }
    float3 F = _OpticalLamp.xyz;                                // filament (dome-local, m)
    // r18: closest approach of the refracted view ray (into the dome) to the filament: vertical offset dvF, horizontal dhF
    float3 wF = F - Position; float tF = max(dot(wF, VrIn), 0.0); float3 qF = Position + VrIn * tF;
    float dvF = qF.y - F.y, dhF = length(qF.xz - F.xz);
    // mode 1 frame at this (projected) point: outward wall normal nS, azimuthal tangent tgS, meridian tangent TmS (along the
    // flute, toward the pole), yA = arc length along the flute from the base (the sphere's analogue of the barrel height y)
    // nO = radial direction (the smooth outer sphere's normal), nS = inner-ellipsoid normal (= nO for a sphere)
    float3 cS = float3(0, min(Position.y, _SphereY), 0);
    float3 dS = Position - cS + float3(1e-6, 0, 0);
    float3 nO = normalize(dS);
    float iRx = max(_InnerR, 1e-4), iRy = max(_InnerRY, 1e-4);
    float3 nS = normalize(dS / float3(iRx * iRx, iRy * iRy, iRx * iRx));
    float3 tgS = normalize(float3(-Position.z, 0, Position.x) + float3(1e-6, 0, 0));
    float3 TmS = normalize(cross(tgS, nS));
    float yA = Position.y <= _SphereY ? Position.y : _SphereY + 0.5 * (iRx + iRy) * asin(saturate(nO.y));
    // mode 1: the filament-image offsets are measured in the local flute frame - along the flute (dvF, = height on a vertical
    // flute) and across it (dhF) - so the bar/halo/hot-zone maths stays 'where the view ray passes the filament'
    if (FD_SPH) { float3 oF = qF - F; dvF = dot(oF, TmS); dhF = length(oF - TmS * dvF); }
    float isCap = Position.y > F.y + 0.008 ? 1.0 : 0.0;
    // r06: smooth barrel -> cap blend across the rounded shoulder (the hard switch gave white "hooks" off the cap edge and a
    // flat-topped side-view core): capW for the facet/view normals and ray weight, capFaceW for lobe length and boost cap
    float capW = smoothstep(F.y + 0.0055, F.y + 0.0105, Position.y);
    float capFaceW = smoothstep(0.0235, 0.0265, Position.y);
    if (FD_SPH) { capW = smoothstep(_CapBlend.x, _CapBlend.y, nS.y); capFaceW = smoothstep(_CapBlend.z, _CapBlend.w, nS.y); }   // pole = cap
    float rC0 = length(Position.xz) / 0.0145, phi0 = atan2(Position.z, Position.x);
    if (FD_SPH) rC0 = length(Position.xz) / max(_CapR, 1e-4);
    float xRoomS = 1.0 - _XRoom * exp(-FD_SQ((rC0 - 0.52) / 0.25)) * (1.0 - pow(abs(sin(2.0 * phi0 + _XPhase)), 3.0));   // r18: same off-beam dim for the cap rays

    // blackbody colour (normalised so max channel = 1), T from the level: T = 2900 K * level^0.1235 (L ~ V^3.4, T ~ V^0.42)
    float T = 2900.0 * pow(max(lvl, 1e-3), 0.1235);
    float t = T / 100.0;
    float3 bb;
    bb.r = 1.0;
    bb.g = saturate((99.4708025861 * log(t) - 161.1195681661) / 255.0);
    bb.b = t <= 19.0 ? 0.0 : saturate((138.5177312231 * log(t - 10.0) - 305.0447927307) / 255.0);
    // _BBTemp (2026-10-15 P5): filament temperature at level 1 for the dome's own emission (K); 0 (default) = the 2900 K above, unchanged
    // (the override recomputes bb after the original lines). A preset whose Source light is warmer than the 2900 K body (Clear: light
    // (1, .62, .32)) sets it lower so the dome stays at least as warm as its own spill through the cool-down.
    if (_BBTemp > 0.0) {
        float tB = _BBTemp * pow(max(lvl, 1e-3), 0.1235) / 100.0;
        bb.g = saturate((99.4708025861 * log(tB) - 161.1195681661) / 255.0);
        bb.b = tB <= 19.0 ? 0.0 : saturate((138.5177312231 * log(tB - 10.0) - 305.0447927307) / 255.0);
    }
    float3 sigma = FD_Sigma();
    float3 trH = exp(-sigma * thH), trN = exp(-sigma * thN);

    // glow term
    float3 toF = F - Position; float r = max(length(toF), 0.004); toF /= r;
    float fall = (0.012 / r) * (0.012 / r);
    // flute structure: groove roots / ray ridges read as bright lines (light concentrates along the edges), flats softer
    float ph = m.b; float e = min(ph, 1.0 - ph);
    float edge = exp(-(e / 0.09) * (e / 0.09));
    // loop r00: steep peak curve. Mid/fade levels keep the r9 look (boost = _CoreBoost); above the
    // knee the boost log-lerps to _BoostPeak at level 1 with weight w = (lvl^p - knee^p)/(1 - knee^p), so only the true
    // peak blows the core out white. Desat and glow follow the same weight.
    float bp = max(_BoostPow, 1.0);
    float kp = pow(saturate(_BoostKnee), bp);
    float wpk = saturate((pow(lvl, bp) - kp) / max(1.0 - kp, 1e-4));
    float boost = exp(lerp(log(max(_CoreBoost, 1e-3)), log(max(_BoostPeak, 1e-3)), wpk));
    // r03: flute/face alternation strengthens toward the peak (_Zebra -> _ZebraPeak by L 0.5..0.7)
    float zb = lerp(_Zebra, _ZebraPeak, smoothstep(0.5, 0.7, lvl));
    // r08: per-facet +-25 % light/dark in the lit body (Lux alternating faces), hashed on flute x flank class
    float fcls = flank > 0.3 ? 0.0 : (flank < -0.3 ? 1.0 : 2.0);
    float facetLit = 0.75 + 0.5 * frac(sin((fluteIdx * 3.0 + fcls) * 57.31 + 3.7) * 43758.5453);
    float3 glow = bb * trH * fall * (0.65 + _EdgeGlowW * edge) * lerp(1.0 - 0.5 * zb, 1.0, par) * lerp(1.0, _GlowPeak, wpk) * facetLit;

    // streak term: outer skin is smooth (normal = radial / up on the cap); inner facet from the flank mask
    float3 rad = normalize(float3(Position.x, 0, Position.z) + float3(1e-6, 0, 0));
    float3 nOut = normalize(lerp(rad, float3(0, 1, 0), capW));
    float3 tg = float3(-rad.z, 0, rad.x);                     // Unity side of the mask's +flank (parity-checked)
    float3 nIn = normalize(lerp(normalize(-rad * (1.0 - 0.45 * abs(flank)) + tg * flank * 1.3), normalize(float3(0, -1, 0) + tg * flank * 0.9), capW));
    if (FD_SPH) {   // continuous wall normal: the barrel (horizontal radial) and cap (up) normals both become nS
        nOut = nO;
        nIn = normalize(lerp(normalize(-nS * (1.0 - 0.45 * abs(flank)) + tg * flank * 1.3), normalize(-nS + tg * flank * 0.9), capW));
    }
    float3 d0 = -v;
    float3 d1 = refract(d0, nOut, 1.0 / 1.49);
    if (dot(d1, d1) < 1e-4) d1 = d0;
    float3 d2 = refract(normalize(d1), -nIn, 1.49);
    float tir = dot(d2, d2) < 1e-4 ? 1.0 : 0.0;
    d2 = tir > 0.5 ? reflect(normalize(d1), -nIn) : normalize(d2);
    // anisotropic lobe: vertical flutes smear each filament image along the flute (vertical) and keep it narrow across
    // (horizontal) -> white-hot vertical streak segments, not a round blob. On the cap the roles turn radial/tangential.
    float w = max(_BandSigma, 0.01);
    float3 axA = normalize(lerp(normalize(cross(float3(0, 1, 0), d2) + float3(1e-6, 0, 0)), tg, capW));   // "across" direction
    if (FD_SPH) axA = normalize(cross(TmS, d2) + float3(1e-6, 0, 0));   // across the meridian flute (= the barrel rule with up -> TmS; -> tg at the pole)
    float3 dd = d2 - toF;
    float aA = dot(dd, axA), aL = length(dd - axA * aA);
    // r01: along-flute length is its own knob (_StreakLen x w); widening w fattened the streaks into white bars
    // r02: the cap underside proper (inner mesh top 27.3 mm) gets its own lobe length and a capped boost - looking down the bulb
    // axis the long cap lobes + the x60 peak boost flooded the top view white (judge r01: 42 % white vs 7 %)
    float capFace = capFaceW;
    float wl = lerp(max(_StreakLen, 0.5), max(_CapStreakLen, 0.5), capW) * w;
    float lobe = exp(-(aA / w) * (aA / w) - (aL / wl) * (aL / wl)) * (1.0 - 0.6 * tir);
    float zebra = lerp(1.0 - zb, 1.0, par);
    // r9 V2: the filament seen through a THIN fin is genuinely near-white - desaturate the streak colour toward the
    // blackbody (unfiltered) by level x thin-fin mask
    float thinFin = saturate(1.0 - (thN * 1000.0 - 1.0) / 2.0);   // 1 mm -> 1, 3 mm -> 0
    float3 strCol = lerp(bb * trN, bb, saturate(_Desat * lvl * thinFin + _DesatPeak * wpk));
    float3 streak = strCol * lobe * fall * zebra * lerp(1.0, _CapRays, capW) * lerp(_StreakBarrel, 1.0, capFaceW) * lerp(1.0, xRoomS, capFaceW);   // r17: barrel share of the old single lobe (= the pale bulb-column slab; the bars carry the barrel now)

    // r9 V1: _CoreBoost scales the dome's own core/streak emission only (the burst light is separate)
    // loop r00: emission black below _LevelToe (the #89 tail otherwise stays visible at <0.5 % level: streaks are ~1e6 nits at
    // peak); colour temperature still follows the raw level
    float lvlE = saturate((lvl - _LevelToe) / max(1.0 - _LevelToe, 1e-4));
    float boostS = lerp(boost, min(boost, _CapBoostMax), capFace);
    // r03: the peak boost above _CoreBoost stays near bulb height (no white spindle from base to cap centre)
    float hy = (Position.y - F.y) / max(_PeakHeight, 1e-4);
    if (FD_SPH) hy = dvF / max(_PeakHeight, 1e-4);   // filament at the base plane: 'bulb height' = where the view ray passes the bulb along the flute
    // loop r01 (hat): the whole miss distance of the refracted view ray to the filament, not only its along-flute part - on a
    // hemisphere centred on the bulb the left/right limbs miss it ACROSS the flute (dhF) with dvF ~ 0, so a dvF-only gate lit them
    if (FD_SPH) hy = length(float2(dvF, dhF)) / max(_PeakHeight, 1e-4);
    float gy = exp(-hy * hy);
    boostS = lerp(min(boostS, max(_CoreBoost, 1e-3)), boostS, gy);
    // r04: vertical Gaussian on the whole streak/core boost (blob at bulb height, Lux), floor _CoreFloor away from it
    boostS *= lerp(saturate(_CoreFloor), 1.0, gy);
    // r07: fade the whole streak/core term below the bulb (Lux: brightest at bulb/cap height, .45-.65 at the base)
    // r08: Gaussian window below the bulb (sigma 4 mm): the white "foot" at the base came from the core lobe on the near
    // barrel 3-12 mm high, where r07's 14 mm ramp still passed 50-100 %
    float yb = min(Position.y - F.y, 0.0) / max(_PeakHeight, 1e-4);
    boostS *= lerp(saturate(_CoreBelow), 1.0, exp(-yb * yb));
    // r03 inner glint (Ben's OFF note): the view ray, refracted in at the smooth skin, reflects off the inner flute FACET
    // (plastic->air; Fresnel -> 1 past the ~42 deg critical angle), goes back out through the skin and picks up a fixed
    // studio environment (gradient + 3 soft cards). Deep red (two passes through the wall). Level independent, no SSR.
    float3 g = 0;
    if (_GlintNits > 0.0) {
        float3 dIn = normalize(d1);
        // r06 (Ben): per-FACET randomness, stable in object space: each facet (flute x {left flank, right flank, flat}) gets its
        // own glint gain (a few hot, most dim, some near-black) and a small tilt of its normal, so neighbouring faces differ
        // r08: no hard barrel/cap switch in the facet id (it drew the "doorframe" bar at the shoulder): barrel and cap hashes
        // are blended with capW
        float facetId = fluteIdx * 3.0 + (flank > 0.3 ? 0.0 : (flank < -0.3 ? 1.0 : 2.0));
        float hA0 = frac(sin(facetId * 78.233 + 1.7) * 43758.5453), hA1 = frac(sin((facetId + 200.0) * 78.233 + 1.7) * 43758.5453);
        float hA = lerp(hA0, min(hA1, 0.75), capW);                 // r08: cap facets never draw the top of the gain range (red wedge)
        float hB = frac(sin(facetId * 12.9898 + 7.3) * 24634.6345);
        float3 tgF = normalize(float3(-Position.z, 0, Position.x) + float3(1e-6, 0, 0));
        float3 nInF = normalize(nIn + tgF * (hB - 0.5) * 0.25 * _FacetJitter + float3(0, (hA - 0.5) * 0.15 * _FacetJitter, 0));
        float facetGain = lerp(1.0, lerp(0.05, lerp(2.5, 1.0, capW), pow(hA, 3.0)), saturate(_FacetJitter));   // cap: no single hot wedge (r07 0.6)
        float3 nInKeep = nIn; nIn = nInF;
        float ci = saturate(dot(dIn, nIn));                         // incidence cos at the inner surface (plastic side)
        float si2 = 1.0 - ci * ci;
        float st2 = 1.49 * 1.49 * si2;
        float Fr = 1.0;
        if (st2 < 1.0) { float ct = sqrt(1.0 - st2); float f0 = 0.0387; Fr = f0 + (1.0 - f0) * pow(1.0 - ct, 5.0); }
        float3 r = reflect(dIn, nIn);
        float3 ro = refract(r, -nOut, 1.49);
        if (dot(ro, ro) < 1e-4) ro = reflect(r, -nOut);
        ro = normalize(ro);
        float3 wd = float3(-ro.x, ro.y, -ro.z);                     // object (rot Y 180) -> world
        // r04: r03 studio env (sky gradient + 3 soft cards) but modulated in azimuth by 6 "windows", so neighbouring facets
        // (which reflect different azimuths) alternate light/dark instead of glowing evenly; smooth everywhere (no seam)
        // r05: alternate facets on EACH flute (one flank x1, the other x0.2, flats x0.35) + sparse hot ridges (hash per flute)
        // r06: near-black room (Ben: dark, almost metallic interior) - tiny sky, narrow bright cards
        float env = lerp(0.008, 0.16, saturate(wd.y * 0.5 + 0.5));   // soft room; per-facet gain (facetGain) breaks the regular pinstripe
        env += 5.0 * pow(saturate(dot(wd, normalize(float3(0.0, 0.75, -0.66)))), 70.0);    // key card above the player side
        env += 3.0 * pow(saturate(dot(wd, normalize(float3(0.85, 0.35, 0.2)))), 60.0);     // side card
        env += 2.5 * pow(saturate(dot(wd, normalize(float3(-0.3, 0.95, 0.4)))), 70.0);     // overhead bar
        env += 2.0 * pow(saturate(dot(wd, normalize(float3(-0.8, 0.3, -0.5)))), 60.0);     // left card
        float3 tint = exp(-sigma * 2.0 * thN);
        float capTaper = lerp(1.0, max(0.35, saturate(length(Position.xz) / 0.0145)), capW);   // r05: no dark pupil
        if (FD_SPH) capTaper = lerp(1.0, max(0.35, saturate(length(Position.xz) / max(_CapR, 1e-4))), capW);
        float side = flank > 0.3 ? 1.0 : (flank < -0.3 ? 0.2 : 0.35);
        float hsh = frac(sin(fluteIdx * 12.9898 + 4.1) * 43758.5453);
        float spark = lerp(0.12, 2.2, pow(hsh, 8.0));                                    // r06: few hot ridges, most dim
        float spark0 = spark;
        spark *= 1.0 + _GlintBand * exp(-FD_SQ((Position.y - 0.0245) / 0.0018)) * (1.0 - capW);   // brighter band under the cap edge (Lux)
        if (FD_SPH) spark = spark0 * (1.0 + _GlintBand * exp(-FD_SQ((Position.y - _GlintBandY) / 0.0018)) * (1.0 - capW));
        float ledge = 1.0 - smoothstep(0.4, 0.6, abs(normalize(NormalOS).y)) * (1.0 - capW);   // r07: no "doorframe" bar on barrel ledges
        if (FD_SPH) ledge = 1.0 - smoothstep(0.4, 0.6, length(cross(normalize(NormalOS), nS)));   // ledge = surface tilted off the sphere (rim, tab), not 'normal.y'
        float shoulder = 1.0 - 0.85 * saturate(4.0 * capW * (1.0 - capW));   // r08: glints fade across the shoulder blend (doorframe bar)
        float capEnv = lerp(env, min(env, 1.0), capW);                         // r08: key card can't blow one cap facet up (red wedge)
        g = _GlintNits * Fr * capEnv * tint * capTaper * side * spark * facetGain * ledge * lerp(1.0, 0.8, capW) * shoulder;
        if (_DbgTerm > 1.5) g = 0;
        // r06 (Ben): micro-flake glitter - sparse tiny flakes (object-space cells, ~0.4 mm, few % density) with random normals
        // on the inner facets; a flake lights only when its reflected ray hits a light card (twinkles with view), red-tinted,
        // Fresnel-scaled. Emitted by the Outer with the glints (not refracted), inner only (outer stays smooth).
        if (_FlakeNits > 0.0) {
            // r07 (Ben): flake SHAPE - cells stretched along the flute (dome axis = object y) by _FlakeAspect; per cell a dot or
            // (with probability _FlakeStreakMix) a streak of random length (30-100 % of the cell), slight tilt, random faintness.
            // Flake count per area is kept (cell probability x aspect), so streaks cover more area than dots.
            float asp = capW > 0.5 ? 1.0 : max(_FlakeAspect, 1.0);   // cap: round cells (cap is horizontal)
            float3 cellP = Position / (max(_FlakeCell, 1e-5) * float3(1.0, asp, 1.0));
            float3 cId = floor(cellP), cF = frac(cellP) - 0.5;
            float h0 = frac(sin(dot(cId, float3(127.1, 311.7, 74.7))) * 43758.5453);
            float h1 = frac(sin(dot(cId, float3(269.5, 183.3, 246.1))) * 43758.5453);
            float h2 = frac(sin(dot(cId, float3(113.5, 271.9, 124.6))) * 43758.5453);
            float h3 = frac(sin(dot(cId, float3(41.3, 289.1, 197.7))) * 43758.5453);
            float h4 = frac(sin(dot(cId, float3(19.7, 93.1, 151.9))) * 43758.5453);
            float h5 = frac(sin(dot(cId, float3(233.3, 61.7, 17.1))) * 43758.5453);
            float h6 = frac(sin(dot(cId, float3(71.9, 13.3, 287.5))) * 43758.5453);
            float onFlake = h0 < saturate(_FlakeDensity * asp * lerp(0.5, 1.6, hA)) ? 1.0 : 0.0;   // r08: more flakes on lighter facets
            float isStreak = (h4 < _FlakeStreakMix ? 1.0 : 0.0) * (1.0 - capW);   // streaks run along the flutes: barrel only
            float across = (cF.x + cF.z) * 0.7071;
            float along = cF.y + across * (h6 - 0.5) * 0.6 / asp;                 // slight tilt
            float halfLen = lerp(0.15, 0.5, h5);
            float endHard = 1.0 - smoothstep(halfLen * 0.7, halfLen, abs(along)), endSoft = exp(-3.0 * (along / halfLen) * (along / halfLen));
            float streakShape = exp(-(across * across) / 0.015) * lerp(endHard, endSoft, saturate(_FlakeSoft)) * lerp(0.15, 1.0, h3);   // r08: soft ends (knob)
            float dot2 = dot(cF.xz, cF.xz) + (cF.y * asp) * (cF.y * asp) * 0.3;  // round dot inside the tall cell
            float shape = lerp(exp(-dot2 / 0.03), streakShape, isStreak);
            float3 nFl = normalize(nInKeep + (float3(h1, h2, h3) - 0.5) * 1.2);
            float3 rf = reflect(dIn, nFl);
            float3 rfo = refract(rf, -nOut, 1.49); if (dot(rfo, rfo) < 1e-4) rfo = reflect(rf, -nOut);
            rfo = normalize(rfo); float3 wf = float3(-rfo.x, rfo.y, -rfo.z);
            float hit = pow(saturate(dot(wf, normalize(float3(0.0, 0.75, -0.66)))), 60.0) + 0.7 * pow(saturate(dot(wf, normalize(float3(0.85, 0.35, 0.2)))), 60.0)
                      + 0.6 * pow(saturate(dot(wf, normalize(float3(-0.3, 0.95, 0.4)))), 60.0) + 0.5 * pow(saturate(dot(wf, normalize(float3(-0.8, 0.3, -0.5)))), 60.0);
            float ciF = saturate(dot(dIn, nFl)); float FrF = 0.0387 + 0.9613 * pow(1.0 - ciF, 5.0);
            g += (_DbgTerm > 0.5 && _DbgTerm < 1.5) ? 0 : _FlakeNits * onFlake * shape * hit * max(FrF, 0.15) * tint * capTaper;
        }
        // r08 (Ben) RIDGE GLINTS: the edges of the internal spokes catch reflections at random places. Per flute edge (two per
        // flute, at the groove-root/flank boundary |e| ~ 0.115 period) a 1-D random field along the height: cells of random
        // length (5-60 % of the barrel), each lit with probability ~0.35 by a TAPERED (gaussian) segment, hot core. The field
        // coordinate includes the view direction relative to the ridge, so segments slide/appear/vanish as the camera moves
        // (stable object-space hashing, no per-frame noise). Fresnel-gated, red-tinted, barrel only (fades into the cap).
        {
            float edgeSide = eP < 0.0 ? 0.0 : 1.0;
            float sgnE = edgeSide * 2.0 - 1.0;
            float3 tgR = normalize(float3(-Position.z, 0, Position.x) + float3(1e-6, 0, 0));
            float facing = smoothstep(-0.15, 0.35, dot(v, sgnE * tgR));                    // flank must face the camera
            float hF0 = frac(sin(fluteIdx * 63.7 + 0.9) * 43758.5453), hF1 = frac(sin(fluteIdx * 21.3 + 4.4) * 24634.6345);
            float hF2 = frac(sin(fluteIdx * 47.9 + 8.1) * 43758.5453), hF3 = frac(sin(fluteIdx * 11.7 + 2.6) * 24634.6345);
            float viewShift = 2.2 * dot(-v, tgR) * sgnE + 1.6 * v.y;
            const float H = 0.025;                                                          // barrel height used (m)
            // mode 0: the old text expanded with its literals (y, 25 mm barrel height, edge at .115 period); mode 1: meridian arc
            // coordinate yA, flute length _FluteLen, edge at _GrooveHalf - .01 period
            if (FD_SPH) { FD_RIDGE_NEEDLE_CAP(yA, _FluteLen, (_GrooveHalf - 0.01)) }
            else { FD_RIDGE_NEEDLE_CAP(Position.y, H, 0.115) }
        }
        nIn = nInKeep;
    }
    // r03 flash veil: a smooth warm-white overlay over the whole dome only above L 0.9 (the clip's 1-2 frame white-out)
    float wv = smoothstep(0.55, 1.0, lvl); wv *= wv;   // r04: wider gate (r03 0.9-1 dropped to red in one frame)
    if (_VeilLevel >= 0.0) { wv = saturate(_VeilLevel); wv *= wv; }   // r05: veil with its own peak-hold + decay (squared), driven at runtime
    float3 veil = _VeilNits * wv * FD_Abs(float3(1.0, 0.82, 0.62)) * fall;
    // r04 split: part 1 = body glow + veil (BeforeRefraction renderer, lensed by the Outer); part 2 = streak/edge/core + glint
    // (second renderer drawn AFTER the refractive Outer, so the thin lines are not resampled into dot chains); 0 = everything
    // r07: cream cap centre (Lux top view: hot cream centre) - desaturated, level >= 0.3, r < 6 mm on the cap
    float3 capCream = _CapCenterNits * smoothstep(0.3, 0.6, lvl) * lvlE * capW * exp(-dot(Position.xz, Position.xz) / (0.0028 * 0.0028)) * lerp(bb * trN, FD_Abs(float3(1.0, 0.85, 0.65)), 0.6);
    // r11b (Ben: the cap should LIGHT when the flasher fires): additive cap body glow in the r08 path - hot orange centre, lit
    // radial rays (flute edges) across the whole cap, red-orange towards the rim. Spectrum = blackbody x wall transmission.
    // r14: two-segment level map for body glow + bars: pow(l, _GlowGamma) above the knee (static L0.4 lift), below it a
    // steeper continuation (gk * (l/k)^_GlowLowPow) so the cooling tail darkens like the clip
    float kG = max(_GlowKnee, 1e-3), gk = pow(kG, max(_GlowGamma, 0.1));
    float lvlG = lvlE >= kG ? pow(lvlE, max(_GlowGamma, 0.1)) : gk * pow(saturate(lvlE / kG), max(_GlowLowPow, 0.1));
    float rC = length(Position.xz) / 0.0145;
    if (FD_SPH) rC = length(Position.xz) / max(_CapR, 1e-4);
    // r12: confined to the RAYS (gaps stay dark), stops at the cap edge (capFaceW, cap top only), small hot orange centre
    float capTop = capFaceW * (1.0 - smoothstep(_CapEdge0, 0.99, rC));   // r15: fade start is a knob (r12 .85, r13/14 .95)
    // r15 (judge): the top view's rim annulus (shoulder seen from above) reads bright vs the cap mid (rim/mid .79, ref .22) ->
    // dim body + lines there, gated to views from above
    float rimDim = 1.0 - _RimDim * smoothstep(_RimR0, _RimR0 + 0.13, rC) * capW * saturate(v.y) * saturate(v.y);   // r24: start radius a knob (.82 before)
    // r17: X-beams (Lux top view: 4-fold beams at r ~.45-.6, aligned with the line filament along x)
    float phiX = atan2(Position.z, Position.x);
    // r24: X-beams scale up with level (soft at L0.4/0.7) and carry a heat path: on the ray cores of the beam the colour
    // leaks G/B like the bars (deep red -> yellow, white only where it clips), the gaps stay red
    float xw = pow(abs(sin(2.0 * phiX + _XPhase)), 12.0) * exp(-FD_SQ((rC - 0.52) / 0.18)) * smoothstep(0.65, 0.92, v.y);
    float xCore = xw * edge * edge * edge * edge;
    float3 xCol = lerp(bb * trH, FD_Abs(float3(1.0, 0.62, 0.10)), saturate(_XHeat * xCore));
    float3 capX = _CapXBeam * pow(lvlE, max(_XPow, 1.0)) * capTop * xCol * xw * (0.5 + 0.5 * edge * edge);
    // r18: room for the X-beams: dim the cap glow/rays off-beam on the beam ring (dark gaps between beams)
    float xRoom = 1.0 - _XRoom * capTop * exp(-FD_SQ((rC - 0.52) / 0.25)) * (1.0 - pow(abs(sin(2.0 * phiX + _XPhase)), 3.0));
    float3 capBody = capX + xRoom * _CapGlow * lvlE * capTop * bb * trH * (0.4 + 0.6 * exp(-rC * rC / 0.35)) * (0.08 + edge * edge)
                     + _CapGlow * 2.0 * lvlE * capFaceW * bb * FD_Filter(float3(1.0, 0.5, 0.22)) * exp(-rC * rC / 0.037);   // r13: centre back to r08 size (capCream r 2.8 mm)
    // r11b spectral veil for the r08 path: a gain on the transmitted glow (no uniform white layer)
    float vgain = 1.0 + _VeilGain * wv;
    // r15: the low-level lift goes on the groove edges more than the flats (flute contrast back, judge mid flute .22 vs .35)
    float lvlB = lerp(lvlE, lvlG, saturate(_LiftFlat + (1.0 - _LiftFlat) * edge));
    float3 bodyG = lvlB * _GlowNits * glow * lerp(1.0, _CapBodyW, capFaceW) * lerp(1.0, xRoom, capFaceW);   // r18: cap share of the body glow (top-view budget for the X-beams) + off-beam dim
    // r17 (judge: pale slab at the bulb column = the near wall closest to the filament, fall ~ 1/r^2): soft knee on the
    // body glow so the hottest column stays at bar-body level (0 = off)
    if (_BodyKnee > 0.0) bodyG /= 1.0 + FD_Max3(bodyG) / _BodyKnee;   // max channel (= R on red)
    float3 body = ((bodyG + capBody) * vgain + veil + capCream) * rimDim;
    // r13 (Ben LED photo): N flank BARS chosen by angle. Each groove flank is evaluated at its own centre (groove root azimuth,
    // bulb height, inner radius) against a LINE filament (5 samples, +-1.6 mm along x): a GGX transmission lobe on the tilted
    // flank normal. The value is constant over the flank -> every flank inside the lobe is one narrow yellow-hot bar at bulb
    // height; the neighbour flank / flats stay dark. Barrel only.
    float3 fbar = 0;
    if (_BarNits > 0.0) {
        float gi = round(fluteF);
        float thG = gi * pitchF + _FluteOffset;   // + 0 is exact
        float sgn = eP >= 0.0 ? 1.0 : -1.0;
        float aB = max(_BarAlpha, 0.02), aB2 = aB * aB;
        float sB = 0;
        if (FD_SPH) {
            // mode 1: the flute is extruded along the MERIDIAN, so the elevation mismatch is smeared along the local flute axis
            // TmC, not along y: project light and view onto the plane across the flute (normal + azimuthal tangent) at the root
            // point at this pixel's latitude. On a vertical flute (TmC = up) this is exactly the old horizontal-plane lobe.
            float3 hR = float3(-cos(thG), 0, -sin(thG));           // outward horizontal at the root azimuth
            // root point = this pixel rotated to the root azimuth (same latitude, same surface); wall normal rotated with it
            float sH = length(nS.xz), rhoP = length(Position.xz);
            float3 nR = normalize(hR * sH + float3(0, nS.y, 0));
            float3 TmC = normalize(float3(0, sH, 0) - hR * nS.y + float3(0, 1e-6, 0));   // along the flute toward the pole (up on a vertical flute)
            float3 Pc = float3(hR.x * rhoP, Position.y, hR.z * rhoP) + TmC * _BarY;
            float3 tgR = float3(hR.z, 0, -hR.x);                     // = the old (-radInB.z, 0, radInB.x)
            float3 NfB = normalize(-nR + tgR * sgn * tan(radians(_BarTilt)));
            float3 wvB = -VrIn; float3 woB = normalize(wvB - TmC * dot(wvB, TmC) + float3(1e-6, 0, 0));
            [unroll] for (int kb = -2; kb <= 2; kb++) {
                float3 toLb = F + float3(kb * 0.0008, 0, 0) - Pc; float3 Lb = normalize(toLb - TmC * dot(toLb, TmC) + float3(1e-6, 0, 0));
                float3 hB = normalize(1.49 * (-woB) - Lb); if (dot(hB, NfB) < 0.0) hB = -hB;
                float nh = saturate(dot(NfB, hB));
                float DB = aB2 / (3.14159 * FD_SQ(nh * nh * (aB2 - 1.0) + 1.0));
                sB += DB * 3.14159 * aB2 * saturate(dot(Lb, NfB) * 4.0);
            }
        } else {
        float3 radInB = float3(cos(thG), 0, sin(thG));            // inward radial at the root (thetaP = atan2(-z,-x))
        float3 Pc = float3(-0.01395 * cos(thG), F.y + _BarY, -0.01395 * sin(thG));
        float3 tgR = float3(-radInB.z, 0, radInB.x);
        float3 NfB = normalize(radInB + tgR * sgn * tan(radians(_BarTilt)));
        float3 woB = normalize(float3(-VrIn.x, 0, -VrIn.z) + float3(1e-6, 0, 0));   // vertical flute = extruded V: elevation mismatch is smeared along it -> lobe in the horizontal plane
        [unroll] for (int kb = -2; kb <= 2; kb++) {
            float3 toLb = F + float3(kb * 0.0008, 0, 0) - Pc; float3 Lb = normalize(float3(toLb.x, 0, toLb.z));
            float3 hB = normalize(1.49 * (-woB) - Lb); if (dot(hB, NfB) < 0.0) hB = -hB;
            float nh = saturate(dot(NfB, hB));
            float DB = aB2 / (3.14159 * FD_SQ(nh * nh * (aB2 - 1.0) + 1.0));
            sB += DB * 3.14159 * aB2 * saturate(dot(Lb, NfB) * 4.0);   // normalised: 1 at the lobe centre
        }
        }
        float acrossB = 1.0 - smoothstep(_BarWidth * 0.6, _BarWidth, abs(eP));
        // r15 (judge + LED photo): staggered, longer, broken, YELLOW-hot bars. Per flank hash: centre height jitter and length;
        // 1-D value noise along the height breaks each bar into segments; flat-topped (super-Gaussian) profile; white only at
        // the single hot point (overexposure of the yellow), body colour yellow-orange (G/R ~.6, B/R ~.1)
        float fid = gi * 2.0 + (sgn > 0.0 ? 1.0 : 0.0);
        float hb1 = frac(sin(fid * 91.7 + 3.1) * 43758.5453), hb2 = frac(sin(fid * 47.3 + 8.9) * 24634.6345);
        float yc = F.y + _BarY + (hb1 - 0.5) * _BarJitter;
        float yP = F.y + dvF;   // r18: bar profile in the view-ray frame (parallax: at 45 the bars sit higher, where the bulb shows)
        float hl = max(_BarHeight, 1e-4) * (0.6 + 0.9 * hb2);
        float hB2 = (yP - yc) / hl;
        float sN = Position.y / max(_BarSeg, 1e-4) + hb2 * 17.0;
        if (FD_SPH) sN = yA / max(_BarSeg, 1e-4) + hb2 * 17.0;   // breaks along the meridian
        float i0 = floor(sN), fN = frac(sN);
        float n0 = frac(sin((i0 + fid * 13.0) * 12.9898) * 43758.5453), n1 = frac(sin((i0 + 1.0 + fid * 13.0) * 12.9898) * 43758.5453);
        float brk = lerp(1.0, smoothstep(0.2, 0.7, lerp(n0, n1, smoothstep(0.0, 1.0, fN))), saturate(_BarBreak));
        float prof = exp(-pow(abs(hB2), 3.0));
        if (FD_SPH) prof *= exp(-FD_SQ(dhF / hl));   // loop r01 (hat): bars only where the view ray passes near the filament across the flute too
        // r16: hot point + intensity peak at the filament height seen through the parallax (F.y + _BarHotY), not the bar centre
        // r18: hot point where the VIEW RAY passes the filament (parallax: at 45 the bulb shows higher on the wall)
        // r19 (judge: 'string of pearls'): per-flank random hot height and length -> slivers at varied heights; white core
        // only on the hottest few flanks
        float hb3 = frac(sin(fid * 17.17 + 5.3) * 43758.5453);
        float yh = (dvF - _BarHotY - (hb3 - 0.5) * _HotJitter) / (0.0040 * (0.5 + 1.2 * hb2));
        // r20 (judge: fat beads): sharp tapered hot profile (parabolic taper, pointed ends) instead of a round Gaussian bead
        float tp = saturate(1.0 - abs(yh) / 2.2);
        // r22 (judge: side 'bead' = the hot point widening to 34 px): hot gain only within a capped width across the flank
        float hotX = 1.0 - smoothstep(0.035, 0.06, abs(eP));
        float hot = (0.45 + 0.55 * tp) * (1.0 + _BarHot * (0.4 + 0.6 * hb1) * tp * tp * tp * hotX);
        // r18 (diag: the 45 bright row IS the bars, sitting on the barrel at 65-75 % of the image; the ref's 45-65 % band is
        // the shoulder): bars continue over the shoulder (unprojected y 23-28.8 mm, r > 12.5 mm, never the cap face) for
        // elevated, non-top views only (a top view would see them as a ring of dots)
        float shB = _BarShoulder * smoothstep(0.022, 0.025, yRaw) * (1.0 - smoothstep(0.0278, 0.0292, yRaw)) * smoothstep(0.0118, 0.0132, rRaw)
                    * smoothstep(0.25, 0.55, v.y) * (1.0 - smoothstep(0.82, 0.95, v.y));
        // r18: the 45 view sees the bulb through the TOP of the barrel / shoulder (y 24-28 mm), which the old y<24.5 mm cut
        // removed. Cut on the unprojected radius instead (never the cap face), and fade the shoulder part out for top views
        float barCut = smoothstep(0.0118, 0.0132, rRaw) * (1.0 - smoothstep(0.0280, 0.0292, yRaw))
                       * lerp(1.0, 1.0 - smoothstep(0.80, 0.93, v.y), smoothstep(0.0245, 0.0271, yRaw));
        if (FD_SPH) barCut = smoothstep(_BarR0, _BarR0 + 0.0014, rRaw);   // only the pole hub is cut (flutes run to the pole; the y gates were the tall shoulder)
        // r18: white only in each bar's hot core
        float coreW = saturate(_BarCoreW * exp(-yh * yh * 6.0)) * step(0.65, hb1);
        float3 bCol = lerp(bb * trN, FD_Abs(float3(1.0, 0.62, 0.10)), saturate(_BarDesat));
        bCol = lerp(bCol, FD_Abs(float3(1.0, 0.92, 0.75)), coreW);
        // r20: white-hot = OVERDRIVE of a 1-2 px core on the groove root line (|eP| < ~.02 period) at the hot centre of the
        // hotter flanks: same yellow colour, x(1 + _CoreOver) -> white only where the red/yellow already clips
        float coreX = (1.0 - smoothstep(0.025, 0.045, abs(eP))) * pow(tp, 1.5) * step(0.5, hb1);   // r21: longer, not wider
        fbar = _BarNits * lvlG * (boost / max(_CoreBoost, 1e-3)) * (sB / 5.0) * acrossB * brk * (prof * hot * barCut + shB) * (1.0 + 2.0 * coreW) * (1.0 + _CoreOver * coreX) * bCol;   // r15: up to the top of the barrel (a radius-based cut onto the shoulder lit a ring of dots round the cap: rejected)
    }
    // r14: top hot centre = the filament seen straight down through the cap: small, view-gated (looking down the axis),
    // blackbody desaturated -> clips white in the core with a yellow-orange fringe
    // r15: starburst ORANGE centre (r12 read better than r14's white oval): ray-confined (edge^2) orange star decaying with
    // radius + a tiny white core (rC < .035); view gate v.y^2 so the 45 cap star comes back
    float3 capSpot = _CapSpotNits * lvlG * capFaceW * saturate(v.y) * saturate(v.y) * bb
                     * (FD_Filter(float3(1.0, 0.42, 0.10)) * exp(-rC / max(_SpotLen, 0.01)) * (0.1 + 0.9 * edge * edge) + FD_Filter(float3(1.0, 0.85, 0.6)) * _SpotCore * exp(-(rC / 0.05) * (rC / 0.05)));
    if (FD_SPH) capSpot *= pow(saturate(v.y), 6.0);   // loop r02 (hat): the pole spot is the bulb seen down the axis - top views only (LuxCore 45 shows no pole spot)
    // r18 (judge): the bulb itself seen through the wall - orange halo where the view ray passes the filament, broken by
    // the flutes (groove lines carry it, flats mostly dark), barrel only
    float3 halo = _BulbHalo * lvlG * exp(-(dvF * dvF + 3.0 * dhF * dhF) / (0.0025 * 0.0025)) * pow(edge, 3.0) * (1.0 - capFaceW) * bb * FD_Filter(float3(1.0, 0.35, 0.06));   // r19: per-flute (groove lines only, dark gaps), deep orange not cream
    float3 lines = ((halo + lvlE * _StreakNits * _Sparkle * boostS * streak * (_DbgTerm > 0.5 && _DbgTerm < 2.5 ? 0.0 : 1.0) + fbar + capSpot) * rimDim + (_DbgTerm > 2.5 ? 0.0 : 1.0) * g) * max(_LinesGain, 0.0);   // r15: rimDim on the lit terms only (OFF glints unchanged)
    // r19 heat A/B (Ben: 'never gets to white-hot'): at the peak only (lvl >= .85) scale the transmitted emission (body + lit
    // line terms, not the glints). Channels keep their wall-transmission ratios, so ACES carries the hottest flutes
    // orange -> yellow -> white while the dimmer walls stay red. 1 = off
    float heat = lerp(1.0, max(_HeatPeak, 1.0), smoothstep(0.85, 1.0, lvl));
    heat = lerp(heat, 1.0 + (heat - 1.0) * 0.5, 1.0 - smoothstep(0.2, 0.5, v.y));   // r21: side views get half the extra heat (x1.5 at x2)
    body *= lerp(1.0, heat, (0.05 + 0.95 * edge * edge * edge) * (1.0 - 0.8 * capFaceW) * _HeatBodyW);   // _HeatBodyW 0 = no extra peak heat   // r21: edges/bars only, base faces stay deep red   // r20: heat on the lit flute faces/lines more than the gaps
    // r22 (Ben: 'the dome turns into a light for 1-3 frames'): short peak-only gain on ALL dome emission (glints excluded),
    // shaped by the flutes (edges carry it, flats less) - not a flat layer
    float flash = 1.0 + _PeakFlash * smoothstep(0.9, 1.0, lvl) * (0.25 + 0.75 * edge);
    // r25 WHITE-HOT body on the Outer's own emission (lines path - the only path that reaches white on screen): peak-only
    // (lvl .9-1 = the 1-2 #89 peak frames), whole dome incl. the cap, physical red-wall colour (G/B 4.4/3.4 % of R) so a
    // large value clips to cream-white; groove lines darker (ribs stay faintly visible); falls off toward the silhouette
    // (grazing) so the edges stay red
    float whF = saturate(dot(Nshell, v)); float whS = (1.0 - 0.45 * edge) * (0.15 + 0.85 * whF);   // r25b: no fall term (it made a hot ring at the shoulder in top views); edges via facing
    lines += _WhiteHot * smoothstep(0.9, 1.0, lvl) * whS * FD_AbsY(float3(1.0, 0.05, 0.018)) * max(_LinesGain, 0.0);   // warm leak (bulb spectrum x red wall): clips cream, not pink
    // r24 peak sweep: white-hot ZONE around where the view ray passes the bulb - a band across 3-5 adjacent bars, peak only
    float hzA = saturate(dot(normalize(Position.xz + 1e-6), normalize(v.xz + 1e-6)));
    if (FD_SPH) hzA = saturate(dot(nO, v));   // facing the wall normal, not the horizontal azimuth
    lines += _HotZone * smoothstep(0.9, 1.0, lvl) * exp(-(dvF * dvF) / (0.0045 * 0.0045)) * pow(hzA, 14.0) * (0.35 + 0.65 * edge) * (1.0 - capFaceW) * FD_AbsY(float3(1.0, 0.8, 0.55)) * max(_LinesGain, 0.0);
    float3 gL = g * max(_LinesGain, 0.0) * (_DbgTerm > 2.5 ? 0.0 : 1.0);
    // r25 white-hot A/B: at the peak, give the transmitted light the PHYSICAL red-wall leak (.79/.035/.027 -> G/B = 4.4 %/3.4 %
    // of R) instead of the thick-wall model's ~0.5 %, so a large peak gain clips G/B too (cream-white) - no overlay
    float pk = _PeakPhys * smoothstep(0.9, 1.0, lvl);
    float3 leakPk = FD_Filter(float3(1.0, 0.044, 0.034));   // physical wall leak, normalised (red: G/B 4.4 / 3.4 %)
    body = lerp(body, max(body, FD_Max3(body) * leakPk), pk);
    float3 lL = lines - gL; lines = gL + lerp(lL, max(lL, FD_Max3(lL) * leakPk), pk);
    body *= flash; lines = gL + (lines - gL) * flash;
    Emission = _GlowPart < 0.5 ? body + lines : (_GlowPart < 1.5 ? body : lines);
    // r09 (Fable items 2+3): rough-dielectric TRANSMISSION lobe on the flank normals + a LINE filament (3 samples over the
    // 3.2 mm coil along x), physical level mapping E = FilamentNits * L^gamma * bb(T(L)) * tau. Each flute = two flanks tilted
    // +-_FlankTilt from the inward radial; flanks inside the filament's GGX transmission cone glow over their whole height
    // (bars), the neighbour flank stays dark (gaps), several adjacent flutes overlap into the broad cream core.
    if (_GlowPart > 3.5) {
        float lt = saturate((lvl - _LevelToe) / max(1.0 - _LevelToe, 1e-4));
        float lvlP = pow(lt, max(_LevelGamma, 0.05)) * smoothstep(0.0, max(_LevelFade, 0.01), lt);   // r09b: gamma fitted at L>=0.4 (Lux refs); below 0.3 fade to ~linear so the cooling tail ends by ~200 ms
        // r09b: real dome48 flute = flat face (radial normal, ~75 % of the period) + a narrow V-groove whose two flanks are
        // steep; flats transmit the filament straight through (centre core), groove flanks tilt the lobe off-axis (bars)
        float par2 = -sign(eP + 1e-6);
        float inGrooveS = 1.0 - smoothstep(0.10, 0.14, abs(eP));
        par2 *= inGrooveS;
        float3 radIn = -normalize(float3(Position.x, 0, Position.z) + float3(1e-6, 0, 0));
        float3 tgB = float3(-radIn.z, 0, radIn.x);
        float tt = tan(radians(_FlankTilt));
        float3 Nf  = normalize(lerp(normalize(radIn + tgB * par2 * tt), normalize(float3(0, -1, 0) + tgB * par2 * tt), capW));
        float3 NfM = normalize(lerp(normalize(radIn - tgB * par2 * tt), normalize(float3(0, -1, 0) - tgB * par2 * tt), capW));
        if (FD_SPH) { radIn = -nS; Nf = normalize(radIn + tgB * par2 * tt); NfM = normalize(radIn - tgB * par2 * tt); }
        float3 wo = -VrIn;                                   // toward the viewer, inside the plastic
        wo = normalize(float3(wo.x, wo.y * _LobeV, wo.z));   // r10: elevation weight of the view in the lobe (1 physical)
        float a2 = max(_FluteAlpha * _FluteAlpha, 1e-4);
        float3 barA = 0, barB = 0, scat = 0;
        float aS = max(_ScatterAlpha, 0.05), aS2 = aS * aS;
        [unroll] for (int k = -2; k <= 2; k++) {
            float3 Fk = F + float3(k * 0.0008, _LobeLift * saturate(v.y), 0);   // r09b: 5 samples over the coil; r11: lobe lift with view elevation
            float3 toL = Fk - Position; float d2 = max(dot(toL, toL), 1e-5); float3 L = toL * rsqrt(d2);
            float3 hT = normalize(1.49 * (-wo) - L);          // -(eta_i wi + eta_o wo), wi = L (air), wo (plastic, eta 1.49)
            float fall2 = (0.012 * 0.012) / d2;
            float cLh = abs(dot(L, hT)); float FT = 1.0 - (0.04 + 0.96 * pow(saturate(1.0 - cLh), 5.0));
            // r09: anisotropic GGX - across the flute alpha = _FluteAlpha, along it (the flank's vertical/radial-in-cap axis)
            // _FluteAlphaV: the flute is an extruded V, roughness + inter-flank scattering smear the filament image along it
            float ax = max(_FluteAlpha, 0.01), ay = max(_FluteAlphaV, 0.01);
            float3 hA = dot(hT, Nf) < 0.0 ? -hT : hT;
            float3 TvA = normalize(lerp(float3(0, 1, 0), -radIn, capW));
            if (FD_SPH) TvA = TmS;   // along the meridian flute
            float3 BhA = normalize(cross(Nf, TvA));
            float hxA = dot(hA, BhA) / ax, hyA = dot(hA, TvA) / ay, hnA = dot(hA, Nf);
            float DA = 1.0 / (3.14159 * ax * ay * FD_SQ(hxA * hxA + hyA * hyA + hnA * hnA)) * (hnA > 0.0 ? 1.0 : 0.0);
            barA += DA * FT * fall2 * saturate(dot(L, Nf) * 4.0) * saturate(-dot(wo, Nf) * 4.0 + 0.2);
            float3 hB = dot(hT, NfM) < 0.0 ? -hT : hT;
            float3 BhB = normalize(cross(NfM, TvA));
            float hxB = dot(hB, BhB) / ax, hyB = dot(hB, TvA) / ay, hnB = dot(hB, NfM);
            float DB = 1.0 / (3.14159 * ax * ay * FD_SQ(hxB * hxB + hyB * hyB + hnB * hnB)) * (hnB > 0.0 ? 1.0 : 0.0);
            barB += DB * FT * fall2 * saturate(dot(L, NfM) * 4.0) * saturate(-dot(wo, NfM) * 4.0 + 0.2);
            // r11: rough-flute scatter (broad isotropic GGX on the radial normal) - fills the bulb-height band over 5-6 flutes
            float3 hS = dot(hT, radIn) < 0.0 ? -hT : hT; float nhS = saturate(dot(radIn, hS));
            float DS = aS2 / (3.14159 * FD_SQ(nhS * nhS * (aS2 - 1.0) + 1.0));
            scat += DS * FT * fall2 * saturate(dot(L, radIn) * 4.0);
        }
        float3 tau = exp(-sigma * thN);
        // ONE steep peak term (orchestrator: Ben's round-9 note): the transfer is scaled by 1 + _PeakNits * L^_PeakPow, so only
        // the true peak blows the transmitted filament image out white
        float peakGain = 1.0 + _PeakNits * pow(lt, max(_PeakPow, 1.0));
        // r09b (Ben: no milky veil): the flash "white-out" is the same transmitted light overexposed - the veil is an extra gain
        // on the transfer (spectrum bb x red wall transmission), so ACES whitens only the core/bars/rays; walls stay red.
        // Cap: the flat faces' straight-through lobe flooded the top view -> on the cap only the ray (groove) flanks transmit.
        float wvT = (_VeilLevel >= 0.0) ? saturate(_VeilLevel) : 0.0;
        float gainT = peakGain + _VeilNits * wvT * wvT;
        float capFlat = lerp(1.0, inGrooveS, capFaceW);   // r11: only the cap top proper (not the shoulder) loses its flat-face lobe
        float rCap = length(Position.xz) / 0.0145;
        if (FD_SPH) rCap = length(Position.xz) / max(_CapR, 1e-4);
        float spokeFade = lerp(1.0, 1.0 - 0.8 * smoothstep(_SpokeFade, _SpokeFade + 0.25, rCap), capFaceW * (1.0 - smoothstep(0.8, 0.95, rCap)));   // not on the shoulder   // r11: weaker cap spokes past r ~0.5
        float3 scatT = _ScatterNits * lvlP * gainT * bb * tau * scat / 5.0 * (1.0 - capW);
        float3 bars = spokeFade * _FilamentNits * lvlP * gainT * lerp(1.0, _CapRays, capW) * capFlat * bb * tau * (barA + _FlankFill * barB) / 5.0;
        float rimT = pow(saturate(1.0 - abs(dot(Nshell, v))), 4.0);
        float3 rim = _RimRing * lvlP * gainT * bb * tau * capW * exp(-FD_SQ((rCap - _RimRadius) / 0.06));   // r11: ring at the Lux radius on the cap
        float phiF = atan2(Position.z, Position.x);
        float3 xb = _XBeam * lvlP * gainT * bb * tau * capW * pow(abs(sin(2.0 * phiF)), 48.0) * saturate(v.y) * saturate(v.y);
        // cap centre spot: the filament seen straight down through the cap (red-transmission spectrum, not cream)
        float3 spot = _CapCenterNits * lvlP * gainT * bb * tau * capW * exp(-dot(Position.xz, Position.xz) / (0.0025 * 0.0025));
        Emission = lvlP * _GlowNits * glow + bars + scatT + rim + xb + spot + g;
        // r09b: OFF facet darkness (what the r07 Inner showed): per-facet hash 0.75-1.25 x flank-vs-flat shading, groove
        // roots darker, evaluated at the parallax point P_in -> the base colour of the opaque shell
        float fcl = abs(eP) < 0.125 ? (eP < 0.0 ? 0.0 : 1.0) : 2.0;
        float fh = frac(sin((fluteIdx * 3.0 + fcl + capW * 200.0) * 57.31 + 3.7) * 43758.5453);
        float grooveDark = lerp(0.35, 1.0, smoothstep(0.02, 0.12, abs(eP)));
        float flankSide = fcl < 0.5 ? 0.7 : (fcl < 1.5 ? 1.25 : 1.0);
        float shade = lerp(1.0, (0.75 + 0.5 * fh) * grooveDark * flankSide, saturate(_FacetShade));
        BaseColor = _ShellBase.r * FD_Filter(_ShellBase.rgb / max(_ShellBase.r, 1e-4)) * shade;   // red-tuned shell colour, remapped
    }
    NormalTS = float3(0, 0, 1);
    Alpha = 1.0;
    if (_GlowPart > 1.5 && _GlowPart < 2.5) {
        // r19 (judge + blue-gain diag: the cap ring + shoulder seam at 45/orb1 = this alpha showing the Outer's specular): top views only
        float shA = saturate(_ShoulderAlpha * shoulderM * saturate(lvl * 4.0) * smoothstep(0.86, 0.97, v.y));
        Alpha = saturate(_OuterAlpha + shA);
        // r25: HDRP premultiplies transparent emission by alpha (_LinesGain = 1/_OuterAlpha compensates the base .03); where the
        // shoulder alpha rises, rescale so the line emission is not multiplied up (it drew a hot ring at the cap edge, top view)
        Emission *= max(_OuterAlpha, 1e-3) / max(Alpha, 1e-3);
        BaseColor = lerp(float3(1.0, 1.0, 1.0), 0.05 * FD_Filter(float3(1.0, 0.04, 0.02)), saturate(shA * 20.0));   // r23: darker under Custom
    }
    // 2026-10-16 P7 (Clear look-dev, "plastic, not blown glass") _SkinMilk: the Outer skin reads milky white where the plastic is thick or
    // seen edge-on. x gain (0 = off, the default: nothing below runs), y base band height (m: the thick foot of the wall at the base plane,
    // fading up), z silhouette gain (grazing view, (1 - |N.v|)^3), w mounting-tab gain (the full dome's tabs are part of this mesh: the
    // region rho > _SkinFoot.x and y < _SkinFoot.y, side faces x (1 + _SkinFoot.z) so the edges catch the light). The white is
    // _SkinMilkColor x the room irradiance (FD_RoomIrr: follows the room); alpha rises to the milk weight, emission rescaled as for the
    // shoulder alpha (HDRP premultiplies transparent emission by alpha). Outer only (_GlowPart 2).
    // P8 (2026-10-16) _SkinFoot.w: far-tab hide strength (0 = off, the default). The full dome's tabs are part of this mesh, drawn after
    // the Inner/Glow (transparent queue, no depth writes), so the FAR tab's front-facing top and end faces lie on top of the dome body
    // as a sharp pale shape. Where the ray from a tab fragment (tab region, footM) toward the camera passes through the dome's barrel
    // (mode 0 literal: outer radius 15.43 mm up to 29.0 mm, the shipped Outer mesh), its milk, line emission and alpha fade by w. Mode 0
    // only (the half dome's tabs are their own renderer: FlasherDomeLens flat part, _LensParallax z).
    [branch] if (_SkinMilk.x > 0.0 && _GlowPart > 1.5 && _GlowPart < 2.5) {
        float cvS = saturate(abs(dot(Nshell, v)));
        float wB = 1.0 - smoothstep(0.0, max(_SkinMilk.y, 1e-5), yRaw);
        float wS = _SkinMilk.z * FD_SQ(1.0 - cvS) * (1.0 - cvS);
        float footM = smoothstep(_SkinFoot.x, _SkinFoot.x + 0.0004, rRaw) * (1.0 - smoothstep(_SkinFoot.y, _SkinFoot.y + 0.0004, yRaw));
        float wF = _SkinMilk.w * footM * (1.0 + _SkinFoot.z * (1.0 - abs(Nshell.y)));
        float wM = saturate(_SkinMilk.x * max(max(wB, wS), wF));
        [branch] if (_SkinFoot.w > 0.0 && !FD_SPH && footM > 0.0) {
            float hideF = 1.0 - saturate(_SkinFoot.w) * footM * FD_BehindBarrel(Position, v, 0.01543, 0.0290, 0.0004);
            wM *= hideF; Emission *= hideF; Alpha *= hideF;
        }
        float aM = max(Alpha, wM);
        Emission = (Emission * Alpha + wM * _SkinMilkColor.rgb * FD_RoomIrr()) / max(aM, 1e-3);
        BaseColor *= Alpha / max(aM, 1e-3);   // keep the lit (translucent) diffuse at its old weight: the milk is all emission (else lilac)
        Alpha = aM;
    }
    // 2026-10-15 (Clear look-dev) _AmbientGlow: clear plastic lights up with the room - light enters the wall, scatters in the flute
    // structure and leaves toward the viewer. Emission = _AmbientGlow x room irradiance at the dome (FD_RoomIrr: the sky ambient
    // probe's all-directions average + the directional lights, so it follows the room light and the HDRI exposure)
    // x the plastic's own transmission through the wall (from _DomeColor: a red dome would glow red) x a wall mask: brighter where the
    // wall is thicker (flute flats vs groove roots) and at grazing view (longer path in the plastic). _AmbientGlow is an albedo-like
    // gain (1 = a white diffuser). Glow layer only; 0 (default) = off, every preset unchanged.
    float3 ambE = 0;
    [branch] if (_AmbientGlow > 0.0 && _GlowPart > 0.5 && _GlowPart < 1.5) {
        float3 tauA = exp(-FD_Sigma() * thN);
        // _AmbientShape (2026-10-15 P4, OFF depth): x flute-edge brightening (mask phase near the groove root), y facet-centre murk,
        // z rim/grazing gain, w thickness contrast. Default (0, 0, 0.8, 0.45) = the first _AmbientGlow formula.
        float wallA = lerp(1.0 - _AmbientShape.w, 1.0, saturate((thN - 0.0013) / 0.0014));
        float rimA = 1.0 + _AmbientShape.z * FD_SQ(1.0 - saturate(abs(dot(Nshell, v))));
        float edgeA = (1.0 + _AmbientShape.x * (1.0 - smoothstep(0.02, 0.18, m.b))) * (1.0 - _AmbientShape.y * smoothstep(0.22, 0.5, m.b));
        ambE = _AmbientGlow * FD_RoomIrr() * tauA * wallA * rimA * edgeA;
    }
    Emission += ambE;   // thN / Nshell: the Glow path's own mask thickness and wall normal (unchanged in _GlowPart 1)
}
#endif
