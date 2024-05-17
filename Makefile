.PHONY: migrate
migrate:
	PGPASSWORD=postgres psql -h localhost -U postgres -d mydb -a -f create_tables_2.psql

.PHONY: pg
pg:
	PGPASSWORD=postgres psql -h localhost -U postgres -d mydb

.PHONY: resetdb
resetdb:
	docker compose down -v && docker compose up -d && sleep 5

.PHONY: remigrate
remigrate: resetdb migrate pg