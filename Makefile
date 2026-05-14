NAME = inception

DATA_PATH = $(CURDIR)/data

all: $(NAME)

$(NAME):
	@mkdir -p $(DATA_PATH)/wordpress
	@mkdir -p $(DATA_PATH)/mariadb
	docker compose -f srcs/docker-compose.yml up -d --build

clean:
	docker compose -f srcs/docker-compose.yml down -v
	docker volume prune -f

fclean: clean
	docker system prune -af --volumes
	@rm -rf $(DATA_PATH)/wordpress/*
	@rm -rf $(DATA_PATH)/mariadb/*

re: fclean all

.PHONY: all clean fclean re