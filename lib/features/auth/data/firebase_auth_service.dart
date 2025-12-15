import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:campus_lost_found/core/domain/app_user.dart';

/// Firebase Auth + Firestore backend for email/password authentication.
class FirebaseAuthService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Register an OFFICER with email & password and create users/{uid} doc.
  ///
  /// TODO(UI): Call this from your Register button.
  Future<UserCredential> registerOfficer({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = cred.user!.uid;

    await _firestore.collection('users').doc(uid).set({
      'name': name,
      'email': email,
      'role': 'OFFICER',
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  /// Email/password sign-in.
  ///
  /// TODO(UI): Call this from your Login button.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Map Firebase auth state to AppUser domain model.
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap(_mapFirebaseUserToAppUser);
  }

  Future<AppUser?> _mapFirebaseUserToAppUser(User? user) async {
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data() ?? <String, dynamic>{};

    final roleString = (data['role'] as String? ?? 'STUDENT').toUpperCase();
    final UserRole role;
    switch (roleString) {
      case 'OFFICER':
        role = UserRole.officer;
        break;
      case 'ADMIN':
        role = UserRole.admin;
        break;
      default:
        role = UserRole.student;
    }

    return AppUser(
      id: user.uid,
      name: (data['name'] as String?) ?? (user.email ?? 'User'),
      role: role,
      studentNumber: data['studentNumber'] as String?,
    );
  }
}


