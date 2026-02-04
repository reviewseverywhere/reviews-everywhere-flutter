import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OnboardingData {
  final String purchaserName;
  final int initialSlots;
  final List<String> wristbandNames;
  final List<TeamData> teams;
  final Map<String, String?> wristbandAssignments;
  final String gbpUrl;

  OnboardingData({
    required this.purchaserName,
    required this.initialSlots,
    required this.wristbandNames,
    required this.teams,
    required this.wristbandAssignments,
    required this.gbpUrl,
  });

  Map<String, dynamic> toJson() => {
    'purchaserName': purchaserName,
    'initialSlots': initialSlots,
    'wristbandNames': wristbandNames,
    'teams': teams.map((t) => t.toJson()).toList(),
    'wristbandAssignments': wristbandAssignments,
    'gbpUrl': gbpUrl,
    'onboardingCompletedAt': FieldValue.serverTimestamp(),
  };
}

class TeamData {
  final String name;
  final List<String> members;

  TeamData({required this.name, required this.members});

  Map<String, dynamic> toJson() => {
    'name': name,
    'members': members,
  };
}

class OnboardingService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> isOnboardingComplete() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return false;

    try {
      final q = await _db
          .collection('accounts')
          .where('shopifyEmail', isEqualTo: email)
          .limit(1)
          .get();

      if (q.docs.isEmpty) return false;

      final data = q.docs.first.data();
      return data['onboardingComplete'] == true;
    } catch (e) {
      return false;
    }
  }

  Future<void> completeOnboarding(OnboardingData data) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in');

    final email = user.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw Exception('No email associated with account');
    }

    final q = await _db
        .collection('accounts')
        .where('shopifyEmail', isEqualTo: email)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      throw Exception('No account found for this email');
    }

    final docRef = q.docs.first.reference;

    await docRef.update({
      'onboardingComplete': true,
      'onboardingData': data.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
