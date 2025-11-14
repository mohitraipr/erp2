import 'package:flutter/material.dart';

import '../models/login_response.dart';

class ResponsePage extends StatelessWidget {
  static const routeName = '/response';

  final LoginResponse data;

  const ResponsePage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login response')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, ${data.username}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text('Role: ${data.role}'),
                if (data.userId != null) ...[
                  const SizedBox(height: 8),
                  Text('User ID: ${data.userId}'),
                ],
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
