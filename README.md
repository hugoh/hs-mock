# hs-mock

A mock of the [Hammerspoon](https://www.hammerspoon.org/) `hs` global for
testing Spoons under [busted](https://lunarmodules.github.io/busted/).

It covers the APIs Spoons commonly share, with Hammerspoon's real event
constants and its own `fnutils` and `inspect` code. It is strict: reading an
`hs.<name>` it doesn't provide raises `hs_mock: hs.<name> is not mocked`, so a
test fails loudly on the first API it hasn't faked yet. Tests can add or replace
anything.

## Install

From [luarocks.org](https://luarocks.org/modules/hugoh/hs-mock), into a
project-local tree so each repo pins its own version:

```sh
luarocks install --tree .rocks hs-mock
```

Or pinned to a GitHub release, which attaches a rockspec pinned to its tag. With
mise, a `deps` task keeps it installed and skips once it is:

```toml
# mise.toml
[env]
HS_MOCK_VERSION = "1.0.0"

[tasks.deps]
run = "luarocks install --tree .rocks https://github.com/hugoh/hs-mock/releases/download/v$HS_MOCK_VERSION/hs-mock-$HS_MOCK_VERSION-1.rockspec"
sources = ["mise.toml"]
outputs = [".rocks/lib/luarocks/rocks-5.4/hs-mock/*/rock_manifest"]

[tasks.test]
depends = ["deps"]
run = "busted"
```

Then point busted at the tree, and add `.rocks/` to `.gitignore`:

```lua
-- .busted
return {
  _all = {
    lpath = ".rocks/share/lua/5.4/?.lua;.rocks/share/lua/5.4/?/init.lua",
  },
}
```

## Use

Build a fresh mock for each test:

```lua
local hs_mock = require("hs_mock")
local hs, ctl, Spoon

before_each(function()
  hs, ctl = hs_mock.new()
  _G.hs = hs
  hs.midi = { devices = function() return {} end } -- add what the spoon also needs
  Spoon = dofile("init.lua")
end)

it("polls every minute", function()
  Spoon:start()
  ctl.advance(60)
  assert.same({ "polled" }, ctl.logged("info"))
end)
```

## API

The mock covers `logger.new`; `timer.doAfter`, `doEvery`, `new`, `secondsSinceEpoch`,
`absoluteTime`; `task.new`; `menubar.new`; `notify.new`, `activationTypes`;
`caffeinate.watcher`; `application.find`, `get`, `watcher`; `hotkey.bind`;
`audiodevice` (devices, defaults, `watcher`); `image.imageFromName`, `iconForFile`;
`execute`; `open`; `ipc` (present); `alert`; `settings`; `screen.mainScreen`;
`mouse.absolutePosition`; `eventtap` (`keyStroke`, `leftClick`, `new`, `event`);
`websocket`; `wifi`; `host.interfaceStyle`; `distributednotifications`;
`spoons.resourcePath` (returns the file unchanged); `application.launchOrFocus`,
`launchOrFocusByBundleID`, `frontmostApplication`;
`json.read`, `write`; `fs.attributes`, `mkdir`; `fnutils` and `inspect`
(Hammerspoon's own code, vendored). Event constants match Hammerspoon 1.1.1.

Tests drive it through `ctl`:

| Control | Effect |
|---|---|
| `ctl.now` | Virtual clock in seconds; drives `secondsSinceEpoch` and `absoluteTime` (ns) |
| `ctl.advance(s)` | Moves the clock, firing due timers in due-time order (ties in scheduling order); `doEvery` and started `timer.new` re-arm |
| `ctl.flush()` | Fires the one-shot timers pending now, whatever their delay; leaves repeating timers and ones scheduled meanwhile |
| `ctl.timers()` | Running timers |
| `ctl.logs`, `ctl.logged(level)` | Every log line at every level (`{ logger, level, message }`), or the messages at one level |
| `ctl.tasks` | Created tasks; `task:complete(code, stdout, stderr)` calls back. `terminate()` doesn't |
| `ctl.onTask = fn(task)` | Called on `task:start()`; returning an exit code completes the task at once |
| `ctl.menubars` | Created menubars (`_title`, `_icon`, `_menu`, `_tooltip`, `_deleted`…); `bar:_click()` |
| `ctl.notifications`, `ctl.activate(note, type)` | Created notifications (`_attributes`, `_sent`, `_withdrawn`); activation calls back |
| `ctl.caffeinate(event)`, `ctl.appEvent(name, event, app)` | Delivers to started watchers |
| `ctl.apps[name]`, `ctl.frontmost` | `application.find` / `get` match a key of `ctl.apps`, else a `bundleID()` among those apps and the frontmost one; `frontmostApplication` returns `ctl.frontmost` |
| `ctl.launched` | Names and bundle ids passed to `launchOrFocus` / `launchOrFocusByBundleID` |
| `ctl.addAudioDevice{ name, uid, input, transport, muted, volume, inUse }` | Adds an output (or `input = true`) device; `uid` defaults to `name` |
| `ctl.audio.defaultOutput`, `ctl.audio.defaultInput` | The default devices; `setDefault*Device()` updates them |
| `ctl.audioEvent(event)`, `ctl.deviceEvent(device, event, scope, element)` | Fires the running `audiodevice.watcher`, or a watching device's callback |
| `ctl.executed`, `ctl.onExecute = fn(cmd)` | Commands passed to `hs.execute`; `onExecute` returns its `output, status, type, rc` (default `"", true, "exit", 0`) |
| `ctl.opened` | Paths passed to `hs.open` |
| `ctl.alerts` | `{ id, text, style, screen, seconds, closed }` per `alert.show` (which returns the string `id`) |
| `ctl.settings`, `ctl.screenFrame`, `ctl.mousePosition` | Backing state for `settings`, `screen.mainScreen():frame()` and `mouse.absolutePosition` |
| `ctl.keyStrokes`, `ctl.clicks`, `ctl.posted` | `eventtap.keyStroke` / `leftClick` calls and posted events |
| `ctl.newEvent{ type, systemKey, flags }`, `ctl.tapEvent(event)` | Builds an event; delivers it to the first enabled tap watching its type and returns that tap's answer |
| `ctl.websockets`, `ctl.websocketEvent(ws, event, message)` | Created websockets (`_url`, `_sent`, `_closed`); calls a socket's callback |
| `ctl.wifiNetwork`, `ctl.wifiEvent(message, interface)` | `wifi.currentNetwork`; notifies running wifi watchers (default `"SSIDChange"`, `"en0"`) |
| `ctl.interfaceStyle` | `host.interfaceStyle`: `nil` (light) or `"Dark"`, as macOS reports |
| `ctl.distributedNotification(name, object, userInfo)` | Delivers to running watchers registered for that name, or for all |
| `ctl.images[nameOrPath]` | What `image.imageFromName` / `iconForFile` return; unknown names give `nil`, as in Hammerspoon |
| `ctl.hotkeys` | Bindings: `mods`, `key`, `message`, `pressed`, `enabled`, `deleted` |
| `ctl.files[path]`, `ctl.dirs[path]` | The filesystem behind `json` and `fs`; a non-table file value reads as malformed JSON |

`json.read` and `json.write` copy, like real serialization.

## What belongs here, and what stays in a Spoon's tests

Generic fakes belong here: ones that record calls or hold simple state, with no
opinion about a particular Spoon. A Spoon's tests keep their own fake, with a
comment on why, when it is:

- **a test assertion** rather than a mock, such as checking a lookup is exact;
- **deliberately unrealistic**, such as a `json.decode` that passes tables through;
- **too deep to share honestly**: `axuielement` trees, `webview` with its
  JavaScript bridge, `canvas` rendering.

## Development

```sh
mise run test          # specs, plus the rock built and required from its own tree
mise run vendor 1.1.1  # refresh vendored fnutils and inspect
```

Commits follow [Conventional Commits](https://www.conventionalcommits.org/);
merging to `main` cuts a semver release, attaches the tag-pinned rockspec, and
uploads it to luarocks.org when the `LUAROCKS_API_KEY` repository secret is set
(the upload job skips with a notice otherwise).

## License

MIT; see [LICENSE](LICENSE). `lua/hs_mock/fnutils.lua` is Hammerspoon's
(MIT, © 2014-2025 its contributors) and `lua/hs_mock/inspect.lua` is
[inspect.lua](https://github.com/kikito/inspect.lua) (MIT, © 2013 Enrique
García Cota), both vendored unchanged with their notices.
