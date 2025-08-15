// sender_location_page.dart - Updated with Google Maps Web Helper
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user.dart';
import 'receiver_users_page.dart';
import 'google_maps_web_helper.dart'; // Import the helper
import 'dart:async';

// Web import
import 'package:universal_html/html.dart' as html;

class SenderLocationPage extends StatefulWidget {
  final User user;

  const SenderLocationPage({super.key, required this.user});

  @override
  State<SenderLocationPage> createState() => _SenderLocationPageState();
}

class _SenderLocationPageState extends State<SenderLocationPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isMapLoading = true;
  String? _errorMessage;
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();

  @override
  void initState() {
    super.initState();
    _initializeMapAndLocation();
  }

  Future<void> _initializeMapAndLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _isMapLoading = true;
        _errorMessage = null;
      });

      // Ensure Google Maps API is loaded for web
      if (kIsWeb) {
        await GoogleMapsWebHelper.instance.waitForMapsToLoad();
        setState(() => _isMapLoading = false);
      } else {
        setState(() => _isMapLoading = false);
      }

      // Get current location
      await _getCurrentLocation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: ${e.toString()}';
        _isLoading = false;
        _isMapLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      if (kIsWeb) {
        await _getWebLocation();
      } else {
        await _getMobileLocation();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getWebLocation() async {
    try {
      // Use a more robust approach for web geolocation
      final position = await html.window.navigator.geolocation
          .getCurrentPosition(enableHighAccuracy: true, timeout: Duration(milliseconds: 10000), maximumAge: Duration(milliseconds: 60000));
      
      setState(() {
        _currentPosition = Position(
          latitude: position.coords!.latitude!.toDouble(),
          longitude: position.coords!.longitude!.toDouble(),
          timestamp: DateTime.now(),
          accuracy: (position.coords!.accuracy ?? 0.0).toDouble(),
          altitude: (position.coords!.altitude ?? 0.0).toDouble(),
          heading: (position.coords!.heading ?? 0.0).toDouble(),
          speed: (position.coords!.speed ?? 0.0).toDouble(),
          speedAccuracy: 0.0,
          altitudeAccuracy: (position.coords!.altitudeAccuracy ?? 0.0).toDouble(),
          headingAccuracy: 0.0,
        );
      });
    } on html.PositionError catch (e) {
      String errorMessage;
      switch (e.code) {
        case 1: // PERMISSION_DENIED
          errorMessage = 'Location permission denied. Please enable location access.';
          break;
        case 2: // POSITION_UNAVAILABLE
          errorMessage = 'Location information unavailable.';
          break;
        case 3: // TIMEOUT
          errorMessage = 'Location request timed out.';
          break;
        default:
          errorMessage = 'Failed to get location: ${e.message}';
      }
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Failed to get web location: ${e.toString()}');
    }
  }

  Future<void> _getMobileLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied. Please grant location permission.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable location permission in settings.');
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    
    setState(() {
      _currentPosition = position;
    });
  }

  void _sendLocation() {
    if (_currentPosition != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReceiverUsersPage(
            sender: widget.user,
            senderLatitude: _currentPosition!.latitude,
            senderLongitude: _currentPosition!.longitude,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.name}\'s Location'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
          if (kIsWeb && GoogleMapsWebHelper.instance.isLoaded)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showMapInfo(),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
      return _buildErrorWidget();
    }

    if (_isLoading && _currentPosition == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Getting your location...'),
          ],
        ),
      );
    }

    return _buildLocationWidget();
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeMapAndLocation,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationWidget() {
    final position = _currentPosition;
    
    return Column(
      children: [
        Expanded(
          child: position != null
              ? GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(position.latitude, position.longitude),
                    zoom: 15,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId(widget.user.username),
                      position: LatLng(position.latitude, position.longitude),
                      infoWindow: InfoWindow(
                        title: widget.user.name,
                        snippet: 'Current Location',
                      ),
                    ),
                  },
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) {
                      _controller.complete(controller);
                    }
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  compassEnabled: true,
                  mapType: MapType.normal,
                )
              : Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_disabled, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Location not available'),
                      ],
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              if (position != null) ...[
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
                            Text(
                              'Current Location',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const Divider(),
                        _buildLocationRow('Latitude', position.latitude.toStringAsFixed(6)),
                        _buildLocationRow('Longitude', position.longitude.toStringAsFixed(6)),
                        _buildLocationRow('Accuracy', '${position.accuracy.toStringAsFixed(1)}m'),
                        if (position.altitude != 0)
                          _buildLocationRow('Altitude', '${position.altitude.toStringAsFixed(1)}m'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sendLocation,
                    icon: const Icon(Icons.send),
                    label: const Text('Send Location to Receiver'),
                  ),
                ),
              ] else ...[
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.location_disabled, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Location not available. Please grant location permission.'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Getting Location Again'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  void _showMapInfo() {
    final version = GoogleMapsWebHelper.instance.getGoogleMapsVersion();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google Maps Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: ${version ?? 'Unknown'}'),
            Text('API Loaded: ${GoogleMapsWebHelper.instance.isLoaded ? 'Yes' : 'No'}'),
            Text('Geometry Library: ${GoogleMapsWebHelper.instance.isLibraryLoaded('geometry') ? 'Loaded' : 'Not Loaded'}'),
            Text('Places Library: ${GoogleMapsWebHelper.instance.isLibraryLoaded('places') ? 'Loaded' : 'Not Loaded'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}