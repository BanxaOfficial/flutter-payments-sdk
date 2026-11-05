/// Hosted KYC request, session and event types.
///
/// These stay in the app-facing package: nothing here crosses the platform
/// channel.
library;

/// Inbound `type` values the hosted KYC flow posts.
const kycLoadingMessageType = 'banxa:loading';
const kycReadyMessageType = 'banxa:ready';
const kycCompleteMessageType = 'banxa:kyc-complete';
const kycErrorMessageType = 'banxa:error';

/// Verification depth for a hosted KYC session.
///
/// `express` is accepted by partner-api but is not binding: Banxa may still
/// run a `standard` check.
enum KycTier {
  standard,
  express,
  enhanced;

  String get wireValue => name;
}

/// Body for `POST /kyc/sessions`.
class CreateKycSessionRequest {
  const CreateKycSessionRequest({
    required this.externalCustomerId,
    this.tier,
    this.country,
    this.returnUrl,
  });

  /// Your id for the customer.
  final String externalCustomerId;

  /// Defaults to [KycTier.standard] on the server when omitted.
  final KycTier? tier;

  /// ISO 3166-1 alpha-2 country code.
  final String? country;

  /// Where the flow sends the customer when it ends.
  final String? returnUrl;
}

/// A hosted KYC link returned by `POST /kyc/sessions`.
///
/// Build it yourself when your backend creates the session and passes the two
/// fields to the app, which keeps the API key off the device.
class KycSession {
  const KycSession({required this.redirectUrl, required this.expiresAt});

  final String redirectUrl;

  /// ISO-8601 time the link stops working, as sent by the server.
  final String expiresAt;

  /// [expiresAt] parsed, or null when the format is unreadable.
  DateTime? get expirationDate => DateTime.tryParse(expiresAt);
}

/// Which signal told the SDK the customer finished the flow.
enum BanxaKycChannel { message, returnUrl }

/// Why the hosted KYC flow failed or was refused before loading.
enum BanxaKycFailureReason {
  sessionExpired,
  invalidSessionUrl,
  unsupportedOsVersion,
  loadTimeout,
  loadFailed,
  flowError,
}

/// Why a `banxa:*` message was ignored.
enum BanxaKycRejectionReason {
  /// The message did not come through the main-frame bridge.
  frame,

  /// It came from an origin outside the session URL and `allowedOrigins`.
  origin,
}

/// Lifecycle event from [BanxaHostedKycView].
sealed class BanxaKycEvent {
  const BanxaKycEvent();
}

/// The customer finished the flow. This is a UI signal only: the verification
/// result reaches your backend by webhook.
class BanxaKycCompleted extends BanxaKycEvent {
  const BanxaKycCompleted({required this.status, required this.channel});

  final String status;
  final BanxaKycChannel channel;
}

/// The flow failed, or the session was refused before loading. Every reason
/// except [BanxaKycFailureReason.flowError] ends the session.
class BanxaKycFailed extends BanxaKycEvent {
  const BanxaKycFailed(this.reason, {this.code, this.message});

  final BanxaKycFailureReason reason;
  final String? code;
  final String? message;
}

/// The hosted flow is ready for the customer.
class BanxaKycReady extends BanxaKycEvent {
  const BanxaKycReady({this.status = 'ready'});

  final String status;
}

/// The hosted flow is loading a step.
class BanxaKycLoading extends BanxaKycEvent {
  const BanxaKycLoading({this.status = 'loading'});

  final String status;
}

/// A `banxa:*` message was received and ignored. Use it to diagnose an
/// integration that never completes.
class BanxaKycMessageRejected extends BanxaKycEvent {
  const BanxaKycMessageRejected({
    required this.reason,
    required this.type,
    this.origin,
  });

  final BanxaKycRejectionReason reason;
  final String type;
  final String? origin;
}

/// The view was disposed before the flow completed or failed.
class BanxaKycDismissed extends BanxaKycEvent {
  const BanxaKycDismissed();
}
