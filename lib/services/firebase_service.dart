import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _firestore!;
  }

  FirebaseAuth get auth {
    if (_auth == null) {
      throw Exception('Firebase not initialized. Call initialize() first.');
    }
    return _auth!;
  }

  Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
  }

  Stream<User?> authStateChanges() {
    return auth.authStateChanges();
  }

  Future<void> _ensureUserDocument(User user) async {
    final userDoc = firestore.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();
    final now = FieldValue.serverTimestamp();
    final defaultLanguage = _defaultLanguageFromSystem();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'email': user.email,
        'createdAt': now,
        'updatedAt': now,
        'settings': {
          'language': defaultLanguage,
          'timeFormat24h': true,
          'visualThemeMode': 'auto',
        },
      });
    } else {
      final data = docSnapshot.data();
      final hasSettings = data != null && data.containsKey('settings');
      if (!hasSettings) {
        await userDoc.set({
          'email': user.email,
          'updatedAt': now,
          'settings': {
            'language': defaultLanguage,
            'timeFormat24h': true,
            'visualThemeMode': 'auto',
          },
        }, SetOptions(merge: true));
      } else {
        final settings = data['settings'] as Map<dynamic, dynamic>?;
        if (settings == null || !settings.containsKey('visualThemeMode')) {
          await userDoc.update({
            'email': user.email,
            'updatedAt': now,
            'settings.visualThemeMode': 'auto',
          });
        } else {
          await userDoc.set({
            'email': user.email,
            'updatedAt': now,
          }, SetOptions(merge: true));
        }
      }
    }
  }

  String _defaultLanguageFromSystem() {
    try {
      final code = ui.PlatformDispatcher.instance.locale.languageCode
          .trim()
          .toLowerCase();
      if (code.isEmpty) return 'pt-BR';
      if (code == 'pt') return 'pt-BR';
      return 'en';
    } catch (_) {
      return 'pt-BR';
    }
  }

  // Auth methods
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _ensureUserDocument(credential.user!);
      }
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        await _ensureUserDocument(credential.user!);
      }
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await auth.signInWithCredential(credential);
      if (userCredential.user != null) {
        await _ensureUserDocument(userCredential.user!);
      }
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await auth.signOut();
  }

  User? get currentUser => _auth?.currentUser;

  // Sleep entries methods (new structure: sleep_entries/{uid} = { entryId: { data } })
  Future<String> createSleepEntry(
    String userId,
    Map<String, dynamic> entryData,
  ) async {
    try {
      final entryId = firestore.collection('sleep_entries').doc().id;
      await firestore.collection('sleep_entries').doc(userId).set({
        entryId: entryData,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return entryId;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateSleepEntry(
    String userId,
    String entryId,
    Map<String, dynamic> entryData,
  ) async {
    try {
      await firestore.collection('sleep_entries').doc(userId).update({
        entryId: entryData,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSleepEntry(String userId, String entryId) async {
    try {
      await firestore.collection('sleep_entries').doc(userId).update({
        FieldPath([entryId]): FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  Stream<DocumentSnapshot> getSleepEntriesStream(String userId) {
    return firestore.collection('sleep_entries').doc(userId).snapshots();
  }

  Future<Map<String, dynamic>> getSleepEntries(String userId) async {
    try {
      final doc = await firestore.collection('sleep_entries').doc(userId).get();
      final data = doc.data() ?? {};
      // Remove campos de sistema
      data.remove('updatedAt');
      data.remove('createdAt');
      return Map<String, dynamic>.from(data);
    } catch (e) {
      return {};
    }
  }

  Future<void> migrateSleepEntriesToFirestore(
    String userId,
    List<Map<String, dynamic>> entries,
  ) async {
    try {
      final Map<String, dynamic> entriesMap = {};
      for (var entry in entries) {
        final entryId = firestore.collection('sleep_entries').doc().id;
        entriesMap[entryId] = entry;
      }
      await firestore.collection('sleep_entries').doc(userId).set({
        ...entriesMap,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> replaceAllSleepEntries(
    String userId,
    List<Map<String, dynamic>> entries,
  ) async {
    try {
      final Map<String, dynamic> entriesMap = {};
      final List<String> generatedIds = [];
      for (var entry in entries) {
        final entryId = firestore.collection('sleep_entries').doc().id;
        entriesMap[entryId] = entry;
        generatedIds.add(entryId);
      }
      await firestore.collection('sleep_entries').doc(userId).set({
        ...entriesMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return generatedIds;
    } catch (e) {
      rethrow;
    }
  }

  // Settings methods
  Future<Map<String, dynamic>> getSettings(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      final data = doc.data() ?? {};
      return (data['settings'] ?? {}) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  Future<void> updateSettings(
    String userId,
    Map<String, dynamic> settings,
  ) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // User Profile methods
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      return doc.data() ?? {};
    } catch (e) {
      return {};
    }
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      await firestore.collection('users').doc(userId).set({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<void> clearPendingBabyName(String userId) async {
    try {
      await firestore.collection('users').doc(userId).update({
        'pendingBabyName': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }

  // ─── Baby profile ──────────────────────────────────────────────────────────
  Future<void> saveBabyData(String userId, Map<String, dynamic> data) async {
    try {
      await firestore.collection('users').doc(userId).set({
        'baby_data': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getBabyData(String userId) async {
    try {
      final doc = await firestore.collection('users').doc(userId).get();
      final data = doc.data();
      if (data == null || !data.containsKey('baby_data')) return null;
      return Map<String, dynamic>.from(data['baby_data'] as Map);
    } catch (_) {
      return null;
    }
  }
}
