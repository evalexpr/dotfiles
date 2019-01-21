#!/bin/bash

DOTFILES_ROOT=$(pwd -P)
export PATH=$PATH:/usr/local/go/bin:$HOME/.cargo/bin:$HOME/.local/bin
set -e
set -o pipefail

info() {
    printf "[\\033[00;34m.\\033[0m] %s\\n" "$1"
}

success() {
    printf "\\033[2K[\\033[00;32m✔\\033[0m] %s\\n" "$1"
}

warn() {
    printf "\\033[2K[\\033[00;33m!\\033[0m] %s\\n" "$1"
}

fail() {
    printf "\\033[2K[\\033[0;31m✘\\033[0m] %s\\n" "$1"
    exit
}

user_input() {
    read -re -p $'\033[0;33m'"$1"$'\033[0m: ' "$2"
}

determine_arch() {
    arch=$(arch)
    case $arch in
        x86*) arch=amd64;;
        arm*) arch=arm;;
    esac
    echo $arch
}

link_file() {
    local src="$1" dest="$2"
    local overwrite="" backup="" skip="" action=""

    # check if the destinaton is already a file/dir/symlink
    if [ -f "$dest" ] || [ -d "$dest" ] || [ -L "$dest" ]; then
        if [ "$overwrite_all" == "false" ] && [ "$backup_all" == "false" ] && [ "$skip_all" == "false" ];then
            # shellcheck disable=SC2155
            local current="$(readlink "$dest")"

            if [ "$current" == "$src" ]; then
                skip=true;
            else
                info "file already exists: $dest ($(basename "$src")), what do you want to do?"
                user_input "[s]kip, [S]kip all, [o]verwrite, [O]verwrite all, [b]ackup, [B]ackup all?" action

                case "$action" in
                    o)
                        overwrite=true;;
                    O)
                        overwrite_all=true;;
                    b)
                        backup=true;;
                    B)
                        backup_all=true;;
                    s)
                        skip=true;;
                    S)
                        skip_all=true;;
                    *)
                        ;;
                esac
            fi
        fi

        overwrite=${overwrite:-$overwrite_all}
        backup=${backup:-$backup_all}
        skip=${skip:-$skip_all}

        if [ "$overwrite" == "true" ]; then
            rm -rf "$dest" || fail "could not remove $dest"
            success "removed $dest"
        fi

        if [ "$backup" == "true" ]; then
            mv "$dest" "$dest.backup" || fail "could not move $dest to $dest.backup"
            success "moved $dest to $dest.backup"
        fi

        if [ "$skip" == "true" ]; then
            info "skipped $src"
        fi
    fi

    if [ "$skip" != "true" ]; then
        ln -s "$1" "$2" || fail "could not link $1 to $2"
        success "linked $1 to $2"
    fi
}

setup_sudo() {
    readonly user="$(whoami)"
    sudo groupadd sudo || true
    sudo groupadd docker || true
    sudo groupadd systemd-journal || true
    sudo groupadd systemd-network || true

    sudo adduser "$user" sudo
    sudo gpasswd -a "$user" systemd-journal
	sudo gpasswd -a "$user" systemd-network
	sudo gpasswd -a "$user" docker
}

install_base() {
    # TODO(jwilkins): Make this arch agnostic
    sudo apt update || true
    sudo apt -y upgrade
    < packages xargs sudo apt install -y --no-install-recommends

    sudo apt autoremove
    sudo apt autoclean
    sudo apt clean
}

