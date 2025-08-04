import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../widgets/optimized_media_item_widget.dart';
import '../models/shared_selection_state.dart';
import '../services/media_cache_manager.dart';

class OptimizedMediaPickerScreen extends StatefulWidget {
  final String mediaType;
  final bool allowMixedSelection;

  const OptimizedMediaPickerScreen({
    super.key, 
    required this.mediaType,
    this.allowMixedSelection = false,
  });

  @override
  State<OptimizedMediaPickerScreen> createState() => _OptimizedMediaPickerScreenState();
}

class _OptimizedMediaPickerScreenState extends State<OptimizedMediaPickerScreen> {
  final List<AssetEntity> _mediaList = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _isLoadingMore = false;
  final SharedSelectionState _selectionState = SharedSelectionState();
  final ScrollController _scrollController = ScrollController();
  final MediaCacheManager _cacheManager = MediaCacheManager();
  
  AssetPathEntity? _currentAlbum;
  int _currentPage = 0;
  static const int _pageSize = 50; // Load 50 items at a time
  bool _hasMoreItems = true;

  @override
  void initState() {
    super.initState();
    _requestPermissionAndLoadMedia();
    _selectionState.addListener(_onSelectionChanged);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _selectionState.removeListener(_onSelectionChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    if (mounted) {
      setState(() {}); // Rebuild to update selection indicators
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreMedia();
    }
  }

  Future<void> _requestPermissionAndLoadMedia() async {
    final PermissionState permission = await PhotoManager.requestPermissionExtend();
    
    if (permission.isAuth) {
      setState(() {
        _hasPermission = true;
      });
      await _loadInitialMedia();
    } else {
      setState(() {
        _hasPermission = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadInitialMedia() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.common,
      );

      if (albums.isNotEmpty) {
        _currentAlbum = albums[0];
        await _loadMediaPage();
      }
    } catch (e) {
      print('Error loading initial media: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMediaPage() async {
    if (_currentAlbum == null || !_hasMoreItems) return;

    try {
      final List<AssetEntity> newMedia = await _currentAlbum!.getAssetListRange(
        start: _currentPage * _pageSize,
        end: (_currentPage + 1) * _pageSize,
      );

      if (newMedia.isEmpty) {
        _hasMoreItems = false;
        return;
      }

      // Filter and sort media
      List<AssetEntity> filteredMedia = newMedia.where((asset) {
        // Show all media types for mixed selection
        return true;
      }).toList();

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
        _mediaList.addAll(filteredMedia);
        _currentPage++;
      });

      // Preload thumbnails for better performance
      _preloadThumbnails(filteredMedia);

    } catch (e) {
      print('Error loading media page: $e');
    }
  }

  Future<void> _loadMoreMedia() async {
    if (_isLoadingMore || !_hasMoreItems) return;

    setState(() {
      _isLoadingMore = true;
    });

    await _loadMediaPage();

    setState(() {
      _isLoadingMore = false;
    });
  }

  void _preloadThumbnails(List<AssetEntity> assets) {
    // Preload thumbnails in background
    for (final asset in assets.take(20)) { // Preload first 20
      _cacheManager.getThumbnail(asset, const ThumbnailSize(150, 150));
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
            controller: _scrollController,
            crossAxisCount: 3,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            padding: const EdgeInsets.all(8),
            itemCount: _mediaList.length + (_isLoadingMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _mediaList.length) {
                // Loading indicator at the end
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    ),
                  ),
                );
              }

              final asset = _mediaList[index];
              final isSelected = _selectionState.isSelected(asset);
              
              return OptimizedMediaItemWidget(
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
