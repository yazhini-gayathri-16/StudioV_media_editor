import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class AudioClip {
  final String id;
  final String filePath;
  final String displayName;
  Duration startTime;
  Duration endTime;
  Duration sourceDuration; // The original duration of the audio file
  double volume;
  

  AudioClip({
    required this.id,
    required this.filePath,
    required this.displayName,
    required this.startTime,
    required this.endTime,
    required this.sourceDuration,
    this.volume = 1.0,
  });

  // Calculated property for the duration of the clip on the timeline
  Duration get duration => endTime - startTime;

  //copyWith method for easy updates
  AudioClip copyWith({
    String? id,
    String? filePath,
    String? displayName,
    Duration? startTime,
    Duration? endTime,
    Duration? sourceDuration,
    double? volume,
  }) {
    return AudioClip(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      displayName: displayName ?? this.displayName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      sourceDuration: sourceDuration ?? this.sourceDuration,
      volume: volume ?? this.volume,
    );
  }

  // Factory for creating a new clip
  factory AudioClip.fromFile({
    required String path,
    required String name,
    required Duration totalProjectDuration,
    required Duration audioFileDuration,
    required Duration playheadPosition,
  }) {
    final id = const Uuid().v4();
    final startTime = playheadPosition;
    // Ensure the clip doesn't extend beyond the project duration
    Duration endTime = startTime + audioFileDuration;
    if (endTime > totalProjectDuration) {
      endTime = totalProjectDuration;
    }

    return AudioClip(
      id: id,
      filePath: path,
      displayName: name,
      startTime: startTime,
      endTime: endTime,
      sourceDuration: audioFileDuration,
    );
  }
}

// A result class to pass data back from the AudioEditorScreen
class AudioEditorResult {
  final List<AudioClip> audioClips;
  AudioEditorResult({required this.audioClips});
}