
Pod::Spec.new do |s|
  s.name         = "RNSpatialite"
  s.version      = "1.0.0"
  s.summary      = "RNSpatialite"
  s.description  = <<-DESC
                  RNSpatialite
                   DESC
  s.homepage     = "https://github.com/fedort/react-native-spatialite"
  s.license      = "MIT"
  # s.license      = { :type => "MIT", :file => "FILE_LICENSE" }
  s.author             = { "author" => "author@domain.cn" }
  s.platform     = :ios, "7.0"
  s.source       = { :git => "https://github.com/fedort/react-native-spatialite.git", :tag => "master" }
  
  s.source_files  = "RNSpatialite.{h,m}", "libspatialite/include/spatialite.h", "libspatialite/include/spatialite/gaiageo.h"
  s.requires_arc = true
  s.vendored_libraries = '**/*.a'

  
  s.dependency "React"
  #s.dependency "others"

end

  