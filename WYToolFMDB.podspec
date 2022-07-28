#
# Be sure to run `pod lib lint WYToolFMDB.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'WYToolFMDB'
  s.version          = '1.0.0'
  s.summary          = '基于FMDB的进一步封装 WYToolFMDB.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
  基于FMDB的进一步封装：纯面向对象(其思想源自php的yii 2架构)，实现了model与数据库的一一映射，并且在大多数情况下，对数据库的操作比如增删改查等操作，完全不需要写sql语句。
                       DESC

  s.homepage         = 'https://github.com/q785618493/WYToolFMDB'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'q785618493.com' => '785618493@qq.com' }
  s.source           = { :git => 'https://github.com/q785618493/WYToolFMDB.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'

  s.source_files = 'WYToolFMDB/Classes/**/*'
  
  # s.resource_bundles = {
  #   'WYToolFMDB' => ['WYToolFMDB/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
   s.dependency 'FMDB'
end
