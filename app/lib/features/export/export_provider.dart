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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:slowverb/domain/entities/project.dart';

/// Simple state to hold export data without AudioPlayer dependencies
class ExportData {
  final Project? project;
  final Map<String, double> parameters;
  final String? exportDirectory;
  final bool isExporting;
  final double exportProgress;
  final String? exportedFilePath;
  final String? errorMessage;

  const ExportData({
    this.project,
    this.parameters = const {},
    this.exportDirectory,
    this.isExporting = false,
    this.exportProgress = 0.0,
    this.exportedFilePath,
    this.errorMessage,
  });

  ExportData copyWith({
    Project? project,
    Map<String, double>? parameters,
    String? exportDirectory,
    bool? isExporting,
    double? exportProgress,
    String? exportedFilePath,
    String? errorMessage,
  }) {
    return ExportData(
      project: project ?? this.project,
      parameters: parameters ?? this.parameters,
      exportDirectory: exportDirectory ?? this.exportDirectory,
      isExporting: isExporting ?? this.isExporting,
      exportProgress: exportProgress ?? this.exportProgress,
      exportedFilePath: exportedFilePath ?? this.exportedFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Provider for export screen data - completely independent of AudioPlayer
final exportDataProvider = StateProvider<ExportData>((ref) {
  return const ExportData();
});
