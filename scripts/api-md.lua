-- Reorders LuaLS's doc.md for the API page: the module first, then the controls,
-- then the objects; drops the empty section LuaLS adds for itself and the
-- `__index` entries of metatable-backed classes.
-- Usage: lua scripts/api-md.lua <doc.md> <out.md>

local ORDER = { "hs_mock", "HsMockCtl", "HsMockTask", "HsMockMenubar" }

local input, output = arg[1], arg[2]
local text = assert(io.open(input)):read("a")

local sections = {}
for section in (text .. "\n---\n"):gmatch("(.-)\n%-%-%-\n") do
	local name = section:match("^%s*# ([%w_]+)")
	if name then sections[name] = section:gsub("^%s+", ""):gsub("%s+$", "") end
end

-- Drops the `__index` entries LuaLS lists for metatable-backed classes.
local function withoutIndex(section)
	local lines, skipping = {}, false
	for line in (section .. "\n"):gmatch("(.-)\n") do
		if line:match("^## ") then skipping = line == "## __index" end
		if not skipping then table.insert(lines, line) end
	end
	return table.concat(lines, "\n")
end

local parts = {}
for _, name in ipairs(ORDER) do
	table.insert(parts, withoutIndex(assert(sections[name], "missing section: " .. name)))
end

local out = assert(io.open(output, "w"))
out:write(table.concat(parts, "\n\n"), "\n")
out:close()
