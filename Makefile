help:
	echo "Usage:"
	echo "    make build|create|start|stop|install|test|attach|clean|remove [APT_PROXY|APT_PROXY_SSL=url]"

build:
	# Grab Dockerfile from the dotfiletest folder
	docker build --tag dotfiles --rm - < docker.sym/dotfiletest/Dockerfile

create:
	docker stop dotfiles > /dev/null 2>&1 ||:
	docker rm dotfiles > /dev/null 2>&1 ||:
	docker create --interactive --tty \
		--name dotfiles \
		--hostname dotfiles \
		--volume ${HOME}/dotfiles:/project \
		dotfiles \
		/bin/zsh --login

start:
	docker start dotfiles

stop:
	docker stop dotfiles

install:
	docker exec --interactive --tty dotfiles \
		./bootstrap.sh \
			--config=zsh \
			--minimal

test:
	docker exec --interactive --tty dotfiles \
		/bin/zsh -cli "./scripts.sym/testscripts"

attach:
	docker exec --interactive --tty dotfiles \
		/bin/zsh --login ||:

clean:
	docker stop dotfiles > /dev/null 2>&1 ||:
	docker rm dotfiles > /dev/null 2>&1 ||:

remove: clean
	docker rmi dotfiles > /dev/null 2>&1 ||:

.SILENT:
