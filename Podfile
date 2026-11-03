platform :ios, '17.0'
use_frameworks!

# 工程结构在 project.yml。改完后执行 xcodegen generate && pod install。
# 打开 WishSaver.xcworkspace，不要直接打开 xcodeproj。
project 'WishSaver.xcodeproj'

target 'WishSaver' do
  # JPush 6.2 依赖 JCore > 5.5.0。5.5.3-noidfa 是预发布版本号，
  # CocoaPods 不会把它算进这个范围，所以这里用正式版，初始化时不传 IDFA。
  pod 'JPush', '~> 6.2'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
    end
  end
end

ost_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.name == "JCore"
      script_path = "./Pods/Target Support Files/JCore/JCore-xcframeworks.sh"
      if File.exist?(script_path)
        File.chmod(0755, script_path)
      end
    end
  end
end