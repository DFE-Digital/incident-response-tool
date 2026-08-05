.PHONY: build dev up down rebuild logs

# Build the production image (uses layer cache — fast for Ruby/ERB-only changes)
build:
	docker build -t incident-response-tool:local .

# Full rebuild without cache (use only when Gemfile or package.json changed)
rebuild:
	docker build --no-cache -t incident-response-tool:local .

# Start dev environment: live source mount, auto-reload, detailed errors
# First run compiles assets once; subsequent runs skip it (~5s startup)
dev:
	docker compose -f docker-compose.dev.yml up

dev-down:
	docker compose -f docker-compose.dev.yml down

# Production-mode compose (for testing the baked image)
up:
	docker compose up -d

down:
	docker compose down

logs:
	docker logs -f incident-response-tool_web_1
