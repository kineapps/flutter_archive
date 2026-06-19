#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_archive.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_archive'
  s.version          = '6.2.0'
  s.summary          = 'Create and extract ZIP archive files in iOS and macOS.'
  s.description      = <<-DESC
Create and extract ZIP archive files in iOS and macOS. Zip all files in a directory recursively or a given list of files.
                       DESC
  s.homepage         = 'https://github.com/kineapps/flutter_archive'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'KineApps' => 'https://github.com/kineapps' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_archive/Sources/flutter_archive/**/*.swift'

  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.dependency 'ZIPFoundation', '0.9.19'

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.11'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
  s.swift_version = '5.9'
end
