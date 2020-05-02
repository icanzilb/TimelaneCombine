Pod::Spec.new do |s|
  s.name             = 'TimelaneCombine'
  s.version          = '1.0.6'
  s.summary          = 'TimelaneCombine provides a Combine bindings for profiling Combine code with the Timelane Instrument.'

  s.description      = <<-DESC
TimelaneCombine provides a Combine bindings for profiling Reactive code with the Timelane Instrument.
                       DESC

  s.homepage         = 'https://github.com/icanzilb/TimelaneCombine'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Marin Todorov' => 'touch-code-magazine@underplot.com' }
  s.source           = { :git => 'https://github.com/icanzilb/TimelaneCombine.git', :tag => s.version.to_s }
  s.social_media_url = 'https://twitter.com/icanzilb'

  s.source_files = 'Sources/**/*.swift'

  s.swift_versions = ['5.0']
  s.requires_arc          = true
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.watchos.deployment_target = '6.0'
  s.tvos.deployment_target = '13.0'
  
  s.source_files = 'Sources/**/*.swift'  
  s.frameworks = 'Foundation', 'Combine'
  
  s.dependency 'TimelaneCore', '~> 1'
end
