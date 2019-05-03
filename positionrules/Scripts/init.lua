
local mod = {}

local function clamp(coord, maximum)
	-- The first on-screen coordinate is 1, not 0. 0 is just outside the level border.
	return math.max(1, math.min(coord, maximum))
end

-- Given a feature structure containing a "here" rule, return {x,y} the tile the
-- here points at, or nil if there is no "here".
local function getheretarget(feature)
	local unitids = feature[3]
	local hereword = nil
	for i = #unitids, 1, -1 do
		local word = mmf.newObject(unitids[i][1])
		if (word ~= nil and word.strings[UNITNAME] == "text_here") then
			hereword = word
			break
		end
	end

	if hereword == nil then
		return nil
	end

	-- Follow the chain of HEREs until we reach the end
	local x,y = hereword.values[XPOS],hereword.values[YPOS]
	local visited = {y * roomsizex + x}

	while hereword ~= nil do
		local targetdir = ndirs[hereword.values[DIR] + 1]
		x = clamp(x + targetdir[1], roomsizex - 2)
		y = clamp(y + targetdir[2], roomsizey - 2)
		local tileid = y * roomsizex + x

		-- Don't get stuck in an infinite loop if the HEREs form a cycle
		for _,vtileid in ipairs(visited) do
			if tileid == vtileid then
				return {x, y}
			end
		end
		table.insert(visited, tileid)

		if unitmap[tileid] == nil then
			return {x, y}
		end

		-- Look through the current tile for a HERE
		hereword = nil
		for _,newunitid in ipairs(unitmap[tileid]) do
			local unit = mmf.newObject(newunitid)
			if unit.strings[UNITNAME] == "text_here" then
				hereword = unit
			end
		end
	end

	return {x, y}
end

-- As above, but for "there".
local function gettheretarget(feature)
	local unitids = feature[3]
	local thereword = nil
	for i = #unitids, 1, -1 do
		local word = mmf.newObject(unitids[i][1])
		if (word ~= nil and word.strings[UNITNAME] == "text_there") then
			thereword = word
			break
		end
	end

	if thereword == nil then
		return nil
	end

	local x,y = thereword.values[XPOS],thereword.values[YPOS]
	local targetdir = ndirs[thereword.values[DIR] + 1]
	
	-- I don't think this is possible, but let's be safe.
	if targetdir[1] == 0 and targetdir[2] == 0 then
		return nil
	end

	while true do
		local newx,newy = x + targetdir[1], y + targetdir[2]
		if newx < 1 or newx > roomsizex - 2 or newy < 1 or newy > roomsizey - 2 then
			return {x,y}
		end

		local obstacles = unitmap[newy * roomsizex + newx]

		if obstacles ~= nil then
			for _,obstacleid in ipairs(obstacles) do
				local obstacle = mmf.newObject(obstacleid)
				local name = getname(obstacle)
				if hasfeature(name,"is","stop",obstacleid) ~= nil or hasfeature(name,"is","push",obstacleid) ~= nil or hasfeature(name,"is","pull",obstacleid) ~= nil then
					return {x,y}
				end
			end
		end

		x,y = newx,newy
	end
end

local lookup = {
	["here"] = getheretarget,
	["there"] = gettheretarget
}

-- Return true if the unit is prevented from entering that tile by a "not here" or "not there" rule.
local function neitherherenorthere(unitid,x,y)
	local unit = mmf.newObject(unitid)

	for rulename,targetfunction in pairs(lookup) do
		local rules = featureindex["not " .. rulename]

		if rules ~= nil then
			for _,rule in ipairs(rules) do
				local baserule = rule[1]
				local conds = rule[2]
				local target = targetfunction(rule)

				if target ~= nil and x == target[1] and y == target[2] then
					if getname(unit) == baserule[1] and testcond(conds,unitid) then
						return true
					elseif baserule[1] == "group" and hasfeature(getname(unit),"is","group",unitid) and testcond(conds,unitid) then
						-- Group needs a special case here. The featureindex does include additional entries for
						-- each type of thing in the group, but the word IDs do not include the "here" rule, so getheretarget doesn't work for those.
						return true
					end
				end
			end
		end
	end
	return false
end

-- Apply all IS HERE and IS THERE rules.
local function applyheresandtheres()
	for rulename,targetfunction in pairs(lookup) do
		local rules = featureindex[rulename]
		if rules ~= nil then
			for _,rule in ipairs(rules) do
				local baserule = rule[1]
				if baserule[2] == "is" then
					local conds = rule[2]
					local target = targetfunction(rule)

					if target ~= nil then
						local targetx,targety = target[1],target[2]
						local applied = false

						if baserule[1] == "group" then
							-- Group needs a special case here. The featureindex does include additional entries for
							-- each type of thing in the group, but the word IDs do not include the "here" rule, so getheretarget/gettheretarget doesn't work for those.
							for _,selector in ipairs(findgroup()) do
								for _,unitid in ipairs(findall(selector)) do
									if testcond(conds,unitid) then
										local unit = mmf.newObject(unitid)
										if unit.values[XPOS] ~= targetx or unit.values[YPOS] ~= targety then
											addaction(unitid,{"update",targetx,targety,unit.values[DIR]})
											applied = true
										end
									end
								end
							end
						else
							for _,unitid in ipairs(findall({baserule[1], conds})) do
								local unit = mmf.newObject(unitid)
								if unit.values[XPOS] ~= targetx or unit.values[YPOS] ~= targety then
									addaction(unitid,{"update",targetx,targety,unit.values[DIR]})
									applied = true
								end
							end
						end

						if applied then
							local pmult,sound = checkeffecthistory("here")
							MF_particles("glow",targetx,targety,5 * pmult,1,4,1,1)
							setsoundname("turn",6,sound)
						end
					end
				end
			end
		end
	end
