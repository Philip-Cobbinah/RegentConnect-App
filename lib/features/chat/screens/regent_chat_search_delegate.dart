import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/official_accounts.dart';
import '../../../core/theme.dart';
import '../../../models/group_model.dart';
import '../../../services/chat_service.dart';
import 'community_chat_screen.dart';
import 'official_account_profile_screen.dart';
import 'dm_screen.dart';

/// WhatsApp-style search across the signed-in user's conversations, group
/// memberships, official offices, directory contacts and recent message text.
class RegentChatSearchDelegate extends SearchDelegate<void> {
  RegentChatSearchDelegate()
      : super(
          searchFieldLabel: 'Search chats, groups, offices and messages',
          searchFieldStyle: const TextStyle(color: Colors.white),
        );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: RegentColors.violet,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      PopupMenuButton<String>(
        tooltip: 'Filter search',
        icon: const Icon(Icons.tune),
        onSelected: (value) => query = value == 'all' ? '' : 'type:$value ',
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'all', child: Text('All')),
          PopupMenuItem(value: 'image', child: Text('Photos')),
          PopupMenuItem(value: 'video', child: Text('Videos')),
          PopupMenuItem(value: 'link', child: Text('Links')),
          PopupMenuItem(value: 'audio', child: Text('Audio')),
          PopupMenuItem(value: 'file', child: Text('Documents')),
          PopupMenuItem(value: 'poll', child: Text('Polls')),
        ],
      ),
      IconButton(
        tooltip: 'Search by date',
        icon: const Icon(Icons.calendar_month_outlined),
        onPressed: () async {
          final date = await showDatePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDate: DateTime.now(),
          );
          if (date != null) {
            query = 'date:${date.year.toString().padLeft(4, '0')}-'
                '${date.month.toString().padLeft(2, '0')}-'
                '${date.day.toString().padLeft(2, '0')} ';
          }
        },
      ),
      if (query.isNotEmpty)
        IconButton(
          tooltip: 'Clear search',
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _SearchResults(
        query: query,
        onOpenChat: (contact) => _openChat(context, contact),
        onOpenGroup: (group) => _openGroup(context, group),
        onOpenMessage: (message) => _openMessage(context, message),
      );

  @override
  Widget buildSuggestions(BuildContext context) => _SearchResults(
        query: query,
        onOpenChat: (contact) => _openChat(context, contact),
        onOpenGroup: (group) => _openGroup(context, group),
        onOpenMessage: (message) => _openMessage(context, message),
      );

  void _openChat(BuildContext context, _SearchContact contact) {
    final navigator = Navigator.of(context);
    close(context, null);
    if (contact.isOfficial) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => OfficialAccountProfileScreen(
            account: contact.toMap(),
          ),
        ),
      );
      return;
    }
    navigator.push(
      MaterialPageRoute(
        builder: (_) => DMScreen(
          recipientId: contact.identity,
          recipientName: contact.name,
          recipientPhoto: contact.photoUrl,
        ),
      ),
    );
  }

  void _openGroup(BuildContext context, GroupModel group) {
    final navigator = Navigator.of(context);
    close(context, null);
    navigator.push(
      MaterialPageRoute(builder: (_) => CommunityChatScreen(group: group)),
    );
  }

  void _openMessage(BuildContext context, _SearchMessage message) {
    final navigator = Navigator.of(context);
    close(context, null);
    navigator.push(
      MaterialPageRoute(
        builder: (_) => DMScreen(
          recipientId: message.contact.identity,
          recipientName: message.contact.name,
          recipientPhoto: message.contact.photoUrl,
          highlightMessageId: message.id,
        ),
      ),
    );
  }
}

class _SearchResults extends StatefulWidget {
  const _SearchResults({
    required this.query,
    required this.onOpenChat,
    required this.onOpenGroup,
    required this.onOpenMessage,
  });

  final String query;
  final ValueChanged<_SearchContact> onOpenChat;
  final ValueChanged<GroupModel> onOpenGroup;
  final ValueChanged<_SearchMessage> onOpenMessage;

  @override
  State<_SearchResults> createState() => _SearchResultsState();
}

class _SearchResultsState extends State<_SearchResults> {
  final ChatService _chatService = ChatService();
  Timer? _debounce;
  _SearchData? _data;
  bool _loading = false;
  String _loadedQuery = '';

