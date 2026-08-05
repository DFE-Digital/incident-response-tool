require "logger" # Load before bundler — Rails 6.1.7.10 requires logger_silence before requiring 'logger'

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
