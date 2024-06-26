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
remigrate: resetdb migrate loaddummydata

.PHONY: loaddummydata
loaddummydata:
	PGPASSWORD=postgres psql -h localhost -U postgres -d mydb -a -f dummy_data.psql

.PHONY: devserver
devserver:
	fastapi dev app/main.py