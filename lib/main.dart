import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'modules/login/admin-login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
      url: 'https://mezfgbopoiyqniykkmnl.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1lemZnYm9wb2l5cW5peWtrbW5sIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDUyMjI3NzcsImV4cCI6MjA2MDc5ODc3N30.sX6vXhWZUQ0QTT5TrJI-XrWGUvyKOy7WyNdNzTPHamk');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CoPartner | Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: LoginScreen(),
    );
  }
}
