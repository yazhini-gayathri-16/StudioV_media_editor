import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class SharedSelectionState extends ChangeNotifier {
  static final SharedSelectionState _instance = SharedSelectionState._internal();
  factory SharedSelectionState() => _instance;
  SharedSelectionState._internal();

  List<AssetEntity> _selectedMedia = [];
  
  List<AssetEntity> get selectedMedia => List.unmodifiable(_selectedMedia);
  
  void addMedia(AssetEntity asset) {
    if (!_selectedMedia.contains(asset)) {
      _selectedMedia.add(asset);
      notifyListeners();
    }
  }
  
  void removeMedia(AssetEntity asset) {
    _selectedMedia.remove(asset);
    notifyListeners();
  }
  
  void clearSelection() {
    _selectedMedia.clear();
    notifyListeners();
  }
  
  bool isSelected(AssetEntity asset) {
    return _selectedMedia.contains(asset);
  }
  
  int getSelectionIndex(AssetEntity asset) {
    final index = _selectedMedia.indexOf(asset);
    return index >= 0 ? index + 1 : 0;
  }
}
