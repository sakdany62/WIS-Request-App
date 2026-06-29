// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart'; // ✅ add
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/staff/dashboard.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/manager/manager_dashboard.dart';
import 'screens/forgot_password.dart';
import 'screens/admin/create_user.dart';
import 'providers/auth_provider.dart';
import 'migration/update_policy_notifications.dart';
import 'app_fonts.dart'; // ✅ add

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Run Migration (only once)
    // await runMigration();
    
    // Run migration for a single policy
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
        // ✅ Roboto + size 14 for ALL screens
        textTheme: GoogleFonts.robotoTextTheme().copyWith(
          bodyLarge: GoogleFonts.roboto(fontSize: AppFonts.md),
          bodyMedium: GoogleFonts.roboto(fontSize: AppFonts.md),
          bodySmall: GoogleFonts.roboto(fontSize: AppFonts.md),
          titleLarge: GoogleFonts.roboto(fontSize: AppFonts.md),
          titleMedium: GoogleFonts.roboto(fontSize: AppFonts.md),
          titleSmall: GoogleFonts.roboto(fontSize: AppFonts.md),
          labelLarge: GoogleFonts.roboto(fontSize: AppFonts.md),
          labelMedium: GoogleFonts.roboto(fontSize: AppFonts.md),
          labelSmall: GoogleFonts.roboto(fontSize: AppFonts.md),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.roboto(
            fontSize: AppFonts.md,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: GoogleFonts.roboto(
              fontSize: AppFonts.md,
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