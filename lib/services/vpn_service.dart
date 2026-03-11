import 'package:flutter/foundation.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

class VpnService extends ChangeNotifier {
  final FlutterV2ray _v2rayPlugin = FlutterV2ray();
  
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
      // Listen to connection status
      _v2rayPlugin.v2rayStatus.listen((status) {
        if (status.state == "CONNECTED") {
          _isConnected = true;
          _isConnecting = false;
          _uploadSpeed = status.uploadSpeed.toInt();
          _downloadSpeed = status.downloadSpeed.toInt();
          _duration = status.duration;
          notifyListeners();
        } else if (status.state == "DISCONNECTED") {
          _isConnected = false;
          _isConnecting = false;
          _uploadSpeed = 0;
          _downloadSpeed = 0;
          _duration = "00:00:00";
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('Error initializing V2Ray: $e');
    }
  }

  Future<bool> connect(String config) async {
    if (_isConnecting || _isConnected) return false;

    try {
      _isConnecting = true;
      _currentConfig = config;
      notifyListeners();

      // Parse and validate config
      String? remark = await _v2rayPlugin.parseConfig(config);
      
      if (remark == null) {
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      // Request VPN permission
      bool? permissionGranted = await _v2rayPlugin.requestPermission();
      
      if (permissionGranted != true) {
        _isConnecting = false;
        notifyListeners();
        return false;
      }

      // Connect to VPN
      await _v2rayPlugin.connect(config);
      
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
      await _v2rayPlugin.disconnect();
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
