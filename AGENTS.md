# AGENTS.md

## Project

`navidrome.koplugin/` is a KOReader plugin that controls a Navidrome server
(Subsonic API) as a jukebox: browse, search and drive playback.

- `main.lua` — the plugin (`NavidromePlugin`) plus the `PlayerDialog` widget.
- `_meta.lua` — plugin metadata for KOReader.

## Testing

There is no CI. Tests are a headless harness that stubs KOReader modules and
runs the plugin under LuaJIT (via Python `lupa`). Rebuild them in `/tmp`:

```bash
pip install lupa luaparser
# harness: /tmp/test_harness.lua  (stubs + load_plugin())
# suites:  /tmp/run_tests.lua /tmp/test_buttons.lua /tmp/test_dialog.lua /tmp/test_async.lua
python3 -c "from lupa import LuaRuntime; LuaRuntime(unpack_returned_tuples=True).execute(open('/tmp/run_tests.lua').read())"
```

Always also syntax-check with `luaparser`:

```bash
python3 -c "from luaparser import ast; ast.parse(open('navidrome.koplugin/main.lua').read()); print('OK')"
```

## KOReader API gotchas learned here

- `makePath` / `pathExists` / `fileExists` live in `frontend/util.lua`
  (`require("util")`), **not** in `ffi/util`. A wrong `pcall(ffiUtil.makePath, ...)`
  silently fails and the cover cache is never created.
- `UIManager:close(widget)` **without a refresh type does not repaint**:
  `_refresh(nil)` returns immediately. A widget then vanishes logically but its
  pixels stay as a "ghost". Use `onCloseWidget()` + `UIManager:setDirty(nil, "ui")`.
- Widgets are event-driven via `handleEvent` → `on<EventName>`; a gesture event
  maps to `onGesture` → `ges_events`. Returning `true` consumes the event and
  stops propagation to widgets below.
- `Button:setText(text)` with no width re-initializes the button and collapses
  its geometry to the glyph size. Pass the width, or set fixed `width`/`height`.
- Icons: colored emoji are absent from every font KOReader bundles. Use
  FontAwesome glyphs from the always-present Nerd Font
  (`resources/fonts/nerdfonts/symbols.ttf`) written as `\u{fxxx}`.

## GitHub

The `GITHUB_TOKEN` in this environment is a GitHub App installation token
(`ghu_` prefix) scoped to a fixed set of existing repositories. It can push to
those repos but **cannot create new repositories** (`Resource not accessible by
integration` on `POST /user/repos`). To publish elsewhere, the user must either
create the repo themselves or provide a token with `repo` scope.
