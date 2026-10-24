// ---------------------------------------------------------------------------
// AuthService: talks to the Laravel API for login, signup, Google sign-in,
// session restore and logout.
//
// GOOGLE SIGN-IN SETUP (already done in Google Cloud):
//  * Android package name: com.rondago.app (register a new Android OAuth client)
//  * SHA-1 of this laptop's debug keystore is registered on the Android client
//  * kGoogleWebClientId (lib/core/api_config.dart) is the WEB client ID, used
//    as serverClientId so Google returns an ID token that Laravel can verify.
// ---------------------------------------------------------------------------
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'announcements.dart';
import 'appointments.dart';
import 'emergency_watcher.dart';
import 'follow_up_alerts.dart';
import 'push_service.dart';
import 'resident_sos.dart';
import 'resident_visits.dart';

/// A GoBiker's ronda days and hours, set by the admin.
class RondaSchedule {
  const RondaSchedule({
    required this.days,
    required this.start,
    required this.end,
  });

  final List<String> days; // e.g. ["Mon", "Wed", "Fri"]
  final String start; // "08:00"
  final String end; // "12:00"

  static RondaSchedule? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final days = (raw['days'] as List?)?.map((d) => '$d').toList() ?? [];
    final start = raw['start']?.toString();
    final end = raw['end']?.toString();
    if (days.isEmpty || start == null || end == null) return null;
    return RondaSchedule(days: days, start: start, end: end);
  }

  /// "Mon, Wed, Fri · 8:00 AM – 12:00 PM"
  String get label => '${days.join(', ')} · ${_time(start)} – ${_time(end)}';

  static String _time(String hhmm) {
    final parts = hhmm.split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h >= 12 ? 'PM' : 'AM'}';
  }
}

/// The logged-in person, as returned by the Laravel API.
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.mobile,
    this.barangay,
    this.schedule,
    this.hasPassword = true,
    this.notificationPrefs = const {},
  });

  final int id;
  final String name;
  final String email;
  final String role; // "User" (resident), "GoBiker" or "Admin"
  final String? mobile;
  final String? barangay;

  /// GoBikers only; null when the admin has not set one.
  final RondaSchedule? schedule;

  /// False for a Google sign-in account that never set its own password.
  final bool hasPassword;

  /// The resident's notification switches as saved on the server.
  final Map<String, bool> notificationPrefs;

  bool get hasMobile => (mobile ?? '').trim().isNotEmpty;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: (json['name'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
    role: (json['role'] ?? 'User').toString(),
    mobile: json['mobile']?.toString(),
    barangay: json['barangay']?.toString(),
    schedule: RondaSchedule.fromJson(json['schedule']),
    hasPassword: json['has_password'] != false,
    notificationPrefs: {
      if (json['notification_prefs'] is Map)
        for (final e in (json['notification_prefs'] as Map).entries)
          '${e.key}': e.value == true,
    },
  );

  String get firstName {
    final parts = name.trim().split(RegExp(r'\s+'));
    return (parts.isEmpty || parts.first.isEmpty) ? 'there' : parts.first;
  }

  bool get isGoBiker => role == 'GoBiker';
  bool get isResident => role == 'User';
  bool get isAdmin => role == 'Admin';
}

/// What a login / signup call returns to the screens.
class AuthResult {
  const AuthResult._({
    required this.ok,
    this.message,
    this.user,
    this.pendingApproval = false,
    this.cancelled = false,
  });

  final bool ok;
  final String? message;
  final AppUser? user;
  final bool pendingApproval;
  final bool cancelled;

  factory AuthResult.success({
    String? message,
    AppUser? user,
    bool pendingApproval = false,
  }) => AuthResult._(
    ok: true,
    message: message,
    user: user,
    pendingApproval: pendingApproval,
  );

  factory AuthResult.failure(String message) =>
      AuthResult._(ok: false, message: message);

  factory AuthResult.cancelled() =>
      const AuthResult._(ok: false, cancelled: true);
}

class _ApiResponse {
  const _ApiResponse(this.status, this.body, {this.networkError});

  final int status; // 0 means "could not reach the server"
  final Map<String, dynamic> body;
  final String? networkError;

  bool get ok => status >= 200 && status < 300;

