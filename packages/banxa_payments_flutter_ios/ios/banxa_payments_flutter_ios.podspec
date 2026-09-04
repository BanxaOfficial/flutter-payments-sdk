#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
# Sources live under banxa_payments_flutter_ios/Sources/ so that the same tree
# serves both CocoaPods and Swift Package Manager (see Package.swift).
#
Pod::Spec.new do |s|
  # Flutter resolves the iOS plugin via this package-matching name.
  # Product branding / CocoaPods public name intent: BanxaPaymentsFlutter.
  s.name             = 'banxa_payments_flutter_ios'
  s.version          = '0.1.0'
  s.summary          = 'Banxa native checkout Flutter plugin (iOS).'
  s.description      = <<-DESC
Banxa partner-api v2 + Primer native checkout for Flutter on iOS.
                       DESC
  s.homepage         = 'https://banxa.com'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Banxa' => 'support@banxa.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'banxa_payments_flutter_ios/Sources/banxa_payments_flutter_ios/**/*.swift'
  s.dependency 'Flutter'
  # Pinned Primer iOS 2.49.0 (same generation as Banxa's existing native iOS client).
  s.dependency 'PrimerSDK', '2.49.0'
  s.dependency 'PrimerCore', '2.49.0'
  # Matches PrimerSDK's Swift Package Manager floor.
  s.platform = :ios, '13.1'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
