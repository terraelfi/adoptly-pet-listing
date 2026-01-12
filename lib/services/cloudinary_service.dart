import 'dart:io';
import 'dart:convert';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'env_config.dart';
// Removed unused: import 'dart:math';

// Enum for upload type
enum UploadType { pet, userProfile }

class CloudinaryService {
  // Cloud configuration - loaded from environment variables
  static String get _cloudName => EnvConfig.cloudinaryCloudName;
  static String get _apiKey => EnvConfig.cloudinaryApiKey;
  static String get _apiSecret => EnvConfig.cloudinaryApiSecret;
  static String get _petUploadPreset => EnvConfig.cloudinaryPetUploadPreset;
  static String get _userProfileUploadPreset => EnvConfig.cloudinaryUserProfileUploadPreset;
  static const String _petFolderName = 'pet_images';
  static const String _userProfileFolderName = 'user_profiles';

  // Create cloudinary instances with your credentials (lazy initialization)
  static CloudinaryPublic get _petCloudinary => CloudinaryPublic(
    _cloudName,
    _petUploadPreset,
  );

  static CloudinaryPublic get _userProfileCloudinary => CloudinaryPublic(
    _cloudName,
    _userProfileUploadPreset,
  );

  // Check if Cloudinary configuration is valid
  static Future<bool> isConfigValid() async {
    try {
      debugPrint('Checking Cloudinary configuration...');
      debugPrint('Cloud name configured: ${_cloudName.isNotEmpty}');
      debugPrint('API Key configured: ${_apiKey.isNotEmpty}');
      debugPrint('Pet upload preset configured: ${_petUploadPreset.isNotEmpty}');
      debugPrint('User profile upload preset configured: ${_userProfileUploadPreset.isNotEmpty}');

      // First, check if the cloud name is valid with an authenticated request
      final authUrl = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/ping',
      );
      final authResponse = await http.get(
        authUrl,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}',
        },
      );

      debugPrint('Auth ping response status: ${authResponse.statusCode}');
      debugPrint('Auth ping response body: ${authResponse.body}');

      if (authResponse.statusCode == 200) {
        debugPrint('Cloudinary authentication successful!');
        return true;
      } else {
        debugPrint('Cloudinary authentication failed');
        return false;
      }
    } catch (e) {
      debugPrint('Error checking Cloudinary configuration: $e');
      return false;
    }
  }

  // Generate Cloudinary signature
  static String generateSignature(
    String timestamp, {
    Map<String, String>? params,
  }) {
    // Start with the base parameters
    final signatureParams = params ?? {};
    signatureParams['timestamp'] = timestamp;

    // Create the string to sign
    final paramsToSign = signatureParams.entries
        .map((entry) => '${entry.key}=${entry.value}')
        .join('&');

    // Add the API secret
    final stringToSign = '$paramsToSign$_apiSecret';

    // Create a SHA-1 hash
    final bytes = utf8.encode(stringToSign);
    final digest = sha1.convert(bytes);

    return digest.toString();
  }

  // Pick image from gallery or camera
  static Future<File?> pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85, // Slightly reduced quality for better upload size
      );

      if (pickedFile != null) {
        debugPrint('Image picked successfully: ${pickedFile.path}');
        return File(pickedFile.path);
      }
      debugPrint('No image picked');
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  // Pick multiple images from gallery
  static Future<List<File>> pickMultipleImages({int maxImages = 5}) async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> pickedFiles = await picker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles.isNotEmpty) {
        // Limit to maxImages
        final limitedFiles = pickedFiles.take(maxImages).toList();
        debugPrint('${limitedFiles.length} images picked successfully');
        return limitedFiles.map((xfile) => File(xfile.path)).toList();
      }
      debugPrint('No images picked');
      return [];
    } catch (e) {
      debugPrint('Error picking multiple images: $e');
      return [];
    }
  }

  // Upload multiple images to Cloudinary
  static Future<List<String>> uploadMultipleImages(
    List<File> imageFiles, {
    UploadType uploadType = UploadType.pet,
    Function(int uploaded, int total)? onProgress,
  }) async {
    final List<String> uploadedUrls = [];
    
    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];
      final url = await uploadImage(file, uploadType: uploadType);
      if (url != null) {
        uploadedUrls.add(url);
      }
      // Report progress
      onProgress?.call(i + 1, imageFiles.length);
    }
    
    return uploadedUrls;
  }

  // Upload image to Cloudinary
  static Future<String?> uploadImage(
    File imageFile, {
    UploadType uploadType = UploadType.pet,
  }) async {
    if (!(await imageFile.exists())) {
      debugPrint('Image file does not exist at path: ${imageFile.path}');
      return null;
    }

    // Determine which configuration to use based on upload type
    final String uploadPreset =
        uploadType == UploadType.pet
            ? _petUploadPreset
            : _userProfileUploadPreset;

    final String folderName =
        uploadType == UploadType.pet ? _petFolderName : _userProfileFolderName;

    final CloudinaryPublic cloudinary =
        uploadType == UploadType.pet ? _petCloudinary : _userProfileCloudinary;

    debugPrint('Starting image upload to Cloudinary...');
    debugPrint('Upload type: ${uploadType.toString()}');
    debugPrint('Using upload preset: $uploadPreset');
    debugPrint('Using folder: $folderName');
    debugPrint('File size: ${await imageFile.length()} bytes');

    // Try authenticated upload first
    String? url = await _tryAuthenticatedUpload(imageFile, folderName);
    if (url != null) return url;

    // Try other methods if authenticated upload fails
    url = await _trySDKUpload(imageFile, cloudinary, folderName);
    if (url != null) return url;

    url = await _tryDirectUpload(imageFile, uploadPreset, folderName);
    if (url != null) return url;

    url = await _tryBase64Upload(imageFile, uploadPreset, folderName);
    if (url != null) return url;

    debugPrint('All upload methods failed');
    return null;
  }

  // Try authenticated upload using API key and secret
  static Future<String?> _tryAuthenticatedUpload(
    File imageFile,
    String folderName,
  ) async {
    try {
      debugPrint('Attempting authenticated upload with API key and secret...');

      // Generate timestamp and signature
      final timestamp =
          (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
      final params = {'folder': folderName, 'timestamp': timestamp};
      final signature = generateSignature(timestamp, params: params);

      // Create a multipart request
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', url);

      // Add the authenticated parameters
      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp;
      request.fields['signature'] = signature;
      request.fields['folder'] = folderName;

      // Add the file
      final filename = path.basename(imageFile.path);
      final fileField = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: filename,
      );
      request.files.add(fileField);

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('Authenticated upload response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final secureUrl = jsonResponse['secure_url'];
        debugPrint('Authenticated upload successful: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('Authenticated upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error in authenticated upload: $e');
      return null;
    }
  }

  // Try uploading with the CloudinaryPublic SDK
  static Future<String?> _trySDKUpload(
    File imageFile,
    CloudinaryPublic cloudinary,
    String folderName,
  ) async {
    try {
      debugPrint('Attempting upload with CloudinaryPublic SDK...');
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folderName,
          resourceType: CloudinaryResourceType.Auto,
        ),
      );
      debugPrint('SDK upload successful: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('SDK upload failed: $e');
      return null;
    }
  }

  // Try direct HTTP multipart upload
  static Future<String?> _tryDirectUpload(
    File imageFile,
    String uploadPreset,
    String folderName,
  ) async {
    try {
      debugPrint('Attempting direct HTTP multipart upload...');
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      // Create a multipart request
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folderName;

      // Add the file
      final filename = path.basename(imageFile.path);
      final fileField = await http.MultipartFile.fromPath(
        'file',
        imageFile.path,
        filename: filename,
      );
      request.files.add(fileField);

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final secureUrl = jsonResponse['secure_url'];
        debugPrint('Direct upload successful: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
          'Direct upload failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error in direct upload: $e');
      return null;
    }
  }

  // Try base64 encoded upload
  static Future<String?> _tryBase64Upload(
    File imageFile,
    String uploadPreset,
    String folderName,
  ) async {
    try {
      debugPrint('Attempting base64 encoded upload...');
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
      );

      final response = await http.post(
        url,
        body: {
          'file': 'data:image/jpeg;base64,$base64Image',
          'upload_preset': uploadPreset,
          'folder': folderName,
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final secureUrl = jsonResponse['secure_url'];
        debugPrint('Base64 upload successful: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
          'Base64 upload failed: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      debugPrint('Error in base64 upload: $e');
      return null;
    }
  }

  // Show image picker dialog
  static Future<File?> showImagePickerDialog(BuildContext context) async {
    final String? source = await showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Pick an Image Source'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.photo_camera, color: Colors.deepPurple),
                        SizedBox(width: 10),
                        Text('Take a Photo'),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext, 'camera');
                  },
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.photo_library, color: Colors.deepPurple),
                        SizedBox(width: 10),
                        Text('Choose from Gallery'),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext, 'gallery');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return null;
    if (source == 'camera') return await pickImage(ImageSource.camera);
    if (source == 'gallery') return await pickImage(ImageSource.gallery);
    return null;
  }

  // Show image picker dialog with multi-select option for gallery
  static Future<dynamic> showMultiImagePickerDialog(
    BuildContext context, {
    int maxImages = 5,
    int currentCount = 0,
  }) async {
    final remaining = maxImages - currentCount;
    
    final String? source = await showDialog<String?>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Add Photos'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.photo_camera, color: Colors.deepPurple),
                        SizedBox(width: 10),
                        Text('Take a Photo'),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext, 'camera');
                  },
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        const Icon(Icons.photo_library, color: Colors.deepPurple),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Choose from Gallery'),
                              Text(
                                'Select up to $remaining photo${remaining > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(dialogContext, 'gallery_multi');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return null;
    if (source == 'camera') {
      // Return single file for camera
      return await pickImage(ImageSource.camera);
    }
    if (source == 'gallery_multi') {
      // Return list of files for multi-select gallery
      return await pickMultipleImages(maxImages: remaining);
    }
    return null;
  }

  // Validate both upload presets directly - useful for troubleshooting
  static Future<Map<String, bool>> validateUploadPresets() async {
    Map<String, bool> results = {
      'cloudName': false,
      'petUploadPreset': false,
      'userProfileUploadPreset': false,
    };

    try {
      debugPrint('Validating Cloudinary configuration...');

      // First verify cloud name with API authentication
      final pingUrl = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/ping',
      );
      final pingResponse = await http.get(
        pingUrl,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}',
        },
      );

      if (pingResponse.statusCode == 200) {
        results['cloudName'] = true;
      } else {
        debugPrint(
          'Cloud name validation failed with status: ${pingResponse.statusCode}',
        );
        return results;
      }

      // Test pet upload preset with API auth
      try {
        final timestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        final petParams = {
          'upload_preset': _petUploadPreset,
          'timestamp': timestamp,
        };

        final petTestUrl = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/upload',
        );
        final petResponse = await http.post(
          petTestUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'api_key': _apiKey,
            'timestamp': timestamp,
            'signature': generateSignature(timestamp, params: petParams),
            'upload_preset': _petUploadPreset,
          }),
        );

        // If we get a 400 with "no file", the preset exists but we didn't provide a file
        // This is expected and means the preset is valid
        final petResponseData = jsonDecode(petResponse.body);
        results['petUploadPreset'] =
            petResponse.statusCode == 400 &&
            petResponseData.containsKey('error') &&
            petResponseData['error']['message'].toString().contains('no file');

        debugPrint(
          'Pet upload preset check: ${results['petUploadPreset']} (${petResponse.statusCode})',
        );
      } catch (e) {
        debugPrint('Error testing pet upload preset: $e');
      }

      // Test user profile upload preset with API auth
      try {
        final timestamp =
            (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
        final userParams = {
          'upload_preset': _userProfileUploadPreset,
          'timestamp': timestamp,
        };

        final userTestUrl = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/upload',
        );
        final userResponse = await http.post(
          userTestUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'api_key': _apiKey,
            'timestamp': timestamp,
            'signature': generateSignature(timestamp, params: userParams),
            'upload_preset': _userProfileUploadPreset,
          }),
        );

        // If we get a 400 with "no file", the preset exists but we didn't provide a file
        // This is expected and means the preset is valid
        final userResponseData = jsonDecode(userResponse.body);
        results['userProfileUploadPreset'] =
            userResponse.statusCode == 400 &&
            userResponseData.containsKey('error') &&
            userResponseData['error']['message'].toString().contains('no file');

        debugPrint(
          'User profile upload preset check: ${results['userProfileUploadPreset']} (${userResponse.statusCode})',
        );
      } catch (e) {
        debugPrint('Error testing user profile upload preset: $e');
      }

      return results;
    } catch (e) {
      debugPrint('Error validating upload presets: $e');
      return results;
    }
  }

  // --- Admin utilities ---
  static String? _extractPublicIdFromUrl(String url) {
    try {
      if (!url.contains('res.cloudinary.com')) return null;
      final uri = Uri.parse(url);
      final segments = uri.path.split('/');
      final uploadIndex = segments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 1 >= segments.length) return null;
      final afterUpload = segments.sublist(uploadIndex + 1);
      final parts =
          afterUpload.isNotEmpty && afterUpload.first.startsWith('v')
              ? afterUpload.sublist(1)
              : afterUpload;
      if (parts.isEmpty) return null;
      final joined = parts.join('/');
      final dot = joined.lastIndexOf('.');
      final publicId = dot > 0 ? joined.substring(0, dot) : joined;
      return publicId.isNotEmpty ? publicId : null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> deleteImageByUrl(String url) async {
    try {
      final publicId = _extractPublicIdFromUrl(url);
      if (publicId == null) return false;
      final apiUrl = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/resources/image/upload?public_ids[]=$publicId',
      );
      final resp = await http.delete(
        apiUrl,
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_apiKey:$_apiSecret'))}',
        },
      );
      debugPrint('Cloudinary delete $publicId -> ${resp.statusCode}');
      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e) {
      debugPrint('Cloudinary delete error: $e');
      return false;
    }
  }

  static Future<void> deleteImagesByUrls(List<String> urls) async {
    for (final url in urls) {
      await deleteImageByUrl(url);
    }
  }
}
