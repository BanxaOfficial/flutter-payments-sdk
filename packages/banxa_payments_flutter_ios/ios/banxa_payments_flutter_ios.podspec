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
  s.version          = '0.1.2'
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
  # >=2.49.0 <3.0.0. Host apps can pin any 2.x in that range.
  s.dependency 'PrimerSDK', '>= 2.49.0', '< 3.0.0'
  s.dependency 'PrimerCore', '>= 2.49.0', '< 3.0.0'
  # PrimerSDK's Swift Package / CocoaPods floor. Flutter 3.47+ still raises the
  # *host app* to 15.0; this plugin does not.
  s.platform = :ios, '13.1'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
