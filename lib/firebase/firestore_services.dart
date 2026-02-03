import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserDatabaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String _normalizeEmail(String? v) => (v ?? '').trim().toLowerCase();

  /// ✅ Check if a user already exists in Firestore by email (case-insensitive best effort).
  /// This is used to block social login if the email was not provisioned by Shopify.
  Future<bool> userExistsByEmail(String email) async {
    try {
      final e = _normalizeEmail(email);
      if (e.isEmpty) return false;

      // Preferred (new) field
      final q1 = await _db
          .collection('users')
          .where('emailLower', isEqualTo: e)
          .limit(1)
          .get();

      if (q1.docs.isNotEmpty) return true;

      // Fallback for older docs (may be case sensitive)
      final q2 = await _db
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get();

      return q2.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Create or update user document in Firestore
  /// NOTE: This keeps your existing behavior for email/password signup/login flows.
  Future<void> createOrUpdateUser() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final email = user.email ?? '';
      final emailLower = _normalizeEmail(email);

      final userRef = _db.collection('users').doc(user.uid);
      final doc = await userRef.get();

      if (!doc.exists) {
        await userRef.set({
          'name': user.displayName ?? '',
          'email': email,
          'emailLower': emailLower, // ✅ add normalized field
          'subscription_plan': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await userRef.update({
          'name': user.displayName ?? (doc.data()?['name'] ?? ''),
          'email': email.isNotEmpty ? email : (doc.data()?['email'] ?? ''),
          'emailLower': emailLower.isNotEmpty
              ? emailLower
              : (doc.data()?['emailLower'] ?? ''),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error creating/updating user in Firestore: $e');
    }
  }

  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _db.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      // ignore: avoid_print
      print('Error fetching user data: $e');
      return null;
    }
  }

  Future<void> updateSubscriptionPlan(int newPlan) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db.collection('users').doc(user.uid).update({
        'subscription_plan': newPlan,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore: avoid_print
      print('Error updating subscription plan: $e');
    }
  }

  Stream<Map<String, dynamic>?> userDataStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _db.collection('users').doc(user.uid).snapshots().map((doc) {
      return doc.data();
    });
  }

  Future<void> deleteUserAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _db.collection('users').doc(user.uid).delete();
      await user.delete();
      // ignore: avoid_print
      print('Data Deleted: ${user.uid}');
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting user account: $e');
    }
  }
}
