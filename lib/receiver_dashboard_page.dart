// receiver_dashboard_page.dart - Updated to show real-time sender locations
import 'package:flutter/material.dart';
import 'dart:async';
import 'user.dart';
import 'sender_receiver_location_page.dart';
import 'dart:math' as math;


class ReceiverDashboardPage extends StatefulWidget {
  final User user;

  const ReceiverDashboardPage({super.key, required this.user});

  @override
  State<ReceiverDashboardPage> createState() => _ReceiverDashboardPageState();
}

class _ReceiverDashboardPageState extends State<ReceiverDashboardPage> {
  Timer? _refreshTimer;
  List<User> _senders = [];
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadSenders();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadSenders() {
    setState(() {
      _senders = UserDatabase.getSenders();
      _lastUpdated = DateTime.now();
    });
  }

  void _startAutoRefresh() {
    // Refresh sender list every 3 seconds to show updated locations
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadSenders();
    });
  }

  String _getLocationStatus(User sender) {
    if (sender.latitude == null || sender.longitude == null) {
      return 'Location not available';
    }

    // In a real app, you'd track when the location was last updated
    // For demo purposes, we'll assume it's recent if coordinates exist
    return 'Live location available';
  }

  Color _getLocationStatusColor(User sender) {
    if (sender.latitude == null || sender.longitude == null) {
      return Colors.red.shade600;
    }
    return Colors.green.shade600;
  }

  IconData _getLocationStatusIcon(User sender) {
    if (sender.latitude == null || sender.longitude == null) {
      return Icons.location_disabled;
    }
    return Icons.location_on;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.name} - Sender Locations'),
        actions: [
          // Auto-refresh indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.refresh,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  'Auto',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSenders,
            tooltip: 'Refresh Now',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Permission Info Card with Real-time Status
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.visibility, color: Colors.green.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receiver Permission - Real-time Access',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'You can view all sender locations in real-time and calculate distances to your location.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_lastUpdated != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.update,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Last refreshed: ${_formatTime(_lastUpdated!)} (Auto-refresh every 3s)',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Senders Count and Status
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Text(
                  'Available Senders (${_senders.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, size: 8, color: Colors.blue.shade600),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Senders List
          Expanded(
            child:
                _senders.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('No sender users available'),
                          SizedBox(height: 8),
                          Text(
                            'Sender users will appear here when they log in and share their location.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      itemCount: _senders.length,
                      itemBuilder: (context, index) {
                        final sender = _senders[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.only(bottom: 12.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16.0),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.blue.shade100,
                                  radius: 24,
                                  child: Text(
                                    sender.name
                                        .split(' ')
                                        .map((e) => e[0])
                                        .take(2)
                                        .join(),
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Location status indicator
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _getLocationStatusColor(sender),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      sender.latitude != null &&
                                              sender.longitude != null
                                          ? Icons.location_on
                                          : Icons.location_disabled,
                                      size: 8,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(
                              sender.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(sender.email),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      _getLocationStatusIcon(sender),
                                      size: 16,
                                      color: _getLocationStatusColor(sender),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        _getLocationStatus(sender),
                                        style: TextStyle(
                                          color: _getLocationStatusColor(
                                            sender,
                                          ),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (sender.latitude != null &&
                                        sender.longitude != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (sender.latitude != null &&
                                    sender.longitude != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Lat: ${sender.latitude!.toStringAsFixed(4)}, Lng: ${sender.longitude!.toStringAsFixed(4)}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton.icon(
                                  onPressed:
                                      () =>
                                          _viewSenderLocation(context, sender),
                                  icon: const Icon(Icons.map, size: 18),
                                  label: const Text('View Map'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    backgroundColor:
                                        sender.latitude != null &&
                                                sender.longitude != null
                                            ? null
                                            : Colors.grey.shade400,
                                  ),
                                ),
                                if (sender.latitude != null &&
                                    sender.longitude != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _calculateQuickDistance(sender),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),

          // Current User Info
          Container(
            margin: const EdgeInsets.all(16.0),
            child: Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'My Information',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Receiver Account',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow(context, 'Name', widget.user.name),
                    _buildInfoRow(context, 'Email', widget.user.email),
                    if (widget.user.latitude != null &&
                        widget.user.longitude != null) ...[
                      _buildInfoRow(
                        context,
                        'My Location',
                        '${widget.user.latitude!.toStringAsFixed(4)}, ${widget.user.longitude!.toStringAsFixed(4)}',
                      ),
                    ] else
                      _buildInfoRow(context, 'My Location', 'Not available'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _calculateQuickDistance(User sender) {
    if (sender.latitude == null ||
        sender.longitude == null ||
        widget.user.latitude == null ||
        widget.user.longitude == null) {
      return '';
    }

    // Calculate distance using Haversine formula (simplified)
    const double earthRadius = 6371; // km

    double lat1Rad = widget.user.latitude! * (3.14159 / 180);
    double lat2Rad = sender.latitude! * (3.14159 / 180);
    double deltaLatRad =
        (sender.latitude! - widget.user.latitude!) * (3.14159 / 180);
    double deltaLngRad =
        (sender.longitude! - widget.user.longitude!) * (3.14159 / 180);

    double a =
        (deltaLatRad / 2) * (deltaLatRad / 2) +
        math.cos(lat1Rad) *
        math.cos(lat2Rad) *
            (deltaLngRad / 2) *
            (deltaLngRad / 2);
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    double distance = earthRadius * c;

    if (distance < 1) {
      return '${(distance * 1000).toInt()}m';
    }
    return '${distance.toStringAsFixed(1)}km';
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  void _viewSenderLocation(BuildContext context, User sender) {
    if (sender.latitude == null || sender.longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${sender.name} location is not available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => SenderReceiverLocationPage(
              sender: sender,
              receiver: widget.user,
            ),
      ),
    );
  }
}
