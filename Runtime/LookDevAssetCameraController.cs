// Visual Pinball Engine
// Copyright (C) 2026 freezy and VPE Team
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.

using UnityEngine;

namespace VisualPinball.Unity.Assets
{
	/// <summary>
	/// Sits on the look dev camera and lets you load, save, rename and delete the asset
	/// library's thumbnail camera presets from the inspector.
	///
	/// The presets are transform presets, which the thumbnail generator applies to the camera.
	/// All the logic lives in the inspector, since presets are an editor-only feature.
	/// </summary>
	[DisallowMultipleComponent]
	[RequireComponent(typeof(Camera))]
	[AddComponentMenu("Pinball/LookDev/Asset Camera Controller")]
	public class LookDevAssetCameraController : MonoBehaviour
	{
		public const string DefaultPresetFolder = "Packages/org.visualpinball.engine.unity/VisualPinball.Unity/Assets/Presets/Asset Thumbcam";

		[Tooltip("Folder containing the thumbnail camera presets of the asset library.")]
		public string PresetFolder = DefaultPresetFolder;
	}
}
