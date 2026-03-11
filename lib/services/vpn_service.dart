import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

class VpnService extends ChangeNotifier {
  late FlutterV2ray _v2rayPlugin;
  
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _currentConfig;
  int _uploadSpeed = 0;
  int _downloadSpeed = 0;
  String _duration = "00:00:00";

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get currentConfig => _currentConfig;
  int get uploadSpeed => _uploadSpeed;
  int get downloadSpeed => _downloadSpeed;
  String get duration => _duration;

  VpnService() {
    _initializeV2Ray();
  }

  Future<void> _initializeV2Ray() async {
    try {
      // Initialize V2Ray with status callback
      _v2rayPlugin = FlutterV2ray(
        onStatusChanged: (status) {
          _handleStatusChange(status);
        },
      );
    } catch (e) {
      debugPrint('Error initializing V2Ray: $e');
    }
  }

  void _handleStatusChange(V2RayStatus status) {
    switch (status.state) {
      case "CONNECTED":
        _isConnected = true;
        _isConnecting = false;
        _uploadSpeed = status.uploadSpeed?.toInt() ?? 0;
        _downloadSpeed = status.downloadSpeed?.toInt() ?? 0;
        _duration = status.duration ?? "00:00:00";
        break;
      case "DISCONNECTED":
        _isConnected = false;
        _isConnecting = false;
        _uploadSpeed = 0;
        _downloadSpeed = 0;
        _duration = "00:00:00";
        break;
      case "CONNECTING":
        _isConnecting = true;
        _isConnected = false;
        break;
    }
    notifyListeners();
  }

  Future<bool> connect(String config) async {
    if (_isConnecting || _isConnected) return false;

    try {
      _isConnecting = true;
      _currentConfig = config;
      notifyListeners();

      // Request VPN permission
      bool? permissionGranted = await _v2rayPlugin.requestPermission();
      
      if (permissionGranted != true) {
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      // Start V2Ray service
      await _v2rayPlugin.startV2Ray(
        remark: "Pingo VPN",
        config: config,
      );
      
      return true;
    } catch (e) {
      debugPrint('Error connecting to VPN: $e');
      _isConnecting = false;
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _v2rayPlugin.stopV2Ray();
      _isConnected = false;
      _isConnecting = false;
      _currentConfig = null;
      _uploadSpeed = 0;
      _downloadSpeed = 0;
      _duration = "00:00:00";
      notifyListeners();
    } catch (e) {
      debugPrint('Error disconnecting VPN: $e');
    }
  }

  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B/s';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB/s';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}