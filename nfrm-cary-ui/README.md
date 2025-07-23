# ai-agents-ui

A Flutter-based UI for AI Agents, designed to be deployable on Web, Android, and iOS.
This initial version features a simple single-page application with a Google search-style text field and image placeholders.

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- An IDE like [VS Code](https://code.visualstudio.com/) (with Flutter extension) or [Android Studio](https://developer.android.com/studio) (with Flutter plugin).
- For iOS development: macOS with Xcode.
- For Android development: Android Studio and Android SDK.

## Project Setup

1.  **Clone the repository (if you haven't already):**
    ```bash
    git clone git@github.com:iwish-vinay/ai-agents-ui.git
    cd ai-agents-ui
    ```

2.  **If you haven't created the Flutter project structure yet:**
    It's recommended to create a Flutter project with the name `ai_agents_ui`.
    ```bash
    # flutter create . # If you are already inside ai-agents-ui and it's empty
    # OR
    # flutter create ai_agents_ui # And then copy these files into it
    ```
    Ensure the `pubspec.yaml`, `lib/` directory, and this `README.md` are correctly placed.

3.  **Create assets folder and add images:**
    Create a folder `assets/images/` in the root of your project.
    Add some placeholder images to this folder, for example:
    - `assets/images/placeholder1.png`
    - `assets/images/placeholder2.png`
    - `assets/images/placeholder3.png`
    *(You'll need to provide these image files yourself.)*

4.  **Get dependencies:**
    Open your project in your IDE or navigate to the project root in your terminal and run:
    ```bash
    flutter pub get
    ```

## Running Locally

You can run the app on different platforms:

### Web
```bash
flutter run -d chrome
```

### Android
Ensure you have an Android emulator running or a device connected.
```bash
flutter run
```

### iOS
Ensure you have an iOS simulator running or a device connected (requires macOS and Xcode).
```bash
flutter run
```

## Building for Deployment

### Web
The output will be in the `build/web` directory.
```bash
flutter build web
```

### Android
For an APK:
```bash
flutter build apk
```
For an App Bundle (recommended for Google Play):
```bash
flutter build appbundle
```
The output will be in `build/app/outputs/`.

### iOS
Requires macOS and Xcode. Open the `ios` folder in Xcode for further configuration and archiving.
```bash
flutter build ios
```
The output .app can be found in `build/ios/iphoneos` or use Xcode to archive and distribute.

## Connecting to Cloud Run Service

This UI is intended to eventually connect to a backend service deployed on Cloud Run.
To do this, you would typically use an HTTP client package like `http` (`dependencies: http: ^1.2.0` in `pubspec.yaml`).

Example (conceptual, to be implemented in your Dart code):
```dart
// import 'package:http/http.dart' as http;
// import 'dart:convert';

// Future<void> fetchData(String query) async {
//   final response = await http.post(
//     Uri.parse('YOUR_CLOUD_RUN_SERVICE_URL'),
//     headers: <String, String>{
//       'Content-Type': 'application/json; charset=UTF-8',
//     },
//     body: jsonEncode(<String, String>{
//       'query': query,
//     }),
//   );
//   if (response.statusCode == 200) {
//     // Process the response
//     print('Response data: ${response.body}');
//   } else {
//     // Handle error
//     print('Failed to fetch data.');
//   }
// }
```
You would call such a function when the user submits the text field or performs an action.



## Deploy web version on Google Cloud Run

flutter clean
flutter pub get
flutter build web --release # or your choice of environment

export PROJECT_ID="ai-agent-repo"
export REGION="us-east1"
export REPOSITORY_NAME="ai-agents-ui"
export SERVICE_NAME="ai-agents-ui-app"
export IMAGE_NAME="${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY_NAME}/${SERVICE_NAME}"

gcloud auth login
gcloud config set project ${PROJECT_ID}
gcloud auth configure-docker ${REGION}-docker.pkg.dev


gcloud services enable artifactregistry.googleapis.com
gcloud artifacts repositories create ${REPOSITORY_NAME} \
    --repository-format=docker \
    --location=${REGION} \
    --description="Docker repository for ai-agents-ui"


# The gcloud auth configure-docker command was already run above.
docker build --platform linux/amd64 -t "${IMAGE_NAME}":latest .
docker push "${IMAGE_NAME}":latest

gcloud run deploy ${SERVICE_NAME} \
  --image="${IMAGE_NAME}":latest \
  --platform=managed \
  --port=80 \
  --region=${REGION} \
  --allow-unauthenticated




## Firebase setup 
https://firebase.google.com/docs/cli#install-cli-mac-linux
curl -sL https://firebase.tools | bash
firebase login
firebase projects:list

## How to setup app on your iphone. Run below command when your phone is wire with Mac
flutter devices
flutter run --release 
## After above command, you an press q end then remove the wire. Your app will work like any other app.
