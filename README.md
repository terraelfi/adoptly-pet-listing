# 🐾 Adoptly - Pet Adoption & Listing App

<p align="center">
  <img src="assets/images/adoptly.png" alt="Adoptly Logo" width="200"/>
</p>

<p align="center">
  <strong>Find your perfect furry companion nearby!</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#screenshots">Screenshots</a> •
  <a href="#installation">Installation</a> •
  <a href="#tech-stack">Tech Stack</a> •
  <a href="#configuration">Configuration</a>
</p>

---

## 📖 About

**Adoptly** is a Flutter-based mobile application that connects pet lovers with animals in need of a home. Users can browse available pets on an interactive map, chat with pet owners, save their favorite listings, and even donate to animal welfare organizations.

---

## ✨ Features

- 🔐 **User Authentication** - Secure login and registration with Firebase Auth
- 🗺️ **Interactive Map** - Browse pets available for adoption near your location
- 🐶 **Pet Listings** - View detailed information about each pet including photos, breed, age, and more
- 💬 **Real-time Chat** - Communicate directly with pet owners/shelters
- ❤️ **Save Favorites** - Bookmark pets you're interested in for later
- ➕ **Add Pet Listings** - List your pet for adoption with photos and details
- 🔔 **Push Notifications** - Get notified about new messages and listing updates
- 💰 **Donation Portal** - Support animal welfare NGOs directly through the app
- 👤 **User Profiles** - Manage your profile and view your listings
- 🛡️ **Admin Panel** - Moderate users, pets, and review pending submissions

---

## 📸 Screenshots

<!-- 
  PLACEHOLDER: Add your app screenshots here
  Recommended: Use a table layout for better organization
  Suggested image dimensions: 300px width for mobile screenshots
-->

### Home & Map View
| Home Screen | Map View | Pet Details |
|:-----------:|:--------:|:-----------:|
| ![Home Screen](screenshots/home_screen.png) | ![Map View](screenshots/map_view.png) | ![Pet Details](screenshots/pet_details.png) |
<!-- TODO: Replace with actual screenshots -->

### User Features
| Login | Register | Profile |
|:-----:|:--------:|:-------:|
| ![Login](screenshots/login.png) | ![Register](screenshots/register.png) | ![Profile](screenshots/profile.png) |
<!-- TODO: Replace with actual screenshots -->

### Chat & Social
| Chat List | Chat Screen | Notifications |
|:---------:|:-----------:|:-------------:|
| ![Chat List](screenshots/chat_list.png) | ![Chat Screen](screenshots/chat.png) | ![Notifications](screenshots/notifications.png) |
<!-- TODO: Replace with actual screenshots -->

### Pet Management
| Add Pet | Saved Pets | Donation |
|:-------:|:----------:|:--------:|
| ![Add Pet](screenshots/add_pet.png) | ![Saved Pets](screenshots/saved_pets.png) | ![Donation](screenshots/donation.png) |
<!-- TODO: Replace with actual screenshots -->

### Admin Panel
| Users Management | Pets Management | Pending Review |
|:----------------:|:---------------:|:--------------:|
| ![Users Tab](screenshots/admin_users.png) | ![Pets Tab](screenshots/admin_pets.png) | ![Review Tab](screenshots/admin_review.png) |
<!-- TODO: Replace with actual screenshots -->

---

## 🛠️ Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.7+ |
| **Language** | Dart |
| **Backend** | Firebase |
| **Authentication** | Firebase Auth |
| **Database** | Cloud Firestore |
| **Storage** | Firebase Storage, Cloudinary |
| **Maps** | Flutter Map + OpenStreetMap |
| **Notifications** | Firebase Cloud Messaging |
| **Location** | Geolocator, Geocoding |

---

## 📦 Installation

### Prerequisites

- Flutter SDK ^3.7.2
- Dart SDK
- Android Studio / VS Code
- Firebase project setup
- Cloudinary account

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/adoptly_pet_listing.git
   cd adoptly_pet_listing
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - Enable Authentication (Email/Password)
   - Enable Cloud Firestore
   - Enable Firebase Storage
   - Enable Firebase Cloud Messaging
   - Download and add the configuration files:
     - `google-services.json` for Android
     - `GoogleService-Info.plist` for iOS
   - Run FlutterFire CLI to generate `firebase_options.dart`:
     ```bash
     flutterfire configure
     ```

