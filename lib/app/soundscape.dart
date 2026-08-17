import 'package:flutter/services.dart';

/// Local, low-volume ambience. Native players keep the loop outside Dart UI.
class Soundscape {
  Soundscape._();

  static const _channel = MethodChannel('namethatbaby/soundscape');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod<void>('startAmbience');
    } on PlatformException {
      // Audio is optional; continue silently if a platform player is absent.
    } on MissingPluginException {
      // Web and widget tests have no native player.
    }
  }
}