install_extras() {
    # oh-my-zsh
    if ! [ -s "$HOME/.oh-my-zsh" ]; then
        git clone git://github.com/robbyrussell/oh-my-zsh.git "$HOME/.oh-my-zsh"
    fi

    # rust
    if ! [ -s "$HOME"/.cargo/bin/rustc ]; then
        curl https://sh.rustup.rs -sSf | sh
    fi
    info "rust installed, running post-install actions"
    cargo install shellharden ripgrep || true

    # go
    GO_VERSION=$(curl -sSL "https://golang.org/VERSION?m=text")
    INSTALLED_VERSION="none"
    if [ -s /usr/local/go/bin/go ]; then
        INSTALLED_VERSION="$(go version | cut -d' ' -f3)"
    fi
    GO_SRC=/usr/local/go
    mkdir -p "$GO_SRC"
    if [[ "$INSTALLED_VERSION" != "$GO_VERSION" ]]; then
        GO_VERSION=${GO_VERSION#go}
        info "installing new go version: $GO_VERSION"
		sudo rm -rf "$GO_SRC"
        curl -sSL "https://storage.googleapis.com/golang/go$GO_VERSION.$KERNEL-$ARCH.tar.gz" | sudo tar -v -C /usr/local -xz
    fi
    info "go installed, running post-install actions"

    # go post-install
    # vim-go
    go get github.com/alecthomas/gometalinter \
        github.com/davidrjenni/reftools/cmd/fillstruct \
        github.com/fatih/gomodifytags \
        github.com/fatih/motion \
        github.com/josharian/impl \
        github.com/jstemmer/gotags \
        github.com/kisielk/errcheck \
        github.com/klauspost/asmfmt/cmd/asmfmt \
        github.com/koron/iferr \
        github.com/mdempsky/gocode \
        github.com/rogpeppe/godef \
        github.com/stamblerre/gocode \
        github.com/zmb3/gogetdoc \
        golang.org/x/lint/golint \
        golang.org/x/tools/cmd/goimports \
        golang.org/x/tools/cmd/gorename \
        golang.org/x/tools/cmd/guru \
        honnef.co/go/tools/cmd/keyify

    # others
    go get honnef.co/go/tools/cmd/staticcheck

    # python
    sudo apt install python3 python3-distutils || true
    if ! command -v pip >/dev/null 2>&1; then
        curl https://bootstrap.pypa.io/get-pip.py -o /tmp/get-pip.py
        python3 /tmp/get-pip.py --user
    fi
    info "python3 and pip installed, running post-install actions"
    pip install --user yapf pipenv icdiff pipreqs

    # fzf
    if ! [ -s "$HOME/.fzf" ]; then
        git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf" && \
            "$HOME/.fzf/install"
    fi
    info "fzf installed"

    # 1password cli
    if ! [ -s /usr/local/bin/op ]; then
        OP=op_"$KERNEL"_"$ARCH"_v0.5.5.zip
        curl -sSLO "https://cache.agilebits.com/dist/1P/op/pkg/v0.5.5/$OP"
        unzip "$OP"
        sudo mv op /usr/local/bin/op
        rm op.sig "$OP"
    fi
    info "1password cli installed"
}

setup_git() {
    if ! [ -s "$HOME/.gitconfig" ]; then
        store="cache"
        if [[ "$OSTYPE" == "Darwin"* ]]; then
            store="osxkeychain"
        fi

        user_input "What is your GitHub author name? (Default: W1lkins)" author
        author=${author:-W1lkins}

        user_input "What is your GitHub email? (Default: wilkinsphysics@gmail.com)" email
        email=${email:-wilkinsphysics@gmail.com}

        user_input "Do you want to use a GPG key with git? [y/N]" using_gpg
        using_gpg=${using_gpg:-N}

        key=
        if [ "$using_gpg" != "${using_gpg#[Yy]}" ] ;then
            gpg --list-secret-keys --keyid-format LONG
            user_input "Which key" key
        fi

        cp git/gitconfig "$HOME/.gitconfig"

        sed -e "s/AUTHORNAME/$author/g" -e "s/AUTHOREMAIL/$email/g" -e "s/GIT_CREDENTIAL_HELPER/$store/g" -i "$HOME/.gitconfig"
        if ! [ -z "$key" ]; then
            sed -e "s/AUTHORGPGKEY/$key/g" -e "s/gpgsign = false/gpgsign = true/g" -i "$HOME/.gitconfig"
        fi

        success "created gitconfig"
    else
        info "skipped gitconfig"
    fi
}


setup_dotfiles() {
    local overwrite_all=false backup_all=false skip_all=false

    # shellcheck disable=SC2044
    for src in $(find -H "$DOTFILES_ROOT" -maxdepth 2 -name '*.sym' -not -path '*.git*')
    do
        dest="$HOME/.$(basename "${src%.*}")"
        link_file "$src" "$dest"
    done
}

setup_vim() {
    ( cd "$HOME"/.vim || exit 1; vim +PlugInstall +qa ) || fail "couldn't cd to $HOME/.vim"

    if ! [ -s "vim.sym/bundle/command-t/ruby/command-t/ext/command-t/ext.bundle" ]; then
        info "installing command-t"
        ( cd vim.sym/bundle/command-t >/dev/null 2>&1 || exit 1; rake make >/dev/null 2>&1 ) ||
            warn "couldnt install command-t, try running rake make manually"
    else
        info "command-t already installed"
    fi
}

main() {
    local cmd="$1"
    KERNEL=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(determine_arch)
    info "Running for kernel: $KERNEL and arch $ARCH"

    if [[ ! -z $cmd && $cmd == "init" ]]; then
        info "setting up sudo"
        setup_sudo
        printf "\\n"

        info "installing base"
        install_base
        printf "\\n"

        info "installing extras"
        install_extras
        printf "\\n"
    fi

    info "setting up git"
    setup_git
    printf "\\n"

    info "linking dotfiles"
    setup_dotfiles
    printf "\\n"

    info "setting up vim"
    setup_vim
    printf "\\n"

    success "installation complete"
}

main "$@"
