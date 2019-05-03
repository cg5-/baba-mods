
local mod = {}

function mod.load(dir)
	loadscript(dir .. "movement")

	tileslist["object120"] = {
		name = "text_find",
		sprite = "text_find",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 1,
		operatortype = "verb",
		colour = {5, 0},
		active = {5, 2},
		tile = {0, 12},
		grid = {11, 0},
		layer = 20,
	}

	tileslist["object121"] = {
		name = "text_evil",
		sprite = "text_evil",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {2, 1},
		active = {2, 2},
		tile = {1, 12},
		grid = {11, 1},
		layer = 20,
	}

	tileslist["object122"] = {
		name = "text_repent",
		sprite = "text_repent",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {5, 0},
		active = {5, 2},
		tile = {2, 12},
		grid = {11, 2},
		layer = 20,
	}

	mod.inspect = loadscript(dir .. "inspect")
end

function mod.unload(dir)
	loadscript("Data/values")
	loadscript("Data/movement")
end

return mod
