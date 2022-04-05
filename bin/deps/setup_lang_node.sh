#!/usr/bin/env bash

# setup node and nvm

install_nvm()
{
	fmt_info "install nvm" 
	if [ ! -d $HOME/.nvm  ]; then
		export NVM_DIR="$HOME/.nvm" && (
			git clone https://github.com/nvm-sh/nvm.git "$NVM_DIR"
			cd "$NVM_DIR"
			git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
		) && \. "$NVM_DIR/nvm.sh"
	fi
	fmt_info "[ok] nvm already installed"

}

link_npmrc()
{
	fmt_info "add dotfile npmrc"
	rm -rf $HOME/.npmrc >/dev/null 2>&1
	ln -s $NIXDBS_HOME/dotfiles/npmrc $HOME/.npmrc
}

setup_nvm_profile()
{
    # for zsh
    if [ -a $HOME/.zshrc ]; then
        if ! grep -Fxq 'export NVM_DIR="$HOME/.nvm"' $HOME/.zshrc ; then
            echo '' >> $HOME/.zshrc
            echo '# ====== NVM ====== ' >> $HOME/.zshrc
            echo 'export NVM_DIR="$HOME/.nvm"' >> $HOME/.zshrc
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm' >> $HOME/.zshrc
        fi
		source $HOME/.zshrc
    fi
    # for bash
    if [ -a $HOME/.bash_profile ]; then
        if ! grep -Fxq 'export NVM_DIR="$HOME/.nvm"' $HOME/.bash_profile ; then
            echo '' >> $HOME/.bash_profile
            echo '# ====== NVM ====== ' >> $HOME/.bash_profile
            echo 'export NVM_DIR="$HOME/.nvm"' >> $HOME/.bash_profile
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm' >> $HOME/.bash_profile
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> $HOME/.bash_profile
        fi
		source $HOME/.bash_profile
    elif [ -a $HOME/.bashrc ]; then
        if ! grep -Fxq 'export NVM_DIR="$HOME/.nvm"' $HOME/.bashrc ; then
            echo '# ====== NVM ====== ' >> $HOME/.bashrc
            echo 'export NVM_DIR="$HOME/.nvm"' >> $HOME/.bashrc
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm' >> $HOME/.bashrc
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> $HOME/.bashrc
        fi
		source $HOME/.bashrc
    fi
}

install_global_node()
{
	fmt_info "setup a global node version"
	nvm install --lts="$GLOBAL_NODE_VERSION"
	nvm alias default "lts/$GLOBAL_NODE_VERSION"
	nvm use default
}

setup_node_kits()
{
	echo_title "Setup Node and NVM"
	fmt_info "checking nvm..."
	# see: https://github.com/nvm-sh/nvm#manual-install
	install_nvm
	link_npmrc
	setup_nvm_profile
	install_global_node

	fmt_success "Setup Node and NVM finish!"
}


run_step "setup_node_kits"