import 'package:flutter/material.dart';
import 'user.dart';
import 'receiver_location_page.dart';

class ReceiverUsersPage extends StatelessWidget {
  final User sender;
  final double senderLatitude;
  final double senderLongitude;

  const ReceiverUsersPage({
    super.key,
    required this.sender,
    required this.senderLatitude,
    required this.senderLongitude,
  });

  @override
  Widget build(BuildContext context) {
    final receivers = UserDatabase.users
        .where((user) => user.username != sender.username)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Select Receiver')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: receivers.length,
        itemBuilder: (context, index) {
          final user = receivers[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: ListTile(
              title: Text(
                user.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(user.email),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReceiverLocationPage(
                    sender: sender,
                    receiver: user,
                    senderLatitude: senderLatitude,
                    senderLongitude: senderLongitude,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}