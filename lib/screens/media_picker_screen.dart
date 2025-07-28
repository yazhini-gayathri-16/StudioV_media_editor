import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../widgets/media_item_widget.dart';
import 'editor_screen.dart';

class MediaPickerScreen extends StatefulWidget {
  final String mediaType;
  final bool allowMixedSelection;

  const MediaPickerScreen({
    Key? key, 
    required this.mediaType,
    this.allowMixedSelection = false,
  }) : super(key: key);

  @override
  State<MediaPickerScreen> createState() => _MediaPickerScreenState();
}

class _MediaPickerScreenState extends State<MediaPickerScreen> {
  List<AssetEntity> _mediaList = [];
  List<AssetEntity> _selectedMedia = [];
  bool _isLoading = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadMedia();
  }

  Future<void> _requestPermissionAndLoadMedia() async {
    final PermissionState permission = await PhotoManager.requestPermissionExtend();
    
    if (permission.isAuth) {
      setState(() {
        _hasPermission = true;
      });
      await _loadMedia();
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      RequestType requestType;
      if (widget.allowMixedSelection) {
        requestType = RequestType.common; // This allows both images and videos
      } else {
        requestType = widget.mediaType == 'video' ? RequestType.video : RequestType.image;
      }

      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: requestType,
      );

      if (albums.isNotEmpty) {
        final List<AssetEntity> media = await albums[0].getAssetListRange(
          start: 0,
          end: 1000,
        );

        // Filter based on current tab if needed
        List<AssetEntity> filteredMedia = media;
        if (!widget.allowMixedSelection) {
          filteredMedia = media.where((asset) {
            return widget.mediaType == 'video' 
                ? asset.type == AssetType.video 
                : asset.type == AssetType.image;
          }).toList();
        } else {
          // For mixed selection, prioritize the current media type
          filteredMedia = media.where((asset) {
            return widget.mediaType == 'video' 
                ? asset.type == AssetType.video 
                : asset.type == AssetType.image;
          }).toList();
        }

        setState(() {
          _mediaList = filteredMedia;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading media: $e');
    }
  }

  void _toggleSelection(AssetEntity asset) {
    setState(() {
      if (_selectedMedia.contains(asset)) {
        _selectedMedia.remove(asset);
      } else {
        _selectedMedia.add(asset);
      }
    });
  }

  void _proceedToEditor() {
    if (_selectedMedia.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(
            selectedMedia: _selectedMedia,
            mediaType: 'video', // Always use video editor for mixed content
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: _buildBody(),
      floatingActionButton: _selectedMedia.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _proceedToEditor,
              backgroundColor: Colors.purple,
              icon: const Icon(Icons.arrow_forward),
              label: Text('Next (${_selectedMedia.length})'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (!_hasPermission) {
      return _buildPermissionDenied();
    }

    if (_isLoading) {
      return _buildLoadingIndicator();
    }

    if (_mediaList.isEmpty) {
      return _buildEmptyState();
    }

    return _buildMediaGrid();
  }

  Widget _buildPermissionDenied() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          const Text(
            'Permission Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Please grant permission to access your media files',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
            ),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
          ),
          SizedBox(height: 20),
          Text(
            'Loading media files...',
            style: TextStyle(color: Colors.white),
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
          Icon(
            widget.mediaType == 'video' ? Icons.videocam_off : Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 20),
          Text(
            'No ${widget.mediaType}s found',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Add some ${widget.mediaType}s to your device to get started',
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    return Column(
      children: [
        if (_selectedMedia.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2A2A2A),
            child: Row(
              children: [
                Text(
                  '${_selectedMedia.length} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedMedia.clear();
                    });
                  },
                  child: const Text(
                    'Clear All',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: MasonryGridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            padding: const EdgeInsets.all(8),
            itemCount: _mediaList.length,
            itemBuilder: (context, index) {
              final asset = _mediaList[index];
              final isSelected = _selectedMedia.contains(asset);
              
              return MediaItemWidget(
                asset: asset,
                isSelected: isSelected,
                onTap: () => _toggleSelection(asset),
                selectionIndex: isSelected ? _selectedMedia.indexOf(asset) + 1 : 0,
              );
            },
          ),
        ),
      ],
    );
  }
}