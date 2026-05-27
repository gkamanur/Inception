NAME = inception

DATA_PATH = $(shell pwd)/data
DOMAIN = gkamanur.42.fr
COMPOSE = docker compose -f srcs/docker-compose.yml

all: $(NAME)

$(NAME): setup
	$(COMPOSE) up -d --build

setup:
	@mkdir -p $(DATA_PATH)/wordpress
	@mkdir -p $(DATA_PATH)/mariadb
	@sed -i 's|^DATA_PATH=.*|DATA_PATH=$(DATA_PATH)|' srcs/.env
	@if ! grep -q "$(DOMAIN)" /etc/hosts; then \
		echo "Adding $(DOMAIN) to /etc/hosts..."; \
		echo "127.0.0.1 $(DOMAIN)" | sudo tee -a /etc/hosts > /dev/null; \
	fi

clean:
	$(COMPOSE) down -v

fclean: clean
	docker system prune -af --volumes
	@sudo rm -rf $(DATA_PATH)/wordpress/*
	@sudo rm -rf $(DATA_PATH)/mariadb/*

re: fclean all

logs:
	$(COMPOSE) logs -f

status:
	$(COMPOSE) ps -a

.PHONY: all clean fclean re setup logs status
