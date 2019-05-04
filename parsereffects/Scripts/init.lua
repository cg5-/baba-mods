
local mod = {}

-- concat arrays in place
function mod.concat(array, ...)
	for _, array2 in ipairs({...}) do
		for _, x in ipairs(array2) do
			table.insert(array, x)
		end
	end
	return array
end

function mod.load(dir)
	loadscript(dir .. "rules")
	loadscript(dir .. "tools")
	loadscript(dir .. "conditions")
	mod.inspect = loadscript(dir .. "inspect")
	mod.parser = loadscript(dir .. "parser")

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

	tileslist["object121"] = {
		name = "text_slant",
		sprite = "text_slant",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {0, 2},
		active = {0, 3},
		tile = {1, 12},
		grid = {11, 1},
		layer = 20,
	}

	tileslist["object122"] = {
		name = "text_yoda",
		sprite = "text_yoda",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {5, 1},
		active = {5, 3},
		tile = {2, 12},
		grid = {11, 2},
		layer = 20,
	}

	tileslist["object123"] = {
		name = "text_caveman",
		sprite = "text_caveman",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 2,
		colour = {0, 2},
		active = {0, 3},
		tile = {3, 12},
		grid = {11, 3},
		layer = 20,
	}
end

function mod.unload(dir)
	loadscript("Data/rules")
	loadscript("Data/tools")
	loadscript("Data/conditions")
end

return mod
