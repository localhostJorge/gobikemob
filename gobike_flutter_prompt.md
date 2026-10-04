You are working on a Flutter app "go_bike_app" (lib/screens/*.dart) for OneGoBike, a Philippine cyclist-responder nonprofit. "Go Bikers" use it on their ronda (patrol) to check on community members, and the RHU admin watches active Go Bikers LIVE on a map in the Laravel web admin (this live tracking is the core feature). Residents have a separate dashboard. Read every file in lib/ and the Android manifest before changing anything.

GOAL: make every button work, polish the UI/UX to a minimal, professional look with clear visual hierarchy, and connect the app to the Laravel API (MySQL behind it) for login, signup, Google sign-in and live tracking.

======================================================================
REAL API (Laravel). Use EXACTLY these endpoints
======================================================================
Base URL constant in lib/core/api_config.dart:
  const String kApiBaseUrl = 'http://127.0.0.1:8000/api';
(The phone is connected by USB; the laptop runs `adb reverse tcp:8000 tcp:8000` and `php artisan serve --port=8000`. Show a clear error toast if the server is unreachable.)
Also in api_config.dart: const String kGoogleWebClientId = 'PASTE_WEB_CLIENT_ID.apps.googleusercontent.com'; (I will replace it myself.)

Endpoints:
- POST /mobile/register  body {name, email, mobile, barangay, role: "Resident"|"GoBiker", password}  -> 201 {message, pending_approval, user}
- POST /mobile/login     body {email, password}  -> {message, token, user}
- POST /mobile/google    body {id_token}         -> {message, token, user}
- GET  /mobile/me        (Bearer token)          -> {user}
- POST /mobile/logout    (Bearer token)
- POST /gobiker/active/start   (Bearer, no body)  starts the ronda
- POST /gobiker/location       (Bearer) body {latitude, longitude} as numbers
- POST /gobiker/active/stop    (Bearer, no body)  ends the ronda
user = {id, name, email, mobile, barangay, role, member_since}
role is "User" (show the Resident dashboard), "GoBiker" (show the Go Biker dashboard with rondas) or "Admin" (show an error toast "Admin accounts use the web admin panel." and do not enter the app).
Errors: 422 {message, errors:{field:[...]}} for validation; 401/403 {message}. A 403 on login means the account is not active/approved yet (show the message in an error toast). After a GoBiker signup with pending_approval=true, show an info toast ("An admin must approve your account before you can log in") and go to Login.
Every request must send headers: Accept: application/json, Content-Type: application/json, and Authorization: Bearer <token> when logged in. Parse errors safely: if the body is not valid JSON, show a generic "Something went wrong" toast, never crash.
There are NO API endpoints yet for: forgot-password, emergency alert, appointments, patients, ronda history, messages to admin. Keep those features working locally in the app (in-memory, as they are now), add a TODO(api) comment on each, and do NOT call made-up endpoints. Hide the "Forgot password?" link for now (TODO(api)).

======================================================================
ANDROID + TRACKING (core feature)
======================================================================
- android/app/src/main/AndroidManifest.xml: add <uses-permission> for INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION. Add android:usesCleartextTraffic="true" on <application> with the comment "DEV ONLY - remove when the API is on HTTPS".
- Use geolocator. Before starting a ronda, check the location service is on and request permission; if denied, show an error toast explaining why it is needed and do not start.
- Start Ronda: after the user confirms in the modal, call POST /gobiker/active/start. On success start sending the position every 10 seconds with POST /gobiker/location {latitude, longitude}. Put this in lib/core/tracking_service.dart (a Timer; stop it on logout, on app close of the ronda, and when the ronda ends). Keep the screen awake during an active ronda (wakelock_plus).
- End/Finish ronda: call POST /gobiker/active/stop, then stop the Timer.
- If the token is rejected (401) or the role is wrong (403), stop tracking and show the API message in an error toast.
- Only the GoBiker role can use these endpoints; residents never see Start Ronda.

======================================================================
RULES
======================================================================
- Work in the PHASES below. After each phase run `flutter analyze`, fix errors, then STOP and summarize what changed so I can test before you continue. Start with Phase 0 and Phase 1 ONLY.
- Keep the existing navy (#1E1E48) / blue (#2E62C8) / orange palette. Minimal: white surfaces, lots of spacing, one accent color, no heavy gradients, no clutter.
- Hierarchy: one clear primary action per screen, secondary actions as outlined/text buttons, consistent type scale (title 22 bold, section label 12 caps, body 14, caption 12), consistent 16px padding and 12-16px radius.
- Use ONE icon set (Material Rounded icons, e.g. Icons.home_rounded). Do not mix filled/outlined randomly.
- Never leave `onPressed: () {}` or fake "coming soon" snackbars. Every button either works or is removed.
- Keep code organized: create lib/widgets/ and lib/core/ for shared pieces instead of growing dashboard_screen.dart.
- If something is ambiguous, ask me before assuming.

======================================================================
PHASE 0 - Cleanup
======================================================================
- pubspec.yaml: google_maps_flutter and geolocator are currently outside `dependencies:`. Move them inside, remove duplicates, and add: http, flutter_secure_storage, google_sign_in (^7.x), url_launcher, wakelock_plus. Run flutter pub get.
- Remove DummyHomeScreen and the unused globalUsers list. Remove the old SQLite auth (auth_database.dart) once the API login works (Phase 2).
- Add lib/core/theme.dart with light AND dark ThemeData built from the palette, and a ThemeController (ChangeNotifier) that persists the choice with shared_preferences. Wire it into MaterialApp (theme, darkTheme, themeMode). Dark mode must apply to the WHOLE app.

======================================================================
PHASE 1 - Reusable UI
======================================================================
1. lib/widgets/app_toast.dart: floating top message. Use an OverlayEntry (NOT SnackBar) that slides down from the top below the status bar, auto-dismisses after ~2.5s, swipe up to dismiss. Types: success (green), error (red), info (blue), each with an icon. API: AppToast.show(context, 'Message', type: ToastType.success). Replace EVERY ScaffoldMessenger/SnackBar in the app with it.
2. lib/widgets/loading_overlay.dart: loading indicator CENTERED on screen (full-screen semi-transparent scrim + centered card with a CircularProgressIndicator or the logo pulsing). Use it for login, signup, Google sign-in, logout and API calls. Remove tiny spinners inside buttons.
3. lib/widgets/confirm_modal.dart: reusable floating dialog (radius 20, centered icon in a tinted circle, title, short description, Cancel (outlined) + Confirm (filled), scale+fade animation via showGeneralDialog). Params: icon, color, title, description, confirmText, onConfirm.
4. lib/widgets/fade_in_slide.dart: wrapper that fades in and slides up 16px with a delay parameter (Curves.easeOutCubic, 450ms).

======================================================================
PHASE 2 - Auth (login, signup, Google) - all fully working
======================================================================
- Create lib/core/auth_service.dart that calls the REAL API above with the `http` package. Store the token with flutter_secure_storage. "Remember me": if checked, persist the session; if unchecked, keep the token in memory only (session ends when the app closes).
- Splash: gentle fade/scale of the logo with a centered loading indicator; checks the stored token with GET /mobile/me, then routes by role (GoBiker -> DashboardScreen, User -> ResidentDashboardScreen, no/invalid token -> Login).
- Login: validation (email format, password min 8), show/hide password, errors via AppToast, centered LoadingOverlay while waiting.
- Signup: validate every field, confirm-password match, password strength hint, barangay + role dropdowns as already built (roles shown as Resident / Go Biker). Terms checkbox required. After success show the proper toast and go to Login.
- Google sign-in: use google_sign_in ^7.x with the NEW API (not 6.x): call `await GoogleSignIn.instance.initialize(serverClientId: kGoogleWebClientId)` once at app start, then `final account = await GoogleSignIn.instance.authenticate();` and read `account.authentication.idToken`. POST it to /mobile/google as {id_token}. Handle cancel (GoogleSignInException), no internet and server errors with AppToast. If idToken is null, show a toast saying the Web client ID is missing/wrong. Put the Android setup notes (package com.example.go_bike_app, SHA-1 of this laptop's debug keystore, Web client ID as serverClientId) in a comment block at the top of auth_service.dart.
- Terms of Service and Privacy Policy: create lib/screens/terms_screen.dart and privacy_screen.dart (or one LegalScreen with a type param). Clean, scrollable, numbered sections with clear headings. Write real, plain-language content for a community health/responder app in the Philippines: what data is collected (name, email, mobile, barangay, role, GPS location while a ronda is active, health notes of residents), why, who can see it (RHU admins), retention, security, user rights under the Data Privacy Act of 2012 (RA 10173), an emergency disclaimer (the app does not replace calling 911 or local emergency lines), and a contact email placeholder. Link them from the signup checkbox text (tappable TextSpans with TapGestureRecognizer) and from the Profile panel.

======================================================================
PHASE 3 - Dashboard (DashboardScreen)
======================================================================
- Greeting at the top: "Good Morning! <first name>" (05:00-11:59), "Good Afternoon!" (12:00-17:59), "Good Evening!" (18:00-21:59), "Good Night!" (22:00-04:59). Name from the logged-in user. Helper in lib/core/greeting.dart; refresh on app resume.
- Simplify the header: white background, small logo at the left, greeting text (small "Good Morning!" line above the bold name). No profile avatar in the header.
- Bottom bar: Home, Notifications, Patients, Profile at the FAR RIGHT. Remove the logout icon from the bar. Selected state = blue icon + small label, animated.
- Profile: tapping the Profile item opens a panel that SLIDES IN FROM THE RIGHT (showGeneralDialog + SlideTransition from Offset(1,0), ~80% width, full height, scrim, tap outside or swipe right to close). Top to bottom: avatar + full name + role badge; "Personal Information" (email, mobile, barangay, role, member since); "Appearance" with a Dark mode Switch bound to ThemeController (changes the whole app instantly and persists); "Legal" with Terms of Service and Privacy Policy rows; Logout button at the very bottom (red outlined). Logout opens confirm_modal ("Log out? You will need to sign in again."), then calls POST /mobile/logout, clears the secure token, stops tracking, shows the toast "You have been logged out", and returns to Login clearing the navigation stack.
- SLIDE TO START RONDA: when the thumb is dragged past 80% it must STAY at the far right (do not reset) and then the confirm modal appears. Cancel -> animate the thumb smoothly back to the left. Start -> keep it at the right while starting, reset when the ronda ends/returns. Haptic feedback (HapticFeedback.mediumImpact) on completion, subtle shimmer on the idle label. No animation while dragging; AnimatedPositioned easeOut on release.
- Start Ronda modal (confirm_modal): bike icon in a blue circle, title "Start your ronda?", description "Your location will be shared with the RHU admin while the ronda is active. Visit each assigned household and record your findings. You can end the ronda anytime.", buttons Cancel (outlined) and "Start Ronda" (filled blue). Start runs the tracking flow from the ANDROID + TRACKING section.
- Emergency button: confirm_modal in red: warning icon, title "Send emergency alert?", description "This immediately alerts the RHU admin with your current location. Use only for real emergencies.", buttons Cancel and "Send Alert". There is no alert endpoint yet, so on confirm: get the location, show the success toast "Emergency alert sent" only after the local step succeeds, add TODO(api), and offer a "Call emergency number" action using url_launcher (tel:) as a fallback.
- Appointments: a real screen (list of upcoming visits with date, patient, status; empty state with icon + short text) instead of a snackbar. Local data for now, TODO(api).
- Message Admin and Ronda History keep working locally, with the new modal/bottom-sheet styling and top toasts.
- Dashboard order and hierarchy: 1) greeting header, 2) Today's Assignment card (primary, biggest), 3) Today's Summary (3 equal stat cards with icons), 4) Quick actions row (Patients, Emergency, Appointments - equal size, label under icon, emergency in red tint), 5) Announcements, 6) Message Admin / Ronda History. Section labels small caps grey. Cards: white, 1px light border, very soft shadow, 16px radius.
- Entrance animation: when the dashboard first builds after login, every component fades in and slides up with ~80ms stagger using fade_in_slide (header -> assignment card -> summary cards one by one -> quick actions -> announcements -> buttons -> bottom bar). Smooth and professional, not flashy; once per dashboard open.
- Replace hard-coded placeholders ("Barangay: Poblacion, Bugallon", sample announcements) with the user's barangay from the profile, and put remaining sample data in lib/core/sample_data.dart, clearly marked.

======================================================================
PHASE 4 - Rest of the app
======================================================================
- Apply the same theme, toasts, centered loading, modals and fade-in to: Resident dashboard (its "Opening Health Records..." style snackbars must open a real screen or be removed), Patient management, Add patient, View patient, Active ronda. Delete/Edit confirmations use confirm_modal.
- Dark mode must look right on every screen (no hard-coded Colors.white / Colors.black87; use Theme.of(context).colorScheme and the theme tokens).
- Patients and rondas stay in the in-memory lists for now (TODO(api)); only add centered loading/empty states.

======================================================================
PHASE 5 - Final checks
======================================================================
- flutter analyze must be clean. Test on the physical phone: signup, login, Google sign-in, logout, dark mode toggle, slide-to-start, emergency, appointments, patients CRUD, and that the admin web Live Map shows the Go Biker while the ronda is active.
- Write API_CONTRACT.md in the project root listing every endpoint the app actually calls (and every TODO(api) feature that still needs one), with request/response JSON.