4. **Configure Cloudinary**
   - Create a Cloudinary account at [cloudinary.com](https://cloudinary.com/)
   - Set up upload presets for:
     - Pet images
     - User profile images
   - Update the cloud name in `lib/main.dart`

5. **Run the app**
   ```bash
   flutter run
   ```

---

## ⚙️ Configuration

### 🔐 Environment Variables Setup (IMPORTANT!)

This project uses environment variables to keep API keys secure. **Never commit your `.env` file to version control!**

#### Step 1: Create your `.env` file

Copy the example file and fill in your actual API keys:

```bash
cp env.example .env
```

#### Step 2: Fill in your API keys

Edit the `.env` file with your actual values:

```env
# Cloudinary Configuration
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret
CLOUDINARY_PET_UPLOAD_PRESET=your_pet_preset
CLOUDINARY_USER_PROFILE_UPLOAD_PRESET=your_user_profile_preset

# MapTiler Configuration
MAPTILER_API_KEY=your_maptiler_key

# Google APIs Configuration
GOOGLE_PLACES_API_KEY=your_google_places_key
GOOGLE_MAPS_API_KEY=your_google_maps_key

# Firebase Configuration (Web)
FIREBASE_WEB_API_KEY=your_firebase_web_api_key
FIREBASE_WEB_APP_ID=your_app_id
FIREBASE_WEB_MESSAGING_SENDER_ID=your_sender_id
FIREBASE_WEB_PROJECT_ID=your_project_id
FIREBASE_WEB_AUTH_DOMAIN=your_auth_domain
FIREBASE_WEB_STORAGE_BUCKET=your_storage_bucket

# Firebase Configuration (Android)
FIREBASE_ANDROID_API_KEY=your_android_api_key
FIREBASE_ANDROID_APP_ID=your_android_app_id

# Firebase Configuration (iOS)
FIREBASE_IOS_API_KEY=your_ios_api_key
FIREBASE_IOS_APP_ID=your_ios_app_id
FIREBASE_IOS_BUNDLE_ID=com.example.adoptlyPetListing
```

#### Where to get your API keys:

| Service | Where to Get |
|---------|-------------|
| **Cloudinary** | [Cloudinary Console](https://console.cloudinary.com/) → Dashboard |
| **MapTiler** | [MapTiler Cloud](https://cloud.maptiler.com/) → API Keys |
| **Google Places/Maps** | [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials |
| **Firebase** | [Firebase Console](https://console.firebase.google.com/) → Project Settings |

### Firebase Setup

1. Create a Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Enable the following services:
   - Authentication (Email/Password)
   - Cloud Firestore
   - Firebase Storage
   - Firebase Cloud Messaging
3. Add your API keys to the `.env` file

Ensure your Firestore has the following collections:
- `users` - User profiles and data
- `pets` - Pet listings
- `chatRooms` - Chat conversations

### Cloudinary Setup

1. Create account at [cloudinary.com](https://cloudinary.com/)
2. Create two **unsigned** upload presets:
   - One for pet images
   - One for user profile images
3. Add your credentials to the `.env` file

---

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── models/                   # Data models
│   └── pet_listing.dart
├── screens/                  # UI screens
│   ├── home_screen.dart
│   ├── map_screen.dart
│   ├── chat_screen.dart
│   ├── profile_screen.dart
│   ├── admin_screen.dart
│   └── map/                  # Map-related widgets
├── services/                 # Business logic
│   ├── auth_service.dart
│   ├── cloudinary_service.dart
│   └── notification_service.dart
└── widgets/                  # Reusable widgets
```

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Contact

<!-- TODO: Add your contact information -->
- **Email**: your.email@example.com
- **GitHub**: [@yourusername](https://github.com/yourusername)

---

<p align="center">
  Made with ❤️ for pets and their future families
</p>
# adoptly-pet-listing
