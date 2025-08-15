import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'user.dart';

class ReceiverLocationPage extends StatefulWidget {
  final User sender;
  final User receiver;
  final double senderLatitude;
  final double senderLongitude;

  const ReceiverLocationPage({
    super.key,
    required this.sender,
    required this.receiver,
    required this.senderLatitude,
    required this.senderLongitude,
  });

  @override
  State<ReceiverLocationPage> createState() => _ReceiverLocationPageState();
}

class _ReceiverLocationPageState extends State<ReceiverLocationPage> {
  GoogleMapController? _mapController;
  double? _distance;

  @override
  void initState() {
    super.initState();
    if (widget.receiver.latitude != null && widget.receiver.longitude != null) {
      _distance = Geolocator.distanceBetween(
        widget.senderLatitude,
        widget.senderLongitude,
        widget.receiver.latitude!,
        widget.receiver.longitude!,
      ) / 1000; // Convert to kilometers
    }
  }

  @override
  Widget build(BuildContext context) {
    final senderPosition = LatLng(widget.senderLatitude, widget.senderLongitude);
    final receiverPosition = widget.receiver.latitude != null &&
            widget.receiver.longitude != null
        ? LatLng(widget.receiver.latitude!, widget.receiver.longitude!)
        : senderPosition;

    final bounds = LatLngBounds(
      southwest: LatLng(
        widget.senderLatitude < (widget.receiver.latitude ?? widget.senderLatitude)
            ? widget.senderLatitude
            : (widget.receiver.latitude ?? widget.senderLatitude),
        widget.senderLongitude <
                (widget.receiver.longitude ?? widget.senderLongitude)
            ? widget.senderLongitude
            : (widget.receiver.longitude ?? widget.senderLongitude),
      ),
      northeast: LatLng(
        widget.senderLatitude > (widget.receiver.latitude ?? widget.senderLatitude)
            ? widget.senderLatitude
            : (widget.receiver.latitude ?? widget.senderLatitude),
        widget.senderLongitude >
                (widget.receiver.longitude ?? widget.senderLongitude)
            ? widget.senderLongitude
            : (widget.receiver.longitude ?? widget.senderLongitude),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${widget.sender.name} to ${widget.receiver.name}')),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: senderPosition,
                zoom: 10,
              ),
              markers: {
                Marker(
                  markerId: MarkerId(widget.sender.username),
                  position: senderPosition,
                  infoWindow: InfoWindow(
                    title: widget.sender.name,
                    snippet: 'Sender Location',
                  ),
                ),
                if (widget.receiver.latitude != null &&
                    widget.receiver.longitude != null)
                  Marker(
                    markerId: MarkerId(widget.receiver.username),
                    position: receiverPosition,
                    infoWindow: InfoWindow(
                      title: widget.receiver.name,
                      snippet: 'Receiver Location',
                    ),
                  ),
              },
              onMapCreated: (controller) {
                _mapController = controller;
                controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sender (${widget.sender.name}):',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${widget.senderLatitude.toStringAsFixed(4)}, ${widget.senderLongitude.toStringAsFixed(4)}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                if (widget.receiver.latitude != null &&
                    widget.receiver.longitude != null) ...[
                  Text(
                    'Receiver (${widget.receiver.name}):',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${widget.receiver.latitude!.toStringAsFixed(4)}, ${widget.receiver.longitude!.toStringAsFixed(4)}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Distance: ${_distance!.toStringAsFixed(2)} km',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ] else
                  Text(
                    'Receiver location not available.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
              ],
            ),
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