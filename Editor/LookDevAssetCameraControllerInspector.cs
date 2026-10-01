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

using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Presets;
using UnityEngine;
using PackageInfo = UnityEditor.PackageManager.PackageInfo;
using PackageSource = UnityEditor.PackageManager.PackageSource;

namespace VisualPinball.Unity.Assets.Editor
{
	[CustomEditor(typeof(LookDevAssetCameraController))]
	public class LookDevAssetCameraControllerInspector : UnityEditor.Editor
	{
		private const string RenameControlName = "LookDevCameraPresetRename";

		private readonly List<Preset> _presets = new();
		private string _newName = string.Empty;
		private Preset _renaming;
		private string _renameName;
		private bool _focusRename;
		private string _loadedFolder;

		private LookDevAssetCameraController Controller => (LookDevAssetCameraController)target;
		private string Folder => Controller.PresetFolder?.Trim().TrimEnd('/');

		private void OnEnable()
		{
			EditorApplication.projectChanged += Reload;
			Reload();
		}

		private void OnDisable()
		{
			EditorApplication.projectChanged -= Reload;
		}

		public override void OnInspectorGUI()
		{
			serializedObject.Update();
			EditorGUILayout.PropertyField(serializedObject.FindProperty(nameof(LookDevAssetCameraController.PresetFolder)));
			serializedObject.ApplyModifiedProperties();

			// compare instead of change check, so undo/redo of the folder reloads too.
			if (Folder != _loadedFolder) {
				Reload();
			}

			if (string.IsNullOrEmpty(Folder) || !AssetDatabase.IsValidFolder(Folder)) {
				EditorGUILayout.HelpBox("Preset folder not found.", MessageType.Error);
				return;
			}
			var isReadOnly = IsReadOnly(Folder);
			if (isReadOnly) {
				EditorGUILayout.HelpBox("This folder is in a read-only package. Presets can be loaded, but not changed.", MessageType.Info);
			}

			// preset list
			EditorGUILayout.Space();
			EditorGUILayout.LabelField("Presets", EditorStyles.boldLabel);
			if (_presets.Count == 0) {
				EditorGUILayout.HelpBox("No camera presets in this folder.", MessageType.None);
			}
			foreach (var preset in _presets.ToArray()) {
				if (preset != null) {
					DrawPreset(preset, isReadOnly);
				}
			}

			// save new
			EditorGUILayout.Space();
			EditorGUILayout.LabelField("Save Current View", EditorStyles.boldLabel);
			using (new EditorGUI.DisabledScope(isReadOnly)) {
				_newName = EditorGUILayout.TextField("Name", _newName);
				var isValid = IsValidName(_newName, null, out var error);
				using (new EditorGUI.DisabledScope(!isValid)) {
					if (GUILayout.Button("Save as New Preset")) {
						SavePreset(_newName.Trim());
						GUIUtility.ExitGUI();
					}
				}
				if (!string.IsNullOrEmpty(_newName) && error != null) {
					EditorGUILayout.HelpBox(error, MessageType.Warning);
				}
			}
		}

		private void DrawPreset(Preset preset, bool isReadOnly)
		{
			using var row = new EditorGUILayout.HorizontalScope();

			// rename mode
			if (_renaming == preset) {
				var evt = Event.current;
				if (evt.type == EventType.KeyDown && GUI.GetNameOfFocusedControl() == RenameControlName) {
					switch (evt.keyCode) {
						case KeyCode.Return or KeyCode.KeypadEnter:
							evt.Use();
							CommitRename(preset);
							GUIUtility.ExitGUI();
							break;
						case KeyCode.Escape:
							evt.Use();
							_renaming = null;
							return;
					}
				}
				GUI.SetNextControlName(RenameControlName);
				_renameName = EditorGUILayout.TextField(_renameName);
				if (_focusRename) {
					EditorGUI.FocusTextInControl(RenameControlName);
					_focusRename = false;
				}
				using (new EditorGUI.DisabledScope(!IsValidName(_renameName, preset, out _))) {
					if (GUILayout.Button("OK", EditorStyles.miniButtonLeft, GUILayout.Width(40))) {
						CommitRename(preset);
						GUIUtility.ExitGUI();
					}
				}
				if (GUILayout.Button("Cancel", EditorStyles.miniButtonRight, GUILayout.Width(55))) {
					_renaming = null;
				}
				return;
			}

			// normal mode
			var isCurrent = preset.DataEquals(Controller.transform);
			var label = new GUIContent((isCurrent ? "✓ " : "    ") + preset.name, $"Move the camera to \"{preset.name}\".");
			var style = new GUIStyle(GUI.skin.button) { alignment = TextAnchor.MiddleLeft, fontStyle = isCurrent ? FontStyle.Bold : FontStyle.Normal };
			if (GUILayout.Button(label, style)) {
				ApplyPreset(preset);
			}
			using (new EditorGUI.DisabledScope(isReadOnly)) {
				if (GUILayout.Button(new GUIContent("Rename", $"Rename \"{preset.name}\"."), EditorStyles.miniButtonLeft, GUILayout.Width(55), GUILayout.Height(EditorGUIUtility.singleLineHeight + 2))) {
					_renaming = preset;
					_renameName = preset.name;
					_focusRename = true;
				}
				if (GUILayout.Button(new GUIContent("Delete", $"Delete \"{preset.name}\"."), EditorStyles.miniButtonRight, GUILayout.Width(50), GUILayout.Height(EditorGUIUtility.singleLineHeight + 2))) {
					DeletePreset(preset);
					GUIUtility.ExitGUI();
				}
			}
		}

