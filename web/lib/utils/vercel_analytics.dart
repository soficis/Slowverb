/*
 * Copyright (C) 2025 Slowverb
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:js_interop';

/// JavaScript interop for Vercel Web Analytics
///
/// This module provides client-side analytics tracking for the Slowverb web app.
/// Vercel Web Analytics is injected via the /_vercel/insights/script.js endpoint
/// and exposed through the window.va object.
///
/// Note: The analytics script runs entirely on the client side and does not
/// include route support. For route tracking in Flutter web, use custom events.

@JS('window.va')
external void _vaTrackEvent(String eventName, [JSAny? properties]);

/// Track a custom analytics event
///
/// Example usage:
/// ```dart
/// trackEvent('audio_export', {'format': 'mp3', 'duration': 120});
/// trackEvent('preset_selected', {'preset': 'Vaporwave Chill'});
/// ```
void trackEvent(String eventName, [Map<String, dynamic>? properties]) {
  try {
    _vaTrackEvent(eventName, properties?.jsify());
  } catch (e) {
    // Silently fail if analytics is not available
    // This can happen during development or if the script fails to load
  }
}

/// Track audio processing event
void trackAudioProcessing({
  required String preset,
  required String inputFormat,
  String? outputFormat,
  int? durationSeconds,
}) {
  trackEvent('audio_processed', {
    'preset': preset,
    'input_format': inputFormat,
    'output_format': outputFormat ?? 'unknown',
    'duration_seconds': durationSeconds ?? 0,
  });
}

/// Track preset selection
void trackPresetSelected(String presetName) {
  trackEvent('preset_selected', {'preset': presetName});
}

/// Track file import
void trackFileImported({required String format, int? fileSizeBytes}) {
  trackEvent('file_imported', {
    'format': format,
    'file_size_bytes': fileSizeBytes ?? 0,
  });
}

/// Track export action
void trackExportAction({required String format, required String destination}) {
  trackEvent('export_initiated', {
    'format': format,
    'destination': destination,
  });
}

/// Track error events
void trackError({required String errorType, String? message}) {
  trackEvent('error_occurred', {
    'error_type': errorType,
    'message': message ?? 'unknown',
  });
}
