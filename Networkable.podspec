#
# Be sure to run `pod lib lint Networkable.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'Networkable'
  s.version          = '1.1.0'
  s.summary          = 'Ad-hoc network layer built on URLSession'

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/duytph/Networkable'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'duytph' => 'tphduy@gmail.com' }
  s.source           = { :git => 'https://github.com/duytph/Networkable.git', :tag => s.version.to_s }

  s.ios.deployment_target = '10.0'
  
  s.swift_versions = "5.3"

  s.source_files = 'Sources/**/*'
end
