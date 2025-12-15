import 'package:slowverb_web/domain/entities/effect_preset.dart';

/// Abstract preset repository for web.
///
/// Allows users to save, load, and manage custom presets
/// using browser storage (IndexedDB with localStorage fallback).
abstract class PresetRepository {
  /// Initialize the storage backend.
  Future<void> initialize();

  /// Get all custom presets saved by the user.
  /// Returns an empty list if no custom presets exist.
  Future<List<EffectPreset>> getAllCustomPresets();

  /// Get a specific custom preset by its ID.
  /// Returns null if the preset doesn't exist.
  Future<EffectPreset?> getCustomPreset(String id);

  /// Save a custom preset.
  /// Updates the preset if it already exists (by ID).
  Future<void> saveCustomPreset(EffectPreset preset);

  /// Delete a custom preset by its ID.
  /// Does nothing if the preset doesn't exist.
  Future<void> deleteCustomPreset(String id);

  /// Check if a custom preset with the given ID exists.
  Future<bool> hasCustomPreset(String id);
}
