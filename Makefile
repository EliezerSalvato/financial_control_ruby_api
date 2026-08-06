COMPOSE = docker compose
SERVICE = api

.DEFAULT_GOAL := help

.PHONY: help build up upd down stop restart logs ps shell bash console \
        setup install migrate rollback seed db-reset \
        test rubocop brakeman audit clean

help: ## List the available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker images
	$(COMPOSE) build

up: ## Start the containers (foreground)
	$(COMPOSE) up

upd: ## Start the containers (background)
	$(COMPOSE) up -d

down: ## Stop and remove the containers and network
	$(COMPOSE) down

stop: ## Stop the containers without removing them
	$(COMPOSE) stop

restart: ## Restart the containers
	$(COMPOSE) restart

logs: ## Follow the api logs
	$(COMPOSE) logs -f $(SERVICE)

logs-jobs: ## Follow the Solid Queue worker logs
	$(COMPOSE) logs -f jobs

jobs: ## Start Solid Queue workers (bin/jobs)
	$(COMPOSE) up jobs

ps: ## List the running containers
	$(COMPOSE) ps

shell: ## Open a shell (sh) in the api container
	$(COMPOSE) exec $(SERVICE) sh

bash: ## Open a bash session in the api container
	$(COMPOSE) exec $(SERVICE) bash

console: ## Open the Rails console
	$(COMPOSE) exec $(SERVICE) bin/rails console

dbconsole: ## Open the Rails dbconsole
	$(COMPOSE) exec $(SERVICE) bin/rails dbconsole

solid-queue-dbconsole: ## Open the Rails dbconsole for the Solid Queue database
	$(COMPOSE) exec $(SERVICE) bin/rails dbconsole --database queue

setup: ## Prepare the environment (build + install + db)
	$(COMPOSE) build
	$(COMPOSE) run --rm $(SERVICE) bundle install
	$(COMPOSE) run --rm $(SERVICE) bin/rails db:prepare

bundle: ## Install the gems via bundler
	$(COMPOSE) exec $(SERVICE) bundle install

migrate: ## Run the database migrations
	$(COMPOSE) exec $(SERVICE) bin/rails db:migrate

rollback: ## Roll back the last migration
	$(COMPOSE) exec $(SERVICE) bin/rails db:rollback

seed: ## Seed the database
	$(COMPOSE) exec $(SERVICE) bin/rails db:seed

db-reset: ## Recreate the database from scratch (drop + create + migrate + seed)
	$(COMPOSE) exec $(SERVICE) bin/rails db:reset

test: ## Run the test suite (rspec)
	$(COMPOSE) exec $(SERVICE) bin/rspec

rubocop: ## Run the rubocop linter
	$(COMPOSE) exec $(SERVICE) bin/rubocop

brakeman: ## Run the brakeman security analysis
	$(COMPOSE) exec $(SERVICE) bin/brakeman

audit: ## Audit gems for known vulnerabilities
	$(COMPOSE) exec $(SERVICE) bin/bundler-audit

clean: ## Remove containers, volumes and orphans
	$(COMPOSE) down -v --remove-orphans

ci: ## Run the CI pipeline
	$(COMPOSE) exec $(SERVICE) bin/ci
