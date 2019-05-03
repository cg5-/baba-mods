
local function tileissolid(tileid)
	local unitids = unitmap[tileid]
	if unitids ~= nil then
		for _, unitid in ipairs(unitids) do
			local name = getname(mmf.newObject(unitid))
			if hasfeature(name, "is", "stop", unitid) or hasfeature(name, "is", "push", unitid) or hasfeature(name, "is", "pull", unitid) then
				return true
			end
		end
	end
	return false
end

local function lowestmanhattandistance(x, y, targets)
	local result = 9999
	for _, target in ipairs(targets) do
		local d = math.abs(x - target[1]) + math.abs(y - target[2])
		if d < result then
			result = d
		end
	end
	return result
end

local function dopathfind(x, y, initialdir, targets, targettileids)
	if #targets == 0 then
		return -2
	end

	local tileid = y * roomsizex + x

	-- https://en.wikipedia.org/wiki/A*_search_algorithm
	local closedset = {}
	local camefrom = {}
	local openset = {[tileid] = 1}
	local gscore = {[tileid] = 0}
	local fscore = {[tileid] = lowestmanhattandistance(x, y, targets)}

	local firststep = true
	local solidcache = {}

	while next(openset) ~= nil do -- i.e. openset is not empty
		local currenttileid = nil
		local currentfscore = 9999
		for tileid, _ in pairs(openset) do
			if fscore[tileid] < currentfscore then
				currenttileid = tileid
				currentfscore = fscore[tileid]
			end
		end

		if targettileids[currenttileid] ~= nil then
			local lastdir = -1
			while camefrom[currenttileid] ~= nil do
				local cf = camefrom[currenttileid]
				currenttileid, lastdir = cf[1], cf[2]
			end
			return lastdir
		end

		openset[currenttileid] = nil
		closedset[currenttileid] = 1

		x, y = currenttileid % roomsizex, math.floor(currenttileid / roomsizex)

		for dir = 0, 3 do
			local ndrs = ndirs[dir + 1]
			local nx, ny = x + ndrs[1], y + ndrs[2]
			local ntileid = ny * roomsizex + nx
			if closedset[ntileid] == nil and nx >= 1 and nx <= roomsizex - 2 and ny >= 1 and ny <= roomsizey - 2 then
				local issolid = solidcache[ntileid]
				if issolid == nil then
					issolid = tileissolid(ntileid)
					solidcache[ntileid] = issolid
				end

				if not issolid then
					tentativegscore = gscore[currenttileid] + 1
					if firststep and dir ~= initialdir then
						-- Slightly prefer not to change direction on the first step
						tentativegscore = tentativegscore + 0.5
					end
					local skip = false
					if openset[ntileid] == nil then
						openset[ntileid] = 1
					elseif gscore[ntileid] ~= nil and tentativegscore >= gscore[ntileid] then
						skip = true
					end

					if not skip then
						camefrom[ntileid] = {currenttileid, dir}
						gscore[ntileid] = tentativegscore
						fscore[ntileid] = tentativegscore + lowestmanhattandistance(nx, ny, targets)
					end
				end
			end
		end

		firststep = false
	end

	return -2
end

local function trybreakrule(unitids, targets, targettileids)
	for _, unitidlist in ipairs(unitids) do
		for _, unitid in ipairs(unitidlist) do
			local unit = mmf.newObject(unitid)
			local x, y = unit.values[XPOS], unit.values[YPOS]

			if x - 1 >= 1 and x + 1 <= roomsizex - 2 and not tileissolid(y * roomsizex + x - 1) and not tileissolid(y * roomsizex + x + 1) then
				-- Can break the rule by pushing horizontally
				table.insert(targets, {x - 1, y})
				targettileids[y * roomsizex + x - 1] = 0
				table.insert(targets, {x + 1, y})
				targettileids[y * roomsizex + x + 1] = 2
			end

			if y - 1 >= 1 and y + 1 <= roomsizey - 2 and not tileissolid((y - 1) * roomsizex + x) and not tileissolid((y + 1) * roomsizex + x) then
				-- Can break the rule by pushing vertically
				table.insert(targets, {x, y - 1})
				targettileids[(y - 1) * roomsizex + x] = 3
				table.insert(targets, {x, y + 1})
				targettileids[(y + 1) * roomsizex + x] = 1
			end
		end
	end
