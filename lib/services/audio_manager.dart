import 'package:just_audio/just_audio.dart';
import '../models/audio_clip_model.dart';
import 'package:flutter/foundation.dart';

class AudioManager {
  final Map<String, AudioPlayer> _players = {};
  List<AudioClip> _currentClips = [];
  bool _isPlaying = false;

  void setClips(List<AudioClip> clips) {
    _currentClips = clips;
    // You could pre-load players here if needed
  }

  Future<void> play(Duration position) async {
    _isPlaying = true;
    for (final clip in _currentClips) {
      if (position >= clip.startTime && position < clip.endTime) {
        await _playClip(clip, position);
      } else {
        await _stopClip(clip);
      }
    }
  }

  Future<void> pause() async {
    _isPlaying = false;
    for (final player in _players.values) {
      if (player.playing) {
        await player.pause();
      }
    }
  }

  Future<void> seek(Duration position) async {
    for (final clip in _currentClips) {
      if (_players.containsKey(clip.id)) {
        final player = _players[clip.id]!;
        final seekPositionInClip = position - clip.startTime;
        
        if (position >= clip.startTime && position < clip.endTime) {
          // Seek within the clip
          await player.seek(seekPositionInClip);
          if (_isPlaying && !player.playing) {
             await player.play();
          }
        } else {
          // Stop if outside the active range
          if (player.playing) {
            await player.pause();
          }
        }
      }
    }
  }

  Future<void> _playClip(AudioClip clip, Duration projectPosition) async {
    AudioPlayer player = _players[clip.id] ?? AudioPlayer();
    
    // UPDATED: Load the audio file using its direct path
    if (_players[clip.id] == null) {
      try {
        await player.setFilePath(clip.filePath);
        _players[clip.id] = player;
      } catch (e) {
        debugPrint("Error loading audio for clip ${clip.id} from path ${clip.filePath}: $e");
        return;
      }
    }

    final seekPositionInClip = projectPosition - clip.startTime;
    if (seekPositionInClip.isNegative) return;

    await player.setVolume(clip.volume);
    await player.seek(seekPositionInClip);
    if (_isPlaying && !player.playing) {
      await player.play();
    }
  }

  Future<void> _stopClip(AudioClip clip) async {
    if (_players.containsKey(clip.id)) {
      final player = _players[clip.id]!;
      if (player.playing) {
        await player.pause();
      }
    }
  }

  void dispose() {
    for (final player in _players.values) {
      player.dispose();
    }
    _players.clear();
  }
}