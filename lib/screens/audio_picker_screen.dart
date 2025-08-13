// lib/screens/audio_picker_screen.dart - FIXED

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';

// The AudioItemWidget class is now defined directly in this file to resolve the error.
class AudioItemWidget extends StatelessWidget {
  final AssetEntity asset;
  final VoidCallback onTap;

  const AudioItemWidget({
    super.key,
    required this.asset,
    required this.onTap,
  });

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final secs = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: const Color(0xFF1A1A1A),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.purple.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.music_note, color: Colors.purple, size: 30),
      ),
      title: Text(
        asset.title ?? 'Unknown Audio',
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatDuration(asset.duration),
        style: const TextStyle(color: Colors.grey),
      ),
      trailing: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text('Add'),
      ),
      onTap: onTap,
    );
  }
}


class AudioPickerScreen extends StatefulWidget {
  const AudioPickerScreen({super.key});

  @override
  State<AudioPickerScreen> createState() => _AudioPickerScreenState();
}

class _AudioPickerScreenState extends State<AudioPickerScreen> {
  List<AssetEntity> _audioList = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadAudio();
  }

  Future<void> _requestPermissionAndLoadAudio() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      setState(() {
        _hasPermission = true;
      });
      await _loadAudio();
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
      if (ps == PermissionState.denied) {
         PhotoManager.openSetting();
      }
    }
  }

  Future<void> _loadAudio() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.audio,
      );

      if (albums.isNotEmpty) {
        final List<AssetEntity> audioAssets = await albums[0].getAssetListRange(
          start: 0,
          end: 1000,
        );

        audioAssets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

        setState(() {
          _audioList = audioAssets;
        });
      }
    } catch (e) {
      debugPrint('Error loading audio: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _selectAudio(AssetEntity audio) {
    Navigator.pop(context, audio);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('Select Audio', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2A2A2A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return _buildPermissionDenied();
    }
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.purple));
    }
    if (_audioList.isEmpty) {
      return _buildEmptyState();
    }
    return _buildAudioList();
  }

  Widget _buildAudioList() {
    return ListView.builder(
      itemCount: _audioList.length,
      itemBuilder: (context, index) {
        final asset = _audioList[index];
        return AudioItemWidget(
          asset: asset,
          onTap: () => _selectAudio(asset),
        );
      },
    );
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'Permission Required',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please grant permission to access your audio files.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: openAppSettings,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_off, size: 80, color: Colors.grey),
          const SizedBox(height: 20),
          const Text(
            'No Audio Found',
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'There are no audio files on your device.',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