  @override
  void initState() {
    super.initState();
    _scheduleSearch();
  }

  @override
  void didUpdateWidget(covariant _SearchResults oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) _scheduleSearch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    final normalized = widget.query.trim();
    if (normalized.isEmpty) {
      setState(() {
        _loadedQuery = '';
        _data = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      final result = await _search(normalized);
      if (!mounted || widget.query.trim() != normalized) return;
      setState(() {
        _loadedQuery = normalized;
        _data = result;
        _loading = false;
      });
    });
  }

  Future<_SearchData> _search(String query) async {
    final parsed = _ParsedSearch.parse(query);
    final needle = parsed.text.toLowerCase();
    try {
      final snapshots = await Future.wait([
        FirebaseFirestore.instance.collection('users').get(),
        _chatService.getChatRooms().first,
        _chatService.getMyGroups().first,
      ]);
      final userSnapshot = snapshots[0];
      final roomSnapshot = snapshots[1];
      final groupSnapshot = snapshots[2];

      final directory = OfficialAccounts.mergeDirectory(
        userSnapshot.docs.map(
          (document) => {
            ...Map<String, dynamic>.from(
              document.data() as Map? ?? const <String, dynamic>{},
            ),
            'uid': document.id,
            'authUid': document.id,
            'documentId': document.id,
          },
        ),
      );
      final contactsByIdentity = <String, _SearchContact>{
        for (final user in directory)
          _identityFor(user): _SearchContact.fromMap(user),
      };

      final contacts = contactsByIdentity.values
          .where((contact) =>
              contact.identity != _chatService.currentMessagingId &&
              _matches(needle, [
                contact.name,
                contact.email,
                contact.office,
                contact.searchTerms,
                contact.isOfficial ? 'official office verified support' : '',
              ]))
          .toList()
        ..sort((a, b) {
          if (a.isOfficial != b.isOfficial) return a.isOfficial ? -1 : 1;
          return a.name.compareTo(b.name);
        });

      final groups = groupSnapshot.docs
          .map(
            (document) => GroupModel.fromMap({
              ...(document.data() as Map<String, dynamic>),
              'id': document.id,
            }),
          )
          .where(
            (group) => _matches(needle, [
              group.name,
              group.description,
              group.kind,
              group.lastMessage,
            ]),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final chatMatches = <_SearchChat>[];
      final messageJobs = <Future<List<_SearchMessage>>>[];
      for (final room in roomSnapshot.docs.take(30)) {
        final roomData = room.data() as Map<String, dynamic>;
        final participants =
            List<String>.from(roomData['participants'] ?? const []);
        final otherIdentity = participants.firstWhere(
          (id) => id != _chatService.currentMessagingId,
          orElse: () => '',
        );
        if (otherIdentity.isEmpty) continue;
        final contact = contactsByIdentity[otherIdentity] ??
            await _contactForIdentity(otherIdentity);
        if (contact == null) continue;

        if (_matches(needle, [
          contact.name,
          contact.email,
          contact.office,
          roomData['lastMessage'],
        ])) {
          chatMatches.add(_SearchChat(contact: contact, roomData: roomData));
        }
        messageJobs.add(_findMessages(room.id, contact, needle, parsed));
      }

      final messageLists = await Future.wait(messageJobs);
      final messages = messageLists.expand((items) => items).toList()
        ..sort(
          (a, b) => (b.timestamp?.millisecondsSinceEpoch ?? 0)
              .compareTo(a.timestamp?.millisecondsSinceEpoch ?? 0),
        );

      return _SearchData(
        contacts: contacts.take(20).toList(),
        chats: chatMatches.take(20).toList(),
        groups: groups.take(20).toList(),
        messages: messages.take(30).toList(),
      );
    } catch (error) {
      debugPrint('Chat search failed: $error');
      return const _SearchData();
    }
  }

  Future<_SearchContact?> _contactForIdentity(String identity) async {
    final user = await _chatService.getUserData(identity);
    if (user == null) return null;
    return _SearchContact.fromMap(user);
  }

  Future<List<_SearchMessage>> _findMessages(
    String chatId,
    _SearchContact contact,
    String needle,
    _ParsedSearch parsed,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .get();
      return snapshot.docs
          .where((document) {
            final data = document.data();
            final timestamp = data['timestamp'];
            final dateMatches = parsed.date == null ||
                (timestamp is Timestamp &&
                    DateFormat('yyyy-MM-dd').format(timestamp.toDate()) == parsed.date);
            final type = (data['type'] ?? 'text').toString();
            final typeMatches = parsed.type == null ||
                (parsed.type == 'link'
                    ? _matches('http', [data['message'], data['content']])
                    : type == parsed.type);
            final senderMatches = parsed.from == null ||
                _matches(parsed.from!, [data['senderName'], data['senderEmail']]);
            return data['isDeleted'] != true && dateMatches && typeMatches &&
                senderMatches &&
                (needle.isEmpty || _matches(needle, [data['message'], data['content']]));
          })
          .map(
            (document) => _SearchMessage(
              id: document.id,
              contact: contact,
              message: (document.data()['message'] ??
                      document.data()['content'] ??
                      '')
                  .toString(),
              senderName: document.data()['senderName']?.toString(),
              timestamp: document.data()['timestamp'] as Timestamp?,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  bool _matches(String query, Iterable<Object?> values) =>
      values.whereType<Object>().join(' ').toLowerCase().contains(query);

  String _identityFor(Map<String, dynamic> user) =>
      (user['chatIdentity'] ?? user['uid'] ?? user['userId']).toString();

  @override
  Widget build(BuildContext context) {
    final query = widget.query.trim();
    if (query.isEmpty) return _buildStartState();
    if (_loading && _loadedQuery != query) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = _data ?? const _SearchData();
    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 56, color: Colors.grey.shade500),
              const SizedBox(height: 12),
              Text('No results for “$query”'),
              const SizedBox(height: 6),
              Text(
                'Try a name, office, group, or words from a message.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (data.chats.isNotEmpty) ...[
          _header(Icons.forum_outlined, 'Chats', data.chats.length),
          ...data.chats.map(_chatTile),
        ],
        if (data.groups.isNotEmpty) ...[
          _header(
            Icons.groups_2_outlined,
            'Groups & channels',
            data.groups.length,
          ),
          ...data.groups.map(_groupTile),
        ],
        if (data.contacts.isNotEmpty) ...[
          _header(
              Icons.people_outline, 'People & offices', data.contacts.length),
          ...data.contacts.map(_contactTile),
        ],
        if (data.messages.isNotEmpty) ...[
          _header(Icons.message_outlined, 'Messages', data.messages.length),
          ...data.messages.map(_messageTile),
        ],
      ],
    );
  }

  Widget _buildStartState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.manage_search,
                  size: 56, color: RegentColors.violet),
              const SizedBox(height: 14),
              const Text(
                'Search Regent Connect',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Find a direct chat, official office, joined group, or text in your recent messages.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );

