import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // UPDATE USER
  // ============================================================
  Future<void> updateUser(UserModel user) async {
    try {
      print('📝 Updating user: ${user.id}');
      
      await _firestore
          .collection('users')
          .doc(user.id)  // user.id is the userId
          .update({
            'fullName': user.fullName,
            'phone': user.phone,
            'email': user.email,
            'roleId': user.roleId,
            'status': user.status,
            'departmentId': user.departmentId ?? '',
            'department': user.department ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
      
      print('✅ User updated successfully');
    } catch (e) {
      print('❌ Failed to update user: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  // ============================================================
  // DELETE USER - FIXED: Delete both Firestore and Firebase Auth
  // ============================================================
  Future<void> deleteUser(String userId, String? authUid) async {
    try {
      // 1. Delete from Firestore
      await _firestore.collection('users').doc(userId).delete();
      print('✅ User deleted from Firestore');
      
      // 2. Delete from Firebase Auth
      if (authUid != null) {
        final currentUser = FirebaseAuth.instance.currentUser;
        
        // If deleting current user
        if (currentUser != null && currentUser.uid == authUid) {
          await currentUser.delete();
          print('✅ Current user deleted from Firebase Auth');
        } else {
          // If deleting other user, we need admin privileges
          // For client-side, we can't delete other users
          print('⚠️ Cannot delete other user from Auth without admin privileges');
          print('ℹ️ Please use Firebase Console or Admin SDK to delete auth users');
        }
      }
      
      print('✅ User deletion process completed');
    } catch (e) {
      print('❌ Failed to delete user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  // ============================================================
  // DELETE USER WITH RE-AUTHENTICATION
  // ============================================================
  Future<void> deleteUserWithReauth(String userId, String password) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      
      if (currentUser == null) {
        throw Exception('No user logged in');
      }
      
      // Re-authenticate before deleting
      final credential = EmailAuthProvider.credential(
        email: currentUser.email!,
        password: password,
      );
      
      await currentUser.reauthenticateWithCredential(credential);
      
      // Delete from Firestore
      await _firestore.collection('users').doc(userId).delete();
      print('✅ User deleted from Firestore');
      
      // Delete from Firebase Auth
      await currentUser.delete();
      print('✅ User deleted from Firebase Auth');
      
    } catch (e) {
      print('❌ Failed to delete user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  // ============================================================
  // GET USER BY ID
  // ============================================================
  Future<UserModel?> getUserById(String userId) async {
    try {
      final docSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .get();
          
      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        return UserModel.fromFirestore(data, docSnapshot.id);
      }
      return null;
    } catch (e) {
      print('❌ Failed to get user: $e');
      return null;
    }
  }

  // ============================================================
  // GET ALL USERS
  // ============================================================
  Future<List<UserModel>> getAllUsers() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .orderBy('createdAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        return UserModel.fromFirestore(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }).toList();
    } catch (e) {
      print('❌ Failed to get users: $e');
      return [];
    }
  }

  // ============================================================
  // GET USER STATS
  // ============================================================
  Future<Map<String, int>> getUserStats() async {
    try {
      final snapshot = await _firestore.collection('users').get();
      final Map<String, int> stats = {
        'total': snapshot.docs.length,
        'admin': 0,
        'staff': 0,
        'manager': 0,
        'head': 0,
        'active': 0,
        'inactive': 0,
      };
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final roleId = data['roleId']?.toString() ?? '2';
        final status = data['status'] ?? 'Active';
        
        switch (roleId) {
          case '1':
            stats['admin'] = (stats['admin'] ?? 0) + 1;
            break;
          case '2':
            stats['staff'] = (stats['staff'] ?? 0) + 1;
            break;
          case '3':
            stats['manager'] = (stats['manager'] ?? 0) + 1;
            break;
          case '4':
            stats['head'] = (stats['head'] ?? 0) + 1;
            break;
        }
        
        if (status == 'Active') {
          stats['active'] = (stats['active'] ?? 0) + 1;
        } else {
          stats['inactive'] = (stats['inactive'] ?? 0) + 1;
        }
      }
      
      return stats;
    } catch (e) {
      print('❌ Failed to get user stats: $e');
      return {};
    }
  }
}