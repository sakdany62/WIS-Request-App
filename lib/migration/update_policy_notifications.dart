// lib/migration/update_policy_notifications.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class PolicyMigration {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateExistingPolicies() async {
    try {
      print('Starting policy migration...');
      
      // ទាញយក Policy ទាំងអស់
      final snapshot = await _firestore
          .collection('permission_policies')
          .get();

      if (snapshot.docs.isEmpty) {
        print('No policies found to update');
        return;
      }

      print('Found ${snapshot.docs.length} policies to update');

      int updatedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          // ពិនិត្យមើលថាតើមាន Notification Settings រួចហើយឬនៅ
          if (data.containsKey('enableNotifications')) {
            print('Policy ${doc.id} already has notification settings - skipping');
            skippedCount++;
            continue;
          }

          // បន្ថែម Notification Settings ទៅ Policy
          await doc.reference.update({
            'enableNotifications': true,
            'notificationTitle': 'ការជូនដំណឹងអំពីសំណើឈប់',
            'notificationBody': 'សំណើឈប់របស់អ្នកត្រូវបានដំណើរការ',
            'notifyOnRequestSubmit': true,
            'notifyOnStatusChange': true,
            'notifyOnApproval': true,
            'notifyOnRejection': true,
            'notifyAdminOnNewRequest': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          print('✅ Updated policy: ${doc.id} - ${data['name'] ?? 'Unnamed'}');
          updatedCount++;
        } catch (e) {
          print('❌ Error updating policy ${doc.id}: $e');
          errorCount++;
        }
      }

      print('\n========================================');
      print('Migration completed successfully!');
      print('========================================');
      print('Total policies: ${snapshot.docs.length}');
      print('✅ Updated: $updatedCount');
      print('⏭️ Skipped: $skippedCount');
      print('❌ Errors: $errorCount');
      print('========================================');
    } catch (e) {
      print('❌ Fatal error during migration: $e');
      rethrow;
    }
  }

  // សម្រាប់ពិនិត្យមើល Policy តែមួយ
  Future<void> updateSinglePolicy(String policyId) async {
    try {
      final docRef = _firestore.collection('permission_policies').doc(policyId);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        print('Policy with ID $policyId not found');
        return;
      }

      final data = doc.data()!;
      
      // ពិនិត្យមើលថាតើមាន Notification Settings រួចហើយឬនៅ
      if (data.containsKey('enableNotifications')) {
        print('Policy $policyId already has notification settings');
        return;
      }

      // បន្ថែម Notification Settings
      await docRef.update({
        'enableNotifications': true,
        'notificationTitle': 'ការជូនដំណឹងអំពីសំណើឈប់',
        'notificationBody': 'សំណើឈប់របស់អ្នកត្រូវបានដំណើរការ',
        'notifyOnRequestSubmit': true,
        'notifyOnStatusChange': true,
        'notifyOnApproval': true,
        'notifyOnRejection': true,
        'notifyAdminOnNewRequest': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Updated policy: $policyId');
    } catch (e) {
      print('❌ Error updating policy $policyId: $e');
      rethrow;
    }
  }

  // សម្រាប់លុប Notification Settings (បើចាំបាច់)
  Future<void> removeNotificationSettings(String policyId) async {
    try {
      final docRef = _firestore.collection('permission_policies').doc(policyId);
      
      await docRef.update({
        'enableNotifications': FieldValue.delete(),
        'notificationTitle': FieldValue.delete(),
        'notificationBody': FieldValue.delete(),
        'notifyOnRequestSubmit': FieldValue.delete(),
        'notifyOnStatusChange': FieldValue.delete(),
        'notifyOnApproval': FieldValue.delete(),
        'notifyOnRejection': FieldValue.delete(),
        'notifyAdminOnNewRequest': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Removed notification settings from policy: $policyId');
    } catch (e) {
      print('❌ Error removing notification settings: $e');
      rethrow;
    }
  }

  // សម្រាប់បន្ថែម Notification Settings ទៅ Policy ថ្មី
  Future<void> addNotificationSettingsToNewPolicy(String policyId) async {
    try {
      final docRef = _firestore.collection('permission_policies').doc(policyId);
      
      await docRef.set({
        'enableNotifications': true,
        'notificationTitle': 'ការជូនដំណឹងអំពីសំណើឈប់',
        'notificationBody': 'សំណើឈប់របស់អ្នកត្រូវបានដំណើរការ',
        'notifyOnRequestSubmit': true,
        'notifyOnStatusChange': true,
        'notifyOnApproval': true,
        'notifyOnRejection': true,
        'notifyAdminOnNewRequest': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ Added notification settings to new policy: $policyId');
    } catch (e) {
      print('❌ Error adding notification settings: $e');
      rethrow;
    }
  }
}

// ដើម្បីដំណើរការ Migration ទាំងអស់
Future<void> runMigration() async {
  try {
    // ត្រូវប្រាកដថា Firebase ត្រូវបាន Initialized រួច
    // ប្រសិនបើអ្នកហៅពី main.dart មិនចាំបាច់បន្ថែមទេ
    // await Firebase.initializeApp();
    
    final migration = PolicyMigration();
    await migration.updateExistingPolicies();
  } catch (e) {
    print('❌ Migration failed: $e');
    rethrow;
  }
}

// ដើម្បីដំណើរការ Migration សម្រាប់ Policy តែមួយ
Future<void> runSinglePolicyMigration(String policyId) async {
  try {
    final migration = PolicyMigration();
    await migration.updateSinglePolicy(policyId);
  } catch (e) {
    print('❌ Single policy migration failed: $e');
    rethrow;
  }
}

// ដើម្បីលុប Notification Settings
Future<void> runRemoveNotificationSettings(String policyId) async {
  try {
    final migration = PolicyMigration();
    await migration.removeNotificationSettings(policyId);
  } catch (e) {
    print('❌ Remove notification settings failed: $e');
    rethrow;
  }
}

// ដើម្បីបន្ថែម Notification Settings ទៅ Policy ថ្មី
Future<void> runAddNotificationSettingsToNewPolicy(String policyId) async {
  try {
    final migration = PolicyMigration();
    await migration.addNotificationSettingsToNewPolicy(policyId);
  } catch (e) {
    print('❌ Add notification settings failed: $e');
    rethrow;
  }
}