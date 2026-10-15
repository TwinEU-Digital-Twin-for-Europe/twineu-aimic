.PHONY: help up down logs

COMPOSE_FILE = docker-compose.prod.yaml

help:
	@echo "TwinEU AI Models Integration Component - Deployment Menu"
	@echo "  up                    Start the AIMIC standalone stack"
	@echo "  down                  Stop the stack and remove containers"
	@echo "  logs                  Tail system logs"

up:
	docker compose -f $(COMPOSE_FILE) up -d

down:
	docker compose -f $(COMPOSE_FILE) down -v

logs:
	docker compose -f $(COMPOSE_FILE) logs -f