end

local function performfind(unitid, findees)
	local unit = mmf.newObject(unitid)
	local x, y, initialdir = unit.values[XPOS], unit.values[YPOS], unit.values[DIR]
	local tileid = y * roomsizex + x

	local alreadyhandled = {}
	local targets = {}
	local targettileids = {}
	for _, findee in ipairs(findees) do
		if alreadyhandled[findee] == nil then
			alreadyhandled[findee] = 1
			for _, funitid in ipairs(findall({findee, {}})) do
				if funitid ~= unitid then
					local funit = mmf.newObject(funitid)
					local fname = getname(funit)
					local fx, fy = funit.values[XPOS], funit.values[YPOS]
					local ftileid = fy * roomsizex + fx
					if not tileissolid(ftileid) then
						table.insert(targets, {fx, fy})
						targettileids[ftileid] = 1
					end
				end
			end
		end
	end
	return dopathfind(x, y, initialdir, targets, targettileids)
end

function movecommand(ox,oy,dir_,playerid_)
	statusblock()
	movelist = {}
	
	local take = 1
	local takecount = 5
	local finaltake = false
	
	local still_moving = {}
	
	local levelpush = -1
	local levelpull = -1
	local levelmove = findfeature("level","is","you")
	if (levelmove ~= nil) then
		local ndrs = ndirs[dir_ + 1]
		local ox,oy = ndrs[1],ndrs[2]
		
		addundo({"levelupdate",Xoffset,Yoffset,Xoffset + ox * tilesize,Yoffset + oy * tilesize,mapdir,dir_})
		MF_scrollroom(ox * tilesize,oy * tilesize)
		mapdir = dir_
		updateundo = true
	end
	
	while (take <= takecount) or finaltake do
		local moving_units = {}
		local been_seen = {}
		
		if (finaltake == false) then
			if (dir_ ~= 4) and (take == 1) then
				local players = {}
				local empty = {}
				local playerid = 1
				
				if (playerid_ ~= nil) then
					playerid = playerid_
				end
				
				if (playerid == 1) then
					players,empty = findallfeature(nil,"is","you")
				elseif (playerid == 2) then
					players,empty = findallfeature(nil,"is","you2")
					
					if (#players == 0) then
						players,empty = findallfeature(nil,"is","you")
					end
				end
				
				for i,v in ipairs(players) do
					local sleeping = false
					
					if (v ~= 2) then
						local unit = mmf.newObject(v)
						
						local unitname = getname(unit)
						local sleep = hasfeature(unitname,"is","sleep",v)
						
						if (sleep ~= nil) then
							sleeping = true
						else
							updatedir(v, dir_)
						end
					else
						local thisempty = empty[i]
						
						for a,b in pairs(thisempty) do
							local x = a % roomsizex
							local y = math.floor(a / roomsizex)
							
							local sleep = hasfeature("empty","is","sleep",2,x,y)
							
							if (sleep ~= nil) then
								thisempty[a] = nil
							end
						end
					end
					
					if (sleeping == false) then
						if (been_seen[v] == nil) then
							local x,y = -1,-1
							if (v ~= 2) then
								local unit = mmf.newObject(v)
								x,y = unit.values[XPOS],unit.values[YPOS]
								
								table.insert(moving_units, {unitid = v, reason = "you", state = 0, moves = 1, dir = dir_, xpos = x, ypos = y})
								been_seen[v] = #moving_units
							else
								local thisempty = empty[i]
								
								for a,b in pairs(thisempty) do
									x = a % roomsizex
									y = math.floor(a / roomsizex)
								
									table.insert(moving_units, {unitid = 2, reason = "you", state = 0, moves = 1, dir = dir_, xpos = x, ypos = y})
									been_seen[v] = #moving_units
								end
							end
						else
							local id = been_seen[v]
							local this = moving_units[id]
							--this.moves = this.moves + 1
						end
					end
				end
			end

			-- FIND
			if take == 2 then
				local findfeatures = featureindex["find"]
				if findfeatures ~= nil then
					local finders = {}
					for _, feature in ipairs(findfeatures) do
						local finder, findee, conds = feature[1][1], feature[1][3], feature[2]
						for _, unitid in ipairs(findall({finder, conds})) do
							if finders[unitid] == nil then
								finders[unitid] = {findee}
							else
								table.insert(finders[unitid], findee)
							end
						end
					end
					for unitid, findees in pairs(finders) do
						local finddir = performfind(unitid, findees)
						if finddir >= 0 then
							local unit = mmf.newObject(unitid)
							updatedir(unitid, finddir)
							table.insert(moving_units, {unitid = unitid, reason = "find", state = 0, moves = 1, dir = finddir, xpos = unit.values[XPOS], ypos = unit.values[YPOS]})
						end
					end
				end
			end
			-- END FIND
			
			-- EVIL/REPENT
			if take == 3 then
				local evils = findallfeature(nil, "is", "evil")
				if evils ~= nil and #evils > 0 then
					local youfeatures = featureindex["you"]
					local targets = {}
					local targettileids = {}
					if youfeatures ~= nil then
						for _, feature in ipairs(youfeatures) do
							if feature[1][2] == "is" and feature[1][3] == "you" then
								trybreakrule(feature[3], targets, targettileids)
							end
						end
					end

					for _, unitid in ipairs(evils) do
						local unit = mmf.newObject(unitid)
						local thesetargets = targets
						local thesetargettileids = targettileids
						local reason = "evil"
						if hasfeature(getname(unit), "is", "repent", unitid) then
							reason = "repent"
							local name = getname(unit)
							local evilfeatures = featureindex["evil"]
							thesetargets = {}
							thesetargettileids = {}
							if evilfeatures ~= nil then
								for _, feature in ipairs(evilfeatures) do
									if feature[1][1] == name and feature[1][2] == "is" and feature[1][3] == "evil" then
										trybreakrule(feature[3], targets, targettileids)
									end
								end
							end
						end

						local x, y, initialdir = unit.values[XPOS], unit.values[YPOS], unit.values[DIR]
						local tileid = y * roomsizex + x

						if targettileids[tileid] ~= nil then
							-- We're in position to do the evil push, now do it
							updatedir(unitid, targettileids[tileid])
							table.insert(moving_units, {unitid = unitid, reason = reason, state = 0, moves = 1, dir = targettileids[tileid], xpos = x, ypos = y})
						else
							-- We still need to get into position to make our evil push, so pathfind there
							local evildir = dopathfind(x, y, initialdir, targets, targettileids)
							if evildir >= 0 then
								updatedir(unitid, evildir)
								table.insert(moving_units, {unitid = unitid, reason = reason, state = 0, moves = 1, dir = evildir, xpos = x, ypos = y})	
							end
						end
					end
				end
			end
			-- END EVIL/REPENT

			if (take == 4) then
				local movers,mempty = findallfeature(nil,"is","move")
				moving_units,been_seen = add_moving_units("move",movers,moving_units,been_seen,mempty)
				
				local chillers,cempty = findallfeature(nil,"is","chill")
				moving_units,been_seen = add_moving_units("chill",chillers,moving_units,been_seen,cempty)
				
				local fears,empty = findallfeature(nil,"fear",nil)
				
				for i,v in ipairs(fears) do
					local valid,feardir = findfears(v)
					local sleeping = false
					
					if valid then
						if (v ~= 2) then
							local unit = mmf.newObject(v)
						
							local unitname = getname(unit)
							local sleep = hasfeature(unitname,"is","sleep",v)
							
							if (sleep ~= nil) then
								sleeping = true
							else
								updatedir(v, feardir)
							end
						else
							local thisempty = empty[i]
							
							for a,b in pairs(thisempty) do
								local x = a % roomsizex
								local y = math.floor(a / roomsizex)
								
								local sleep = hasfeature("empty","is","sleep",2,x,y)
								
								if (sleep ~= nil) then
									thisempty[a] = nil
								end
							end
						end
						
						if (sleeping == false) then
							if (been_seen[v] == nil) then
								local x,y = -1,-1
								if (v ~= 2) then
									local unit = mmf.newObject(v)
									x,y = unit.values[XPOS],unit.values[YPOS]
									
									table.insert(moving_units, {unitid = v, reason = "you", state = 0, moves = 1, dir = feardir, xpos = x, ypos = y})
									been_seen[v] = #moving_units
								else
									local thisempty = empty[i]
								
									for a,b in pairs(thisempty) do
										x = a % roomsizex
										y = math.floor(a / roomsizex)
									
										table.insert(moving_units, {unitid = 2, reason = "you", state = 0, moves = 1, dir = feardir, xpos = x, ypos = y})
										been_seen[v] = #moving_units
									end
								end
							else
								local id = been_seen[v]
								local this = moving_units[id]
								this.moves = this.moves + 1
							end
						end
					end
				end
			elseif (take == 5) then
				local shifts = findallfeature(nil,"is","shift",true)
				
				for i,v in ipairs(shifts) do
					if (v ~= 2) then
						local affected = {}
						local unit = mmf.newObject(v)
						
						local x,y = unit.values[XPOS],unit.values[YPOS]
						local tileid = x + y * roomsizex
						
						if (unitmap[tileid] ~= nil) then
							if (#unitmap[tileid] > 1) then
								for a,b in ipairs(unitmap[tileid]) do
									if (b ~= v) and floating(b,v) then
										local newunit = mmf.newObject(b)
										
										updatedir(b, unit.values[DIR])
										--newunit.values[DIR] = unit.values[DIR]
										
										if (been_seen[b] == nil) then
											table.insert(moving_units, {unitid = b, reason = "shift", state = 0, moves = 1, dir = unit.values[DIR], xpos = x, ypos = y})
											been_seen[b] = #moving_units
										else
											local id = been_seen[b]
											local this = moving_units[id]
											this.moves = this.moves + 1
										end
									end
								end
							end
						end
					end
				end
				
				local levelshift = findfeature("level","is","shift")
				
				if (levelshift ~= nil) then
					local leveldir = mapdir
						
					for a,unit in ipairs(units) do
						local x,y = unit.values[XPOS],unit.values[YPOS]
						
						if floating_level(unit.fixed) then
							updatedir(unit.fixed, leveldir)
							table.insert(moving_units, {unitid = unit.fixed, reason = "shift", state = 0, moves = 1, dir = unit.values[DIR], xpos = x, ypos = y})
						end
					end
				end
			end
		else
			for i,data in ipairs(still_moving) do
				if (data.unitid ~= 2) then
					local unit = mmf.newObject(data.unitid)
					
					table.insert(moving_units, {unitid = data.unitid, reason = data.reason, state = data.state, moves = data.moves, dir = unit.values[DIR], xpos = unit.values[XPOS], ypos = unit.values[YPOS]})
				else
					table.insert(moving_units, {unitid = data.unitid, reason = data.reason, state = data.state, moves = data.moves, dir = data.dir, xpos = -1, ypos = -1})
				end
			end
			
			still_moving = {}
		end
		
		local unitcount = #moving_units
			
		for i,data in ipairs(moving_units) do
			if (i <= unitcount) then
				if (data.unitid == 2) and (data.xpos == -1) and (data.ypos == -1) then
					local positions = getemptytiles()
					
					for a,b in ipairs(positions) do
						local x,y = b[1],b[2]
						table.insert(moving_units, {unitid = 2, reason = data.reason, state = data.state, moves = data.moves, dir = data.dir, xpos = x, ypos = y})
					end
				end
			else
				break
			end
		end
		
		local done = false
		local state = 0
		
		while (done == false) do
			local smallest_state = 99
			local delete_moving_units = {}
			
			for i,data in ipairs(moving_units) do
				local solved = false
				smallest_state = math.min(smallest_state,data.state)
				
				if (data.unitid == 0) then
					solved = true
				end
				
				if (data.state == state) and (data.moves > 0) and (data.unitid ~= 0) then
					local unit = {}
					local dir,name = 4,""
					local x,y = data.xpos,data.ypos
					
					if (data.unitid ~= 2) then
						unit = mmf.newObject(data.unitid)
						dir = unit.values[DIR]
						name = getname(unit)
						x,y = unit.values[XPOS],unit.values[YPOS]
					else
						dir = data.dir
						name = "empty"
					end
					
					if (x ~= -1) and (y ~= -1) then
						local result = -1
						solved = false
						
						if (state == 0) then
							if (data.reason == "chill") then
								dir = math.random(0,3)
								
								if (data.unitid ~= 2) then
									updatedir(data.unitid, dir)
									--unit.values[DIR] = dir
								end
							end
							
							if (data.reason == "move") and (data.unitid == 2) then
								dir = math.random(0,3)
							end
						elseif (state == 3) then
							if ((data.reason == "move") or (data.reason == "chill")) then
								dir = rotate(dir)
								
								if (data.unitid ~= 2) then
									updatedir(data.unitid, dir)
									--unit.values[DIR] = dir
								end
							end
						end
						
						local ndrs = ndirs[dir + 1]
						local ox,oy = ndrs[1],ndrs[2]
						local pushobslist = {}
						
						local obslist,allobs,specials = check(data.unitid,x,y,dir,false,data.reason)
						local pullobs,pullallobs,pullspecials = check(data.unitid,x,y,dir,true,data.reason)
						
						local swap = hasfeature(name,"is","swap",data.unitid,x,y)
						
						for c,obs in pairs(obslist) do
							if (solved == false) then
								if (obs == 0) then
									if (state == 0) then
										result = math.max(result, 0)
									else
										result = math.max(result, 0)
									end
								elseif (obs == -1) then
									result = math.max(result, 2)
									
									local levelpush_ = findfeature("level","is","push")
									
									if (levelpush_ ~= nil) then
										for e,f in ipairs(levelpush_) do
											if testcond(f[2],1) then
												levelpush = dir
											end
										end
									end
								else
									if (swap == nil) then
										if (#allobs == 0) then
											obs = 0
										end
										
										if (obs == 1) then
											local thisobs = allobs[c]
											local solid = true
											
											for f,g in pairs(specials) do
												if (g[1] == thisobs) and (g[2] == "weak") then
													solid = false
													obs = 0
													result = math.max(result, 0)
												end
											end
											
											if solid then
												if (state < 2) then
													data.state = math.max(data.state, 2)
													result = math.max(result, 2)
												else
													result = math.max(result, 2)
												end
											end
										else
											if (state < 1) then
												data.state = math.max(data.state, 1)
												result = math.max(result, 1)
											else
												table.insert(pushobslist, obs)
												result = math.max(result, 1)
											end
										end
									else
										result = math.max(result, 0)
									end
								end
							end
						end
						
						local result_check = false
						
						while (result_check == false) and (solved == false) do
							if (result == 0) then
								if (state > 0) then
									for j,jdata in pairs(moving_units) do
										if (jdata.state >= 2) then
											jdata.state = 0
										end
									end
								end
								
								table.insert(movelist, {data.unitid,ox,oy,dir,specials})
								--move(data.unitid,ox,oy,dir,specials)
								
								local swapped = {}
								
								if (swap ~= nil) then
									for a,b in ipairs(allobs) do
										if (b ~= -1) and (b ~= 2) and (b ~= 0) then
											addaction(b,{"update",x,y,nil})
											swapped[b] = 1
										end
									end
								end
								
								local swaps = findfeatureat(nil,"is","swap",x+ox,y+oy)
								if (swaps ~= nil) then
									for a,b in ipairs(swaps) do
										if (swapped[b] == nil) then
											addaction(b,{"update",x,y,nil})
										end
									end
								end
								
								local finalpullobs = {}
								
								for c,pobs in ipairs(pullobs) do
									if (pobs < -1) or (pobs > 1) then
										local paobs = pullallobs[c]
										
										local hm = trypush(paobs,ox,oy,dir,true,x,y,data.reason,data.unitid)
										if (hm == 0) then
											table.insert(finalpullobs, paobs)
										end
									elseif (pobs == -1) then
										local levelpull_ = findfeature("level","is","pull")
									
										if (levelpull_ ~= nil) then
											for e,f in ipairs(levelpull_) do
												if testcond(f[2],1) then
													levelpull = dir
												end
											end
										end
									end
								end
								
								for c,pobs in ipairs(finalpullobs) do
									pushedunits = {}
									dopush(pobs,ox,oy,dir,true,x,y,data.reason,data.unitid)
								end
								
								solved = true
							elseif (result == 1) then
								if (state < 1) then
									data.state = math.max(data.state, 1)
									result_check = true
								else
									local finalpushobs = {}
									
									for c,pushobs in ipairs(pushobslist) do
										local hm = trypush(pushobs,ox,oy,dir,false,x,y,data.reason)
										if (hm == 0) then
											table.insert(finalpushobs, pushobs)
										elseif (hm == 1) or (hm == -1) then
											result = math.max(result, 2)
										else
											MF_alert("HOO HAH")
											return
										end
									end
									
									if (result == 1) then
										for c,pushobs in ipairs(finalpushobs) do
											pushedunits = {}
											dopush(pushobs,ox,oy,dir,false,x,y,data.reason)
										end
										result = 0
									end
								end
							elseif (result == 2) then
								if (state < 2) then
									data.state = math.max(data.state, 2)
									result_check = true
								else
									if (state < 3) then
										data.state = math.max(data.state, 3)
										result_check = true
									else
										if ((data.reason == "move") or (data.reason == "chill")) and (state < 4) then
											data.state = math.max(data.state, 4)
											result_check = true
										else
											local weak = hasfeature(name,"is","weak",data.unitid,x,y)
											
											if (weak ~= nil) then
												delete(data.unitid,x,y)
												generaldata.values[SHAKE] = 3
												
												local pmult,sound = checkeffecthistory("weak")
												MF_particles("destroy",x,y,5 * pmult,0,3,1,1)
												setsoundname("removal",1,sound)
												data.moves = 1
											end
											solved = true
										end
									end
								end
							else
								result_check = true
							end
						end
					else
						solved = true
					end
				end
				
				if solved then
					data.moves = data.moves - 1
					data.state = 10
					
					local tunit = mmf.newObject(data.unitid)
					
					if (data.moves == 0) then
						--print(tunit.strings[UNITNAME] .. " - removed from queue")
						table.insert(delete_moving_units, i)
					else
						if (data.unitid ~= 2) or ((data.unitid == 2) and (data.xpos == -1) and (data.ypos == -1)) then
							table.insert(still_moving, {unitid = data.unitid, reason = data.reason, state = data.state, moves = data.moves, dir = data.dir, xpos = data.xpos, ypos = data.ypos})
						end
						--print(tunit.strings[UNITNAME] .. " - removed from queue")
						table.insert(delete_moving_units, i)
					end
				end
			end
			
			local deloffset = 0
			for i,v in ipairs(delete_moving_units) do
				local todel = v - deloffset
				table.remove(moving_units, todel)
				deloffset = deloffset + 1
			end
			
			if (#movelist > 0) then
				for i,data in ipairs(movelist) do
					move(data[1],data[2],data[3],data[4],data[5])
				end
			end
			
			movelist = {}
			
			if (smallest_state > state) then
				state = state + 1
			else
				state = smallest_state
			end
			
			if (#moving_units == 0) then
				doupdate()
				done = true
			end
		end

		if (#still_moving > 0) then
			finaltake = true
			moving_units = {}
		else
			finaltake = false
		end
		
		if (finaltake == false) then
			take = take + 1
		end
	end
	
	if (levelpush >= 0) then
		local ndrs = ndirs[levelpush + 1]
		local ox,oy = ndrs[1],ndrs[2]
		
		mapdir = levelpush
		
		addundo({"levelupdate",Xoffset,Yoffset,Xoffset + ox * tilesize,Yoffset + oy * tilesize,mapdir,levelpush})
		MF_scrollroom(ox * tilesize,oy * tilesize)
		updateundo = true
	end
	
	if (levelpull >= 0) then
		local ndrs = ndirs[levelpull + 1]
		local ox,oy = ndrs[1],ndrs[2]
		
		mapdir = levelpush
		
		addundo({"levelupdate",Xoffset,Yoffset,Xoffset + ox * tilesize,Yoffset + oy * tilesize,mapdir,levelpull})
		MF_scrollroom(ox * tilesize,oy * tilesize)
		updateundo = true
	end
	
	doupdate()
	code()
	conversion()
	doupdate()
	code()
	moveblock()
	
	if (dir_ ~= nil) then
		MF_mapcursor(ox,oy,dir_)
	end
end