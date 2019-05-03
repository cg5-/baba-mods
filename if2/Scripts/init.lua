
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

-- Version of hasfeature which won't cause a stack overflow if there is a dependency cycle
-- (e.g. rock is group if group is near baba, if baba is near a rock then we get a dependency
-- cycle trying to figure out if the rule applies)
local shfstack = {}
function mod.safehasfeature(unitid, verb, object)
	for _,data in ipairs(shfstack) do
		if data[1] == unitid and data[2] == verb and data[3] == object then
			return false
		end
	end

	local unit = mmf.newObject(unitid)

	table.insert(shfstack, {unitid, verb, object})
	local result = hasfeature(getname(unit), verb, object, unitid)
	table.remove(shfstack)
	
	return result
end

local vanillamovecommand = movecommand
local function mymovecommand(ox, oy, dir, playerid)
	-- Just in case
	shfstack = {}

	vanillamovecommand(ox, oy, dir, playerid)
end

function mod.load(dir)
	loadscript(dir .. "rules")
	loadscript(dir .. "tools")
	loadscript(dir .. "conditions")
	mod.inspect = loadscript(dir .. "inspect")
	mod.parser = loadscript(dir .. "parser")

	movecommand = mymovecommand

	tileslist["object120"] = {
		name = "text_if",
		sprite = "text_if",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 10,
		colour = {0, 1},
		active = {0, 3},
		tile = {0, 12},
		grid = {11, 0},
		layer = 20,
	}

	tileslist["object121"] = {
		name = "text_every",
		sprite = "text_every",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 11,
		colour = {5, 0},
		active = {5, 2},
		tile = {1, 12},
		grid = {11, 1},
		layer = 20,
	}

	tileslist["object122"] = {
		name = "text_1",
		sprite = "text_1",
		sprite_in_root = false,
		unittype = "text",
		tiling = -1,
		type = 11,
		colour = {5, 0},
		active = {5, 2},
		tile = {2, 12},
		grid = {11, 2},
		layer = 20,
	}
end

function mod.unload(dir)
	loadscript("Data/values")
	loadscript("Data/rules")
	loadscript("Data/conditions")
	loadscript("Data/tools")

	movecommand = vanillamovecommand
end

return mod
