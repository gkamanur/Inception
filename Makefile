NAME = inception

DATA_PATH = $(CURDIR)/data

all: $(NAME)

$(NAME):
	@mkdir -p $(DATA_PATH)/wordpress
	@mkdir -p $(DATA_PATH)/mariadb
	@mkdir -p $(DATA_PATH)/ftp_user
	docker compose -f srcs/docker-compose.yml up -d --build

clean:
	@docker compose -f srcs/docker-compose.yml down -v
	@docker volume ls -q | xargs -r docker volume rm -f

fclean: clean
	docker system prune -af --volumes
	@sudo rm -rf $(DATA_PATH)/wordpress/*
	@sudo rm -rf $(DATA_PATH)/mariadb/*
	@sudo rm -rf $(DATA_PATH)/ftp_user/*

re: fclean all

.PHONY: all clean fclean re