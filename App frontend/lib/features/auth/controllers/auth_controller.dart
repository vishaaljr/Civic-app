// lib/features/auth/controllers/auth_controller.dart
// Calls the real Django REST / JWT backend.
// JWT access token stored in flutter_secure_storage.
// User name/role cached in SharedPreferences for fast session restore.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../issues/models/user.dart';
import '../../issues/models/issue_status.dart';
import '../models/auth_state.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/services/api_service.dart';

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._prefs) : super(_loadState(_prefs));

  final SharedPreferences _prefs;

  static AuthState _loadState(SharedPreferences prefs) {
    final userId = prefs.getString(AppConstants.keyUserId);
    final roleStr = prefs.getString(AppConstants.keyUserRole);
    final name = prefs.getString(AppConstants.keyUserName) ?? '';
    final email = prefs.getString(AppConstants.keyUserEmail) ?? '';

    if (userId != null && roleStr != null) {
      final role = roleStr == 'admin' || roleStr == 'authority'
          ? UserRole.admin
          : UserRole.citizen;
      return AuthState(
        user: AppUser(id: userId, name: name, email: email, role: role),
        isAuthenticated: true,
        isOnboarded: true,
      );
    }
    return const AuthState(isAuthenticated: false, isOnboarded: false);
  }

  /// Register a new user via the Django backend. Returns null on success, error string on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final response = await ApiService.post(
        '/auth/register/',
        {
          'username': email,
          'email': email,
          'password': password,
          'role': role == UserRole.admin ? 'authority' : 'citizen',
        },
        authenticated: false,
      );

      if (!ApiService.isSuccess(response)) {
        final data = ApiService.decodeResponse(response);
        if (data is Map) {
          final msg = data.values.first;
          return msg is List ? msg.first.toString() : msg.toString();
        }
        return 'Registration failed.';
      }

      // Auto-login after registration
      return login(email: email, password: password, role: role);
    } catch (e) {
      return 'Network error: $e';
    }
  }

  /// Login via Django JWT endpoint. Returns null on success, error string on failure.
  Future<String?> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final response = await ApiService.post(
        '/auth/login/',
        {'username': email, 'password': password},
        authenticated: false,
      );

      if (!ApiService.isSuccess(response)) {
        return 'Invalid credentials. Please try again.';
      }

      final data = ApiService.decodeResponse(response) as Map<String, dynamic>;
      final token = data['access'] as String?;
      if (token == null) return 'Login failed: no token received.';

      await ApiService.saveToken(token);

      // Fetch user profile to get role and id
      final meResponse = await ApiService.get('/auth/me/');
      String userId = email;
      String actualRole = role.name;
      String fetchedName = email;

      if (ApiService.isSuccess(meResponse)) {
        final me = ApiService.decodeResponse(meResponse) as Map<String, dynamic>;
        userId = me['id']?.toString() ?? email;
        actualRole = me['role'] as String? ?? role.name;
        fetchedName = me['username'] as String? ?? email;
      }

      final resolvedRole = actualRole == 'authority' || actualRole == 'admin'
          ? UserRole.admin
          : UserRole.citizen;

      final user = AppUser(
        id: userId,
        name: fetchedName,
        email: email,
        role: resolvedRole,
      );

      await _persistSession(user);
      state = AuthState(user: user, isAuthenticated: true, isOnboarded: true);
      return null;
    } catch (e) {
      return 'Network error: $e';
    }
  }

  Future<void> _persistSession(AppUser user) async {
    await _prefs.setString(AppConstants.keyUserId, user.id);
    await _prefs.setString(AppConstants.keyUserRole, user.role.name);
    await _prefs.setString(AppConstants.keyUserName, user.name);
    await _prefs.setString(AppConstants.keyUserEmail, user.email);
  }

  Future<void> switchToAdmin() async {
    if (state.user == null) return;
    final updated = state.user!.copyWith(role: UserRole.admin);
    await _prefs.setString(AppConstants.keyUserRole, 'admin');
    state = state.copyWith(user: updated);
  }

  Future<void> switchToCitizen() async {
    if (state.user == null) return;
    final updated = state.user!.copyWith(role: UserRole.citizen);
    await _prefs.setString(AppConstants.keyUserRole, 'citizen');
    state = state.copyWith(user: updated);
  }

  Future<void> updateName(String name) async {
    if (state.user == null) return;
    final updated = state.user!.copyWith(name: name);
    await _prefs.setString(AppConstants.keyUserName, name);
    state = state.copyWith(user: updated);
  }

  /// Logout: clears secure token and local session data.
  Future<void> logout() async {
    await ApiService.clearToken();
    await _prefs.remove(AppConstants.keyUserId);
    await _prefs.remove(AppConstants.keyUserRole);
    await _prefs.remove(AppConstants.keyUserName);
    await _prefs.remove(AppConstants.keyUserEmail);
    state = const AuthState(isAuthenticated: false, isOnboarded: false);
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthController(prefs);
});
