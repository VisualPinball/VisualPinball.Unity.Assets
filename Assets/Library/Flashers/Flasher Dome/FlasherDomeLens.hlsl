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
#ifndef VPE_FLASHER_DOME_LENS
#define VPE_FLASHER_DOME_LENS

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
// live environment along d (object space) from P: table (colour pyramid at the y = 0 plane hit, when on screen) or sky
float3 FDL_Env(float3 P, float3 d, float lod)
{
    float3 c = 0;
#if defined(SHADERPASS) && (SHADERPASS == SHADERPASS_FORWARD)
    float3 dW = TransformObjectToWorldDir(d, true);
    c = SampleSkyTexture(dW, lod, 0).rgb;
    if (d.y < -1e-3) {
        float3 H = P + d * (max(P.y, 0.0) / -d.y);
        // _LensFloor: a hit inside the dome's own footprint (the mounting hole / socket in a real table) is mirrored out across the
        // base circle onto the table just outside it (0 = the true hit, 1 = mirrored: the dome's floor reads like the table around it)
        float rF = _ProfileMode > 0.5 ? _InnerR : 0.01395, rH = length(H.xz);
        // (mirrored to 1.25 rF .. : clear of the hole rim and the dome's own contact shadow, which read as dark teeth)
        if (rH < 1.25 * rF && _LensFloor > 0.0) H.xz *= lerp(1.0, (2.5 * rF - rH) / max(rH, 1e-5), _LensFloor);
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
float3 FDL_Lens(float3 Position, float3 View, out float nearW)
{
    float3 v = normalize(View + float3(0, 1e-6, 0));
    float thetaP = atan2(-Position.z, -Position.x) - _FluteOffset; if (thetaP < 0.0) thetaP += 6.2831853;
    float pitch = 6.2831853 / max(_FluteCount, 1.0);
    float u = frac(thetaP / pitch) - 0.5;                        // across the rib: 0 centre, +-0.5 at the groove roots
    float rxz = length(Position.xz);
    float3 rad = normalize(float3(Position.x, 0, Position.z) + float3(1e-6, 0, 0));
    float3 tg = float3(-rad.z, 0, rad.x);                         // +theta
    float3 nOut, nB;
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
    float aa = saturate(1.6 - 1.2 * pp);                          // flutes under ~1.3 px: fade the lens toward the smooth wall
    float sa = sign(u) * pow(saturate(abs(2.0 * u)), max(_LensShape.y, 0.05)) * sin(radians(_LensShape.x)) * smoothstep(0.0015, 0.004, rxz) * aa;
    float3 nIn = normalize(-nB * sqrt(1.0 - sa * sa) + tg * sa);
    nearW = smoothstep(-0.02, 0.06, dot(v, nOut));               // near wall (seen from outside); the far wall is looked through
    float rWall = _ProfileMode > 0.5 ? _InnerR * 1.12 : 0.0156;   // the inner mesh's base flange / rim outside the wall: no lens (a flat disc)
    nearW *= 1.0 - smoothstep(rWall, rWall + 0.0006, rxz);
    float3 d0 = -v;
    float F1; float3 d1 = FDL_Refract(d0, nOut, 1.0 / 1.49, F1);  // in at the smooth skin
    float F2; float3 d2 = FDL_Refract(d1, -nIn, 1.49, F2);        // out through the flute (F2 = 1 at TIR)
    float3 r2 = reflect(d1, nIn);                                 // reflected at the flute, back toward the skin
    float F3; float3 ro = FDL_Refract(r2, -nOut, 1.49, F3);       // out through the skin (F3 = 1: trapped in the wall -> dark)
    float lod = _FluteBlur;
    float3 eT = F2 < 0.999 ? FDL_Env(Position, d2, lod) : 0;
    float3 eR = F3 < 0.999 ? FDL_Env(Position, ro, lod) : 0;
    // trapped (TIR at the flute and again at the skin): guided along the wall to the base -> the table right under this wall point
    float3 eB = (_LensTrap > 0.0 && F2 * F3 > 0.001) ? FDL_Env(Position, float3(0, -1, 0), lod + 1.0) : 0;
    float3 E = (1.0 - F1) * ((1.0 - F2) * 0.92 * eT + _LensShape.w * F2 * (1.0 - F3) * eR + _LensTrap * F2 * F3 * eB);   // .92: far wall
    // weak isotropic murk: the sky ambient probe (L0) diffused by the flute roughness
    float3 amb = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) + float3(unity_SHBr.z, unity_SHBg.z, unity_SHBb.z) / 3.0;
    return E + _FluteScatter * max(amb, 0.0);
}

void FlasherDomeLens_float(float3 Position, float3 View, out float3 BaseColor, out float Smoothness, out float Alpha, out float3 Emission)
{
    float w = smoothstep(_FrostLitRamp.x, max(_FrostLitRamp.y, _FrostLitRamp.x + 1e-4), saturate(_InsertLampLevel));
    BaseColor = lerp(_FrostColor.rgb, _FrostLitColor.rgb, w);
    Alpha = lerp(_FrostColor.a, _FrostLitColor.a, w);
    Smoothness = lerp(_FrostSmooth, _FrostLitSmooth, w);
    Emission = 0;
    [branch] if (_LensEnv > 0.0) {
        float nearW;
        Emission = _LensEnv * lerp(1.0, _LensLitK, w) * FDL_Lens(Position, View, nearW);   // HDRP scales transparent emission by Alpha
        Alpha *= nearW;
    }
}
#endif
