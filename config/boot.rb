ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

env_file = File.expand_path("../.env", __dir__)
if File.exist?(env_file)
  File.foreach(env_file) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")
    key, value = line.split("=", 2)
    next if key.to_s.strip.empty? || value.nil?

    ENV[key.strip] ||= value.strip.sub(/\A["']/, "").sub(/["']\z/, "")
  end
end

require "bundler/setup" # Set up gems listed in the Gemfile.
require "bootsnap/setup" # Speed up boot time by caching expensive operations.
