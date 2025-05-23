import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bcrypt/bcrypt.dart';

class RegisterAdmin extends StatefulWidget {
  const RegisterAdmin({super.key});

  @override
  _RegisterAdminState createState() => _RegisterAdminState();
}

class _RegisterAdminState extends State<RegisterAdmin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final SupabaseClient supabase = Supabase.instance.client;

  Future<void> _registerAdmin() async {
    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // Hash the password securely
      final hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      // Register the user with Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      if (user == null) throw Exception('User registration failed');

      // Insert the admin record into the table
      final inserted = await supabase.from('copartner-admin-account').insert({
        'uid': user.id, // User ID from Supabase auth
        'email': email,
        'password': hashedPassword,
        'role': 'admin',
      }).select(); // Ensure operation executes and returns data

      // Optional: Check if insert returned anything
      if (inserted.isEmpty) {
        throw Exception('Insert failed. Check RLS policy or data format.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Admin Registered Securely!")),
      );
    } catch (e) {
      print("❌ Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: "Admin Email"),
            ),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Admin Password"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _registerAdmin,
              child: const Text("Register Admin"),
            ),
          ],
        ),
      ),
    );
  }
}
