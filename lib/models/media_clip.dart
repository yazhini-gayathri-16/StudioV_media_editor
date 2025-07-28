import 'package:photo_manager/photo_manager.dart';

class MediaClip {
  final AssetEntity asset;
  Duration startTime;
  Duration endTime;
  Duration originalDuration;
  final int selectionOrder;

  MediaClip({
    required this.asset,
    required this.startTime,
    required this.endTime,
    required this.originalDuration,
    required this.selectionOrder,
  });

  Duration get trimmedDuration => endTime - startTime;

  MediaClip copyWith({
    AssetEntity? asset,
    Duration? startTime,
    Duration? endTime,
    Duration? originalDuration,
    int? selectionOrder,
  }) {
    return MediaClip(
      asset: asset ?? this.asset,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      originalDuration: originalDuration ?? this.originalDuration,
      selectionOrder: selectionOrder ?? this.selectionOrder,
    );
  }
}
