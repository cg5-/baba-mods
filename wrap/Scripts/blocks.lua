
local function vanillafallblock(things)
	local checks = {}
	
	if (things == nil) then
		local isfall = findallfeature(nil,"is","fall",true)

		for a,unitid in ipairs(isfall) do
			table.insert(checks, unitid)
		end
	else
		for a,unitid in ipairs(things) do
			table.insert(checks, unitid)
		end
	end
	
	local done = false
	
	while (done == false) do
		local settled = true
		
		if (#checks > 0) then
			for a,unitid in pairs(checks) do
				local unit = mmf.newObject(unitid)
				local x,y,dir = unit.values[XPOS],unit.values[YPOS],unit.values[DIR]
				local name = getname(unit)
				local onground = false
				
				while (onground == false) do
					local below,below_,specials = check(unitid,x,y,3,false,"fall")
					
					local result = 0
					for c,d in pairs(below) do
						if (d ~= 0) then
							result = 1
						else
							if (below_[c] ~= 0) and (result ~= 1) then
								if (result ~= 0) then
									result = 2
								else
									for e,f in ipairs(specials) do
										if (f[1] == below_[c]) then
											result = 2
										end
									end
								end
							end
						end
						
						--MF_alert(tostring(y) .. " -- " .. tostring(d) .. " (" .. tostring(below_[c]) .. ")")
					end
					
					--MF_alert(tostring(y) .. " -- result: " .. tostring(result))
					
					if (result ~= 1) then
						local gone = false
						
						if (result == 0) then
							update(unitid,x,y+1)
						elseif (result == 2) then
							gone = move(unitid,0,1,dir,specials,true,true)
						end
						
						-- Poista tästä kommenttimerkit jos haluat, että fall tsekkaa juttuja per pudottu tile
						if (gone == false) then
							y = y + 1
							--block({unitid},true)
							settled = false
							
							if unit.flags[DEAD] then
								onground = true
								table.remove(checks, a)
							else
								--[[
								local stillgoing = hasfeature(name,"is","fall",unitid,x,y)
								if (stillgoing == nil) then
									onground = true
									table.remove(checks, a)
								end
								]]--
							end
						else
							onground = true
							settled = true
						end
					else
						onground = true
					end
				end
			end
			
			if settled then
				done = true
			end
		else
			done = true
		end
	end
end


function fallblock(things)
	-- Just in case my modified version of fallblock behaves differently in some cases,
	-- use the vanilla implementation if the modified one isn't necessary.
	if featureindex["wrap"] == nil and featureindex["portal"] == nil then
		return vanillafallblock(things)
	end

	local checks = {}
	
	if (things == nil) then
		local isfall = findallfeature(nil,"is","fall",true)

		for a,unitid in ipairs(isfall) do
			table.insert(checks, unitid)
		end
	else
		for a,unitid in ipairs(things) do
			table.insert(checks, unitid)
		end
	end
	
	local unitwarps = {}
	local settled = false

	while not settled do
		settled = true
		for a,unitid in pairs(checks) do
			local unit = mmf.newObject(unitid)
			if unit ~= nil then
				local x,y = unit.values[XPOS],unit.values[YPOS]
				local name = getname(unit)
				local donewiththisunit = false
				local falldir = 3
				local warps = unitwarps[a]
				if warps == nil then
					warps = {}
					unitwarps[a] = warps
				end
				
				while not donewiththisunit do
					local below,below_,specials = check(unitid,x,y,falldir,false,"fall")
					
					local result = 0
					for c,d in pairs(below) do
						if (d ~= 0) then
							result = 1
						else
							if (below_[c] ~= 0) and (result ~= 1) then
								if (result ~= 0) then
									result = 2
								else
									for e,f in ipairs(specials) do
										if (f[1] == below_[c]) then
											result = 2
										end
									end
								end
							end
						end
					end
					
					if result == 1 then
						if falldir == 0 or falldir == 2 then
							-- We hit the wall while being flung sideways, now we fall back down again.
							falldir = 3
						else
							donewiththisunit = true
						end
					else
						local rx, ry, rdir, newwarps = activemod.getadjacenttile(unitid, x, y, falldir)

						-- Don't follow the same warp more than once (infinite loop protection)
						for _, warp in ipairs(newwarps) do
							for _, otherwarp in ipairs(warps) do
								if warp[1] == otherwarp[1] and warp[2] == otherwarp[2] then
									donewiththisunit = true
									break
								end
							end

							if donewiththisunit then
								break
							else
								table.insert(warps, warp)
							end
						end

						if not donewiththisunit then
							activemod.warpedidchanges = {}
							gone = move(unitid,falldir,specials,false,false,true)
							if #activemod.warpedidchanges > 0 and activemod.warpedidchanges[1][1] == unitid then
								unitid = activemod.warpedidchanges[1][2]
								checks[a] = unitid
								unit = mmf.newObject(unitid)
							end
							doupdate()

							if gone then
								donewiththisunit = true
							else
								settled = false
								x, y, falldir = rx, ry, rdir
								
								if unit.flags[DEAD] then
									donewiththisunit = true
								end
							end
						end
					end
				end
			end
		end
	end
end