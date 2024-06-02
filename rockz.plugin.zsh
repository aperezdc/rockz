#! /bin/zsh
#
# rockz.plugin.zsh
# Copyright (C) 2016 Adrian Perez <aperez@igalia.com>
#
# Distributed under terms of the GPLv3 license.
#

: ${ROCKZ_HOME:=${HOME}/.rockenvs}
: ${ROCKZ_LUAROCKS_VERSION:=3.11.1}
: ${ROCKZ_LUAROCKS_DISTURL:='https://luarocks.org/releases/'}

typeset -gr _rockz_dir=${0:A:h}

# Arguments: prefix_path lua_bin lua_lib lua_inc
#
__rockz_luarocks_install () {
	emulate -L zsh
	setopt local_options err_return

	local -a confopts=( --force-config --prefix="$1" )
	case ${ROCKZ_LUAROCKS_VERSION} in
		2.*.*)
			confopts+=(
				--with-downloader=curl
				--with-lua="$1"
				--with-lua-lib="${3:h}"
				--with-lua-include="$4"
			) ;;
		3.*.*)
			confopts+=(
				--with-lua-bin="${2:h}"
				--with-lua-interpreter="${2:t}"
				--with-lua-lib="${3:h}"
				--with-lua-include="$4"
			) ;;
		*) __rockz_die "Unsupported LuaRocks version: ${ROCKZ_LUAROCKS_VERSION}\nPlease file a bug at https://github.com/aperezdc/rockz/issues"
			;;
	esac

	mkdir -p "$1/bin"
	pushd -q "$1"
	ln -s "$2" "$1/bin/lua"

	local tarball="luarocks-${ROCKZ_LUAROCKS_VERSION}.tar.gz"
	curl -\# -fLo "${tarball}#1" "${ROCKZ_LUAROCKS_DISTURL}/${tarball}{,.asc}"

	local gpgbin
	read -r gpgbin < <(whence gpg2 gpg)
	if [[ -n ${gpgbin} && -x ${gpgbin} ]] ; then
		"${gpgbin}" --verify "${tarball}.asc" "${tarball}" \
			|| __rockz_die "Invalid PGP signature for ${tarball}"
	else
		echo '[1;31m== WARNING: GnuPG is not installed ==[0;0m'
		printf 'Cannot check signature of %s, continue anyway? [y/N] ' "${tarball}"
		local answer
		read -q answer ; echo "${answer}"
		[[ ${answer} = y ]] || __rockz_die 'LuaRocks intallation aborted by user'
	fi

	tar -xzf "${tarball}"
	rm "${tarball}" "${tarball}.asc"
	cd "luarocks-${ROCKZ_LUAROCKS_VERSION}"
	./configure "${confopts[@]}"
	make -s bootstrap
	rm -rf "../luarocks-${ROCKZ_LUAROCKS_VERSION}"
	popd -q
}

__rockz_die () {
	echo "$*" 1>&2
	return 1
}

