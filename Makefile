NAME = inception

COMPOSE = docker compose
COMPOSE_FILE = ./srcs/docker-compose.yml

DATA_PATH = /home/piyu/data

all: up

make-datadir:
	@if [ ! -d "$(DATA_PATH)/mariadb" ]; then mkdir -p $(DATA_PATH)/mariadb; fi
	@if [ ! -d "$(DATA_PATH)/wordpress" ]; then mkdir -p $(DATA_PATH)/wordpress; fi

# Create bind mount directories if not exists and force rebuild of the containers
build: make-datadir
	$(COMPOSE) -f $(COMPOSE_FILE) up -d --build

# Create bind mount directories if not exists and build/start the containers
up: make-datadir
	$(COMPOSE) -f $(COMPOSE_FILE) up -d

# Stop and remove the containers, but preserve volumes
down:
	$(COMPOSE) -f $(COMPOSE_FILE) down

# Stop containers without removing them
stop:
	$(COMPOSE) -f $(COMPOSE_FILE) stop

# Start existing stopped containers
start:
	$(COMPOSE) -f $(COMPOSE_FILE) start

# Restart the whole stack
restart: down up

# Check out logs of all containers or a specific container by setting the SERVICE option.
# e.g. make logs SERVICE=nginx. In follow mode.
logs:
ifdef SERVICE
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f $(SERVICE)
else
	$(COMPOSE) -f $(COMPOSE_FILE) logs -f
endif

# List all containers, including those that are stopped, exited or crashed, and only list the container IDs
ps:
	$(COMPOSE) -f $(COMPOSE_FILE) ps -aq

# Remove all containers and volumes
clean:
	$(COMPOSE) -f $(COMPOSE_FILE) down -v

# Remove everything, including docker images, unused resources and the bind-mounted data directory
fclean: clean
	docker system prune -af
	docker volume prune -f
	sudo rm -rf $(DATA_PATH)

# Remove everything and perform a fresh restart
re: fclean build

.PHONY: make-datadir all build up down stop start restart logs ps clean fclean re
