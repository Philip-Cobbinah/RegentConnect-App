import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import 'admin_dashboard_screen.dart';

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AdminService().isAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) return const AdminDashboardScreen();

        return Scaffold(
          appBar: AppBar(title: const Text('Admin access')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Administrator access is restricted to approved admin accounts.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
