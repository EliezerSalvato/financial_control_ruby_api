source "https://rubygems.org"

ruby "~> 3.4.5"

# Core
gem "rails", "~> 8.1"
gem "pg", "~> 1.6"
gem "puma", "~> 8.0"
gem "bootsnap", "~> 1.24", require: false
gem "propshaft", "~> 1.3"

# API
gem "jsonapi-serializer", "~> 2.2"
gem "pagy", "~> 43.6"
gem "ransack", "~> 4.4"
gem "rack-cors", "~> 3.0"
gem "rack-attack", "~> 6.8"

# I18n
gem "rails-i18n", "~> 8.1"

# Auth / security
gem "bcrypt", "~> 3.1"

# Auditing
gem "paper_trail", "~> 17.0"

# Domain / process
gem "solid-process", "~> 0.6"
gem "solid-adapters", "~> 1.1"

# Jobs
gem "solid_queue", "~> 1.6"
gem "mission_control-jobs", "~> 1.2"

group :development do
  gem "rubocop-rails-omakase", "~> 1.1", require: false
  gem "i18n-tasks", "~> 1.1"
end

group :test do
  gem "simplecov", "~> 1.0", require: false
  gem "rspec-rails", "~> 8.0"
end

group :development, :test do
  gem "brakeman", "~> 8.0", require: false
  gem "bundler-audit", "~> 0.9", require: false
  gem "debug", "~> 1.11", platforms: %i[mri windows], require: "debug/prelude"
  gem "dotenv-rails", "~> 3.2"
  gem "factory_bot_rails", "~> 6.5"
  gem "faker", "~> 3.8"
end
