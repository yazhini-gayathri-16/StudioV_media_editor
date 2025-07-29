import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../widgets/media_item_widget.dart';
import '../models/shared_selection_state.dart';

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
  bool _isLoading = true;
  bool _hasPermission = false;
  final SharedSelectionState _selectionState = SharedSelectionState();

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadMedia();
    _selectionState.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _selectionState.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    setState(() {}); // Rebuild to update selection indicators
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
      // Always load both images and videos for mixed selection
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );

      if (albums.isNotEmpty) {
        final List<AssetEntity> media = await albums[0].getAssetListRange(
          start: 0,
          end: 1000,
        );

        // Show all media types but prioritize the selected tab
        List<AssetEntity> filteredMedia = media;
        
        // Sort to show the current media type first
        filteredMedia.sort((a, b) {
          bool aIsCurrentType = widget.mediaType == 'video' 
              ? a.type == AssetType.video 
              : a.type == AssetType.image;
          bool bIsCurrentType = widget.mediaType == 'video' 
              ? b.type == AssetType.video 
              : b.type == AssetType.image;
          
          if (aIsCurrentType && !bIsCurrentType) return -1;
          if (!aIsCurrentType && bIsCurrentType) return 1;
          
          // Secondary sort by creation date (newest first)
          return b.createDateTime.compareTo(a.createDateTime);
        });

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
    if (_selectionState.isSelected(asset)) {
      _selectionState.removeMedia(asset);
    } else {
      _selectionState.addMedia(asset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: _buildBody(),
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
          const Text(
            'No media found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Add some photos or videos to your device to get started',
            style: TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    return Column(
      children: [
        if (_selectionState.selectedMedia.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF2A2A2A),
            child: Row(
              children: [
                Text(
                  '${_selectionState.selectedMedia.length} selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _selectionState.clearSelection();
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
              final isSelected = _selectionState.isSelected(asset);
              
              return MediaItemWidget(
                asset: asset,
                isSelected: isSelected,
                onTap: () => _toggleSelection(asset),
                selectionIndex: _selectionState.getSelectionIndex(asset),
              );
            },
          ),
        ),
      ],
    );
  }
}
