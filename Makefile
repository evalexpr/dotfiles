# Variables {{{

# output prefix
PREFIX?=$(shell pwd)

# binary
MAIN := main.go

# variables
NAME := dotfiles
PKG := github.com/w1lkins/$(NAME)
SHELLCHECK := ./scripts.sym/testscripts

# build-tags
BUILDTAGS :=

# build-dir
BUILDDIR := ${PREFIX}/cross

# compile time
VERSION := "0.1.0"
GITCOMMIT := $(shell git rev-parse --short HEAD)
GITUNTRACKED := $(shell git status --porcelain --untracked-files=no)
ifneq ($(GITUNTRACKEDCHANGES),)
	GITCOMMIT := $(GITCOMMIT)-dirty
endif
CTIME=-X $(PKG)/version.GITCOMMIT=$(GITCOMMIT) -X $(PKG)/version.VERSION=$(VERSION)
GO_LDFLAGS=-ldflags "-w $(CTIME)"
GO_LDFLAGS_STATIC=-ldflags "-w $(CTIMEVAR) -extldflags -static"

# architecture
ARCH := linux/amd64 darwin/amd64 linux/arm64

# }}}

# Golang {{{

all: clean update build setup ## runs a clean, build, fmt, lint, test, staticcheck, vet and install

.PHONY: update ## update from Github
update:
	@echo "+ $@"
	@git pull origin master

.PHONY: setup ## run the dotfile install script
setup:
	@echo "+ $@"
	./$(NAME)

.PHONY: build
build: $(NAME) ## builds a dynamic exe

$(NAME): $(MAIN)
	@echo "+ $@"
	go build -tags "$(BUILDTAGS)" ${GO_LDFLAGS} .

.PHONY: static
static: ## build a static executable
	@echo "+ $@"
	GCO_ENABLED=0 go build -tags "$(BUILDTAGS) static_build" ${GO_LDFLAGS_STATIC} -o $(NAME) .

.PHONY: fmt
fmt: ## verify gofmt on main.go
	@echo "+ $@"
	@gofmt -s -l -e $(MAIN)

.PHONY: lint
lint: ## golint main.go
	@echo "+ $@"
	@golint -set_exit_status $(MAIN)

.PHONY: test
test: ## run the tests if there are any
	@echo "+ $@"
	@go test -v -tags "$(BUILDTAGS) cgo" && $(SHELLCHECK)

.PHONY: vet
vet: ## verify go vet
	@echo "+ $@"
	@go vet -n -x $(MAIN)

.PHONY: staticcheck
staticcheck: ## verify staticcheck
	@echo "+ $@"
	@staticcheck $(MAIN)

.PHONY: install
install:
	@echo "+ $@"
	go install -tags "$(BUILDTAGS)" ${GO_LDFLAGS} $(MAIN)

define buildrelease
GOOS=$(1) GOARCH=$(2) CGO_ENABLED=0 go build \
	 -o $(BUILDDIR)/$(NAME)-$(1)-$(2) \
	 -a -tags "$(BUILDTAGS) static_build netgo" \
	 -installsuffix netgo ${GO_LDFLAGS_STATIC} .;
md5sum $(BUILDDIR)/$(NAME)-$(1)-$(2) > $(BUILDDIR)/$(NAME)-$(1)-$(2).md5;
sha256sum $(BUILDDIR)/$(NAME)-$(1)-$(2) > $(BUILDDIR)/$(NAME)-$(1)-$(2).sha256;
endef

.PHONY: release
release: $(MAIN) ## build cross-compiled binaries binary-GOOS-GOARCH
	@echo "+ $@"
	$(foreach GOOS,$(ARCH), $(call buildrelease,$(subst /,,$(dir $(GOOS))),$(notdir $(GOOS))))

.PHONY: tag
tag: ## create a new tag for releasing
	git tag -a $(VERSION) -m "$(VERSION)"
	@echo "Tag created. Run git push origin $(VERSION)"

.PHONY: clean
clean: ## clean built binaries
	@echo "+ $@"
	$(RM) $(NAME)
	$(RM) -r $(BUILDDIR)

# }}}

# Docker {{{

.PHONY: docker
docker: docker-build docker-create docker-start docker-setup docker-attach ## build docker file and attach
	@echo "+ $@"

.PHONY: docker-build
docker-build:
	@echo "+ $@"
	docker build --tag dotfiles --rm - < docker.sym/dotfiletest/Dockerfile

.PHONY: docker-create
docker-create: docker-stop docker-clean ## stop dotfile container, remove, and recreate
	@echo "+ $@"
	docker create --interactive --tty \
		--name dotfiles \
		--hostname dotfiles \
		--volume ${HOME}/dotfiles:/dotfiles \
		dotfiles \
		/bin/zsh --login

.PHONY: docker-start
docker-start: ## start dotfile container
	@echo "+ $@"
	@docker start dotfiles > /dev/null 2>&1

.PHONY: docker-stop
docker-stop:
	@echo "+ $@"
	@docker stop dotfiles > /dev/null 2>&1 ||:

.PHONY: docker-setup
docker-setup: ## run make in dotfile container
	@echo "+ $@"
	@docker exec --interactive --tty dotfiles make

.PHONY: docker-attach
docker-attach: ## attach to running dotfile container
	@echo "+ $@"
	@docker exec --interactive --tty dotfiles /bin/zsh --login ||:

.PHONY: docker-clean
docker-clean: docker-stop ## stop and clean dotfile container
	@echo "+ $@"
	@docker rm dotfiles > /dev/null 2>&1 ||:

.PHONY: docker-destroy
docker-destroy: docker-clean ## stop and remove dotfile container, remove built image
	@echo "+ $@"
	@docker rmi dotfiles > /dev/null 2>&1 ||:

# }}}

# Misc {{{

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1,$$2}'

# }}}
