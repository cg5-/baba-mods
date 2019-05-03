
-- Stop counting earlier than normal if we reach maxhits or maxmisses.
local function countwithconds(noun, conds, maxhits, maxmisses)
	local tries = 0
	local hits = 0

	local function tryunit(unitid)
		tries = tries + 1
		if testcond(conds, unitid) then
			hits = hits + 1
		end
		-- Return true if we should stop now.
		return (maxhits ~= nil and hits >= maxhits) or (maxmisses ~= nil and tries - hits >= maxmisses)		
	end

	local notnoun = false
	local prefix = string.sub(noun, 1, 3)
	if prefix == "not" then
		notnoun = true
		noun = string.sub(noun, 5)
	end
	if notnoun then
		if noun == "all" then
			-- not all = all \ all = empty set
			return 0, 0
		end
		-- We don't support "not group" here, but neither does vanilla, so we have an excuse :upside-down:
		for name, unitids in pairs(unitlists) do
			if name ~= noun and name ~= "text" then
				for _, unitid in ipairs(unitids) do
					if tryunit(unitid) then
						return tries, hits
					end
				end
			end
		end
	elseif noun == "all" then
		for name, unitids in pairs(unitlists) do
			for _, unitid in ipairs(unitids) do
				if tryunit(unitid) then
					return tries, hits
				end
			end
		end
	elseif noun == "group" then
		local groupfeatures = featureindex["group"]
		local alreadychecked = {}
		if groupfeatures ~= nil then
			for _, feature in ipairs(groupfeatures) do
				local groupnoun = feature[1][1]
				if alreadychecked[groupnoun] == nil then
					alreadychecked[groupnoun] = 1

					local checklist = unitlists[groupnoun]

					if checklist ~= nil then
						for _, unitid in ipairs(checklist) do
							if activemod.safehasfeature(unitid, "is", "group") then
								if tryunit(unitid) then
									return tries, hits
								end
							end
						end
					end
				end
			end
		end
	else
		local checklist = unitlists[noun]
		if checklist ~= nil then
			for _, unitid in ipairs(checklist) do
				if tryunit(unitid) then
					return tries, hits
				end
			end
		end
	end

	return tries, hits
end

