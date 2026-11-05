# Firebase Auth Lab — In-Class Activity 13

**Nour Khoulani · CSC 4360**

An Android Flutter app that uses Firebase Authentication for email and password registration, sign-in, and sign-out. The app displays the signed-in user's email on a protected profile. It also supports password changes, reauthentication when Firebase requires a recent login, input validation, and loading and error feedback.

## Setup and run

1. Create or select a Firebase project and enable **Authentication → Sign-in method → Email/Password**.
2. With the Firebase and FlutterFire CLIs installed, run these commands from the project folder:

   ```sh
   flutter pub get
   firebase login
   flutterfire configure
   ```

3. Select your Firebase project and **Android**. Use the Android application ID `com.example.my_product_app`. The Firebase project configuration files are generated locally.
4. Start an Android emulator and run `flutter run`. To build the release APK, run `flutter build apk --release`.

## Manual testing

- Submit a blank form or a password shorter than six characters during registration. Confirm the app displays validation feedback.
- Register a test account. Confirm the profile shows the test email and check Firebase Authentication → Users for the account.
- Close and reopen the app while signed in. Confirm the profile reappears.
- Change the password and sign out. Confirm Android Back cannot reopen the profile. Confirm the old password is rejected and the new password works.