import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔍 Check if user is an admin
  Future<bool> isAdmin(String uid) async {
    try {
      DocumentSnapshot adminDoc =
          await _firestore.collection('copartner-admin-accounts').doc(uid).get();
      
      if (adminDoc.exists) {
        print("✅ User is an admin");
        return true;
      } else {
        print("❌ User is not an admin");
        return false;
      }
    } catch (e) {
      print("❌ Error checking admin status: $e");
      return false;
    }
  }
}
