import 'dart:convert';
import 'dart:typed_data';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../disaster_mode/models/user_health_profile.dart';

class VulnerableGroupService {
  static final VulnerableGroupService _instance =
      VulnerableGroupService._internal();
  factory VulnerableGroupService() => _instance;
  VulnerableGroupService._internal();

  static const _keyIsVulnerable = 'vg_is_vulnerable';
  static const _keyProfileBytes = 'vg_profile_bytes';
  static const _keyLastLat = 'vg_last_lat';
  static const _keyLastLng = 'vg_last_lng';
  static const _keyLastLocationTime = 'vg_last_location_time';

  bool _isVulnerableGroup = false;
  UserHealthProfile _profile = UserHealthProfile.empty();
  double? _lastLat;
  double? _lastLng;
  DateTime? _lastLocationTime;

  bool get isVulnerableGroup => _isVulnerableGroup;
  UserHealthProfile get profile => _profile;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;
  DateTime? get lastLocationTime => _lastLocationTime;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isVulnerableGroup = prefs.getBool(_keyIsVulnerable) ?? false;

    final bytesJson = prefs.getString(_keyProfileBytes);
    if (bytesJson != null) {
      final list = (jsonDecode(bytesJson) as List).cast<int>();
      _profile = UserHealthProfile.fromBytes(Uint8List.fromList(list));
    }

    _lastLat = prefs.getDouble(_keyLastLat);
    _lastLng = prefs.getDouble(_keyLastLng);
    final timeMs = prefs.getInt(_keyLastLocationTime);
    _lastLocationTime = timeMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(timeMs);
  }

  Future<void> saveProfile({
    required UserHealthProfile profile,
    required bool isVulnerableGroup,
  }) async {
    _profile = profile;
    _isVulnerableGroup = isVulnerableGroup;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsVulnerable, isVulnerableGroup);
    await prefs.setString(
      _keyProfileBytes,
      jsonEncode(profile.toBytes().toList()),
    );
  }

  // ── Per-member profile storage ───────────────────────────────────────────

  static String _memberKey(String gatewayId, String memberName) =>
      'vg_m_${gatewayId}_${memberName.replaceAll(' ', '_')}';

  Future<(UserHealthProfile, bool)> loadMemberProfile(
    String gatewayId,
    String memberName,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _memberKey(gatewayId, memberName);
    final isVulnerable = prefs.getBool('${key}_v') ?? false;
    final bytesJson = prefs.getString('${key}_p');
    if (bytesJson == null) return (UserHealthProfile.empty(), isVulnerable);
    final list = (jsonDecode(bytesJson) as List).cast<int>();
    final profile = UserHealthProfile.fromBytes(Uint8List.fromList(list));
    return (profile, isVulnerable);
  }

  Future<void> saveMemberProfile(
    String gatewayId,
    String memberName,
    UserHealthProfile profile,
    bool isVulnerable,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _memberKey(gatewayId, memberName);
    await prefs.setBool('${key}_v', isVulnerable);
    await prefs.setString('${key}_p', jsonEncode(profile.toBytes().toList()));
  }

  Future<void> updateLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      _lastLocationTime = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyLastLat, pos.latitude);
      await prefs.setDouble(_keyLastLng, pos.longitude);
      await prefs.setInt(
        _keyLastLocationTime,
        _lastLocationTime!.millisecondsSinceEpoch,
      );
    } catch (_) {
      // Best-effort cache refresh. Existing cached location remains usable.
    }
  }
}

