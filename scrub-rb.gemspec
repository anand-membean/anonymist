# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "scrub-rb"
  spec.version = "0.1.0"
  spec.authors = ["Bhanu Prakash"]
  spec.email = ["bhanu.prakash292@gmail.com"]
  spec.homepage = "https://github.com/bhanuone/scrub-rb"
  spec.summary = "A data sanitization library for Ruby applications."
  spec.license = "Hippocratic-2.1"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/bhanuone/scrub-rb/issues",
    "changelog_uri" => "https://github.com/bhanuone/scrub-rb/versions",
    "homepage_uri" => "https://github.com/bhanuone/scrub-rb",
    "funding_uri" => "https://github.com/sponsors/bhanuone",
    "label" => "Scrub Rb",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/bhanuone/scrub-rb",
  }

  spec.signing_key = Gem.default_key_path
  spec.cert_chain = [Gem.default_cert_path]

  spec.required_ruby_version = "~> 3.3"
  spec.add_dependency "refinements", "~> 12.10"
  spec.add_dependency "zeitwerk", "~> 2.7"
  spec.add_dependency "faker", "~> 3.5"
  spec.add_dependency "bloomfilter-rb", "~> 2.1"
  spec.add_dependency "mysql2", "~> 0.5"
  spec.add_dependency "ruby-progressbar", "~> 1.13"

  spec.extra_rdoc_files = Dir["README*", "LICENSE*"]
  spec.files = Dir["*.gemspec", "lib/**/*"]
end
