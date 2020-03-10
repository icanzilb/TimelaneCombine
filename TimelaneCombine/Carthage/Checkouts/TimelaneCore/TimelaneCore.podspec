Pod::Spec.new do |s|
  s.name             = 'TimelaneCore'
  s.version          = '1.0.2'
  s.summary          = 'The core logging package for Timelane.'

  s.description      = <<-DESC
The core logging package for Timelane Library.
                       DESC

  s.homepage   = 'https://github.com/icanzilb/TimelaneCore'
  s.license         = { :type => 'MIT', :file => 'LICENSE' }
  s.author          = { 'Marin Todorov' => 'touch-code-magazine@underplot.com' }
  s.source         = { :git => 'https://github.com/icanzilb/TimelaneCore.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/icanzilb'

  s.swift_versions = ['5.0']
  s.requires_arc          = true
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '3.0'
  s.tvos.deployment_target = '9.0'
  
  s.source_files = 'Sources/**/*.swift'  
  s.frameworks = 'Foundation'
end
