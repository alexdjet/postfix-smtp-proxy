.PHONY: up down down-clean

up:
	docker compose up -d --build

down:
	docker compose down

down-clean:
	docker compose down -v