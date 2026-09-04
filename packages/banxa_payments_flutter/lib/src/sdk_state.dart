import 'api/banxa_api_client.dart';

/// Process-wide client slot. Not exported from the public barrel.
class BanxaSdkState {
  static BanxaApiClient? client;

  static void reset() {
    client?.close();
    client = null;
  }
}
