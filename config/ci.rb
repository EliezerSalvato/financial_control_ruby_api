# Run using bin/ci
#
# Single source of truth for which checks to run.
# GitHub Actions runs these as parallel jobs via CI_JOB (lint, security, test).
# Locally, omit CI_JOB to run everything. Machine prep lives in .github/workflows/ci.yml.

job = ENV["CI_JOB"]
all = job.nil?

if job && !%w[lint security test].include?(job)
  abort "Unknown CI_JOB=#{job.inspect}. Expected lint, security, or test."
end

CI.run do
  if all || job == "test"
    step "Setup", "bin/setup --skip-server"
  end

  if all || job == "lint"
    step "Style: Ruby", "bin/rubocop"
    step "I18n: Health", "bundle exec i18n-tasks health"
  end

  if all || job == "security"
    step "Security: Gem audit", "bin/bundler-audit check --update"
    step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  end

  if all || job == "test"
    step "Test: RSpec", "bin/rspec"
  end
end
