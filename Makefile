SHELL := /bin/bash

.PHONY: up down logs ps health clean

up:
	docker compose up -d

down:
	docker compose down -v

logs:
	docker compose logs -f --tail=100

ps:
	docker compose ps

health:
	bash scripts/healthcheck.sh

clean:
	docker compose down -v || true
	docker system prune -f


