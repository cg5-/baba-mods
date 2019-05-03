
local mod = {}

function mod.load(dir)
	loadscript(dir .. "conditions")

	tileslist["object120"] = {
		name = "text_active",
		sprite = "text_active",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 3,
		operatortype = "cond_start",
		colour = {4, 0},
		active = {4, 1},
		tile = {0, 12},
		grid = {11, 0},
		layer = 20,
	}

	tileslist["object121"] = {
		name = "text_blocked",
		sprite = "text_blocked",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 3,
		operatortype = "cond_start",
		colour = {4, 0},
		active = {4, 1},
		tile = {1, 12},
		grid = {11, 1},
		layer = 20,
	}
end

function mod.unload(dir)
	loadscript("Data/values")
	loadscript("Data/conditions")
end

return mod
