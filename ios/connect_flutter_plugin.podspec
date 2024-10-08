require 'json'

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint connect_flutter_plugin.podspec` to validate before publishing.
#

# Load and parse package and Connect configuration
# package = JSON.parse(File.read('package.json'))
# Load and parse pubspec.yaml configuration
pubspec = YAML.load_file('../pubspec.yaml')
connectConfig = JSON.parse(File.read('../automation/ConnectConfig.json'))

# Extract values from configurations
repository = pubspec["repository"]
useRelease = connectConfig["Connect"]["useRelease"]
dependencyName = useRelease ? 'AcousticConnect' : 'AcousticConnectDebug'
iOSVersion = connectConfig["Connect"]["iOSVersion"]
dependencyVersion = iOSVersion.to_s.empty? ? "" : ", #{iOSVersion}"
tlDependency = "'#{dependencyName}'#{dependencyVersion}"

puts "*********flutter-native-acoustic-ea-connect-beta.podspec*********"
puts "connectConfig:"
puts JSON.pretty_generate(connectConfig)
puts "repository:#{repository}"
puts "useRelease:#{useRelease}"
puts "dependencyName:#{dependencyName}"
puts "dependencyVersion:#{dependencyVersion}"
puts "tlDependency:#{dependencyName}#{dependencyVersion}"
puts "'#{dependencyName}'#{dependencyVersion}"
puts "***************************************************************"

# Podspec definition starts here
Pod::Spec.new do |s|
  s.name             = 'connect_flutter_plugin' # Updated name to target
  s.version          = pubspec["version"] # Version from pubspec.yaml
  s.summary          = 'Connect flutter plugin project.' # Keeping target summary
  s.description      = <<-DESC
A new flutter plugin project uses native SDKs and Flutter code to capture user experience.
                       DESC
  s.homepage         = pubspec["homepage"] # Homepage from pubspec.yaml
  s.license          = { :file => '../LICENSE' } # License file location
  s.author           = { 'Your Company' => 'email@example.com' }
  s.platform         = :ios, '13.0' # iOS platform version
  
  # Source configuration with dynamic version tag
  # s.source           = { :git => repository, :tag => s.version }
  s.source           = { :path => '.' }

  # Define source files and preserve paths
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.*h'
  
  # Dependencies
  s.dependency 'Flutter' # Flutter dependency
  s.dependency       "#{dependencyName}#{dependencyVersion}"
  # Optional: Add any additional dependencies here
  
  # Target xcconfig for Flutter
  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '../../../ios/Pods/** ' # Search paths
  }
  
  # Custom script phase for build config.  Don't think we need it, use launch.json prelaunch task instead
  # s.script_phase = {
  #   name: 'Build Config',
  #   script: %(
  #     "${PODS_TARGET_SRCROOT}/ios/connectConfig/Build_Config.rb" "$PODS_ROOT" "connectConfig.json"
  #   ), 
  #   execution_position: :before_compile,
  # }
end
