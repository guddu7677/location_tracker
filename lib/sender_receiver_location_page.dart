// sender_receiver_location_page.dart - Updated with real-time location tracking
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user.dart';
import 'google_maps_web_helper.dart';
import 'dart:async';

// Web import
import 'package:universal_html/html.dart' as html;

class SenderReceiverLocationPage extends StatefulWidget {
  final User sender;
  final User receiver;

  const SenderReceiverLocationPage({
    super.key,
    required this.sender,
    required this.receiver,
  });

  @override
  State<SenderReceiverLocationPage> createState() =>
      _SenderReceiverLocationPageState();
}

class _SenderReceiverLocationPageState
    extends State<SenderReceiverLocationPage> {
  GoogleMapController? _mapController;
  double? _distance;
  bool _isMapLoading = true;
  bool _isLocationLoading = false;
  String? _errorMessage;
  Position? _receiverCurrentPosition;
  Timer? _refreshTimer;
  User? _currentSender;

  @override
  void initState() {
    super.initState();
    _currentSender = widget.sender;
    _initializeMap();
    _calculateDistance();
    _startLocationRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    try {
      setState(() {
        _isMapLoading = true;
        _errorMessage = null;
      });

      // Ensure Google Maps API is loaded for web
      if (kIsWeb) {
        await GoogleMapsWebHelper.instance.waitForMapsToLoad();
      }

      setState(() => _isMapLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load map: ${e.toString()}';
        _isMapLoading = false;
      });
    }
  }

  void _startLocationRefresh() {
    // Refresh sender location from database every 2 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      final updatedSender = UserDatabase.getUserByUsername(
        widget.sender.username,
      );
      if (updatedSender != null) {
        setState(() {
          _currentSender = updatedSender;
        });
        _calculateDistance();
        _updateMapView();
      }
    });
  }

  void _calculateDistance() {
    final sender = _currentSender;
    if (sender?.latitude != null &&
        sender?.longitude != null &&
        (_receiverCurrentPosition?.latitude ?? widget.receiver.latitude) !=
            null &&
        (_receiverCurrentPosition?.longitude ?? widget.receiver.longitude) !=
            null) {
      final receiverLat =
          _receiverCurrentPosition?.latitude ?? widget.receiver.latitude!;
      final receiverLng =
          _receiverCurrentPosition?.longitude ?? widget.receiver.longitude!;

      setState(() {
        _distance =
            Geolocator.distanceBetween(
              sender!.latitude!,
              sender.longitude!,
              receiverLat,
              receiverLng,
            ) /
            1000; // Convert to kilometers
      });
    }
  }

  void _updateMapView() {
    if (_mapController != null && _currentSender != null) {
      final sender = _currentSender!;
      final receiverLat =
          _receiverCurrentPosition?.latitude ?? widget.receiver.latitude;
      final receiverLng =
          _receiverCurrentPosition?.longitude ?? widget.receiver.longitude;

      if (sender.latitude != null &&
          sender.longitude != null &&
          receiverLat != null &&
          receiverLng != null) {
        // Calculate bounds to show both locations
        final bounds = LatLngBounds(
          southwest: LatLng(
            sender.latitude! < receiverLat ? sender.latitude! : receiverLat,
            sender.longitude! < receiverLng ? sender.longitude! : receiverLng,
          ),
          northeast: LatLng(
            sender.latitude! > receiverLat ? sender.latitude! : receiverLat,
            sender.longitude! > receiverLng ? sender.longitude! : receiverLng,
          ),
        );

        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
      }
    }
  }

  Future<void> _updateReceiverLocation() async {
    try {
      setState(() {
        _isLocationLoading = true;
        _errorMessage = null;
      });

      if (kIsWeb) {
        await _getWebLocation();
      } else {
        await _getMobileLocation();
      }

      // Recalculate distance with new receiver location
      _calculateDistance();
      _updateMapView();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _getWebLocation() async {
    try {
      final position = await html.window.navigator.geolocation
          .getCurrentPosition(
            enableHighAccuracy: true,
            timeout: Duration(milliseconds: 10000),
          );

      setState(() {
        _receiverCurrentPosition = Position(
          latitude: position.coords!.latitude!.toDouble(),
          longitude: position.coords!.longitude!.toDouble(),
          timestamp: DateTime.now(),
          accuracy: (position.coords!.accuracy ?? 0.0).toDouble(),
          altitude: (position.coords!.altitude ?? 0.0).toDouble(),
          heading: (position.coords!.heading ?? 0.0).toDouble(),
          speed: (position.coords!.speed ?? 0.0).toDouble(),
          speedAccuracy: 0.0,
          altitudeAccuracy:
              (position.coords!.altitudeAccuracy ?? 0.0).toDouble(),
          headingAccuracy: 0.0,
        );
      });
    } catch (e) {
      throw Exception('Failed to get current location: ${e.toString()}');
    }
  }

  Future<void> _getMobileLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    setState(() {
      _receiverCurrentPosition = position;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sender = _currentSender ?? widget.sender;

    // Determine which receiver location to use (current GPS or stored)
    final receiverLat =
        _receiverCurrentPosition?.latitude ?? widget.receiver.latitude;
    final receiverLng =
        _receiverCurrentPosition?.longitude ?? widget.receiver.longitude;

    final senderPosition =
        sender.latitude != null && sender.longitude != null
            ? LatLng(sender.latitude!, sender.longitude!)
            : null;

    final receiverPosition =
        receiverLat != null && receiverLng != null
            ? LatLng(receiverLat, receiverLng)
            : null;

    // Calculate bounds for the map
    LatLngBounds? bounds;
    if (senderPosition != null && receiverPosition != null) {
      bounds = LatLngBounds(
        southwest: LatLng(
          senderPosition.latitude < receiverPosition.latitude
              ? senderPosition.latitude
              : receiverPosition.latitude,
          senderPosition.longitude < receiverPosition.longitude
              ? senderPosition.longitude
              : receiverPosition.longitude,
        ),
        northeast: LatLng(
          senderPosition.latitude > receiverPosition.latitude
              ? senderPosition.latitude
              : receiverPosition.latitude,
          senderPosition.longitude > receiverPosition.longitude
              ? senderPosition.longitude
              : receiverPosition.longitude,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text('${sender.name} → ${widget.receiver.name}')),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 8, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon:
                _isLocationLoading
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.my_location),
            onPressed: _isLocationLoading ? null : _updateReceiverLocation,
            tooltip: 'Update My Current Location',
          ),
        ],
      ),
      body: _buildBody(
        senderPosition,
        receiverPosition,
        bounds,
        receiverLat,
        receiverLng,
        sender,
      ),
    );
  }

  Widget _buildBody(
    LatLng? senderPosition,
    LatLng? receiverPosition,
    LatLngBounds? bounds,
    double? receiverLat,
    double? receiverLng,
    User sender,
  ) {
    if (_isMapLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading Google Maps...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_errorMessage'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initializeMap,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Real-time Status Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16.0),
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.track_changes, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Real-time Location Tracking',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sender location updates automatically every 5 seconds',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (sender.locationUpdatedAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.update,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Last updated: ${_formatTime(sender.locationUpdatedAt!)}',
                                style: TextStyle(
                                  color: Colors.blue.shade600,
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
                ],
              ),
            ),
          ),
        ),

        // Map
        Expanded(
          flex: 2,
          child:
              senderPosition != null || receiverPosition != null
                  ? GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target:
                          senderPosition ??
                          receiverPosition ??
                          const LatLng(0, 0),
                      zoom: 10,
                    ),
                    markers: _buildMarkers(
                      senderPosition,
                      receiverPosition,
                      sender,
                    ),
                    polylines: _buildPolylines(
                      senderPosition,
                      receiverPosition,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      if (bounds != null) {
                        Future.delayed(const Duration(milliseconds: 500), () {
                          controller.animateCamera(
                            CameraUpdate.newLatLngBounds(bounds, 50),
                          );
                        });
                      }
                    },
                    myLocationEnabled: false,
                    compassEnabled: true,
                    mapType: MapType.normal,
                  )
                  : Container(
                    color: Colors.grey[200],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_disabled,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text('Location data not available'),
                        ],
                      ),
                    ),
                  ),
        ),

        // Location Details
        Expanded(
          flex: 1,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Distance Card
                if (_distance != null)
                  Card(
                    color: Colors.green.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(Icons.straighten, color: Colors.green.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Real-time Distance',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_distance!.toStringAsFixed(2)} km',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'LIVE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Sender Location Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.send, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Sender: ${sender.name}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            if (sender.hasRecentLocation)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.circle,
                                      size: 6,
                                      color: Colors.green.shade600,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'LIVE',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const Divider(),
                        if (sender.latitude != null &&
                            sender.longitude != null) ...[
                          _buildLocationRow(
                            'Latitude',
                            sender.latitude!.toStringAsFixed(6),
                          ),
                          _buildLocationRow(
                            'Longitude',
                            sender.longitude!.toStringAsFixed(6),
                          ),
                          if (sender.locationUpdatedAt != null)
                            _buildLocationRow(
                              'Updated',
                              _formatDateTime(sender.locationUpdatedAt!),
                            ),
                        ] else
                          const Text('Location not available'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Receiver Location Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Receiver: ${widget.receiver.name} (You)',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (receiverLat != null && receiverLng != null) ...[
                          _buildLocationRow(
                            'Latitude',
                            receiverLat.toStringAsFixed(6),
                          ),
                          _buildLocationRow(
                            'Longitude',
                            receiverLng.toStringAsFixed(6),
                          ),
                          if (_receiverCurrentPosition != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.update,
                                  size: 16,
                                  color: Colors.green.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Using current GPS location',
                                  style: TextStyle(
                                    color: Colors.green.shade600,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: Colors.orange.shade600,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Using stored location',
                                  style: TextStyle(
                                    color: Colors.orange.shade600,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ] else
                          const Text('Location not available'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Update Location Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isLocationLoading ? null : _updateReceiverLocation,
                    icon:
                        _isLocationLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.my_location),
                    label: Text(
                      _isLocationLoading
                          ? 'Getting Location...'
                          : 'Update My Current Location',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Set<Marker> _buildMarkers(
    LatLng? senderPosition,
    LatLng? receiverPosition,
    User sender,
  ) {
    Set<Marker> markers = {};

    if (senderPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('sender_${sender.username}'),
          position: senderPosition,
          infoWindow: InfoWindow(
            title: sender.name,
            snippet:
                sender.hasRecentLocation
                    ? 'Live Sender Location'
                    : 'Sender Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            sender.hasRecentLocation
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    if (receiverPosition != null) {
      markers.add(
        Marker(
          markerId: MarkerId('receiver_${widget.receiver.username}'),
          position: receiverPosition,
          infoWindow: InfoWindow(
            title: widget.receiver.name,
            snippet:
                _receiverCurrentPosition != null
                    ? 'Your Current Location'
                    : 'Your Stored Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(
    LatLng? senderPosition,
    LatLng? receiverPosition,
  ) {
    Set<Polyline> polylines = {};

    if (senderPosition != null && receiverPosition != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('distance_line'),
          points: [senderPosition, receiverPosition],
          color: Colors.red,
          width: 3,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      );
    }

    return polylines;
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dateTime) {
    return '${_formatTime(dateTime)} (${DateTime.now().difference(dateTime).inSeconds}s ago)';
  }

  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
