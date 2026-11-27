Playtest the game in Roblox Studio through the Studio MCP server and report what's wrong.

1. Run `list_roblox_studios` and pick the Studio running this game.
2. Make sure `rojo serve` is running and the Rojo plugin is connected (check that
   ServerScriptService.Server exists with `search_game_tree`). If not, tell me.
3. Start a playtest with `start_stop_play`. Wait about 5 seconds.
4. Read `get_console_output`. Take a `screen_capture`.
5. $ARGUMENTS
6. Stop the playtest.
7. Report errors and warnings in a short list with the file and line, then fix the ones in
   `src/` and run the playtest again until the Output is clean.
