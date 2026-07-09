// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "octopus_sdk_flutter",
    platforms: [
        .iOS("14.0")
    ],
    products: [
        .library(name: "octopus-sdk-flutter", targets: ["octopus_sdk_flutter"])
    ],
    dependencies: [
        // Native Octopus iOS SDK, distributed as a Swift Package. Keep this
        // version in lockstep with the CocoaPods pins in
        // `octopus_sdk_flutter.podspec` (OctopusCommunity / OctopusCommunityUI).
        .package(url: "https://github.com/Octopus-Community/octopus-sdk-swift.git", exact: "1.12.6")
    ],
    targets: [
        .target(
            name: "octopus_sdk_flutter",
            dependencies: [
                .product(name: "Octopus", package: "octopus-sdk-swift"),
                .product(name: "OctopusUI", package: "octopus-sdk-swift")
            ],
            resources: [
                // Privacy manifest, mirrored by the podspec's resource_bundles.
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
