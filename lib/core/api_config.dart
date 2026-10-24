// The hosted Laravel API (Railway) the app uses unless a build says otherwise.
const String kProductionApiBaseUrl = 'https://gobike.up.railway.app/api';

// Base URL of the Laravel API. Set it per build, without editing code:
//   flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000/api   (local, over adb reverse)
//   flutter build apk --release                                       (hosted API)
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: kProductionApiBaseUrl,
);

// Web OAuth client ID from Google Cloud (ends in .apps.googleusercontent.com).
const String kGoogleWebClientId =
    '74930481103-etb908md584r1otulev0b9a0a5qpbcjf.apps.googleusercontent.com';
