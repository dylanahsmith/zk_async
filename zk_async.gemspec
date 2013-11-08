# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'zk_async/version'

Gem::Specification.new do |spec|
  spec.name          = "zk_async"
  spec.version       = ZkAsync::VERSION
  spec.authors       = "Shopify"
  spec.email         = ["Dylan.Smith@shopify.com"]
  spec.summary       = "High-level asynchronous zookeeper client"
  spec.description   = spec.summary
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'zk', '~> 1.9.2'
  spec.add_runtime_dependency 'zookeeper', '~> 1.4.6'

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency('debugger')
end
