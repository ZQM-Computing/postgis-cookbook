.PHONY: up down psql demo validate reset

up:
	docker compose up -d db
	bash scripts/wait_for_db.sh

down:
	docker compose down

psql:
	docker compose exec db psql -U patterns -d postgis_patterns

demo: up
	bash scripts/run_examples.sh

validate: up
	bash scripts/run_examples.sh

reset:
	docker compose down --volumes
	docker compose up -d db
	bash scripts/run_examples.sh
