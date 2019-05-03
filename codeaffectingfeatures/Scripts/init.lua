
local mod = {}

function mod.load(dir)
	loadscript(dir .. "rules")
	mod.inspect = loadscript(dir .. "inspect")

	tileslist["object120"] = {
		name = "paradoxmessage",
		sprite = "paradoxmessage",
		sprite_in_root = false,
		unittype = "object",
		tiling = -1,
		type = 0,
		colour = {2, 2},
		tile = {0, 12},
		grid = {11, 0},
		layer = 4,
	}
end

function mod.unload(dir)
	loadscript("Data/rules")
end

return mod
