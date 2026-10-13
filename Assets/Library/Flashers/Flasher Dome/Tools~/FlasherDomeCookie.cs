using UnityEditor;
using UnityEngine;

// Flasher Dome burst-light cookie generator (Unity Editor script), flute count as a parameter.
// Usage: this file lives in Tools~ so Unity does not compile it in the package. Copy it into any Editor folder of your project
// (e.g. Assets/Editor/), then call from an Editor script or the C# console:
//   FlasherDomeCookie.MakeBoth(24, "Assets/MyDome/Flasher Dome, Red 24");   // writes "... - Cookie Open.asset" and "... - Cookie Saucer.asset"
// The cookie is the luminaire's own emission profile (IES-like), in the Source light's local frame (+Y = dome axis):
// one radial beam per flute (cos^sharp around the flute azimuth, floor between beams), a soft wash through the cap, and
// optionally the saucer-lip cut-off cutDeg below the filament horizon with a softDeg soft edge.
// Library values: Open = (floor .76, sharp 10, altDim 1, no cut), Saucer = same + cut 16.7 / soft 8. 256 px cubemap.
// Single cookie: FlasherDomeCookie.Make(24, "Assets/MyDome/Open.asset");
public static class FlasherDomeCookie
{
	public static Cubemap Make(int flutes, string path, float cutDeg = 0f, float softDeg = 8f, float floor = 0.76f, float sharp = 10f, float altDim = 1f, int size = 256)
	{
		var cm = new Cubemap(size, TextureFormat.RGBA32, true);
		var faces = new[] { CubemapFace.PositiveX, CubemapFace.NegativeX, CubemapFace.PositiveY, CubemapFace.NegativeY, CubemapFace.PositiveZ, CubemapFace.NegativeZ };
		var px = new Color[size * size];
		foreach (var f in faces) {
			for (var y = 0; y < size; y++) for (var x = 0; x < size; x++) {
				float u = (x + 0.5f) / size * 2f - 1f, v = (y + 0.5f) / size * 2f - 1f;
				Vector3 d;
				switch (f) {
					case CubemapFace.PositiveX: d = new Vector3(1, -v, -u); break;
					case CubemapFace.NegativeX: d = new Vector3(-1, -v, u); break;
					case CubemapFace.PositiveY: d = new Vector3(u, 1, v); break;
					case CubemapFace.NegativeY: d = new Vector3(u, -1, -v); break;
					case CubemapFace.PositiveZ: d = new Vector3(u, -v, 1); break;
					default: d = new Vector3(-u, -v, -1); break;
				}
				d.Normalize();
				var phi = Mathf.Atan2(d.z, d.x); if (phi < 0) phi += 2f * Mathf.PI;
				var k = Mathf.FloorToInt(phi / (2f * Mathf.PI / flutes));
				var beam = Mathf.Pow(0.5f + 0.5f * Mathf.Cos(flutes * phi), sharp) * ((k & 1) == 0 ? 1f : altDim);
				var side = Mathf.Lerp(floor, 1f, beam);
				var w = Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(0.35f, 0.75f, d.y));
				var val = Mathf.Lerp(side, 0.55f, w);
				if (cutDeg > 0f) { var el = Mathf.Asin(Mathf.Clamp(d.y, -1f, 1f)) * Mathf.Rad2Deg; val *= Mathf.SmoothStep(0f, 1f, Mathf.InverseLerp(-cutDeg - softDeg * 0.5f, -cutDeg + softDeg * 0.5f, el)); }
				px[y * size + x] = new Color(val, val, val, 1f);
			}
			cm.SetPixels(px, f);
		}
		cm.Apply(true);
		var old = AssetDatabase.LoadAssetAtPath<Cubemap>(path);
		if (old != null) { EditorUtility.CopySerialized(cm, old); EditorUtility.SetDirty(old); AssetDatabase.SaveAssets(); Object.DestroyImmediate(cm); return old; }   // keeps the GUID
		AssetDatabase.CreateAsset(cm, path);
		return cm;
	}

	// both library cookies for a flute count: "<prefix> - Cookie Open.asset" + "<prefix> - Cookie Saucer.asset"
	public static void MakeBoth(int flutes, string prefix)
	{
		Make(flutes, prefix + " - Cookie Open.asset");
		Make(flutes, prefix + " - Cookie Saucer.asset", 16.7f, 8f);
	}
}
