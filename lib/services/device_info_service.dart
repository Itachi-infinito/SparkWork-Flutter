import 'dart:io';
import 'dart:math';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

final deviceInfoServiceProvider =
    Provider<DeviceInfoService>((ref) => DeviceInfoService());

class DeviceInfoService {
  static const _deviceIdKey = 'sparkwork_device_id';
  final _storage = const FlutterSecureStorage();

  String? _cachedDeviceId;

  /// Identifiant stable et unique de cet appareil, généré une fois à
  /// l'installation et persisté dans le keychain/keystore sécurisé du
  /// système (survit aux mises à jour de l'app, pas aux réinstallations).
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    String? id = await _storage.read(key: _deviceIdKey);
    if (id == null || id.isEmpty) {
      id = _generateId();
      await _storage.write(key: _deviceIdKey, value: id);
    }
    _cachedDeviceId = id;
    return id;
  }

  String _generateId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(32, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> getDeviceModel() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return '${info.manufacturer} ${info.model}';
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return info.utsname.machine;
      }
    } catch (_) {}
    return 'Appareil inconnu';
  }

  Future<String> getDeviceOS() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final info = await plugin.androidInfo;
        return 'Android ${info.version.release}';
      }
      if (Platform.isIOS) {
        final info = await plugin.iosInfo;
        return 'iOS ${info.systemVersion}';
      }
    } catch (_) {}
    return Platform.operatingSystem;
  }

  Future<String> getAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return '${info.version}+${info.buildNumber}';
    } catch (_) {
      return 'inconnu';
    }
  }
}
