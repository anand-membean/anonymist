# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "scrub-rb"
  spec.version = "0.0.0"
  spec.authors = ["Bhanu Prakash"]
  spec.email = ["bhanu.prakash292@gmail.com"]
  spec.homepage = "https://undefined.io/projects/scrub-rb"
  spec.summary = ""
  spec.license = "Hippocratic-2.1"

  spec.metadata = {
    "bug_tracker_uri" => "https://github.com/undefined/scrub-rb/issues",
    "changelog_uri" => "https://undefined.io/projects/scrub-rb/versions",
    "homepage_uri" => "https://undefined.io/projects/scrub-rb",
    "funding_uri" => "https://github.com/sponsors/undefined",
    "label" => "Scrub Rb",
    "rubygems_mfa_required" => "true",
    "source_code_uri" => "https://github.com/undefined/scrub-rb"
  }

  spec.signing_key = Gem.default_key_path
  spec.cert_chain = [Gem.default_cert_path]

  spec.required_ruby_version = "~> 3.3"
  spec.add_dependency "refinements", "~> 12.10"
  spec.add_dependency "zeitwerk", "~> 2.7"

  spec.extra_rdoc_files = Dir["README*", "LICENSE*"]
  spec.files = Dir["*.gemspec", "lib/**/*"]
end
