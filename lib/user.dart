// user.dart - Updated with location tracking and real-time updates
enum UserPermission {
  sender,
  receiver,
}

class User {
  final String username;
  final String password;
  final String name;
  final String email;
  final double? latitude;
  final double? longitude;
  final UserPermission permission;
  final DateTime? locationUpdatedAt;

  User({
    required this.username,
    required this.password,
    required this.name,
    required this.email,
    required this.permission,
    this.latitude,
    this.longitude,
    this.locationUpdatedAt,
  });

  bool get isSender => permission == UserPermission.sender;
  bool get isReceiver => permission == UserPermission.receiver;

  // Create a copy of user with updated location
  User copyWithLocation({
    required double latitude,
    required double longitude,
    DateTime? locationUpdatedAt,
  }) {
    return User(
      username: username,
      password: password,
      name: name,
      email: email,
      permission: permission,
      latitude: latitude,
      longitude: longitude,
      locationUpdatedAt: locationUpdatedAt ?? DateTime.now(),
    );
  }

  // Check if location is recent (within last 30 seconds)
  bool get hasRecentLocation {
    if (locationUpdatedAt == null) return false;
    return DateTime.now().difference(locationUpdatedAt!).inSeconds < 30;
  }
}

class UserDatabase {
  static final List<User> users = [
    // Sender Users - Can only view their own location
    User(
      username: 'john_sender',
      password: 'pass123',
      name: 'John Doe (Sender)',
      email: 'john.sender@example.com',
      permission: UserPermission.sender,
      latitude: 37.7749, // San Francisco
      longitude: -122.4194,
      locationUpdatedAt: DateTime.now().subtract(const Duration(seconds: 10)),
    ),
    User(
      username: 'jane_sender',
      password: 'secure456',
      name: 'Jane Smith (Sender)',
      email: 'jane.sender@example.com',
      permission: UserPermission.sender,
      latitude: 34.0522, // Los Angeles
      longitude: -118.2437,
      locationUpdatedAt: DateTime.now().subtract(const Duration(seconds: 5)),
    ),
    User(
      username: 'alice_sender',
      password: 'alice789',
      name: 'Alice Wong (Sender)',
      email: 'alice.sender@example.com',
      permission: UserPermission.sender,
      latitude: 40.7128, // New York
      longitude: -74.0060,
      locationUpdatedAt: DateTime.now().subtract(const Duration(seconds: 15)),
    ),
    
    // Receiver Users - Can view sender locations and calculate distances
    User(
      username: 'bob_receiver',
      password: 'bob101',
      name: 'Bob Jones (Receiver)',
      email: 'bob.receiver@example.com',
      permission: UserPermission.receiver,
      latitude: 51.5074, // London
      longitude: -0.1278,
      locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    User(
      username: 'emma_receiver',
      password: 'emma202',
      name: 'Emma Brown (Receiver)',
      email: 'emma.receiver@example.com',
      permission: UserPermission.receiver,
      latitude: 48.8566, // Paris
      longitude: 2.3522,
      locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
    User(
      username: 'mike_receiver',
      password: 'mike303',
      name: 'Mike Wilson (Receiver)',
      email: 'mike.receiver@example.com',
      permission: UserPermission.receiver,
      latitude: 35.6762, // Tokyo
      longitude: 139.6503,
      locationUpdatedAt: DateTime.now().subtract(const Duration(minutes: 1)),
    ),
  ];

  // Get all sender users
  static List<User> getSenders() {
    return users.where((user) => user.isSender).toList();
  }

  // Get all receiver users
  static List<User> getReceivers() {
    return users.where((user) => user.isReceiver).toList();
  }

  // Update user location
  static void updateUserLocation({
    required String username,
    required double latitude,
    required double longitude,
  }) {
    final userIndex = users.indexWhere((user) => user.username == username);
    if (userIndex != -1) {
      final oldUser = users[userIndex];
      users[userIndex] = oldUser.copyWithLocation(
        latitude: latitude,
        longitude: longitude,
        locationUpdatedAt: DateTime.now(),
      );
    }
  }

  // Get user by username
  static User? getUserByUsername(String username) {
    try {
      return users.firstWhere((user) => user.username == username);
    } catch (e) {
      return null;
    }
  }

  // Get active senders (those with recent location updates)
  static List<User> getActiveSenders() {
    return getSenders().where((sender) => sender.hasRecentLocation).toList();
  }

  // Simulate location updates for demo purposes
  static void simulateLocationUpdates() {
    // This would be called periodically to simulate real location updates
    // In a real app, this would come from actual GPS updates from sender devices
    
    for (int i = 0; i < users.length; i++) {
      final user = users[i];
      if (user.isSender && user.latitude != null && user.longitude != null) {
        // Add small random variations to simulate movement
        final random = DateTime.now().millisecondsSinceEpoch % 1000;
        final latVariation = (random - 500) / 100000.0; // Very small movement
        final lngVariation = (random - 250) / 100000.0;
        
        users[i] = user.copyWithLocation(
          latitude: user.latitude! + latVariation,
          longitude: user.longitude! + lngVariation,
          locationUpdatedAt: DateTime.now(),
        );
      }
    }
  }
}