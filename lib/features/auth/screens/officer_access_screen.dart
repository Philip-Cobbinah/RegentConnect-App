import 'package:flutter/material.dart';

import '../../../core/official_accounts.dart';
import '../../../core/theme.dart';

class OfficerAccessScreen extends StatelessWidget {
  const OfficerAccessScreen({
    super.key,
    this.allowAccountSelection = false,
  });

  final bool allowAccountSelection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Official office access'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  RegentColors.darkViolet,
                  RegentColors.violet,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Verified Regent staff accounts',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  'Students never need an officer password. Open an official office from Chats and send your message there.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'How officers reply',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const _AccessStep(
            number: '1',
            title: 'Account activation',
            description:
                'The Regent Connect administrator provisions the office’s approved institutional email in Firebase Authentication.',
          ),
          const _AccessStep(
            number: '2',
            title: 'Sign in here',
            description:
                'The officer uses the normal Sign in page with the office email and the temporary password supplied privately by the administrator.',
          ),
          const _AccessStep(
            number: '3',
            title: 'Open the office inbox',
            description:
                'After sign-in, Chats becomes that office’s shared verified inbox. Existing and new student conversations appear under Direct messages.',
          ),
          const _AccessStep(
            number: '4',
            title: 'Reply as the office',
            description:
                'Messages, attachments, read receipts and replies are stored in Firebase and sent with the verified office identity.',
          ),
          const SizedBox(height: 22),
          const Text(
            'Official accounts',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...OfficialAccounts.accounts.map(
            (account) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: RegentColors.violet,
                  child: Icon(Icons.account_balance, color: Colors.white),
                ),
                title: Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.verified,
                      color: RegentColors.blue,
                      size: 17,
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${account.email}\n${account.responseHours}',
                  ),
                ),
                isThreeLine: true,
                trailing: allowAccountSelection
                    ? const Icon(Icons.login_rounded)
                    : null,
                onTap: allowAccountSelection
                    ? () => Navigator.pop(context, account.email)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RegentColors.violet.withOpacity(0.09),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: RegentColors.violet.withOpacity(0.22),
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.security, color: RegentColors.violet),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Official registration is not public. If an officer has not received access, the university’s designated Regent Connect administrator must activate or reset the account.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessStep extends StatelessWidget {
  const _AccessStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: RegentColors.violet,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
