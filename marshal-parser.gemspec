# frozen_string_literal: true

require_relative "lib/marshal-parser/version"

Gem::Specification.new do |spec|
  spec.name = "marshal-parser"
  spec.version = MarshalParser::VERSION
  spec.authors = ["Andrew Konchin"]
  spec.email = ["andry.konchin@gmail.com"]

  spec.summary = "Parser of the Ruby Marshal format"
  spec.description = "Ruby library and a CLI tool to parse Ruby Marshal serialization format."
  spec.homepage = "https://github.com/andrykonchin/marshal-parser"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/andrykonchin/marshal-parser"
  spec.metadata["changelog_uri"] = "https://github.com/andrykonchin/marshal-parser/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:sig|spec)/|\.|(Gemfile|Rakefile))})
    end
  end
  spec.bindir = "bin"
  spec.executables = ["marshal-cli"]
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "dry-cli", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
