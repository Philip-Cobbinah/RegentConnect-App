class GroupModel {
  final String id;
  final String name;
  final String? profilePictureUrl;
  final String createdBy;
  final String creatorName;
  final String? creatorPhotoUrl;
  final DateTime createdAt;
  final List<String> members;
  final List<String> admins;
  final String description;
  final String? inviteLink;
  final String kind;
  final bool allowMemberStatusTagging;
  final bool membersCanPost;
  final String lastMessage;

  // Aliases for compatibility
  String get groupName => name;
  List<String> get memberIds => members;
  List<String> get adminIds => admins;
  bool get isChannel => kind == 'channel';
  bool get isGroup => !isChannel;

  GroupModel({
    required this.id,
    required this.name,
    this.profilePictureUrl,
    required this.createdBy,
    required this.creatorName,
    this.creatorPhotoUrl,
    required this.createdAt,
    required this.members,
    List<String>? admins,
    this.description = '',
    this.inviteLink,
    this.kind = 'group',
    this.allowMemberStatusTagging = true,
    bool? membersCanPost,
    this.lastMessage = '',
  })  : admins = admins ?? [createdBy],
        membersCanPost = membersCanPost ?? kind != 'channel';

  bool isAdmin(String userId) => createdBy == userId || admins.contains(userId);

  bool canPost(String userId) => membersCanPost || isAdmin(userId);

  bool canTagOnStatus(String userId) =>
      allowMemberStatusTagging || isAdmin(userId);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'profilePictureUrl': profilePictureUrl,
      'createdBy': createdBy,
      'creatorName': creatorName,
      'creatorPhotoUrl': creatorPhotoUrl,
      'createdAt': createdAt,
      'members': members,
      'admins': admins,
      'description': description,
      'inviteLink': inviteLink,
      'kind': kind,
      'allowMemberStatusTagging': allowMemberStatusTagging,
      'membersCanPost': membersCanPost,
      'lastMessage': lastMessage,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    final createdBy = (map['createdBy'] ?? '').toString();
    final rawCreatedAt = map['createdAt'];
    final createdAt = rawCreatedAt is DateTime
        ? rawCreatedAt
        : (rawCreatedAt as dynamic)?.toDate() ?? DateTime.now();
    return GroupModel(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      profilePictureUrl: map['profilePictureUrl'],
      createdBy: createdBy,
      creatorName: map['creatorName'] ?? '',
      creatorPhotoUrl: map['creatorPhotoUrl'],
      createdAt: createdAt,
      members: List<String>.from(map['members'] ?? []),
      admins: List<String>.from(map['admins'] ?? [createdBy]),
      description: map['description'] ?? '',
      inviteLink: map['inviteLink'],
      kind: map['kind'] ?? map['type'] ?? 'group',
      allowMemberStatusTagging: map['allowMemberStatusTagging'] ?? true,
      membersCanPost: map['membersCanPost'],
      lastMessage: (map['lastMessage'] ?? '').toString(),
    );
  }
}
