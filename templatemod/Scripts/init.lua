
local mod = {}

function mod.load(dir)
	-- loadscript(dir .. "movement")

	-- tileslist["object120"] = {
	-- 	name = "text_zoom",
	-- 	sprite = "text_zoom",
	-- 	sprite_in_root = false,
	-- 	unittype = "text",
	-- 	tiling = -1,
	-- 	type = 2,
	-- 	colour = {1, 1},
	-- 	active = {3, 2},
	-- 	tile = {0, 12},
	-- 	grid = {11, 0},
	-- 	layer = 20,
	-- }
end

function mod.unload(dir)
	loadscript("Data/values")
	-- loadscript("Data/movement")
end

return mod
