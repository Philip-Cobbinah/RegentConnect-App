import 'package:cloud_firestore/cloud_firestore.dart';

class StatusModel {
  final String id;
  final String odId;
  final String postedBy;
  final String posterName;
  final String? posterPhotoUrl;
  final String content; // text or image url
  final String type; // 'text', 'image'
  final String? backgroundColor; // for text status
  final DateTime createdAt;
  final DateTime expiresAt;
  final List<String> viewedBy;
  final List<String> likedBy;
  final String? taggedGroupId;
  final String? taggedGroupName;
  final String? taggedGroupKind;

  StatusModel({
    required this.id,
    required this.odId,
    required this.postedBy,
    required this.posterName,
    this.posterPhotoUrl,
    required this.content,
    required this.type,
    this.backgroundColor,
    required this.createdAt,
    required this.expiresAt,
    this.viewedBy = const [],
    this.likedBy = const [],
    this.taggedGroupId,
    this.taggedGroupName,
    this.taggedGroupKind,
  });

  factory StatusModel.fromMap(Map<String, dynamic> map, String id) {
    final createdAt = map['createdAt'];
    final expiresAt = map['expiresAt'];
    final rawViews = map['viewedBy'] ?? map['views'] ?? const [];
    final viewedBy = rawViews is List
        ? rawViews
            .map((view) => view is Map ? view['userId'] : view)
            .whereType<String>()
            .toList()
        : <String>[];

    return StatusModel(
      id: id,
      odId: map['odId'] ?? map['userId'] ?? '',
      postedBy: map['postedBy'] ?? map['userId'] ?? '',
      posterName: map['posterName'] ?? map['userName'] ?? '',
      posterPhotoUrl: map['posterPhotoUrl'] ?? map['userPhoto'],
      content: map['content'] ?? map['text'] ?? map['mediaUrl'] ?? '',
      type: map['type'] ?? 'text',
      backgroundColor: map['backgroundColor'],
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      expiresAt: expiresAt is Timestamp
          ? expiresAt.toDate()
          : DateTime.now().add(const Duration(hours: 24)),
      viewedBy: viewedBy,
      likedBy: List<String>.from(map['likedBy'] ?? []),
      taggedGroupId: map['taggedGroupId'] ?? map['taggedGroup']?['id'],
      taggedGroupName: map['taggedGroupName'] ?? map['taggedGroup']?['name'],
      taggedGroupKind: map['taggedGroupKind'] ?? map['taggedGroup']?['kind'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'odId': odId,
      'postedBy': postedBy,
      'posterName': posterName,
      'posterPhotoUrl': posterPhotoUrl,
      'content': content,
      'type': type,
      'backgroundColor': backgroundColor,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'viewedBy': viewedBy,
      'likedBy': likedBy,
      'taggedGroupId': taggedGroupId,
      'taggedGroupName': taggedGroupName,
      'taggedGroupKind': taggedGroupKind,
      'taggedGroup': taggedGroupId == null
          ? null
          : {
              'id': taggedGroupId,
              'name': taggedGroupName,
              'kind': taggedGroupKind,
            },
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
