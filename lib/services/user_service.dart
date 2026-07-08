import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _usersCollection = 
      FirebaseFirestore.instance.collection('users');

  Future<void> updateUser(UserModel user) async {
    try {
      print('📝 Updating user: ${user.id}');
      print('📝 FullName: ${user.fullName}');
      print('📝 Email: ${user.email}');
      print('📝 Phone: ${user.phone}');
      print('📝 RoleId: ${user.roleId}');
      print('📝 Status: ${user.status}');
      print('📝 Department ID: ${user.departmentId}');
      print('📝 Department Name: ${user.department}');
      
      await _usersCollection.doc(user.id).update({
        'fullName': user.fullName,
        'phone': user.phone,
        'email': user.email,
        'roleId': user.roleId,
        'status': user.status,
        'departmentId': user.departmentId ?? '',
        'department': user.department ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      print('User updated successfully');
    } catch (e) {
      print(' Failed to update user: $e');
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> deleteUser(String userId, String? authUid) async {
    try {
      await _usersCollection.doc(userId).delete();
      if (authUid != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.uid == authUid) {
          await user.delete();
        }
      }
      print('User deleted successfully');
    } catch (e) {
      print('Failed to delete user: $e');
      throw Exception('Failed to delete user: $e');
    }
  }

  Future<Map<String, int>> getUserStats() async {
    try {
      final snapshot = await _usersCollection.get();
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
      print(' Failed to get user stats: $e');
      return {};
    }
  }
}