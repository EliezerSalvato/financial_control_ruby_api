# Verify

Run the project CI and fix every failure before treating the task as done.

1. Confirm the Compose stack is up: `docker compose ps`.
2. From the host, run `make ci`.
3. When a step fails, fix the cause and run `make ci` again.
4. Keep RuboCop, Brakeman, i18n-tasks, bundler-audit, and the 100% line coverage gate enabled unless the user explicitly approves an exception.
5. Leave the work uncommitted unless the user asked for a commit.
