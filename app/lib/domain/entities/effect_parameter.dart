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
/// Definition of a single effect parameter
///
/// Defines the range, default value, and display properties
/// for a parameter like tempo, pitch, or reverb amount.
class EffectParameter {
  final String id;
  final String label;
  final double min;
  final double max;
  final double defaultValue;
  final double? step;
  final String? unit;

  const EffectParameter({
    required this.id,
    required this.label,
    required this.min,
    required this.max,
    required this.defaultValue,
    this.step,
    this.unit,
  });
}
