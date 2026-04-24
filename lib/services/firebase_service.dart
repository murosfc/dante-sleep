import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;

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

  // Auth methods
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth!.signOut();
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
}