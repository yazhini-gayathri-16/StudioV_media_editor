import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'media_picker_screen.dart';
import '../models/shared_selection_state.dart';
import '../models/media_clip.dart';
import 'editor_screen.dart';

class MediaTypeSelectionScreen extends StatefulWidget {
  final String primaryType;

  const MediaTypeSelectionScreen({Key? key, required this.primaryType}) : super(key: key);

  @override
  State<MediaTypeSelectionScreen> createState() => _MediaTypeSelectionScreenState();
}

class _MediaTypeSelectionScreenState extends State<MediaTypeSelectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;
  final SharedSelectionState _selectionState = SharedSelectionState();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedTabIndex = widget.primaryType == 'video' ? 0 : 1;
    _tabController.index = _selectedTabIndex;
    _selectionState.clearSelection(); // Clear previous selections
    _selectionState.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _selectionState.removeListener(_onSelectionChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    setState(() {}); // Rebuild to update the floating action button
  }

  Future<void> _proceedToEditor() async {
    final selectedMedia = _selectionState.selectedMedia;
    if (selectedMedia.isNotEmpty) {
      // Convert selected media to MediaClip objects
      List<MediaClip> mediaClips = [];
      
      for (int i = 0; i < selectedMedia.length; i++) {
        final asset = selectedMedia[i];
        Duration originalDuration = Duration.zero;
        
        if (asset.type == AssetType.video) {
          originalDuration = Duration(seconds: asset.duration);
        } else {
          // For images, set a default duration of 3 seconds
          originalDuration = const Duration(seconds: 3);
        }
        
        mediaClips.add(MediaClip(
          asset: asset,
          startTime: Duration.zero,
          endTime: originalDuration,
          originalDuration: originalDuration,
          selectionOrder: i + 1,
        ));
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EditorScreen(
            mediaClips: mediaClips,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Select Media',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purple,
          labelColor: Colors.purple,
          unselectedLabelColor: Colors.grey,
          onTap: (index) {
            setState(() {
              _selectedTabIndex = index;
            });
          },
          tabs: const [
            Tab(
              icon: Icon(Icons.videocam),
              text: 'Video',
            ),
            Tab(
              icon: Icon(Icons.photo_library),
              text: 'Images',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MediaPickerScreen(
            mediaType: 'video',
            allowMixedSelection: true,
          ),
          MediaPickerScreen(
            mediaType: 'image',
            allowMixedSelection: true,
          ),
        ],
      ),
      floatingActionButton: _selectionState.selectedMedia.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _proceedToEditor,
              backgroundColor: Colors.purple,
              icon: const Icon(Icons.arrow_forward),
              label: Text('Next (${_selectionState.selectedMedia.length})'),
            )
          : null,
    );
  }
}
