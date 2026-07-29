import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/chat_service.dart';
import '../../../services/auth_service.dart';
import '../../../core/theme.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _chatService = ChatService();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final group = await _chatService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        creatorId: _authService.currentUser!.uid,
      );

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Group Created!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Share this link to invite members:'),
                const SizedBox(height: 8),
                SelectableText(group.inviteLink ?? ''),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Clipboard.setData(
                      ClipboardData(text: group.inviteLink ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied!')),
                  );
                },
                child: const Text('Copy Link'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Group')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: RegentColors.violet.withOpacity(0.1),
              child: IconButton(
                icon: const Icon(Icons.camera_alt, size: 32),
                onPressed: () {},
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                prefixIcon: Icon(Icons.group),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: RegentColors.violet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Create Group'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
