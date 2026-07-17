// lib/services/terms_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TermsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'terms_conditions';

  // Get current active terms & conditions
  static Future<Map<String, dynamic>?> getCurrentTerms() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('version', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }
      return null;
    } catch (e) {
      print('❌ Error fetching terms: $e');
      return null;
    }
  }

  // Get all terms versions (for admin)
  static Stream<QuerySnapshot> getAllTerms() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Create new terms & conditions
  static Future<void> createTerms({
    required String title,
    required String content,
    required List<Map<String, String>> sections,
    required String version,
    String? lastUpdated,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      // Deactivate all previous versions
      final previousTerms = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      
      for (var doc in previousTerms.docs) {
        batch.update(doc.reference, {'isActive': false});
      }

      // Create new terms
      final newDoc = _firestore.collection(_collection).doc();
      batch.set(newDoc, {
        'title': title,
        'content': content,
        'sections': sections,
        'version': version,
        'lastUpdated': lastUpdated ?? DateTime.now().toString(),
        'isActive': true,
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      print('✅ Terms & Conditions created successfully');
    } catch (e) {
      print('❌ Error creating terms: $e');
      throw Exception('Failed to create terms: $e');
    }
  }

  // Update terms & conditions
  static Future<void> updateTerms({
    required String termsId,
    String? title,
    String? content,
    List<Map<String, String>>? sections,
    String? version,
    String? lastUpdated,
    bool? isActive,
  }) async {
    try {
      final Map<String, dynamic> updates = {};
      if (title != null) updates['title'] = title;
      if (content != null) updates['content'] = content;
      if (sections != null) updates['sections'] = sections;
      if (version != null) updates['version'] = version;
      if (lastUpdated != null) updates['lastUpdated'] = lastUpdated;
      if (isActive != null) updates['isActive'] = isActive;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore.collection(_collection).doc(termsId).update(updates);
      print('✅ Terms updated successfully');
    } catch (e) {
      print('❌ Error updating terms: $e');
      throw Exception('Failed to update terms: $e');
    }
  }

  // Delete terms & conditions
  static Future<void> deleteTerms(String termsId) async {
    try {
      await _firestore.collection(_collection).doc(termsId).delete();
      print('✅ Terms deleted successfully');
    } catch (e) {
      print('❌ Error deleting terms: $e');
      throw Exception('Failed to delete terms: $e');
    }
  }

  // Get terms by version
  static Future<Map<String, dynamic>?> getTermsByVersion(String version) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('version', isEqualTo: version)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
        };
      }
      return null;
    } catch (e) {
      print('❌ Error fetching terms by version: $e');
      return null;
    }
  }
}