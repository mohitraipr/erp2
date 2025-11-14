# aurora_login_app

Simple Flutter login screen that posts credentials to the Aurora backend and displays
the response payload.

## Getting Started

1. Update the `_baseUrl` in `lib/services/api_service.dart` if your API lives elsewhere.
2. Run the app with `flutter run`.
3. Enter credentials and tap **Sign in**.

On success the app navigates to a response screen showing the returned username, role,
and optional user id.