  String get errorMessage {
    if (networkError != null) return networkError!;
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
      return first.toString();
    }
    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;
    return 'Something went wrong. Please try again.';
  }
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';
  static const _timeout = Duration(seconds: 15);
  static const _storage = FlutterSecureStorage();

  String? _token;
  AppUser? _user;
  bool _googleReady = false;

  AppUser? get currentUser => _user;
  String? get token => _token;
  bool get isLoggedIn => _token != null && _user != null;

  /// Headers for any authenticated call (used later by live tracking).
  Map<String, String> get authHeaders => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  //  HTTP

  Future<_ApiResponse> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool auth = false,
  }) async {
    final uri = Uri.parse('$kApiBaseUrl$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (auth && _token != null) 'Authorization': 'Bearer $_token',
    };

    try {
      final http.Response res;
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: headers).timeout(_timeout);
        case 'PUT':
          res = await http
              .put(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(_timeout);
        case 'DELETE':
          res = await http.delete(uri, headers: headers).timeout(_timeout);
        default:
          res = await http
              .post(uri, headers: headers, body: jsonEncode(body ?? {}))
              .timeout(_timeout);
      }

      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {
        // Not JSON; errorMessage falls back to a generic message.
      }
      return _ApiResponse(res.statusCode, json);
    } on TimeoutException {
      return const _ApiResponse(
        0,
        {},
        networkError: 'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      return const _ApiResponse(
        0,
        {},
        networkError: "Can't reach the server. Check your connection.",
      );
    } on http.ClientException {
      return const _ApiResponse(
        0,
        {},
        networkError: "Can't reach the server. Check your connection.",
      );
    } catch (_) {
      return const _ApiResponse(
        0,
        {},
        networkError: 'Something went wrong. Please try again.',
      );
    }
  }

  //  sessions

  Future<AuthResult> _sessionFrom(
    _ApiResponse res, {
    required bool remember,
  }) async {
    if (!res.ok) return AuthResult.failure(res.errorMessage);

    final token = res.body['token'];
    final userJson = res.body['user'];
    if (token is! String || userJson is! Map<String, dynamic>) {
      return AuthResult.failure('Unexpected response from the server.');
    }

    final user = AppUser.fromJson(userJson);
    _token = token;
    _user = user;

    // Remember me: save the token. If unchecked, make sure nothing is saved.
    try {
      if (remember) {
        await _storage.write(key: _tokenKey, value: token);
      } else {
        await _storage.delete(key: _tokenKey);
      }
    } catch (e) {
      debugPrint('[session] could not save the token: $e');
    }

    unawaited(PushService.instance.registerDevice());
    return AuthResult.success(
      user: user,
      message: res.body['message']?.toString(),
    );
  }

  /// Authenticated POST used by live tracking.
  /// `message` is empty when the call succeeds.
  Future<({bool ok, int status, String message})> postAuthed(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _request('POST', path, body: body, auth: true);
    return (
      ok: res.ok,
      status: res.status,
      message: res.ok ? '' : res.errorMessage,
    );
  }

  /// Updates a GoBiker profile. The API response must include the updated user.
  Future<({bool ok, String message})> updateGoBikerProfile({
    required String mobile,
    required String barangay,
    String? currentPassword,
    String? newPassword,
  }) async {
    final body = <String, dynamic>{
      'mobile': mobile.trim(),
      'barangay': barangay,
    };
    if (newPassword != null && newPassword.isNotEmpty) {
      body['current_password'] = currentPassword;
      body['password'] = newPassword;
      body['password_confirmation'] = newPassword;
    }

    final res = await _request(
      'PUT',
      '/gobiker/profile',
      body: body,
      auth: true,
    );
    if (!res.ok) {
      return (ok: false, message: res.errorMessage);
    }

    final userJson = res.body['user'];
    if (userJson is! Map<String, dynamic>) {
      return (
        ok: false,
        message: 'Profile update returned an unexpected server response.',
      );
    }
    _user = AppUser.fromJson(userJson);
    return (ok: true, message: '');
  }

  /// Updates a resident's name, mobile number and barangay.
  Future<({bool ok, String message})> updateResidentProfile({
    required String name,
    required String mobile,
    required String barangay,
  }) async {
    final res = await _request(
      'PUT',
      '/resident/profile',
      body: {
        'name': name.trim(),
        'mobile': mobile.trim(),
        'barangay': barangay,
      },
      auth: true,
    );
    if (!res.ok) return (ok: false, message: res.errorMessage);

    final userJson = res.body['user'];
    if (userJson is! Map<String, dynamic>) {
      return (ok: false, message: 'Unexpected response from the server.');
    }
    _user = AppUser.fromJson(userJson);
    return (ok: true, message: '');
  }

  /// Changes the password of any signed-in user. Other phones are signed out.
  Future<({bool ok, String message})> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _request(
      'PUT',
      '/mobile/password',
      body: {
        // A Google account setting its first password has no current one.
        if (currentPassword.isNotEmpty) 'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': newPassword,
      },
      auth: true,
    );
    final u = res.body['user'];
    if (res.ok && u is Map<String, dynamic>) _user = AppUser.fromJson(u);
    return (ok: res.ok, message: res.ok ? '' : res.errorMessage);
  }

  Future<void> _clearLocalSession() async {
    _token = null;
    _user = null;
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {}
  }

  /// Reloads the signed-in user (e.g. a schedule the admin just changed).
  /// Keeps the current user when the server can't be reached.
  Future<void> refreshUser() async {
    if (_token == null) return;
    final res = await _request('GET', '/mobile/me', auth: true);
    final u = res.body['user'];
    if (res.ok && u is Map<String, dynamic>) _user = AppUser.fromJson(u);
  }

  /// Called by the splash screen. Returns the user if a saved session is valid.
  Future<AppUser?> restoreSession() async {
    String? saved;
    try {
      saved = await _storage.read(key: _tokenKey);
    } catch (e) {
      debugPrint('[session] could not read the saved token: $e');
    }
    debugPrint(
      '[session] saved token found: ${saved != null && saved.isNotEmpty}',
    );
    if (saved == null || saved.isEmpty) return null;

    _token = saved;
    final res = await _request('GET', '/mobile/me', auth: true);
    debugPrint(
      '[session] /mobile/me -> status ${res.status} ${res.networkError ?? ''}',
    );

    if (res.ok) {
      final u = res.body['user'];
      if (u is Map<String, dynamic>) {
        _user = AppUser.fromJson(u);
        unawaited(PushService.instance.registerDevice());
        return _user;
      }
    }

    if (res.status == 401 || res.status == 403) {
      await _clearLocalSession(); // token no longer valid
    } else {
      _token = null; // server unreachable: keep the saved token for next time
    }
    return null;
  }

  // ---------------------------------------------------------- public calls

  Future<AuthResult> login({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final res = await _request(
      'POST',
      '/mobile/login',
      body: {'email': email.trim(), 'password': password},
    );
    return _sessionFrom(res, remember: remember);
  }

  /// [role] is "Resident" or "GoBiker".
  Future<AuthResult> register({
    required String name,
    required String email,
    required String mobile,
    required String barangay,
    required String role,
    required String password,
  }) async {
    final res = await _request(
      'POST',
      '/mobile/register',
      body: {
        'name': name.trim(),
        'email': email.trim(),
        'mobile': mobile.trim(),
        'barangay': barangay,
        'role': role,
        'password': password,
      },
    );

    if (!res.ok) return AuthResult.failure(res.errorMessage);

    return AuthResult.success(
      message: res.body['message']?.toString(),
      pendingApproval: res.body['pending_approval'] == true,
    );
  }

  Future<AuthResult> signInWithGoogle() async {
    if (kGoogleWebClientId.contains('PASTE_WEB_CLIENT_ID')) {
      return AuthResult.failure(
        'Google sign-in is not set up yet. Add your Web client ID in lib/core/api_config.dart.',
      );
    }

    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(
          serverClientId: kGoogleWebClientId,
        );
        _googleReady = true;
      }

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        return AuthResult.failure(
          'Google did not return a sign-in token. Check the Web client ID in api_config.dart.',
        );
      }

      final res = await _request(
        'POST',
        '/mobile/google',
        body: {'id_token': idToken},
      );
      return await _sessionFrom(res, remember: true);
    } on GoogleSignInException catch (e) {
      debugPrint('Google sign-in error: ${e.code} ${e.description}');
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return AuthResult.cancelled();
      }
      return AuthResult.failure('Google sign-in failed. Please try again.');
    } catch (e) {
      debugPrint('Google sign-in error: $e');
      return AuthResult.failure('Google sign-in failed. Please try again.');
    }
  }

  /// Authenticated JSON call. [method] is GET, POST, PUT or DELETE.
  /// `message` is empty when the call succeeds.
  Future<({bool ok, int status, String message, Map<String, dynamic> body})>
  callAuthed(String method, String path, {Map<String, dynamic>? body}) async {
    final res = await _request(method, path, body: body, auth: true);
    return (
      ok: res.ok,
      status: res.status,
      message: res.ok ? '' : res.errorMessage,
      body: res.body,
    );
  }

  /// Authenticated file upload (multipart/form-data). [files] maps a field
  /// name to a file path on the phone. Videos are large, so the wait is long.
  Future<({bool ok, int status, String message, Map<String, dynamic> body})>
  uploadAuthed(
    String path, {
    Map<String, String> fields = const {},
    required Map<String, String> files,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$kApiBaseUrl$path'))
          ..headers.addAll({
            'Accept': 'application/json',
            if (_token != null) 'Authorization': 'Bearer $_token',
          })
          ..fields.addAll(fields);

    try {
      for (final entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value),
        );
      }
      final streamed = await request.send().timeout(const Duration(minutes: 3));
      final res = await http.Response.fromStream(streamed);
      Map<String, dynamic> json = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}
      final api = _ApiResponse(res.statusCode, json);
      return (
        ok: api.ok,
        status: api.status,
        message: api.ok ? '' : api.errorMessage,
        body: json,
      );
    } on TimeoutException {
      return (
        ok: false,
        status: 0,
        message: 'The upload took too long. Please try again.',
        body: const <String, dynamic>{},
      );
    } catch (_) {
      return (
        ok: false,
        status: 0,
        message: "Can't reach the server. Check your connection.",
        body: const <String, dynamic>{},
      );
    }
  }

  Future<void> logout() async {
    await PushService.instance.unregisterDevice(); // while still signed in
    if (_token != null) {
      await _request('POST', '/mobile/logout', auth: true); // result ignored
    }
    await _clearLocalSession();
    await EmergencyWatcher.instance
        .reset(); // another account must not inherit it
    FollowUpAlerts.instance.reset();
    await Announcements.instance.reset();
    ResidentVisits.instance.reset();
    ResidentSos.instance.reset();
    GobikerAppointments.instance.reset();
    ResidentAppointments.instance.reset();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