  Widget _header(IconData icon, String label, int count) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
        child: Row(
          children: [
            Icon(icon, color: RegentColors.violet, size: 20),
            const SizedBox(width: 8),
            Text(
              '$label ($count)',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );

  Widget _contactTile(_SearchContact contact) => ListTile(
        leading: CircleAvatar(
          backgroundColor:
              contact.isOfficial ? RegentColors.violet : Colors.grey.shade300,
          backgroundImage: contact.photoUrl?.isNotEmpty == true
              ? NetworkImage(contact.photoUrl!)
              : null,
          child: contact.photoUrl?.isNotEmpty == true
              ? null
              : Icon(
                  contact.isOfficial ? Icons.account_balance : Icons.person,
                  color:
                      contact.isOfficial ? Colors.white : Colors.grey.shade700,
                ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(contact.name)),
            if (contact.isOfficial)
              const Icon(Icons.verified, color: RegentColors.blue, size: 17),
          ],
        ),
        subtitle:
            Text(contact.office.isNotEmpty ? contact.office : contact.email),
        trailing: Icon(
          contact.isOfficial ? Icons.info_outline : Icons.chat_bubble_outline,
        ),
        onTap: () => widget.onOpenChat(contact),
      );

  Widget _chatTile(_SearchChat chat) => ListTile(
        leading: const CircleAvatar(
          backgroundColor: RegentColors.violet,
          child: Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
        title: Text(chat.contact.name),
        subtitle: Text(
          (chat.roomData['lastMessage'] ?? 'Start a conversation').toString(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onOpenChat(chat.contact),
      );

  Widget _groupTile(GroupModel group) => ListTile(
        leading: CircleAvatar(
          backgroundColor: RegentColors.violet,
          backgroundImage: group.profilePictureUrl?.isNotEmpty == true
              ? NetworkImage(group.profilePictureUrl!)
              : null,
          child: group.profilePictureUrl?.isNotEmpty == true
              ? null
              : const Icon(Icons.groups_2, color: Colors.white),
        ),
        title: Text(group.name),
        subtitle: Text(
          group.description.isNotEmpty
              ? group.description
              : '${group.kind == 'channel' ? 'Channel' : 'Group'} · ${group.members.length} members',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => widget.onOpenGroup(group),
      );

  Widget _messageTile(_SearchMessage message) => ListTile(
        leading: CircleAvatar(
          backgroundColor: RegentColors.violet.withValues(alpha: 0.12),
          child: const Icon(Icons.message, color: RegentColors.violet),
        ),
        title: Text(message.contact.name),
        subtitle: Text(
          message.senderName == null || message.senderName!.isEmpty
              ? message.message
              : '${message.senderName}: ${message.message}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(_timeLabel(message.timestamp)),
        onTap: () => widget.onOpenMessage(message),
      );

  String _timeLabel(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('h:mm a').format(date);
    }
    return '${date.day}/${date.month}';
  }
}

class _ParsedSearch {
  const _ParsedSearch({required this.text, this.type, this.date, this.from});

  final String text;
  final String? type;
  final String? date;
  final String? from;

  static _ParsedSearch parse(String value) {
    var text = value;
    String? read(String key) {
      final match = RegExp('$key:([^ ]+)').firstMatch(text);
      if (match == null) return null;
      text = text.replaceFirst(match.group(0)!, '').trim();
      return match.group(1)!.toLowerCase();
    }
    return _ParsedSearch(
      text: text,
      type: read('type'),
      date: read('date'),
      from: read('from'),
    );
  }
}

class _SearchData {
  const _SearchData({
    this.contacts = const [],
    this.chats = const [],
    this.groups = const [],
    this.messages = const [],
  });

  final List<_SearchContact> contacts;
  final List<_SearchChat> chats;
  final List<GroupModel> groups;
  final List<_SearchMessage> messages;

  bool get isEmpty =>
      contacts.isEmpty && chats.isEmpty && groups.isEmpty && messages.isEmpty;
}

class _SearchContact {
  const _SearchContact({
    required this.identity,
    required this.name,
    required this.email,
    required this.office,
    required this.searchTerms,
    required this.isOfficial,
    required this.accountActive,
    required this.responseHours,
    this.photoUrl,
  });

  factory _SearchContact.fromMap(Map<String, dynamic> user) => _SearchContact(
        identity:
            (user['chatIdentity'] ?? user['uid'] ?? user['userId']).toString(),
        name: (user['fullName'] ??
                user['displayName'] ??
                user['email'] ??
                'Regent user')
            .toString(),
        email: user['email']?.toString() ?? '',
        office: (user['office'] ?? user['program'] ?? user['department'] ?? '')
            .toString(),
        searchTerms: user['searchTerms']?.toString() ?? '',
        isOfficial: user['isOfficial'] == true,
        accountActive: user['accountActive'] == true,
        responseHours: user['responseHours']?.toString() ?? '',
        photoUrl: user['photoUrl']?.toString(),
      );

  final String identity;
  final String name;
  final String email;
  final String office;
  final String searchTerms;
  final bool isOfficial;
  final bool accountActive;
  final String responseHours;
  final String? photoUrl;

  Map<String, dynamic> toMap() {
    return {
      'chatIdentity': identity,
      'uid': identity,
      'userId': identity,
      'fullName': name,
      'displayName': name,
      'email': email,
      'office': office,
      'department': office,
      'searchTerms': searchTerms,
      'isOfficial': isOfficial,
      'accountActive': accountActive,
      'responseHours': responseHours,
      'photoUrl': photoUrl,
      if (isOfficial) 'officialAccountId': identity,
    };
  }
}

class _SearchChat {
  const _SearchChat({required this.contact, required this.roomData});

  final _SearchContact contact;
  final Map<String, dynamic> roomData;
}

class _SearchMessage {
  const _SearchMessage({
    required this.id,
    required this.contact,
    required this.message,
    required this.timestamp,
    this.senderName,
  });

  final String id;
  final _SearchContact contact;
  final String message;
  final String? senderName;
  final Timestamp? timestamp;
}
