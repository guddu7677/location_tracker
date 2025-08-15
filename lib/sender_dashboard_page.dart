// sender_dashboard_page.dart - Updated with automatic location updates every 5 seconds
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user.dart';
import 'google_maps_web_helper.dart';
import 'dart:async';

// Web import
import 'package:universal_html/html.dart' as html;

class SenderDashboardPage extends StatefulWidget {
  final User user;

  const SenderDashboardPage({super.key, required this.user});

  @override
  State<SenderDashboardPage> createState() => _SenderDashboardPageState();
}

class _SenderDashboardPageState extends State<SenderDashboardPage> {
  Position? _currentPosition;
  bool _isLoading = true;
  bool _isMapLoading = true;
  String? _errorMessage;
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  Timer? _locationTimer;
  bool _hasLocationPermission = false;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initializeMapAndLocation();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
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

      // Request location permission and get initial location
      await _requestLocationPermission();
      
      // Start automatic location updates if permission granted
      if (_hasLocationPermission) {
        await _getCurrentLocation();
        _startLocationUpdates();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize: ${e.toString()}';
        _isLoading = false;
        _isMapLoading = false;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      if (kIsWeb) {
        // For web, we'll try to get location which will prompt for permission
        await _getWebLocation();
        _hasLocationPermission = true;
      } else {
        // For mobile, explicitly request permission
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

        _hasLocationPermission = true;
      }
    } catch (e) {
      _hasLocationPermission = false;
      rethrow;
    }
  }

  void _startLocationUpdates() {
    // Cancel any existing timer
    _locationTimer?.cancel();
    
    // Start timer for location updates every 5 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_hasLocationPermission) {
        _getCurrentLocation();
      }
    });

    // Also try to use position stream for more real-time updates on mobile
    if (!kIsWeb && _hasLocationPermission) {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10, // Update when moved 10 meters
        ),
      ).listen(
        (Position position) {
          setState(() {
            _currentPosition = position;
          });
          _updateUserLocationInDatabase(position);
          _updateMapCamera(position);
        },
        onError: (e) {
          print('Position stream error: $e');
        },
      );
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      if (!_hasLocationPermission) return;

      if (kIsWeb) {
        await _getWebLocation();
      } else {
        await _getMobileLocation();
      }

      // Update user location in the database
      if (_currentPosition != null) {
        _updateUserLocationInDatabase(_currentPosition!);
        _updateMapCamera(_currentPosition!);
      }
    } catch (e) {
      print('Location update error: $e');
      // Don't show error for automatic updates, just log it
    } finally {
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _updateUserLocationInDatabase(Position position) {
    // Find and update user location in the database
    final userIndex = UserDatabase.users.indexWhere(
      (u) => u.username == widget.user.username,
    );
    
    if (userIndex != -1) {
      // Create updated user with new location
      final updatedUser = User(
        username: widget.user.username,
        password: widget.user.password,
        name: widget.user.name,
        email: widget.user.email,
        permission: widget.user.permission,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      // Update in database
      UserDatabase.users[userIndex] = updatedUser;
      
      print('Updated ${widget.user.name} location: ${position.latitude}, ${position.longitude}');
    }
  }

  void _updateMapCamera(Position position) {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(position.latitude, position.longitude),
        ),
      );
    }
  }

  Future<void> _getWebLocation() async {
    try {
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
        case 1:
          errorMessage = 'Location permission denied. Please enable location access.';
          _hasLocationPermission = false;
          break;
        case 2:
          errorMessage = 'Location information unavailable.';
          break;
        case 3:
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
    if (!_hasLocationPermission) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      throw Exception('Failed to get mobile location: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.user.name} - My Location'),
        actions: [
          // Location status indicator
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasLocationPermission && _currentPosition != null
                      ? Icons.location_on
                      : Icons.location_disabled,
                  size: 20,
                  color: _hasLocationPermission && _currentPosition != null
                      ? Colors.green
                      : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  _hasLocationPermission && _currentPosition != null
                      ? 'Live'
                      : 'Off',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _getCurrentLocation,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                Navigator.pushNamedAndRemoveUntil(
                  context, '/login', (route) => false);
              }
            },
            itemBuilder: (context) => [
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

    if (_errorMessage != null && !_hasLocationPermission) {
      return _buildErrorWidget();
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
            const Icon(Icons.location_disabled, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Location Permission Required',
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
              child: const Text('Grant Location Permission'),
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
        // Permission Info Card with Live Updates Status
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16.0),
          child: Card(
            color: _hasLocationPermission ? Colors.green.shade50 : Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    _hasLocationPermission ? Icons.location_on : Icons.info_outline, 
                    color: _hasLocationPermission ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _hasLocationPermission ? 'Live Location Updates Active' : 'Sender Permission',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _hasLocationPermission ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _hasLocationPermission 
                              ? 'Your location is automatically updated every 5 seconds and shared with receivers.'
                              : 'You can only view your own location. Other users\' locations are not accessible.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (_hasLocationPermission && _currentPosition != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.update, size: 16, color: Colors.green.shade600),
                              const SizedBox(width: 4),
                              Text(
                                'Last updated: ${_formatTime(_currentPosition!.timestamp)}',
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
                ],
              ),
            ),
          ),
        ),
        
        // Map
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
                        snippet: 'My Current Location (Live Updates)',
                      ),
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isLoading ? Icons.location_searching : Icons.location_disabled, 
                          size: 64, 
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(_isLoading ? 'Getting your location...' : 'Location not available'),
                        if (_isLoading) ...[
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
        
        // Location Details
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
                              'My Current Location (Live)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 8, color: Colors.green.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      fontSize: 10,
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
                        _buildLocationRow('Latitude', position.latitude.toStringAsFixed(6)),
                        _buildLocationRow('Longitude', position.longitude.toStringAsFixed(6)),
                        _buildLocationRow('Accuracy', '${position.accuracy.toStringAsFixed(1)}m'),
                        if (position.altitude != 0)
                          _buildLocationRow('Altitude', '${position.altitude.toStringAsFixed(1)}m'),
                        _buildLocationRow('Last Update', _formatTime(position.timestamp)),
                      ],
                    ),
                  ),
                ),
              ] else if (!_isLoading) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.location_disabled, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
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
                    onPressed: _initializeMapAndLocation,
                    icon: const Icon(Icons.location_on),
                    label: const Text('Enable Location Updates'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
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
}