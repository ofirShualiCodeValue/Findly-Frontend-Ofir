// Backend base URL.
//
// Web: http://localhost:3000  (browser → server on same machine)
// Android emulator: http://10.0.2.2:3000  (10.0.2.2 is the host's loopback alias)
// Physical Android device on the same Wi-Fi: http://<your-PC-LAN-IP>:3000
//
// Override at run time with: flutter run --dart-define=API_BASE_URL=http://...
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);
