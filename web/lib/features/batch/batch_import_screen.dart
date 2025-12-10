/*
 * Copyright (C) 2025 Slowverb Web
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:slowverb_web/domain/repositories/audio_engine.dart';
import 'package:slowverb_web/domain/entities/batch_job.dart';
import 'package:slowverb_web/domain/entities/effect_preset.dart';
import 'package:slowverb_web/app/router.dart';

/// Batch import screen for selecting multiple audio files
///
/// Allows user to:
/// - Select multiple audio files (up to 50)
/// - Choose a default preset for all files
/// - Optionally override preset per-file
/// - View total size and estimated processing time
class BatchImportScreen extends StatefulWidget {
  const BatchImportScreen({super.key});

  @override
  State<BatchImportScreen> createState() => _BatchImportScreenState();
}

class _BatchImportScreenState extends State<BatchImportScreen> {
  final List<BatchInputFile> _selectedFiles = [];
  EffectPreset _defaultPreset = Presets.slowedReverb;
  bool _isLoading = false;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      // Enforce 50 file limit for web
      if (result.files.length > 50) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 50 files allowed for batch processing'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final files = <BatchInputFile>[];
      for (final file in result.files) {
        if (file.bytes != null) {
          files.add(
            BatchInputFile(
              fileId:
                  'file-${DateTime.now().millisecondsSinceEpoch}-${file.name}',
              fileName: file.name,
              bytes: file.bytes!,
            ),
          );
        }
      }

      setState(() {
        _selectedFiles.clear();
        _selectedFiles.addAll(files);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  void _startBatchProcessing() {
    if (_selectedFiles.isEmpty) return;

    // Navigate to batch export screen with files and preset
    Navigator.of(context).pushNamed(
      '/batch-export',
      arguments: {'files': _selectedFiles, 'defaultPreset': _defaultPreset},
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSize = _selectedFiles.fold<int>(
      0,
      (sum, file) => sum + file.bytes.length,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Batch Import'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            TextButton.icon(
              onPressed: _startBatchProcessing,
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: const Text(
                'Process All',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // File selection section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.audio_file),
                        label: const Text('Select Audio Files'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_selectedFiles.isNotEmpty) ...[
                        Text(
                          '${_selectedFiles.length} file(s) selected • ${(totalSize / 1024 / 1024).toStringAsFixed(1)} MB total',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<EffectPreset>(
                          initialValue: _defaultPreset,
                          decoration: const InputDecoration(
                            labelText: 'Default Preset (Apply to All)',
                            border: OutlineInputBorder(),
                          ),
                          items: Presets.all.map((preset) {
                            return DropdownMenuItem(
                              value: preset,
                              child: Text(preset.name),
                            );
                          }).toList(),
                          onChanged: (preset) {
                            if (preset != null) {
                              setState(() {
                                _defaultPreset = preset;
                              });
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),

                // File list
                Expanded(
                  child: _selectedFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(
                                Icons.queue_music,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'No files selected',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Select up to 50 audio files to process',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _selectedFiles.length,
                          itemBuilder: (context, index) {
                            final file = _selectedFiles[index];
                            final sizeKb = file.bytes.length / 1024;

                            return ListTile(
                              leading: const Icon(Icons.audio_file),
                              title: Text(file.fileName),
                              subtitle: Text('${sizeKb.toStringAsFixed(1)} KB'),
                              trailing: IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => _removeFile(index),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
