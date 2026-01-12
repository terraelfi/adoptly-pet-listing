import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration service
/// Loads and provides access to environment variables from .env file
class EnvConfig {
  // Cloudinary Configuration
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get cloudinaryApiKey =>
      dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get cloudinaryApiSecret =>
      dotenv.env['CLOUDINARY_API_SECRET'] ?? '';
  static String get cloudinaryPetUploadPreset =>
      dotenv.env['CLOUDINARY_PET_UPLOAD_PRESET'] ?? '';
  static String get cloudinaryUserProfileUploadPreset =>
      dotenv.env['CLOUDINARY_USER_PROFILE_UPLOAD_PRESET'] ?? '';

  // MapTiler Configuration
  static String get mapTilerApiKey =>
      dotenv.env['MAPTILER_API_KEY'] ?? '';

  // Google APIs Configuration
  static String get googlePlacesApiKey =>
      dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
  static String get googleMapsApiKey =>
      dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Firebase Web Configuration
  static String get firebaseWebApiKey =>
      dotenv.env['FIREBASE_WEB_API_KEY'] ?? '';
  static String get firebaseWebAppId =>
      dotenv.env['FIREBASE_WEB_APP_ID'] ?? '';
  static String get firebaseWebMessagingSenderId =>
      dotenv.env['FIREBASE_WEB_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseWebProjectId =>
      dotenv.env['FIREBASE_WEB_PROJECT_ID'] ?? '';
  static String get firebaseWebAuthDomain =>
      dotenv.env['FIREBASE_WEB_AUTH_DOMAIN'] ?? '';
  static String get firebaseWebStorageBucket =>
      dotenv.env['FIREBASE_WEB_STORAGE_BUCKET'] ?? '';

  // Firebase Android Configuration
  static String get firebaseAndroidApiKey =>
      dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? '';
  static String get firebaseAndroidAppId =>
      dotenv.env['FIREBASE_ANDROID_APP_ID'] ?? '';

  // Firebase iOS Configuration
  static String get firebaseIosApiKey =>
      dotenv.env['FIREBASE_IOS_API_KEY'] ?? '';
  static String get firebaseIosAppId =>
      dotenv.env['FIREBASE_IOS_APP_ID'] ?? '';
  static String get firebaseIosBundleId =>
      dotenv.env['FIREBASE_IOS_BUNDLE_ID'] ?? '';

  /// Initialize environment configuration
  /// Call this before runApp() in main.dart
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
  }

  /// Check if all required environment variables are set
  static bool isConfigValid() {
    final requiredVars = [
      cloudinaryCloudName,
      cloudinaryApiKey,
      cloudinaryApiSecret,
      mapTilerApiKey,
      googlePlacesApiKey,
    ];

    return requiredVars.every((v) => v.isNotEmpty);
  }

  /// Get a summary of which configs are set (for debugging)
  static Map<String, bool> getConfigStatus() {
    return {
      'Cloudinary Cloud Name': cloudinaryCloudName.isNotEmpty,
      'Cloudinary API Key': cloudinaryApiKey.isNotEmpty,
      'Cloudinary API Secret': cloudinaryApiSecret.isNotEmpty,
      'Cloudinary Pet Preset': cloudinaryPetUploadPreset.isNotEmpty,
      'Cloudinary User Preset': cloudinaryUserProfileUploadPreset.isNotEmpty,
      'MapTiler API Key': mapTilerApiKey.isNotEmpty,
      'Google Places API Key': googlePlacesApiKey.isNotEmpty,
      'Google Maps API Key': googleMapsApiKey.isNotEmpty,
      'Firebase Web API Key': firebaseWebApiKey.isNotEmpty,
      'Firebase Android API Key': firebaseAndroidApiKey.isNotEmpty,
      'Firebase iOS API Key': firebaseIosApiKey.isNotEmpty,
    };
  }
}
