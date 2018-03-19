Pod::Spec.new do |s|
  s.name                      = "OfflinePackage"
  s.version                   = "0.0.1"
  s.summary                   = "offline-package manager module in iOS"
  s.homepage                  = "https://github.com/CodingForMoney/offline-pack-ios"
  s.license                   = { :type => "MIT"}
  s.author                    = { "luoxianming" => "luoxianmingg@gmail.com" }
  s.ios.deployment_target     = '8.0'
  s.source                    = { :git => "https://github.com/CodingForMoney/offline-pack-ios.git", :tag => s.version}
  s.library = 'bz2'
  s.source_files              = "OfflinePackage/OfflinePackage/*.h"
  s.subspec "Core" do |ss|
    ss.source_files           = "OfflinePackage/OfflinePackage/OfflinePackage/*.{h,m}"
  end
  s.dependency                "SSZipArchive"
  s.dependency                "MXRSA"
end