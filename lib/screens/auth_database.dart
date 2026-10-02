import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Temporary local database for account creation and login.
/// Later, replace the bodies of register() and login() with calls to your
/// Laravel API. The screens won't need to change.
class AuthDatabase {
  AuthDatabase._();
  static final AuthDatabase instance = AuthDatabase._();

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final path = join(await getDatabasesPath(), 'gobike_local.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            full_name TEXT NOT NULL,
            email TEXT NOT NULL UNIQUE,
            mobile TEXT NOT NULL,
            barangay TEXT NOT NULL,
            role TEXT NOT NULL,
            password_hash TEXT NOT NULL,
            salt TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  // ---------- password helpers ----------

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String password, String salt) {
    return sha256.convert(utf8.encode(salt + password)).toString();
  }

  // ---------- public API ----------

  /// Returns null on success, or an error message to show the user.
  Future<String?> register({
    required String fullName,
    required String email,
    required String mobile,
    required String barangay,
    required String role,
    required String password,
  }) async {
    final db = await _database;
    final cleanEmail = email.trim().toLowerCase();

    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [cleanEmail],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      return 'An account with this email already exists';
    }

    final salt = _generateSalt();
    await db.insert('users', {
      'full_name': fullName.trim(),
      'email': cleanEmail,
      'mobile': mobile.trim(),
      'barangay': barangay,
      'role': role,
      'password_hash': _hash(password, salt),
      'salt': salt,
      'created_at': DateTime.now().toIso8601String(),
    });
    return null;
  }

  /// Returns the user row (without password info) if login is correct,
  /// otherwise null.
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final user = rows.first;
    final hash = _hash(password, user['salt'] as String);
    if (hash != user['password_hash']) return null;

    return {
      'id': user['id'],
      'full_name': user['full_name'],
      'email': user['email'],
      'mobile': user['mobile'],
      'barangay': user['barangay'],
      'role': user['role'],
    };
  }

  /// Handy while testing: wipes all accounts.
  Future<void> clearAllUsers() async {
    final db = await _database;
    await db.delete('users');
  }
}