import 'package:flutter/material.dart';
import 'user.dart';
import 'sender_location_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
                context, '/login', (route) => false),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: UserDatabase.users.length,
        itemBuilder: (context, index) {
          final user = UserDatabase.users[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              title: Text(
                user.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(user.email),
              trailing: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SenderLocationPage(user: user),
                  ),
                ),
                child: const Text('Select as Sender'),
              ),
            ),
          );
        },
      ),
    );
  }
}