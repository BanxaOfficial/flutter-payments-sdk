// swift-tools-version: 5.9

import PackageDescription

// Swift Package Manager support. CocoaPods consumers use
// ../banxa_payments_flutter_ios.podspec, which compiles the same sources.
//
// PrimerSDK's own SPM floor. Flutter 3.47+ still raises the host app to 15.0.
let package = Package(
  name: "banxa_payments_flutter_ios",
  platforms: [
    .iOS("13.1")
  ],
  products: [
    .library(
      name: "banxa-payments-flutter-ios",
      targets: ["banxa_payments_flutter_ios"]
    )
  ],
  dependencies: [
    // >=2.49.0 <3.0.0. Host apps can pin any 2.x in that range.
    .package(
      url: "https://github.com/primer-io/primer-sdk-ios.git",
      from: "2.49.0"
    )
  ],
  targets: [
    .target(
      name: "banxa_payments_flutter_ios",
      dependencies: [
        .product(name: "PrimerSDK", package: "primer-sdk-ios")
        // PrimerCore is not a public SPM product; the module is linked via
        // PrimerSDK. CocoaPods declares PrimerCore explicitly in the podspec.
      ]
    )
  ]
)
