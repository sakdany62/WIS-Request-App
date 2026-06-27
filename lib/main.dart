// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/staff/dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/forgot_password.dart';
import 'screens/admin/create_user.dart';
import 'providers/auth_provider.dart';
// ============ បន្ថែម Migration ============
import 'migration/update_policy_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // ============ ដំណើរការ Migration (ធ្វើតែម្តង) ============
    // ប្រសិនបើអ្នកចង់ដំណើរការ Migration សូមដក comment បន្ទាត់ខាងក្រោម
    // រួចរត់កម្មវិធីម្តង បន្ទាប់មកដាក់ comment វិញ
    // await runMigration();
    
    // ============ ប្រសិនបើចង់ដំណើរការសម្រាប់ Policy តែមួយ ============
    // await runSinglePolicyMigration('YOUR_POLICY_ID_HERE');
    
  } catch (e) {
    print('❌ Firebase initialization error: $e');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Westland Permission App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const Dashboard(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/manager-dashboard': (context) => const ManagerDashboard(),
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/create-user': (context) => const CreateUserScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const Scaffold(
            body: Center(
              child: Text('Page not found'),
            ),
          ),
        );
      },
    );
  }
}