// lib/services/terms_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TermsService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'terms_conditions';

  // ===================== GET CURRENT TERMS =====================
  static Future<Map<String, dynamic>?> getCurrentTerms() async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .orderBy('version', descending: true)
          .limit(1)
          .get(
            const GetOptions(source: Source.server), // ✅ Force server to avoid cache
          );

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

  // ===================== GET ALL TERMS =====================
  static Stream<QuerySnapshot> getAllTerms() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ===================== CREATE TERMS =====================
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

  // ===================== UPDATE TERMS =====================
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

  // ===================== DELETE TERMS =====================
  static Future<void> deleteTerms(String termsId) async {
    try {
      // Delete from Firestore
      await _firestore.collection(_collection).doc(termsId).delete();
      
      // Delete all read statuses for this terms
      final readStatusSnapshot = await _firestore
          .collection('terms_read_status')
          .where('termsId', isEqualTo: termsId)
          .get();
      
      if (readStatusSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (var doc in readStatusSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        print('✅ Deleted ${readStatusSnapshot.docs.length} read statuses');
      }
      
      print('✅ Terms deleted successfully');
    } catch (e) {
      print('❌ Error deleting terms: $e');
      throw Exception('Failed to delete terms: $e');
    }
  }

  // ===================== GET TERMS BY VERSION =====================
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

  // ===================== GET TERMS BY ID =====================
  static Future<Map<String, dynamic>?> getTermsById(String termsId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(termsId).get();
      if (doc.exists) {
        return {
          'id': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting terms by ID: $e');
      return null;
    }
  }

  // ===================== MARK TERMS AS READ =====================
  static Future<void> markTermsAsRead(String staffId, String termsId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      // 1. Get or create user document with proper info
      final userDocRef = _firestore.collection('users').doc(staffId);
      final userDoc = await userDocRef.get();
      
      // Get user info from Firebase Auth
      String fullName = currentUser?.displayName ?? 'Staff';
      String email = currentUser?.email ?? '';
      String username = email.split('@').first;
      
      // If user exists in Firestore, use that data
      if (userDoc.exists) {
        final existingData = userDoc.data()!;
        fullName = existingData['fullName'] ?? 
                   existingData['name'] ?? 
                   existingData['displayName'] ?? 
                   fullName;
        email = existingData['email'] ?? email;
        username = existingData['username'] ?? username;
      }
      
      // 2. Create or update user document with proper role
      if (!userDoc.exists) {
        await userDocRef.set({
          'uid': staffId,
          'userId': staffId,
          'fullName': fullName,
          'name': fullName,
          'displayName': fullName,
          'email': email,
          'username': username,
          'roleId': '2', // Staff role
          'roleName': 'Staff',
          'role': 'staff',
          'status': 'Active',
          'isActive': true,
          'hasReadTerms': false,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ Created new user document for staff: $staffId ($fullName)');
      } else {
        // Update existing user document
        await userDocRef.update({
          'fullName': fullName,
          'name': fullName,
          'displayName': fullName,
          'email': email,
          'username': username,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // 3. Save read status to terms_read_status collection
      final readStatusRef = _firestore.collection('terms_read_status').doc(staffId);
      await readStatusRef.set({
        'staffId': staffId,
        'termsId': termsId,
        'readAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // 4. Update user document with read status
      await userDocRef.update({
        'hasReadTerms': true,
        'termsReadAt': FieldValue.serverTimestamp(),
        'currentTermsId': termsId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('✅ Terms marked as read for staff: $staffId ($fullName)');
    } catch (e) {
      print('❌ Error marking terms as read: $e');
      rethrow;
    }
  }

  // ===================== CHECK IF STAFF HAS READ TERMS =====================
  static Future<bool> hasStaffReadTerms(String staffId, String termsId) async {
    try {
      final doc = await _firestore.collection('terms_read_status').doc(staffId).get();
      
      if (!doc.exists) return false;
      
      final data = doc.data()!;
      return data['termsId'] == termsId;
    } catch (e) {
      print('❌ Error checking terms read status: $e');
      return false;
    }
  }

  // ✅ GET STAFF WHO READ TERMS WITH PROPER ROLE
  static Future<List<Map<String, dynamic>>> getStaffWhoReadTerms(String termsId) async {
    try {
      final snapshot = await _firestore
          .collection('terms_read_status')
          .where('termsId', isEqualTo: termsId)
          .get();
      
      final List<Map<String, dynamic>> staffList = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final staffId = data['staffId'];
        
        // Get staff details from users collection
        final staffDoc = await _firestore.collection('users').doc(staffId).get();
        
        String name = 'Unknown User';
        String email = '';
        String department = 'N/A';
        String role = 'Staff';
        String status = 'Active';
        String roleId = '2';
        String roleName = 'Staff';
        
        if (staffDoc.exists) {
          final staffData = staffDoc.data()!;
          name = staffData['fullName'] ?? 
                 staffData['name'] ?? 
                 staffData['displayName'] ?? 
                 'Unknown User';
          email = staffData['email'] ?? '';
          department = staffData['department'] ?? 'N/A';
          
          // Get role from multiple possible fields
          role = staffData['role'] ?? 'Staff';
          roleName = staffData['roleName'] ?? 'Staff';
          roleId = staffData['roleId'] ?? '2';
          status = staffData['status'] ?? 'Active';
          
          // If roleId is 3, set role to Manager
          if (roleId == '3' || role.toLowerCase() == 'manager') {
            role = 'Manager';
            roleName = 'Manager';
          }
        }
        
        staffList.add({
          'staffId': staffId,
          'name': name,
          'email': email,
          'readAt': data['readAt'],
          'role': role,
          'roleId': roleId,
          'department': department,
          'status': status,
        });
      }
      
      // Sort by read time (newest first)
      staffList.sort((a, b) {
        final aTime = a['readAt'] as Timestamp?;
        final bTime = b['readAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      
      return staffList;
    } catch (e) {
      print('❌ Error getting staff who read terms: $e');
      return [];
    }
  }

  // ✅ GET ALL STAFF AND MANAGER (EXCLUDE ADMIN)
  static Future<List<Map<String, dynamic>>> getAllStaffAndManagers() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .get();
      
      final List<Map<String, dynamic>> userList = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final role = (data['role'] ?? data['roleName'] ?? '').toString().toLowerCase();
        final roleId = data['roleId'] ?? '';
        
        // Check if user is Admin
        final isAdmin = (role == 'admin' || roleId == '1');
        
        // Check if user is Staff or Manager
        final isStaff = (role == 'staff' || roleId == '2');
        final isManager = (role == 'manager' || roleId == '3');
        final isStaffOrManager = isStaff || isManager;
        
        // Skip admin, include staff and manager
        if (!isAdmin && isStaffOrManager) {
          String displayRole = 'Staff';
          if (isManager || roleId == '3' || role == 'manager') {
            displayRole = 'Manager';
          }
          
          userList.add({
            'staffId': doc.id,
            'name': data['fullName'] ?? data['name'] ?? data['displayName'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'hasReadTerms': data['hasReadTerms'] ?? false,
            'termsReadAt': data['termsReadAt'],
            'currentTermsId': data['currentTermsId'],
            'department': data['department'] ?? 'N/A',
            'role': displayRole,
            'roleId': roleId,
            'status': data['status'] ?? 'Active',
          });
        }
      }
      
      print('✅ Found ${userList.length} staff and managers');
      return userList;
    } catch (e) {
      print('❌ Error getting all staff and managers: $e');
      return [];
    }
  }

  // ✅ GET TERMS READ STATISTICS (Include Staff and Manager)
  static Future<Map<String, dynamic>> getTermsReadStats(String termsId) async {
    try {
      final allUsers = await getAllStaffAndManagers();
      final readUsers = await getStaffWhoReadTerms(termsId);
      
      final readUserIds = readUsers.map((s) => s['staffId']).toSet();
      
      // Users who haven't read
      final notReadUsers = allUsers.where((user) {
        return !readUserIds.contains(user['staffId']);
      }).toList();
      
      final totalUsers = allUsers.length;
      final readCount = readUsers.length;
      final notReadCount = totalUsers - readCount;
      final readPercentage = totalUsers > 0 ? (readCount / totalUsers * 100) : 0;
      
      return {
        'totalStaff': totalUsers,
        'readCount': readCount,
        'notReadCount': notReadCount > 0 ? notReadCount : 0,
        'readPercentage': readPercentage,
        'readStaff': readUsers,
        'notReadStaff': notReadUsers,
      };
    } catch (e) {
      print('❌ Error getting terms read stats: $e');
      return {
        'totalStaff': 0,
        'readCount': 0,
        'notReadCount': 0,
        'readPercentage': 0,
        'readStaff': [],
        'notReadStaff': [],
      };
    }
  }

  // ===================== RESET TERMS READ STATUS =====================
  static Future<void> resetTermsReadStatus(String termsId) async {
    try {
      final snapshot = await _firestore
          .collection('terms_read_status')
          .where('termsId', isEqualTo: termsId)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        final staffId = doc.data()['staffId'];
        // Reset user's hasReadTerms
        final userRef = _firestore.collection('users').doc(staffId);
        batch.update(userRef, {
          'hasReadTerms': false,
          'termsReadAt': null,
          'currentTermsId': null,
        });
        batch.delete(doc.reference);
      }
      await batch.commit();
      print('✅ Reset read status for terms: $termsId');
    } catch (e) {
      print('❌ Error resetting terms read status: $e');
      rethrow;
    }
  }

  // ===================== GET STAFF READ STATUS BY USER ID =====================
  static Future<Map<String, dynamic>?> getStaffReadStatus(String staffId) async {
    try {
      final doc = await _firestore.collection('terms_read_status').doc(staffId).get();
      if (doc.exists) {
        return {
          'staffId': doc.id,
          ...doc.data()!,
        };
      }
      return null;
    } catch (e) {
      print('❌ Error getting staff read status: $e');
      return null;
    }
  }

  // ===================== GET ALL READ STATUSES =====================
  static Stream<QuerySnapshot> getAllReadStatuses() {
    return _firestore
        .collection('terms_read_status')
        .orderBy('readAt', descending: true)
        .snapshots();
  }

  // ===================== CHECK IF TERMS EXIST =====================
  static Future<bool> checkTermsExist() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      print('❌ Error checking terms exist: $e');
      return false;
    }
  }

  // ===================== GET LATEST VERSION =====================
  static Future<String?> getLatestVersion() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('version', descending: true)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['version'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting latest version: $e');
      return null;
    }
  }

  // ===================== CLEAR CACHE =====================
  static Future<void> clearCache() async {
    try {
      await FirebaseFirestore.instance.clearPersistence();
      print('✅ Cache cleared successfully');
    } catch (e) {
      print('❌ Error clearing cache: $e');
      rethrow;
    }
  }

  // ===================== FORCE REFRESH TERMS =====================
  static Future<Map<String, dynamic>?> forceRefreshTerms() async {
    try {
      // Clear cache first
      await clearCache();
      
      // Then fetch from server
      return await getCurrentTerms();
    } catch (e) {
      print('❌ Error force refreshing terms: $e');
      return null;
    }
  }
}