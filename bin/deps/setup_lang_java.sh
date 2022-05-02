#!/usr/bin/env bash

install_sdkman()
{
	if [ ! -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
		local http_proxy=$(get_http_proxy)
		if [ ! -z "${http_proxy:-}" ]; then
			curl --proxy $http_proxy -s "https://get.sdkman.io" | bash
		else
			curl -s "https://get.sdkman.io" | bash
		fi
	fi
	# sdkman script not set -eu, it's sucks
	set +eu
	source "$HOME/.sdkman/bin/sdkman-init.sh"
	# show sdkman version
	sdk version
	set -eu
}

install_jdk()
{
	set +eu
	# set http proxy
	local script_http_proxy=$(get_http_proxy)
	if [ ! -z "${script_http_proxy:-}" ]; then
		export http_proxy="$script_http_proxy"
	fi
	sdk install java "$JDK_DEFAULT_VERSION"
	sdk default java "$JDK_DEFAULT_VERSION"
	sdk install gradle "$GRADLE_DEFAULT_VERSION"
	sdk default gradle "$GRADLE_DEFAULT_VERSION"
	sdk current
	unset http_proxy
	set -eu
}

setup_java_kits()
{
	echo_title "Setup JDK and Gradle"
	install_sdkman
	install_jdk
	fmt_success "Setup JDK and Gradle finish!"
}

append_step "setup_java_kits"