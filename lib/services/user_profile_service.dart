import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'cloudinary_service.dart';

class UserProfileService {
  static final AuthService _authService = AuthService();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pick profile image
  static Future<File?> pickProfileImage(ImageSource source) async {
    try {
      final File? pickedImage = await CloudinaryService.pickImage(source);
      return pickedImage;
    } catch (e) {
      debugPrint('Error picking profile image: $e');
      return null;
    }
  }

  // Upload user profile image
  static Future<String?> uploadProfileImage(File imageFile) async {
    try {
      debugPrint('Starting profile image upload process...');

      // Use the CloudinaryService with user profile upload type
      final imageUrl = await CloudinaryService.uploadImage(
        imageFile,
        uploadType: UploadType.userProfile,
      );

      if (imageUrl != null) {
        // Update user profile in Firestore
        await _updateUserProfileImage(imageUrl);
        return imageUrl;
      } else {
        debugPrint('Profile image upload failed');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  // Update user profile image URL in Firestore
  static Future<void> _updateUserProfileImage(String imageUrl) async {
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'profileImageUrl': imageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('User profile image updated in Firestore');
      }
    } catch (e) {
      debugPrint('Error updating user profile in Firestore: $e');
    }
  }

  // Show profile image picker dialog
  static Future<File?> showProfileImagePickerDialog(
    BuildContext context,
  ) async {
    return await CloudinaryService.showImagePickerDialog(context);
  }
}
