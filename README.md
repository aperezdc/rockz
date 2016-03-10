# RockZ

A [Z shell](http://zsh.org) virtualenvwrapper-lookalike, loosely based on Adam
Brenecki's [virtualfish](https://github.com/adambrenecki/virtualfish) for the
[Fish shell](http://fishshell.com), and highly based upon my own
[VirtualZ](https://github.com/aperezdc/virtualz).

* For [Lua](http://www.lua.org) instead of Python.
* Using [LuaRocks](https://luarocks.org) instead of Pip.

☺

## Quickstart

RockZ needs the paths to the Lua header files and the Lua library in order to
bootstrap LuaRocks — so in turn LuaRocks knows how to build binary modules.
The names and locations vary in each system, so instead RockZ expects the user
to define a *profile* which stores the needed paths.

The following should work for creating a `default` profile in most GNU/Linux
distributions:

```sh
rockz profile default \
  --lua=/usr/bin/lua \
  --include=/usr/include \
  --library=/usr/lib/liblua.so
```

Once you have a profile, you can create a new “rockenv” (Lua+LuaRocks
environment):

```sh
rockz new myenv
```

The variables `${ROCK_ENV}` and `${ROCK_ENV_NAME}` will be set with the full
path to the rockenv prefix directory and the rockenv name, respectively.

Environments can be managed with the rest of `rockz` subcommands:

```sh
rockz activate myenv
rockz new myotherenv
rockz rm myenv
rockz deactivate
```


## Installation & Setup

The recommended way is to use a plugin manager. By default, the location where
RockZ looks for rockenvs is `~/.rockenvs`. This can be changed by setting the
desired path in the `${ROCKZ_HOME}` variable.

With [zgen](https://github.com/tarjoilija/zgen), add the following to your
`.zshrc`:

```sh
zgen load aperezdc/rockz
```


### Rockenv name in the prompt

When a rockenv is active, the following variables are defined:

- `ROCK_ENV` contains the full path to the active environment.
- `ROCK_ENV_NAME` contains the name of the active environment.

For example, the following will prepend the name of the current rockenv to
your existing prompt, but only if there is an environment active:

```sh
PROMPT="\${ROCK_ENV_NAME:+\${ROCK_ENV_NAME} }${PROMPT}"
```
