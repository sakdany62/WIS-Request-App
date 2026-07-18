// lib/services/policy_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/policy_model.dart';

class PolicyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _policiesCollection = 
      FirebaseFirestore.instance.collection('permission_policies');

  Future<PolicyModel?> getActivePolicy() async {
    try {
      final snapshot = await _policiesCollection
          .where('isActive', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return PolicyModel.fromFirestore(
          snapshot.docs.first.data() as Map<String, dynamic>,
          snapshot.docs.first.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting active policy: $e');
      return null;
    }
  }

  Future<void> savePolicy(PolicyModel policy) async {
    try {
      if (policy.id.isEmpty) {
        await _policiesCollection.add(policy.toMap());
      } else {
        await _policiesCollection.doc(policy.id).update(policy.toMap());
      }
    } catch (e) {
      throw Exception('Failed to save policy: $e');
    }
  }

  Stream<List<PolicyModel>> getAllPolicies() {
    return _policiesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return PolicyModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    });
  }

  // Method សម្រាប់ទាញយក Policy តាម ID
  Future<PolicyModel?> getPolicyById(String id) async {
    try {
      final doc = await _policiesCollection.doc(id).get();
      if (doc.exists) {
        return PolicyModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
      return null;
    } catch (e) {
      print('Error getting policy by id: $e');
      return null;
    }
  }

  // ✅ Method ថ្មី: ទាញយក Allowed Reasons ពី Policy សកម្ម
  Future<List<String>> getAllowedReasons() async {
    try {
      final policy = await getActivePolicy();
      if (policy != null) {
        final reasons = policy.allowedReasons;
        // ✅ ធានាថា "Other" តែងតែមាន
        if (!reasons.contains('Other')) {
          reasons.add('Other');
        }
        return reasons;
      }
      // Default reasons if no policy exists
      return ['Sick', 'Personal issue', 'Vacation', 'Emergency', 'Other'];
    } catch (e) {
      print('❌ Error getting allowed reasons: $e');
      return ['Sick', 'Personal issue', 'Vacation', 'Emergency', 'Other'];
    }
  }

  // ✅ Method ថ្មី: Stream សម្រាប់ស្តាប់ការផ្លាស់ប្តូរ Real-time
  Stream<List<String>> streamAllowedReasons() {
    return _policiesCollection
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return ['Sick', 'Personal issue', 'Vacation', 'Emergency', 'Other'];
      }
      final doc = snapshot.docs.first;
      final data = doc.data() as Map<String, dynamic>;
      final reasons = List<String>.from(data['allowedReasons'] ?? []);
      // ✅ ធានាថា "Other" តែងតែមាន
      if (!reasons.contains('Other')) {
        reasons.add('Other');
      }
      return reasons.isEmpty 
          ? ['Sick', 'Personal issue', 'Vacation', 'Emergency', 'Other']
          : reasons;
    });
  }
}