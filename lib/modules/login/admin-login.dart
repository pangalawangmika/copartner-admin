import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:bcrypt/bcrypt.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:admin_panel/modules/dashboard/admin-dashboard.dart';
import 'package:animations/animations.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  String loginError = '';
  bool isLoading = false;

  Future<void> loginAdmin(BuildContext context, String email, String password) async {
    setState(() {
      loginError = '';
      isLoading = true;
    });
    try {
      final response = await supabase
          .from('copartner-admin-account')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (response == null) {
        throw Exception("Email not found");
      }

      final storedHashedPassword = response['password'];
      final role = response['role'];

      final passwordMatch = BCrypt.checkpw(password, storedHashedPassword);

      if (!passwordMatch) {
        throw Exception("Incorrect password");
      }

      if (role != 'admin') {
        throw Exception("Access denied: Not an admin");
      }

      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const AdminDashboard(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeThroughTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 700),
        ),
      );
      setState(() { isLoading = false; });
    } catch (e) {
      print("❌ Login error: $e");
      setState(() {
        loginError = 'Invalid username or password';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'lib/assets/images/copartner-admin-bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset('lib/assets/images/copartner-withname.png', height: 150),
                    const SizedBox(height: 30),
                    const Text('Sign in',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Poppins')),
                    const SizedBox(height: 30),
                    TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        hintText: 'Email',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                loginAdmin(context, emailController.text, passwordController.text);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F3296),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text('Log In', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    if (loginError.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          loginError,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (context) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(20),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: InteractiveViewer(
                                    child: Image.asset('lib/assets/images/pnp-dataprivacy.jpg'),
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: GestureDetector(
                                    onTap: () => Navigator.of(context).pop(),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: const Icon(Icons.close, color: Colors.white, size: 24),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: const Text(
                        'Data Privacy Notice',
                        style: TextStyle(fontSize: 13, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('lib/assets/images/copartner-logo-pnp.png', height: 50),
                        const SizedBox(width: 5),
                        Image.asset('lib/assets/images/copartner-logo-ldims.png', height: 50),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
