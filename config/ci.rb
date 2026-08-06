# Run using bin/ci
#
# Single source of truth for which checks to run.
# Machine/environment prep lives in .github/workflows/ci.yml (and locally via Docker).

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"
  step "I18n: Health", "bundle exec i18n-tasks health"

  step "Security: Gem audit", "bin/bundler-audit check --update"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Test: RSpec", "bin/rspec"
end
