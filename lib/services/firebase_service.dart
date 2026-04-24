import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
    await Firebase.initializeApp();
    _firestore = FirebaseFirestore.instance;
    _auth = FirebaseAuth.instance;
  }

  Stream<User?> authStateChanges() {
    return auth.authStateChanges();
  }

  Future<void> _ensureUserDocument(User user) async {
    final userDoc = firestore.collection('users').doc(user.uid);
    final now = FieldValue.serverTimestamp();

    await userDoc.set({
      'email': user.email,
      'createdAt': now,
      'updatedAt': now,
      'settings': {
        'language': 'en',
        'timeFormat24h': true,
      },
    }, SetOptions(merge: true));
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

  // Firestore methods for SleepEntry
  Future<void> saveSleepEntry(String userId, Map<String, dynamic> entry) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_entries')
        .add(entry);
  }

  Future<void> updateSleepEntry(
    String userId,
    String entryId,
    Map<String, dynamic> entry,
  ) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_entries')
        .doc(entryId)
        .update(entry);
  }

  Future<void> deleteSleepEntry(String userId, String entryId) async {
    await firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_entries')
        .doc(entryId)
        .delete();
  }

  Stream<QuerySnapshot> getSleepEntriesStream(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_entries')
        .orderBy('wokeUp', descending: true)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot>> getSleepEntries(String userId) async {
    final snapshot = await firestore
        .collection('users')
        .doc(userId)
        .collection('sleep_entries')
        .orderBy('wokeUp', descending: true)
        .get();
    return snapshot.docs;
  }

  // Sleep entries methods (new structure: sleep_entries/{uid}/entries/{entryId})
  Future<String> createSleepEntry(String userId, Map<String, dynamic> entryData) async {
    try {
      final docRef = await firestore
          .collection('sleep_entries')
          .doc(userId)
          .collection('entries')
          .add(entryData);
      return docRef.id;
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
      await firestore
          .collection('sleep_entries')
          .doc(userId)
          .collection('entries')
          .doc(entryId)
          .update(entryData);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSleepEntry(String userId, String entryId) async {
    try {
      await firestore
          .collection('sleep_entries')
          .doc(userId)
          .collection('entries')
          .doc(entryId)
          .delete();
    } catch (e) {
      rethrow;
    }
  }

  Stream<QuerySnapshot> getSleepEntriesStream(String userId) {
    return firestore
        .collection('sleep_entries')
        .doc(userId)
        .collection('entries')
        .orderBy('wokeUp', descending: true)
        .snapshots();
  }

  Future<void> migrateSleepEntriesToFirestore(
    String userId,
    List<Map<String, dynamic>> entries,
  ) async {
    try {
      // Ensure anchor document exists
      await firestore
          .collection('sleep_entries')
          .doc(userId)
          .set({'createdAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

      // Batch add entries
      final batch = firestore.batch();
      for (var entry in entries) {
        final docRef = firestore
            .collection('sleep_entries')
            .doc(userId)
            .collection('entries')
            .doc();
        batch.set(docRef, entry);
      }
      await batch.commit();
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
      await firestore
          .collection('users')
          .doc(userId)
          .update({
        'settings': settings,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
}