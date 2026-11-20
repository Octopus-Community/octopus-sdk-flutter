// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// Internal tooling (native-dev): inert unless both variables are set. During a
// native dev-source window the Octopus package resolves from one revision of
// another repository; SwiftPM names a package after its URL, so the product
// references below follow that name.
let octopusDevEnvironment = ProcessInfo.processInfo.environment
let octopusDevURL = octopusDevEnvironment["OCTOPUS_IOS_DEV_PACKAGE_URL"] ?? ""
let octopusDevRevision = octopusDevEnvironment["OCTOPUS_IOS_DEV_REVISION"] ?? ""
let octopusUsesDevRevision = !octopusDevURL.isEmpty && !octopusDevRevision.isEmpty
let octopusPackage: Package.Dependency = octopusUsesDevRevision
    ? .package(url: octopusDevURL, revision: octopusDevRevision)
    // Native Octopus iOS SDK, distributed as a Swift Package. Keep this
    // version in lockstep with the CocoaPods pins in
    // `octopus_sdk_flutter.podspec` (OctopusCommunity / OctopusCommunityUI).
    : .package(url: "https://github.com/Octopus-Community/octopus-sdk-swift.git", exact: "1.16.0")
let octopusPackageName = octopusUsesDevRevision
    ? (URL(string: octopusDevURL)?.deletingPathExtension().lastPathComponent ?? "")
    : "octopus-sdk-swift"

let package = Package(
    name: "octopus_sdk_flutter",
    platforms: [
        .iOS("14.0")
    ],
    products: [
        .library(name: "octopus-sdk-flutter", targets: ["octopus_sdk_flutter"])
    ],
    dependencies: [
        // The Flutter engine (`import Flutter`), as a package the Flutter tool
        // generates next to every SwiftPM plugin it links. Declared the way
        // https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-plugin-authors
        // prescribes. Flutter generates it from 3.41.0 on: on an older Flutter
        // with SwiftPM enabled the path does not exist and resolution fails, so
        // those apps take the CocoaPods path (`octopus_sdk_flutter.podspec`),
        // which never reads this file.
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        // Native Octopus iOS SDK — `octopusPackage` above.
        octopusPackage
    ],
    targets: [
        .target(
            name: "octopus_sdk_flutter",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "Octopus", package: octopusPackageName),
                .product(name: "OctopusUI", package: octopusPackageName)
            ],
            resources: [
                // Privacy manifest, mirrored by the podspec's resource_bundles.
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
