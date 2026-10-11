# hs-mock

[![LuaRocks](https://img.shields.io/luarocks/v/hugoh/hs-mock)](https://luarocks.org/modules/hugoh/hs-mock)
[![API docs](https://img.shields.io/badge/docs-API-blue)](https://hugoh.github.io/hs-mock/)

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

The [API reference](https://hugoh.github.io/hs-mock/) lists what is mocked and
every `ctl` test control. It is generated from the
[LuaLS](https://luals.github.io/) annotations in `lua/hs_mock.lua`, so editors
running LuaLS also complete and type-check `ctl` once the install tree is on
the library path:

```json
{ "workspace.library": [".rocks/share/lua/5.4"] }
```

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
mise run docs          # build the API page into docs/ from the annotations
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