function testcond(conds,unitid,x_,y_)
	local result = true
	
	local x,y,name,dir = 0,0,"",4
	local surrounds = {}
	
	-- 0 = bug, 1 = level, 2 = empty
	
	if (unitid ~= 2) and (unitid ~= 0) and (unitid ~= 1) then
		local unit = mmf.newObject(unitid)
		x = unit.values[XPOS]
		y = unit.values[YPOS]
		name = unit.strings[UNITNAME]
		dir = unit.values[DIR]
		
		if (unit.strings[UNITTYPE] == "text") then
			name = "text"
		end
	elseif (unitid == 2) then
		x = x_
		y = y_
		name = "empty"
	elseif (unitid == 1) then
		name = "level"
		surrounds = parsesurrounds()
		dir = tonumber(surrounds.dir)
	end
	
	if (unitid == 0) then
		print("WARNING!! Unitid is zero!!")
	end
	
	if (conds ~= nil) then
		if (#conds > 0) then
			local valid = false
			
			for i,cond in ipairs(conds) do
				local condtype = cond[1]
				local params = cond[2]
				
				local extras = {}

				local isnot = string.sub(condtype, 1, 3)
				local basecondtype = condtype
				
				if (isnot == "not") then
					basecondtype = string.sub(condtype, 5)
				else
					basecondtype = condtype
				end

				if (condtype ~= "never" and basecondtype ~= "if" and basecondtype ~= "cg5with") then
					local conddata = conditions[basecondtype]
					if (conddata.argextra ~= nil) then
						extras = conddata.argextra
					end
				end
				
				if (condtype == "never") then
					result = false
					valid = true
				elseif (condtype == "on") then
					valid = true
					local allfound = 0
					local alreadyfound = {}
					
					local tileid = x + y * roomsizex
					
					if (#params > 0) then
						for a,b in ipairs(params) do
							if (unitid ~= 1) then
								if (b ~= "empty") and (b ~= "level") then
									if (unitmap[tileid] ~= nil) then
										for c,d in ipairs(unitmap[tileid]) do
											if (d ~= unitid) then
												local unit = mmf.newObject(d)
												local name_ = getname(unit)
												
												if (name_ == b) and (alreadyfound[b] == nil) then
													alreadyfound[b] = 1
													allfound = allfound + 1
												end
											end
										end
									else
										print("unitmap is nil at " .. tostring(x) .. ", " .. tostring(y) .. " for object " .. unit.strings[UNITNAME] .. " (" .. tostring(unitid) .. ")!")
									end
								elseif (b == "empty") then
									result = false
								elseif (b == "level") then
									alreadyfound[b] = 1
									allfound = allfound + 1
								end
							else
								local ulist = false
								
								if (b ~= "empty") and (b ~= "level") then
									if (unitlists[b] ~= nil) then
										if (#unitlists[b] > 0) then
											ulist = true
										end
									end
								elseif (b == "empty") then
									local empties = findempty()
									
									if (#findempty > 0) then
										ulist = true
									end
								end
								
								if (b ~= "text") and (ulist == false) then
									if (surrounds["o"] ~= nil) then
										for c,d in ipairs(surrounds["o"]) do
											if (d == b) then
												ulist = true
											end
										end
									end
								end
								
								if ulist or (b == "text") then
									if (alreadyfound[b] == nil) then
										alreadyfound[b] = 1
										allfound = allfound + 1
									end
								end
							end
						end
					else
						print("no parameters given!")
					end
					
					--MF_alert(tostring(allfound) .. ", " .. tostring(#params) .. " for " .. name)
					
					if (allfound ~= #params) then
						result = false
					end
				elseif (condtype == "not on") then
					valid = true
					local tileid = x + y * roomsizex
					
					if (#params > 0) then
						for a,b in ipairs(params) do
							if (unitid ~= 1) then
								if (b ~= "empty") and (b ~= "level") then
									if (unitmap[tileid] ~= nil) then
										for c,d in ipairs(unitmap[tileid]) do
											if (d ~= unitid) then
												local unit = mmf.newObject(d)
												local name_ = getname(unit)
												
												if (name_ == b) then
													result = false
												end
											end
										end
									else
										print("unitmap is nil at " .. tostring(x) .. ", " .. tostring(y) .. "!")
									end
								elseif (b == "empty") then
									local onempty = false

									if (unitmap[tileid] == nil) or (#unitmap[tileid] == 0) then 
										onempty = true
									end
									
									if onempty then
										result = false
									end
								elseif (b == "level") then
									result = false
								end
							else
								if (b ~= "empty") and (b ~= "level") and (b ~= "text") then
									if (unitlists[b] ~= nil) then
										if (#unitlists[b] > 0) then
											result = false
										end
									end
								elseif (b == "empty") then
									local empties = findempty()
									
									if (#findempty > 0) then
										result = false
									end
								elseif (b == "text") then
									result = false
								end
								
								if result then
									if (surrounds["o"] ~= nil) then
										for c,d in ipairs(surrounds["o"]) do
											if (d == b) then
												result = false
											end
										end
									end
								end
							end
						end
					else
						print("no parameters given!")
					end
				elseif (condtype == "facing") then
					valid = true
					local allfound = 0
					local alreadyfound = {}
					
					local ndrs = ndirs[dir+1]
					local ox = ndrs[1]
					local oy = ndrs[2]
					
					local tileid = (x + ox) + (y + oy) * roomsizex
					
					if (#params > 0) then
						if (name ~= "empty") then
							for a,b in ipairs(params) do
								if (unitid ~= 1) then
									if (b ~= "empty") and (b ~= "level") then
										if (stringintable(b,extras) == false) then
											if (unitmap[tileid] ~= nil) then
												for c,d in ipairs(unitmap[tileid]) do
													if (d ~= unitid) then
														local unit = mmf.newObject(d)
														local name_ = getname(unit)
														
														if (name_ == b) and (alreadyfound[b] == nil) then
															alreadyfound[b] = 1
															allfound = allfound + 1
														end
													end
												end
											end
										else
											if ((b == "right") and (dir == 0)) or ((b == "up") and (dir == 1)) or ((b == "left") and (dir == 2)) or ((b == "down") and (dir == 3)) then
												alreadyfound[b] = 1
												allfound = allfound + 1
											end
										end
									elseif (b == "empty") then
										if (unitmap[tileid] == nil) or (#unitmap[tileid] == 0) then
											if (alreadyfound[b] == nil) then
												alreadyfound[b] = 1
												allfound = allfound + 1
											end
										end
									elseif (b == "level") then
										alreadyfound[b] = 1
										allfound = allfound + 1
									end
								else
									local dirids = {"r","u","l","d"}
									local dirid = dirids[dir + 1]
									
									if (surrounds[dirid] ~= nil) then
										for c,d in ipairs(surrounds[dirid]) do
											if (d == b) and (alreadyfound[b] == nil) then
												alreadyfound[b] = 1
												allfound = allfound + 1
											end
										end
									end
								end
							end
						else
							result = false
						end
					else
						print("no parameters given!")
					end
					
					if (allfound ~= #params) then
						result = false
					end
				elseif (condtype == "not facing") then
					valid = true

					local ndrs = ndirs[dir+1]
					local ox = ndrs[1]
					local oy = ndrs[2]
					
					local tileid = (x + ox) + (y + oy) * roomsizex
					
					if (#params > 0) then
						if (name ~= "empty") then
							for a,b in ipairs(params) do
								if (unitid ~= 1) then
									if (b ~= "empty") and (b ~= "level") then
										if (stringintable(b, extras) == false) then
											if (unitmap[tileid] ~= nil) then
												for c,d in ipairs(unitmap[tileid]) do
													if (d ~= unitid) then
														local unit = mmf.newObject(d)
														local name_ = getname(unit)
														
														if (name_ == b) then
															result = false
														end
													end
												end
											end
										else
											if ((b == "right") and (dir == 0)) or ((b == "up") and (dir == 1)) or ((b == "left") and (dir == 2)) or ((b == "down") and (dir == 3)) then
												result = false
											end
										end
									elseif (b == "empty") then
										if (unitmap[tileid] == nil) or (#unitmap[tileid] == 0) then
											result = false
										end
									elseif (b == "level") then
										result = false
									end
								else
									local dirids = {"r","u","l","d"}
									local dirid = dirids[dir + 1]
									
									if (surrounds[dirid] ~= nil) then
										for c,d in ipairs(surrounds[dirid]) do
											if (d == b) and (alreadyfound[b] == nil) then
												result = false
											end
										end
									end
								end
							end
						elseif (name == "empty") then
							result = false
						end
					else
						print("no parameters given!")
					end
				elseif (condtype == "near") then
					valid = true
					local allfound = 0
					local alreadyfound = {}
					
					if (#params > 0) then
						for a,b in ipairs(params) do
							if (unitid ~= 1) then
								if (b ~= "level") then
									for g=-1,1 do
										for h=-1,1 do
											if (b ~= "empty") then
												local tileid = (x + g) + (y + h) * roomsizex
												if (unitmap[tileid] ~= nil) then
													for c,d in ipairs(unitmap[tileid]) do
														if (d ~= unitid) then
															local unit = mmf.newObject(d)
															local name_ = getname(unit)
															
															if (name_ == b) and (alreadyfound[b] == nil) then
																alreadyfound[b] = 1
																allfound = allfound + 1
															end
														end
													end
												end
											else
												local nearempty = false
										
												local tileid = (x + g) + (y + h) * roomsizex
												if (unitmap[tileid] == nil) or (#unitmap[tileid] == 0) then 
													nearempty = true
												end
												
												if nearempty and (alreadyfound[b] == nil) then
													alreadyfound[b] = 1
													allfound = allfound + 1
												end
											end
										end
									end
								elseif (b == "level") then
									alreadyfound[b] = 1
									allfound = allfound + 1
								end
							else
								local ulist = false
							
								if (b ~= "empty") and (b ~= "level") then
									if (unitlists[b] ~= nil) then
										if (#unitlists[b] > 0) then
											ulist = true
										end
									end
								elseif (b == "empty") then
									local empties = findempty()
									
									if (#findempty > 0) then
										ulist = true
									end
								end
								
								if (b ~= "text") and (ulist == false) then
									for e,f in pairs(surrounds) do
										if (e ~= "dir") then
											for c,d in ipairs(f) do
												if (ulist == false) and (d == b) then
													ulist = true
												end
											end
										end
									end
								end
								
								if ulist or (b == "text") then
									if (alreadyfound[b] == nil) then
										alreadyfound[b] = 1
										allfound = allfound + 1
									end
								end
							end
						end
					else
						print("no parameters given!")
					end

					if (allfound ~= #params) then
						result = false
					end
				elseif (condtype == "not near") then
					valid = true
					
					if (#params > 0) then
						for a,b in ipairs(params) do
							if (unitid ~= 1) then
								if (b ~= "level") then
									for g=-1,1 do
										for h=-1,1 do
											if (b ~= "empty") then
												local tileid = (x + g) + (y + h) * roomsizex
												if (unitmap[tileid] ~= nil) then
													for c,d in ipairs(unitmap[tileid]) do
														local unit = mmf.newObject(d)
														local name_ = getname(unit)
														
														if (name_ == b) then
															result = false
														end
													end
												end
											else
												local nearempty = false
										
												local tileid = (x + g) + (y + h) * roomsizex
												if (unitmap[tileid] == nil) or (#unitmap[tileid] == 0) then 
													nearempty = true
												end
												
												if nearempty then
													result = false
												end
											end
										end
									end
								else
									result = false
								end
							else
								local ulist = false
							
								if (b ~= "empty") and (b ~= "level") and (b ~= "text") then
									if (unitlists[b] ~= nil) then
										if (#unitlists[b] > 0) then
											result = false
										end
									end
								elseif (b == "empty") then
									local empties = findempty()
									
									if (#findempty > 0) then
										result = false
									end
								elseif (b == "text") then
									result = false
								end
								
								if (b ~= "text") and result then
									for e,f in pairs(surrounds) do
										if (e ~= "dir") then
											for c,d in ipairs(f) do
												if result and (d == b) then
													result = false
												end
											end
										end
									end
								end
							end
						end
					else
						print("no parameters given!")
					end
				elseif (condtype == "lonely") then
					valid = true
					
					if (unitid ~= 1) then
						local tileid = x + y * roomsizex
						if (unitmap[tileid] ~= nil) then
							for c,d in ipairs(unitmap[tileid]) do
								if (d ~= unitid) then
									result = false
								end
							end
						end
					else
						result = false
					end
				elseif (condtype == "not lonely") then
					valid = true
					
					if (unitid ~= 1) then
						local tileid = x + y * roomsizex
						if (unitmap[tileid] ~= nil) then
							if (#unitmap[tileid] == 1) then
								result = false
							end
						end
					else
						if (surrounds["o"] ~= nil) then
							if (#surrounds["o"] > 0) then
								result = false
							end
						end
					end
				elseif basecondtype == "cg5with" then
					valid = true
					local ourresult = true

					for _,object in ipairs(params) do
						if not activemod.safehasfeature(unitid, "is", object) then
							ourresult = false
							break
						end
					end

					if condtype == "not cg5with" then
						ourresult = not ourresult
					end
					result = result and ourresult
				elseif basecondtype == "if" then
					valid = true
					local ourresult = true

					for _,ifcond in ipairs(params) do
						local quantifier, noun, innerconds = ifcond[1], ifcond[2], ifcond[3]

						local notquantifier = false
						local quantifierprefix = string.sub(quantifier, 1, 3)
						if quantifierprefix == "not" then
							notquantifier = true
							quantifier = string.sub(quantifier, 5)
						end

						local numquantifier = tonumber(quantifier)

						local thisresult = false
						if quantifier == "all" then
							local tries, hits = countwithconds(noun, innerconds, nil, 1)
							thisresult = (tries == hits)
						elseif numquantifier ~= nil then
							local tries, hits = countwithconds(noun, innerconds, numquantifier + 1, nil)
							thisresult = (hits == numquantifier)
						else
							local tries, hits = countwithconds(noun, innerconds, 1, nil)
							thisresult = (hits >= 1)
						end

						if notquantifier == thisresult then
							ourresult = false
							break
						end
					end

					if condtype == "not if" then
						ourresult = not ourresult
					end
					result = result and ourresult
				end
			end
			
			if (valid == false) then
				print("invalid condition: " .. condtype)
				result = true
			end
		end
	end
	
	return result
end