		#region Actions

		private void ApplyPreset(Preset preset)
		{
			Undo.RecordObject(Controller.transform, $"Apply camera preset \"{preset.name}\"");
			preset.ApplyTo(Controller.transform);
		}

		private void SavePreset(string presetName)
		{
			var path = $"{Folder}/{presetName}.preset";
			AssetDatabase.CreateAsset(new Preset(Controller.transform), path);
			_newName = string.Empty;
			Reload();
		}

		private void CommitRename(Preset preset)
		{
			var newName = _renameName?.Trim();
			_renaming = null;
			if (newName == preset.name || !IsValidName(newName, preset, out _)) {
				return;
			}
			var error = AssetDatabase.RenameAsset(AssetDatabase.GetAssetPath(preset), newName);
			if (!string.IsNullOrEmpty(error)) {
				EditorUtility.DisplayDialog("Rename Camera Preset", $"Could not rename \"{preset.name}\":\n\n{error}", "OK");
			}
			Reload();
		}

		private void DeletePreset(Preset preset)
		{
			// the thumbnail generator falls back to the library default, so that one must stay.
			var libraries = LibrariesUsingAsDefault(preset);
			if (libraries.Length > 0) {
				EditorUtility.DisplayDialog("Delete Camera Preset",
					$"\"{preset.name}\" is the default camera preset of {string.Join(", ", libraries)}. Set another default in the library first.",
					"OK");
				return;
			}
			var confirmed = EditorUtility.DisplayDialog("Delete Camera Preset",
				$"Delete \"{preset.name}\"?\n\nAssets that use this preset will fall back to the library's default camera preset. The file is moved to the trash.",
				"Delete", "Cancel");
			if (!confirmed) {
				return;
			}
			if (_renaming == preset) {
				_renaming = null;
			}
			if (!AssetDatabase.MoveAssetToTrash(AssetDatabase.GetAssetPath(preset))) {
				EditorUtility.DisplayDialog("Delete Camera Preset", $"Could not delete \"{preset.name}\".", "OK");
			}
			Reload();
		}

		#endregion

		#region Helpers

		private void Reload()
		{
			_presets.Clear();
			_loadedFolder = target == null ? null : Folder;
			if (target == null || string.IsNullOrEmpty(Folder) || !AssetDatabase.IsValidFolder(Folder)) {
				return;
			}
			// only the folder itself, like the asset browser's preset dropdown, and only presets that fit a transform.
			_presets.AddRange(AssetDatabase.FindAssets("t:Preset", new[] { Folder })
				.Select(AssetDatabase.GUIDToAssetPath)
				.Where(path => Path.GetDirectoryName(path)?.Replace('\\', '/') == Folder)
				.Select(AssetDatabase.LoadAssetAtPath<Preset>)
				.Where(preset => preset != null && preset.CanBeAppliedTo(Controller.transform))
				.OrderBy(preset => preset.name, StringComparer.OrdinalIgnoreCase));
			if (_renaming != null && !_presets.Contains(_renaming)) {
				_renaming = null;
			}
			Repaint();
		}

		private bool IsValidName(string presetName, Preset except, out string error)
		{
			presetName = presetName?.Trim();
			if (string.IsNullOrEmpty(presetName)) {
				error = "Enter a name.";
				return false;
			}
			if (presetName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0) {
				error = "The name contains characters that aren't allowed in a file name.";
				return false;
			}
			var path = $"{Folder}/{presetName}.preset";
			var existing = AssetDatabase.LoadMainAssetAtPath(path);
			if (existing != null && existing != except || _presets.Any(p => p != except && string.Equals(p.name, presetName, StringComparison.OrdinalIgnoreCase))) {
				error = $"\"{presetName}\" already exists.";
				return false;
			}
			error = null;
			return true;
		}

		/// <summary>
		/// Returns the names of the asset libraries using the given preset as default thumbnail camera.
		/// Read through serialization, so this package doesn't need to reference the asset browser.
		/// </summary>
		private static string[] LibrariesUsingAsDefault(Preset preset)
		{
			return AssetDatabase.FindAssets("t:AssetLibrary")
				.Select(guid => AssetDatabase.LoadMainAssetAtPath(AssetDatabase.GUIDToAssetPath(guid)))
				.Where(lib => lib != null)
				.Where(lib => {
					using var so = new SerializedObject(lib);
					return so.FindProperty("DefaultThumbCameraPreset")?.objectReferenceValue == preset;
				})
				.Select(lib => lib.name)
				.ToArray();
		}

		private static bool IsReadOnly(string folder)
		{
			if (!folder.StartsWith("Packages/")) {
				return false;
			}
			var package = PackageInfo.FindForAssetPath(folder);
			return package != null && package.source != PackageSource.Local && package.source != PackageSource.Embedded;
		}

		#endregion
	}
}