end

-- Hook "update", found in tools.lua
local vanillaupdate = update
local function myupdate(unitid,x,y,dir_)
	local unit = mmf.newObject(unitid)
	local name = getname(unit)
	local dir = dir_

	-- In vanilla Baba, the right/up/left/down rules only apply once,
	-- fairly late in the turn. This means that if, say, rock is push and left,
	-- and you push it up, it will still be facing up for a while before it points
	-- left again. With THOSE and "text is right/up/left/down", this causes unpredictable
	-- behaviour, so we fix this issue here by preventing all other direction changes when these rules apply.
	if hasfeature(name,"is","down",unitid) then
		dir = 3
	elseif hasfeature(name,"is","left",unitid) then
		dir = 2
	elseif hasfeature(name,"is","up",unitid) then
		dir = 1
	elseif hasfeature(name,"is","right",unitid) then
		dir = 0
	end

	-- In "check" we prevent regular movement from moving the unit onto "not here" tiles.
	-- But there are some special kinds of movement as well, like TELE. Prevent those.
	if neitherherenorthere(unitid,x,y) then
		vanillaupdate(unitid,unit.values[XPOS],unit.values[YPOS],dir)
	else
		vanillaupdate(unitid,x,y,dir)
	end
end

-- Hook "check" from movement.lua. Here we make the "not here" tiles act like
-- solid walls, so e.g. attempts to PUSH something onto a not-here tile will stop you
-- from moving too, MOVE objects will turn around and so on.
local vanillacheck = check
local function mycheck(unitid,x,y,dir,pulling,reason)
	result,results,specials = vanillacheck(unitid,x,y,dir,pulling,reason)

	local ndir = ndirs[dir + 1]
	local ox,oy = ndir[1],ndir[2]

	if neitherherenorthere(unitid, x + ox, y + oy) then
		table.insert(result, -1)
		table.insert(results, -1)
	end

	return result,results,specials
end

-- Hook "moveblock" from blocks.lua.
local vanillamoveblock = moveblock
local function mymoveblock()
	vanillamoveblock()
	applyheresandtheres()
	doupdate()
end

-- Hook "movecommand" from movement.lua
local vanillamovecommand = movecommand
local function mymovecommand(ox,oy,dir,playerid)
	vanillamovecommand(ox,oy,dir,playerid)

	-- Without this, there is an awkward bug where visual effects from rules
	-- are sometimes not correctly updated when the facing direction of THOSE rules
	-- is changed during a turn, especially by "text is left/right/etc".
	-- Adding an extra call to statusblock() at the end of the turn fixes the
	-- issue. Best as I can tell, statusblock() just updates things which should
	-- be set continuously anyway, so it /shouldn't/ cause any issues.
	statusblock()
end

function mod.load(dir)
	-- Patch conditions.lua to add the THOSE condition.
	loadscript(dir .. "conditions")

	-- Patch rules.lua to add the unitid of condition words to the condition structure.
	-- So instead of e.g. {"lonely", {}} we have {"lonely", {}, unitid_of_text_lonely}. THOSE needs this.
	loadscript(dir .. "rules")

	mod.inspect = loadscript(dir .. "inspect")

	update = myupdate
	check = mycheck
	moveblock = mymoveblock
	movecommand = mymovecommand

	tileslist.object120 = {
		name = "text_those",
		sprite = "text_those",
		sprite_in_root = false,
		unittype = "text",
		tiling = 2,
		type = 3,
		operatortype = "cond_start",
		colour = {3, 2},
		active = {3, 3},
		tile = {0, 12},
		grid = {11, 0},
		layer = 20,
	}

	tileslist.object121 = {
		name = "text_here",
		sprite = "text_here",
		sprite_in_root = false,
		unittype = "text",
		tiling = 2,
		type = 2,
		colour = {3, 2},
		active = {3, 3},
		tile = {1, 12},
		grid = {11, 1},
		layer = 20,
	}

	tileslist.object122 = {
		name = "text_there",
		sprite = "text_there",
		sprite_in_root = false,
		unittype = "text",
		tiling = 2,
		type = 2,
		colour = {1, 2},
		active = {1, 4},
		tile = {2, 12},
		grid = {11, 2},
		layer = 20,
	}
end

function mod.unload(dir)
	loadscript("Data/values")
	loadscript("Data/conditions")
	loadscript("Data/rules")

	update = vanillaupdate
	check = vanillacheck
	moveblock = vanillamoveblock
	movecommand = vanillamovecommand
end

return mod
