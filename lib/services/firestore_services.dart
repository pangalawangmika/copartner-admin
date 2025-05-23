import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart';

class FirestoreService {
  final CollectionReference admins = FirebaseFirestore.instance.collection('admins');

  // Function to add an admin account
  Future<void> addAdmin(String email, String password) async {
    try {
      // Hash the password before storing
      String hashedPassword = BCrypt.hashpw(password, BCrypt.gensalt());

      await admins.add({
        'email': email,
        'password': hashedPassword, // Store hashed password
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ Admin added successfully!");
    } catch (e) {
      print("❌ Error adding admin: $e");
    }
  }

  // Function to verify admin login
  Future<bool> verifyAdmin(String email, String password) async {
    try {
      var snapshot = await admins.where('email', isEqualTo: email).get();

      if (snapshot.docs.isNotEmpty) {
        String storedHashedPassword = snapshot.docs.first.get('password');
        return BCrypt.checkpw(password, storedHashedPassword); // Verify password
      }

      return false;
    } catch (e) {
      print("❌ Error verifying admin: $e");
      return false;
    }
  }
}
