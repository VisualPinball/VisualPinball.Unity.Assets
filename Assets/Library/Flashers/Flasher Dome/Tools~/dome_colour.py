"""Flasher Dome colour template - offline twin of FlasherDome.hlsl's colour model (FD_Sigma / FD_Remap / FD_Filter / FD_Abs).
Computes, for a plastic given as its linear transmittance T through the nominal 2.4 mm wall (or sigma in 1/m):
  the material's _DomeColor (sRGB, what the colour picker shows), the burst light colour, and the Inner/Outer HDRP colours
  (remapped from the red-tuned values), so a new preset needs no hand tuning.
  python3 dome_colour.py                      -> table for the shipped presets
  python3 dome_colour.py 30 150 1400          -> one plastic from absorption sigma R G B (1/m)
  python3 dome_colour.py --t 0.79 0.035 0.027 -> one plastic from its linear transmittance R G B through the 2.4 mm wall
                                                 (sigma = -ln(T) / 0.0024 m); convert an sRGB picker colour to linear first
Prints _DomeColor (sRGB), the Source light colour, and the Inner/Outer HDRP colours (sRGB values for the material colour fields).
"""
import sys, math
import numpy as np

WALL = 0.0024
RED_T = np.array([0.7866279, 0.03473526, 0.02732372])
BB2900 = np.array([1.0, 0.68167863, 0.40318515])
PRESETS = {  # sigma_a (1/m) over the clear volume, as rendered in LuxCore
    "Red": [100, 1400, 1500], "Orange": [50, 400, 1500], "Yellow": [30, 150, 1400], "Olive": [250, 300, 1500],
    "Green": [1200, 120, 900], "Blue": [1300, 500, 60], "Clear": [3, 3, 4], "Purple": [300, 1800, 200],
}


def s2lin(c): c = np.asarray(c, float); return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
def lin2s(c): c = np.asarray(c, float); return np.where(c <= 0.0031308, 12.92 * c, 1.055 * np.power(np.maximum(c, 0), 1 / 2.4) - 0.055)
def norm(c): c = np.asarray(c, float); return c / max(c.max(), 1e-6)


def remap(C, q, qref):
    xg, xb, yg, yb = math.log(qref[1]), math.log(qref[2]), math.log(C[1]), math.log(C[2])
    x = np.log(np.maximum(q, 1e-6))
    return np.exp(np.where(x >= xg, yg * x / xg, yg + (x - xg) * ((yb - yg) / (xb - xg))))


def filt(C, T): return remap(np.asarray(C, float), norm(T), norm(RED_T))
def absc(C, T): return remap(np.asarray(C, float), norm(BB2900 * T), norm(BB2900 * RED_T))


def lin_colour_remap(lin, T, eps=1e-4):
    """remap a red-tuned linear colour (any scale, R = largest) as a filter"""
    lin = np.maximum(np.asarray(lin, float), eps * lin[0])
    return lin[0] * filt(lin / lin[0], T)


def preset(T):
    T = np.asarray(T, float)
    srgb = lambda v: "(%.4f, %.4f, %.4f)" % tuple(lin2s(v))
    out = {}
    out["_DomeColor (sRGB in the .mat)"] = srgb(T)
    out["Source light colour"] = "(%.4f, %.4f, %.4f)" % tuple(absc([1.0, 0.0127, 0.0028], T))   # light colours are linear in HDRP
    out["Outer _TransmittanceColor"] = srgb(lin_colour_remap(s2lin([0.737, 0, 0]), T))
    out["Inner _BaseColor/_Color"] = srgb(lin_colour_remap(s2lin([0.46415097, 0.0127414, 0]), T))
    out["Inner _TransmittanceColor"] = srgb(lin_colour_remap(s2lin([0.9716981, 0, 0]), T))
    out["Half Dome Tabs emissive-map tint (sRGB; map = glow mask x this; keep _EmissiveColor white x150)"] = srgb(lin_colour_remap(s2lin([1.0, 0.05, 0.02]), T))
    out["bar colour (1,.62,.10)"] = "(%.3f, %.3f, %.3f)" % tuple(absc([1, .62, .10], T))
    out["halo filter (1,.35,.06)"] = "(%.3f, %.3f, %.3f)" % tuple(filt([1, .35, .06], T))
    return out


if __name__ == "__main__":
    if len(sys.argv) == 5 and sys.argv[1] == "--t":
        P = {"custom": [float(x) for x in -np.log(np.maximum([float(a) for a in sys.argv[2:]], 1e-6)) / WALL]}
    elif len(sys.argv) == 4:
        P = {"custom": [float(a) for a in sys.argv[1:]]}
    else:
        P = PRESETS
    for k, s in P.items():
        T = np.exp(-np.array(s, float) * WALL)
        print(f"{k}: sigma {s} /m -> T(2.4 mm) linear ({T[0]:.7f}, {T[1]:.7f}, {T[2]:.7f})")
        for a, b in preset(T).items():
            print(f"   {a:32s} {b}")
