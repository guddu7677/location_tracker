// google_maps_web_helper.dart
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';

/// Helper class to manage Google Maps API loading for Flutter Web
class GoogleMapsWebHelper {
  static GoogleMapsWebHelper? _instance;
  static GoogleMapsWebHelper get instance => _instance ??= GoogleMapsWebHelper._();
  
  GoogleMapsWebHelper._();
  
  bool _isLoaded = false;
  Completer<void>? _loadingCompleter;
  
  /// Check if Google Maps API is loaded
  bool get isLoaded => _isLoaded;
  
  /// Wait for Google Maps API to be loaded
  Future<void> waitForMapsToLoad() async {
    if (_isLoaded) return;
    
    // If already loading, wait for the existing operation
    if (_loadingCompleter != null) {
      return _loadingCompleter!.future;
    }
    
    _loadingCompleter = Completer<void>();
    
    try {
      // Check if Google Maps is already available
      if (_checkIfGoogleMapsIsAvailable()) {
        _isLoaded = true;
        _loadingCompleter!.complete();
        return;
      }
      
      // Wait for the google-maps-loaded event
      await _waitForGoogleMapsEvent();
      
      _isLoaded = true;
      _loadingCompleter!.complete();
    } catch (e) {
      _loadingCompleter!.completeError(e);
      rethrow;
    } finally {
      _loadingCompleter = null;
    }
  }
  
  /// Force load Google Maps API if not already loaded
  Future<void> loadGoogleMapsAPI() async {
    if (!kIsWeb) return;
    
    if (_isLoaded) return;
    
    try {
      // Try to use the loader from the web page
      if (js.context.hasProperty('googleMapsLoader')) {
        await _promiseToFuture(js.context['googleMapsLoader'].callMethod('load'));
        _isLoaded = true;
      } else {
        // Fallback: wait for the event
        await _waitForGoogleMapsEvent();
        _isLoaded = true;
      }
    } catch (e) {
      throw Exception('Failed to load Google Maps API: $e');
    }
  }
  
  /// Check if Google Maps API is available in the JavaScript context
  bool _checkIfGoogleMapsIsAvailable() {
    if (!kIsWeb) return false;
    
    try {
      return js.context.hasProperty('google') &&
             js.context['google'] != null &&
             js.context['google'].hasProperty('maps') &&
             js.context['google']['maps'] != null;
    } catch (e) {
      return false;
    }
  }
  
  /// Wait for the google-maps-loaded custom event
  Future<void> _waitForGoogleMapsEvent() async {
    final completer = Completer<void>();
    late html.EventListener listener;
    
    listener = (html.Event event) {
      html.window.removeEventListener('google-maps-loaded', listener);
      completer.complete();
    };
    
    html.window.addEventListener('google-maps-loaded', listener);
    
    // Add timeout to prevent indefinite waiting
    Timer(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        html.window.removeEventListener('google-maps-loaded', listener);
        completer.completeError(TimeoutException(
          'Timeout waiting for Google Maps API to load',
          const Duration(seconds: 15),
        ));
      }
    });
    
    return completer.future;
  }
  
  /// Convert JavaScript Promise to Dart Future
  Future<T> _promiseToFuture<T>(js.JsObject promise) {
    final completer = Completer<T>();
    
    promise.callMethod('then', [
      (result) => completer.complete(result),
      (error) => completer.completeError(error),
    ]);
    
    return completer.future;
  }
  
  /// Get Google Maps API version info (if available)
  String? getGoogleMapsVersion() {
    if (!kIsWeb || !_isLoaded) return null;
    
    try {
      return js.context['google']['maps']['version'];
    } catch (e) {
      return null;
    }
  }
  
  /// Check if specific Google Maps libraries are loaded
  bool isLibraryLoaded(String libraryName) {
    if (!kIsWeb || !_isLoaded) return false;
    
    try {
      switch (libraryName) {
        case 'geometry':
          return js.context['google']['maps'].hasProperty('geometry');
        case 'places':
          return js.context['google']['maps'].hasProperty('places');
        case 'drawing':
          return js.context['google']['maps'].hasProperty('drawing');
        case 'visualization':
          return js.context['google']['maps'].hasProperty('visualization');
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }
}

/// Extension to make it easier to use with GoogleMap widget
extension GoogleMapControllerExtension on GoogleMapsWebHelper {
  /// Ensure Google Maps is loaded before creating map
  static Future<void> ensureInitialized() async {
    if (kIsWeb) {
      await GoogleMapsWebHelper.instance.waitForMapsToLoad();
    }
  }
}