#
# Be sure to run `pod lib lint YJFNetworking.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'YJFNetworking'
  s.version          = '0.1.0'
  s.summary          = '网络请求类针对AFNetworking的封装'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
	YTKNetworking的copy版。代码里加了部分注释，仅仅为了学习。如有需要请直接使用YTKNetworking,https://github.com/yuantiku/YTKNetwork。                       
DESC

  s.homepage         = 'https://github.com/sclcoder/YJFNetworking'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = 'MIT'
  s.author           = { 'sclcoder' => 'sclcoder@163.com' }
  s.source           = { :git => 'https://github.com/sclcoder/YJFNetworking.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'

  s.source_files = 'YJFNetworking/Classes/**/*'
  
  # s.resource_bundles = {
  #   'YJFNetworking' => ['YJFNetworking/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
    s.frameworks = 'UIKit'
    s.dependency 'AFNetworking', '~> 3.1.0'
end
