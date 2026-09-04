// swift-tools-version: 5.9

import PackageDescription

// Swift Package Manager support. CocoaPods consumers use
// ../banxa_payments_flutter_ios.podspec, which compiles the same sources.
//
// iOS 13.1 is PrimerSDK's own SPM floor.
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
    // Pinned to the same generation as Banxa's native iOS client.
    .package(
      url: "https://github.com/primer-io/primer-sdk-ios.git",
      exact: "2.49.0"
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
