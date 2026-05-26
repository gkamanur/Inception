NAME = inception

DATA_PATH = /home/guruvenu/data
COMPOSE = docker compose -f srcs/docker-compose.yml

all: $(NAME)

$(NAME):
	@mkdir -p $(DATA_PATH)/wordpress
	@mkdir -p $(DATA_PATH)/mariadb
	$(COMPOSE) up -d --build

clean:
	$(COMPOSE) down -v

fclean: clean
	docker system prune -af --volumes
	@sudo rm -rf $(DATA_PATH)/wordpress/*
	@sudo rm -rf $(DATA_PATH)/mariadb/*

re: fclean all

.PHONY: all clean fclean re
