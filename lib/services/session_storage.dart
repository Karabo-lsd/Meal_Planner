import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed, per-user session cache.
///
/// All keys are scoped to the authenticated user's ID so that different
/// accounts on the same device never see each other's data.
///
/// Call [SessionStorage.init()] once in `main()` before the app widget tree
/// is created. All other methods are synchronous reads or fire-and-forget
/// async writes because Hive accesses are essentially instant once the box
/// is open.
class SessionStorage {
  static const _boxName = 'session_v1';

  // ── lifecycle ─────────────────────────────────────────────────────────────

  static Box? _box;
  static bool get isInitialized => _box?.isOpen ?? false;

  static Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  static Box get _b {
    assert(
      _box != null && _box!.isOpen,
      'SessionStorage.init() must be called before use',
    );
    return _box!;
  }

  // ── low-level key/value ───────────────────────────────────────────────────

  static String _k(String userId, String key) => '${userId}_$key';

  /// Persists [value] (any JSON-serialisable object) keyed to [userId].
  static Future<void> save(String userId, String key, dynamic value) =>
      _b.put(_k(userId, key), jsonEncode(value));

  /// Returns the decoded value for [key], or null if not found.
  static dynamic load(String userId, String key) {
    final raw = _b.get(_k(userId, key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw as String);
    } catch (_) {
      return null;
    }
  }

  /// Removes all cached data for [userId] — call on logout.
  static Future<void> clearUser(String userId) async {
    final toDelete = _b.keys
        .where((k) => k.toString().startsWith('${userId}_'))
        .toList();
    await _b.deleteAll(toDelete);
  }

  // ── well-known keys ───────────────────────────────────────────────────────

  static const _kProfile = 'profile';
  static const _kPantry = 'pantry';
  static const _kSavedIds = 'saved_ids';
  static const _kTab = 'tab';
  static const _kProfileSetupReminderDismissed =
      'profile_setup_reminder_dismissed';
  static const _kCheckedGroceries = 'checked_groceries';
  static const _kPendingVerificationEmail = 'pending_verification_email';
  static const _authStorageUserId = 'auth';

  static Future<void> savePendingVerificationEmail(String email) =>
      save(_authStorageUserId, _kPendingVerificationEmail, email);

  static String? loadPendingVerificationEmail() {
    final email = load(_authStorageUserId, _kPendingVerificationEmail);
    return email is String ? email : null;
  }

  static Future<void> clearPendingVerificationEmail() =>
      _b.delete(_k(_authStorageUserId, _kPendingVerificationEmail));

  // profile -----------------------------------------------------------------

  static Future<void> saveProfile(String userId, Map<String, dynamic> data) =>
      save(userId, _kProfile, data);

  /// Returns the cached user profile, or null if never stored.
  static Map<String, dynamic>? loadProfile(String userId) {
    final raw = load(userId, _kProfile);
    if (raw == null) return null;
    return (raw as Map).cast<String, dynamic>();
  }

  // pantry ------------------------------------------------------------------

  static Future<void> savePantry(
    String userId,
    List<Map<String, dynamic>> items,
  ) {
    // Simplify: only store the fields Ingredient.fromPantryJson needs.
    final slim = items.map((r) {
      final fm = r['foods_master'] as Map<String, dynamic>?;
      final fn = fm?['food_nutrition'] as Map<String, dynamic>?;
      return {
        'id': r['id'],
        'ingredient_name_raw': r['ingredient_name_raw'],
        'canonical_food_id': r['canonical_food_id'],
        'quantity': r['quantity'],
        'unit': r['unit'],
        'expiry_date': r['expiry_date'],
        if (fm != null)
          'foods_master': {
            'canonical_name': fm['canonical_name'],
            if (fn != null)
              'food_nutrition': {
                'per_100g_calories': fn['per_100g_calories'],
                'per_100g_protein': fn['per_100g_protein'],
                'per_100g_carbs': fn['per_100g_carbs'],
                'per_100g_fat': fn['per_100g_fat'],
              },
          },
      };
    }).toList();
    return save(userId, _kPantry, slim);
  }

  static List<Map<String, dynamic>>? loadPantry(String userId) {
    final raw = load(userId, _kPantry);
    if (raw == null) return null;
    return (raw as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  // saved recipe IDs --------------------------------------------------------

  static Future<void> saveSavedIds(String userId, Iterable<String> ids) =>
      save(userId, _kSavedIds, ids.toList());

  static Set<String>? loadSavedIds(String userId) {
    final raw = load(userId, _kSavedIds);
    if (raw == null) return null;
    return (raw as List).map((e) => e.toString()).toSet();
  }

  // last tab ----------------------------------------------------------------

  /// Synchronous — reads directly from the already-open box.
  static int loadTab(String userId) => (load(userId, _kTab) as int?) ?? 0;

  static Future<void> saveTab(String userId, int index) =>
      save(userId, _kTab, index);

  static bool hasProfileSetupReminderBeenDismissed(String userId) {
    final raw = load(userId, _kProfileSetupReminderDismissed);
    return raw is bool ? raw : false;
  }

  static Future<void> markProfileSetupReminderDismissed(String userId) =>
      save(userId, _kProfileSetupReminderDismissed, true);

  // checked groceries -------------------------------------------------------

  static Future<void> saveCheckedGroceries(
    String userId,
    Iterable<String> items,
  ) => save(userId, _kCheckedGroceries, items.toList());

  static Set<String>? loadCheckedGroceries(String userId) {
    final raw = load(userId, _kCheckedGroceries);
    if (raw == null) return null;
    return (raw as List)
        .map((e) => e.toString().trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();
  }
}