rockz () {
	if [[ $# -eq 0 || $1 = --help || $1 = -h ]] ; then
		rockz help
		return
	fi

	local cmd=$1 fname="rockz-$1"
	shift

	if typeset -fz "${fname}" ; then
		if [[ $1 = --help || $1 = -h ]] ; then
			rockz help "${cmd}"
		else
			"${fname}" "$@"
		fi
	elif [[ -d ${ROCKZ_HOME}/${cmd} ]] ; then
		rockz activate "${cmd}"
	else
		echo "The subcommand '${cmd}' is not defined" 1>&2
	fi
}

rockz-activate () {
	emulate -L zsh
	setopt local_options err_return

	if [[ $# -ne 1 ]] ; then
		__rockz_die 'No rockenv specified.'
	fi

	local renv_path="${ROCKZ_HOME}/$1"
	[[ -d ${renv_path} ]] || __rockz_die "The rockenv '$1' does not exist."

	# If a rockenv is in use, deactivate it first
	if [[ ${ROCK_ENV:+set} = set ]] ; then
		rockz-deactivate
	fi

	ROCK_ENV_NAME=$1
	ROCK_ENV=${renv_path}

	path=( "${ROCK_ENV}/bin" "${path[@]}" )

	# Save variables overriden by "luarocks path"
	if [[ ${LUA_PATH:+set} = set ]] ; then
		_ROCKZ_OLD_LUA_PATH=${LUA_PATH}
		unset LUA_PATH
	fi
	if [[ ${LUA_CPATH:+set} = set ]] ; then
		_ROCKZ_OLD_LUA_CPATH=${LUA_CPATH}
	fi

	eval "$("${ROCK_ENV}/bin/luarocks" path)"
}

rockz-new () {
	emulate -L zsh
	setopt local_options err_return

	local -A opt
	zparseopts -E -D -A opt -- p: -profile:=p
	[[ $# -eq 1 ]] || __rockz_die 'No rockenv name specified.'

	local profile=${(i)opt[-p]}
	[[ -n ${profile} ]] || profile='default'
	[[ -r ${ROCKZ_HOME}/.rockprofile.${profile} ]] || __rockz_die "Profile '${profile}' is not defined."

	local renv_name=$1
	local renv_path="${ROCKZ_HOME}/${renv_name}"

	source "${ROCKZ_HOME}/.rockprofile.${profile}"
	echo "Rockenv path: ${renv_path} (profile: ${profile})"
	echo "Lua executable: ${ROCKZ_LUA_BIN}"
	echo "Lua library: ${ROCKZ_LUA_LIB}"
	echo "Lua include: ${ROCKZ_LUA_INC}"

	# Save them in a local variable, so we can unset the globals
	local args=("${ROCKZ_LUA_BIN}" "${ROCKZ_LUA_LIB}" "${ROCKZ_LUA_INC}")
	unset ROCKZ_LUA_BIN ROCKZ_LUA_LIB ROCKZ_LUA_INC

	trap "[[ \$? -eq 0 ]] || rm -rf '${renv_path}' ; cd '$(pwd)'" EXIT

	__rockz_luarocks_install "${renv_path}" "${args[@]}"
	rockz-activate "${renv_name}"
}

rockz-deactivate () {
	emulate -L zsh
	setopt local_options err_return

	[[ ${ROCK_ENV:+set} = set ]] || __rockz_die 'No rockenv is active.'

	# Remove element from $PATH
	local renv_bin="${ROCK_ENV}/bin"
	local -a new_path=( )
	for path_item in "${path[@]}" ; do
		if [[ ${path_item} != ${renv_bin} ]] ; then
			new_path=( "${new_path[@]}" "${path_item}" )
		fi
	done
	path=( "${new_path[@]}" )

	# Restore $LUA_PATH
	if [[ ${_ROCKZ_OLD_LUA_PATH:+set} = set ]] ; then
		export LUA_PATH=${_ROCKZ_OLD_LUA_PATH}
	else
		unset LUA_PATH
	fi

	# Restore $LUA_CPATH
	if [[ ${_ROCKZ_OLD_LUA_CPATH:+set} = set ]] ; then
		export LUA_CPATH=${_ROCKZ_OLD_LUA_CPATH}
	else
		unset LUA_CPATH
	fi

	unset ROCK_ENV ROCK_ENV_NAME
}

rockz-rm () {
	emulate -L zsh
	setopt local_options err_return

	[[ $# -eq 1 ]] || __rockz_die 'No rockenv specified.'
	if [[ ${ROCK_ENV_NAME} = $1 ]] ; then
		__rockz_die 'Cannot delete rockenv while in use.'
	fi

	local renv_path="${ROCKZ_HOME}/$1"
	[[ -d ${renv_path} ]] || __rockz_die "The rockenv '$1' does not exist."

	rm -rf "${renv_path}"
}

rockz-ls () {
	emulate -L zsh
	setopt local_options err_return null_glob

	if [[ -d ${ROCKZ_HOME} ]] ; then
		pushd -q "${ROCKZ_HOME}"
		for item in */bin/lua ; do
			echo "${item%/bin/lua}"
		done
		popd -q
	fi
}

rockz-_exists () {
	emulate -L zsh
	setopt local_options err_return
	[[ $# -eq 1 ]] || __rockz_die 'No rockenv specified.'
	[[ -x ${ROCKZ_HOME}/$1/bin/lua ]]
}

rockz-cd () {
	emulate -L zsh
	setopt local_options err_return

	[[ ${ROCK_ENV:+set} = set ]] || __rockz_die 'No rockenv is active.'

	cd "${ROCK_ENV}"
}

rockz-current () {
	emulate -L zsh
	setopt local_options err_return
	[[ ${ROCK_ENV:+set} = set ]] || __rockz_die 'No rockenv is active.'
	echo "${ROCK_ENV}"
}

rockz-help () {
	if [[ $# -eq 0 || $1 = commands ]] ; then
		if [[ $# -eq 0 ]] ; then
			echo 'Usage: rockz <command> [<args>]'
			echo
		fi
		echo 'Available commands:'
		echo
		for file in "${_rockz_dir}"/doc/cmd-*.txt ; do
			local cmd=${file#*/cmd-}
			printf '  %-12s ' "${cmd%.txt}"
			read -re < "${file}"
		done
		echo
	elif [[ $# -eq 1 && $1 = topics ]] ; then
		echo 'Available topics:'
		echo
		for file in "${_rockz_dir}"/doc/topic-*.txt ; do
			local topic=${file#*/topic-}
			printf '  %-12s ' "${topic%.txt}"
			read -re < "${file}"
		done
		echo
	elif [[ $# -eq 1 ]] ; then
		if [[ -r ${_rockz_dir}/doc/cmd-$1.txt ]] ; then
			cat "${_rockz_dir}/doc/cmd-$1.txt"
		elif [[ -r ${_rockz_dir}/doc/topic-$1.txt ]] ; then
			cat "${_rockz_dir}/doc/topic-$1.txt"
		else
			cat 1>&2 <<-EOF
			No such topic or command: $1
			Tip: Use "rockz help topics" for a list of topics, or "rockz help commands" for a list of commands.
			EOF
			return 1
		fi
	else
		echo 'Usage: rockz <command> [<args>]' 1>&2
		return 1
	fi
}

rockz-profile () {
	emulate -L zsh
	setopt local_options err_return

	if [[ $# -eq 0 ]] ; then
		# List profiles
		if [[ -d ${ROCKZ_HOME} ]] ; then
			pushd -q "${ROCKZ_HOME}"
			for item in .rockprofile.* ; do
				echo "${item#.rockprofile.}"
			done
			popd -q
		fi
		return 0
	fi

	local -A opt
	zparseopts -E -D -A opt -- \
		I: -include:=I \
		L: -library:=L \
		l: -lua:=l     \
		s -show=s

	[[ $# -eq 1 ]] || __rockz_die 'No profile name specified.'

	if [[ -n ${(k)opt[-s]} ]] ; then
		[[ -r ${ROCKZ_HOME}/.rockprofile.$1 ]] || __rockz_die "Profile '$1' does not exist."
		cat "${ROCKZ_HOME}/.rockprofile.$1"
		return
	fi

	local lua_bin=${(i)opt[-l]} lua_lib=${(i)opt[-L]} lua_inc=${(i)opt[-I]}

	[[ -n ${lua_bin} ]] || __rockz_die 'Path to Lua binary (-l, --lua) not specified.'
	[[ -n ${lua_lib} ]] || __rockz_die 'Path to Lua library (-L, --library) not specified.'
	[[ -n ${lua_inc} ]] || __rockz_die 'Path to Lua includes (-I, --include) not specified.'

	# Sanity checks.
	[[ -x ${lua_bin} ]] || __rockz_die "File '${lua_bin}' is not executable."
	[[ -r ${lua_lib} ]] || __rockz_die "File '${lua_lib}' is not readable."
	[[ -d ${lua_inc} ]] || __rockz_die "Path '${lua_inc}' is not a directory."

	[[ -d ${ROCKZ_HOME} ]] || mkdir -p "${ROCKZ_HOME}"

	cat > "${ROCKZ_HOME}/.rockprofile.$1" <<-EOF
	ROCKZ_LUA_BIN='${lua_bin}'
	ROCKZ_LUA_LIB='${lua_lib}'
	ROCKZ_LUA_INC='${lua_inc}'
	EOF
}
