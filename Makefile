SERVER = pi@192.168.4.181
REMOTE_PATH = ~/adguard

.PHONY: up down restart full-restart logs status pull clean deploy remote-restart remote-logs

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

full-restart:
	docker compose down && docker compose up -d

remote-restart:
	ssh $(SERVER) "cd $(REMOTE_PATH) && sudo docker compose down && sudo docker compose up -d"

remote-logs:
	ssh $(SERVER) "cd $(REMOTE_PATH) && sudo docker compose logs -f"

logs:
	docker compose logs -f

status:
	docker compose ps

pull:
	docker compose pull

clean:
	docker compose down --remove-orphans
	rm -rf ./data

deploy:
	rsync -avz --exclude 'data/' --exclude '.git/' ./ $(SERVER):$(REMOTE_PATH)/
