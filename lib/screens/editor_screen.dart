import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class EditorScreen extends StatefulWidget {
  final List<AssetEntity> selectedMedia;
  final String mediaType;

  const EditorScreen({
    Key? key,
    required this.selectedMedia,
    required this.mediaType,
  }) : super(key: key);

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(
          '${widget.mediaType == 'video' ? 'Video' : 'Image'} Editor',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              // Implement save/export functionality
              _showExportDialog();
            },
            child: const Text(
              'Export',
              style: TextStyle(
                color: Colors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Preview Area
          Expanded(
            flex: 3,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Center(
                child: FutureBuilder<Widget>(
                  future: _buildPreview(),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      return snapshot.data!;
                    }
                    return const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Media Timeline
          if (widget.selectedMedia.length > 1)
            Container(
              height: 80,
              color: const Color(0xFF2A2A2A),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: widget.selectedMedia.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    child: Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: _currentIndex == index
                            ? Border.all(color: Colors.purple, width: 2)
                            : null,
                      ),
                      child: FutureBuilder<Widget>(
                        future: _buildThumbnail(widget.selectedMedia[index]),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: snapshot.data!,
                            );
                          }
                          return Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.photo, color: Colors.white),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Editing Tools
          Container(
            height: 120,
            color: const Color(0xFF2A2A2A),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text(
                    'Editing Tools',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildToolButton(Icons.crop, 'Crop'),
                      _buildToolButton(Icons.tune, 'Adjust'),
                      _buildToolButton(Icons.filter, 'Filter'),
                      _buildToolButton(Icons.text_fields, 'Text'),
                      _buildToolButton(Icons.music_note, 'Audio'),
                      _buildToolButton(Icons.speed, 'Speed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.purple),
            ),
            child: Icon(icon, color: Colors.purple),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<Widget> _buildPreview() async {
    if (widget.selectedMedia.isEmpty) {
      return const Text('No media selected', style: TextStyle(color: Colors.white));
    }

    final asset = widget.selectedMedia[_currentIndex];
    
    try {
      final file = await asset.file;
      if (file != null) {
        return Image.file(
          file,
          fit: BoxFit.contain,
        );
      }
    } catch (e) {
      print('Error loading preview: $e');
    }
    
    return const Text('Error loading preview', style: TextStyle(color: Colors.white));
  }

  Future<Widget> _buildThumbnail(AssetEntity asset) async {
    try {
      final thumbnail = await asset.thumbnailDataWithSize(
        const ThumbnailSize(60, 60),
      );
      
      if (thumbnail != null) {
        return Image.memory(
          thumbnail,
          fit: BoxFit.cover,
          width: 60,
          height: 60,
        );
      }
    } catch (e) {
      print('Error loading thumbnail: $e');
    }
    
    return Container(
      color: Colors.grey[800],
      child: const Icon(Icons.photo, color: Colors.white),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A2A),
          title: const Text('Export Media', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Export functionality will be implemented here.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Implement export logic
              },
              child: const Text('Export', style: TextStyle(color: Colors.purple)),
            ),
          ],
        );
      },
    );
  }
}