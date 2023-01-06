# GMR-Discord-Bot

## Installation

1. Install [Luvit](https://luvit.io/install.html).
2. Clone this repository.
3. Install the following packages with the Lit package manager:\
``lit install SinisterRectus/sqlite3``\
``lit install creationix/coro-spawn``.
4. Download the required [sqlite3](https://sqlite.org/download.html) Dynamic Link Library ``sqlite3`` and ``sqlite3.def``.
5. Create a Discord bot via the [Discord Developer Portal](https://discord.com/developers/applications) and add the Bot user to your guild.
6. Create a file ``token.txt`` and place your bot's token inside.
7. Create a valid [configuration](#configuration) file.
8. Start the bot with ``luvit main.lua``

## Configuration

Included in the repository is an example config (``Config.json.example``), before starting the bot ensure all values are provided.

> Note: Ensure ``_DEBUG`` is ``false`` in a live environment!

When ready to use rename to ``Config.json``.
