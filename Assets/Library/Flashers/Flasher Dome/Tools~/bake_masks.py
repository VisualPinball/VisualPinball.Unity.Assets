"""Flasher Dome mask baker: geometry-derived masks for the live dome materials (no lighting baked). Blender, CPU, ~1 min.
Usage:
  blender -b --factory-startup --python bake_masks.py -- OUTDIR [RES] --blend dome.blend --object DomeObject --flutes N [--cap-z MM] [--name PREFIX]
    OUTDIR  output folder            RES  texture size (default 1024)
    --blend / --object  .blend file and the dome mesh object in it (both required)
    --flutes N  flute count (default 36)     --cap-z MM  height above which downward-facing inner faces count as the cap underside (default 20)
    --name PREFIX  output file prefix (default "dome"); writes <PREFIX>_masks.exr, <PREFIX>_parity.png, <PREFIX>_coverage.png and previews
  Needs Blender's bundled Python modules (bpy, OpenImageIO, numpy, PIL).
The object must carry the inner-surface atlas as UV layer "UVMap" (the Glow/Inner mesh's UV1 in Unity), dome axis +Z (Blender),
groove roots at theta = atan2(y, x) = 0 mod pitch, base at z = 0, units metres.
Per texel of every dome face:
  thick_n   wall thickness along the inward normal (mm)            -> source for an Inner thickness map; see README step 3 (not a drop-in _ThicknessMap)
  thick_h   mean thickness over 16 cosine-weighted inward rays    (softer, closer to what transmission 'sees')
  phase     position inside the flute period (0 = groove root, 0.5 = flat centre), from theta
  flank     tangential tilt of the INNER surface under this texel (-1 left flank, 0 flat, +1 right flank) -> 0..1
  parity    flute index parity (0/1) = the zebra / alternate-spoke mask
Writes <name>_masks.exr (R thick_n mm, G thick_h mm, B phase, A flank) + <name>_parity.png + previews.
"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

A = sys.argv[sys.argv.index("--") + 1:]
def opt(k, d):
    if k in A:
        i = A.index(k); v = A[i + 1]; del A[i:i + 2]; return v
    return d
N_FLUTE = int(opt("--flutes", "36"))
BLEND = opt("--blend", None)
OBJ = opt("--object", None)
CAPZ = float(opt("--cap-z", "20"))      # mm: inner faces facing down above this height are the cap underside (default 20)
NAME = opt("--name", "dome")          # output prefix
if not BLEND or not OBJ or not A:
    sys.exit("usage: ... -- OUTDIR [RES] --blend dome.blend --object NAME [--flutes N] [--cap-z MM] [--name PREFIX]")
OUT = A[0]; RES = int(A[1]) if len(A) > 1 else 1024
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=BLEND)
ob = bpy.data.objects[OBJ]
me = ob.data
MM = 0.001
PITCH = 2 * math.pi / N_FLUTE
print("bake_masks:", BLEND, OBJ, N_FLUTE, "flutes", RES, "px ->", OUT)
bm = bmesh.new(); bm.from_mesh(me); bmesh.ops.triangulate(bm, faces=bm.faces[:])
bm.normal_update()
uvl = bm.loops.layers.uv["UVMap"]
bvh = BVHTree.FromBMesh(bm)
TMAX = 6.0  # mm, rays that escape (open bottom, rim) are capped here

rng = np.random.default_rng(1)
# 16 cosine-weighted directions around +z (rotated per texel)
u1, u2 = rng.random(16), rng.random(16)
r = np.sqrt(u1); ph = 2 * np.pi * u2
HEMI = [Vector((float(r[i] * np.cos(ph[i])), float(r[i] * np.sin(ph[i])), float(np.sqrt(max(0.0, 1 - u1[i]))))) for i in range(16)]


def thickness(p, d):
    hit = bvh.ray_cast(p + d * 2e-6, d, TMAX * MM)
    if hit[0] is None:
        return TMAX
    return (hit[3] + 2e-6) / MM


img = np.zeros((RES, RES, 4), np.float32)
par = np.zeros((RES, RES), np.uint8)
cov = np.zeros((RES, RES), np.uint8)
for f in bm.faces:
    ls = f.loops
    uv = np.array([[l[uvl].uv.x, l[uvl].uv.y] for l in ls]) * RES
    P3 = [l.vert.co.copy() for l in ls]
    N3 = [f.normal.copy() for _ in ls]  # flat face normal: the facet orientation IS the signal (flanks vs flats)
    x0, y0 = np.floor(uv.min(0)).astype(int); x1, y1 = np.ceil(uv.max(0)).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, RES - 1), min(y1, RES - 1)
    (ax, ay), (bx, by), (cx, cy) = uv
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-12:
        continue
    n = f.normal
    inward = -n
    # tangent frame for the hemisphere
    t = inward.orthogonal().normalized(); b = inward.cross(t)
    c = f.calc_center_median()
    th = math.atan2(c.y, c.x) % (2 * math.pi)
    k = int(th // PITCH); phase = (th % PITCH) / PITCH
    radial = Vector((c.x, c.y, 0)); rr = radial.length
    tang = Vector((-c.y, c.x, 0)).normalized() if rr > 1e-7 else Vector((0, 0, 0))
    inner = rr > 1e-7 and (n.dot(radial / rr) < -0.3 or (n.z < -0.5 and c.z > CAPZ * MM))
    flank = n.dot(tang) if inner else 0.0  # inner-surface facet tilt; outer texels get it from the facing inner facet below
    for yy in range(y0, y1 + 1):
        for xx in range(x0, x1 + 1):
            px, py = xx + 0.5, yy + 0.5
            w0 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / den
            w1 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / den
            w2 = 1 - w0 - w1
            if min(w0, w1, w2) < -0.02:
                continue
            p = P3[0] * w0 + P3[1] * w1 + P3[2] * w2
            tn = thickness(p, inward)
            th_h = 0.0
            for h in HEMI:
                d = (t * h.x + b * h.y + inward * h.z).normalized()
                th_h += thickness(p, d)
            th_h /= len(HEMI)
            fl = flank
            if not inner:  # outer texel: read the flank of the inner facet hit along the inward normal
                hit = bvh.ray_cast(p + inward * 2e-6, inward, TMAX * MM)
                if hit[0] is not None:
                    hn = hit[1]
                    hc = hit[0]; hr = Vector((hc.x, hc.y, 0))
                    if hr.length > 1e-7:
                        fl = hn.dot(Vector((-hc.y, hc.x, 0)).normalized())
                    hth = math.atan2(hc.y, hc.x) % (2 * math.pi)
                    k = int(hth // PITCH); phase = (hth % PITCH) / PITCH
            img[yy, xx] = (tn, th_h, phase, 0.5 + 0.5 * max(-1.0, min(1.0, fl)))
            par[yy, xx] = 255 if k % 2 else 0
            cov[yy, xx] = 255

import OpenImageIO as oiio
spec = oiio.ImageSpec(RES, RES, 4, oiio.FLOAT)
o = oiio.ImageOutput.create(os.path.join(OUT, NAME + "_masks.exr")); o.open(os.path.join(OUT, NAME + "_masks.exr"), spec)
o.write_image(img[::-1].copy()); o.close()
from PIL import Image
Image.fromarray(par[::-1]).save(os.path.join(OUT, NAME + "_parity.png"))
Image.fromarray(cov[::-1]).save(os.path.join(OUT, NAME + "_coverage.png"))
# previews (8-bit): thickness normal / hemi as grey 0..TMAX, phase, flank
for i, (nm, sc) in enumerate([("thick_n", TMAX), ("thick_h", TMAX), ("phase", 1.0), ("flank", 1.0)]):
    a = np.clip(img[..., i] / sc, 0, 1)
    Image.fromarray((a[::-1] * 255).astype(np.uint8)).save(os.path.join(OUT, NAME + "_%s.png" % nm))
m = cov > 0
print("THICK_N mm: min %.2f p5 %.2f p50 %.2f p95 %.2f" % tuple([img[..., 0][m].min()] + list(np.percentile(img[..., 0][m], [5, 50, 95]))))
print("THICK_H mm: min %.2f p50 %.2f p95 %.2f" % tuple([img[..., 1][m].min()] + list(np.percentile(img[..., 1][m], [50, 95]))))
print("coverage %.1f%%" % (100 * m.mean()))
