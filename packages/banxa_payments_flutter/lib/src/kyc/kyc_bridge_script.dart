import 'dart:convert';

/// JavaScript channel the bridge script posts to.
const kycBridgeChannelName = 'BanxaKycBridge';

/// Returns the script that forwards `banxa:*` messages to the Dart channel.
String kycBridgeScript({required String nonce}) {
  final encodedNonce = jsonEncode(nonce);
  return '''
(function () {
  if (window.__banxaKycBridge) return;
  window.__banxaKycBridge = true;
  var channel = window.$kycBridgeChannelName;
  var nonce = $encodedNonce;
  var original = window.postMessage;
  window.postMessage = function (data) {
    try {
      if (channel && data && typeof data === 'object' &&
          typeof data.type === 'string' && data.type.indexOf('banxa:') === 0) {
        channel.postMessage(JSON.stringify({
          nonce: nonce,
          origin: window.location.origin,
          type: data.type,
          status: data.status,
          code: data.code,
          message: data.message
        }));
      }
    } catch (e) {}
    return original.apply(this, arguments);
  };
})();
''';
}
