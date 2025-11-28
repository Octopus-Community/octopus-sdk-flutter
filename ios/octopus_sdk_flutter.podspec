#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint octopus_sdk_flutter.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'octopus_sdk_flutter'
  s.version          = '0.0.1'
  s.summary          = 'Flutter plugin to integrate Octopus Community SDK on iOS.'
  s.description      = <<-DESC
This Flutter plugin bridges to the native Octopus Community iOS SDK, enabling
social features (feeds, posts, notifications, etc.) inside your Flutter apps.
                       DESC
  s.homepage         = 'https://github.com/Octopus-Community/octopus-sdk-swift'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  # Add Octopus Community SDK dependencies (CocoaPods names)
  s.dependency 'OctopusCommunity'
  s.dependency 'OctopusCommunityUI'
  s.platform = :ios, '14.0'
  s.static_framework = true
  s.dependency 'OctopusCommunity', '1.7.1'
  s.dependency 'OctopusCommunityUI', '1.7.1'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  s.resource_bundles = {'octopus_sdk_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
