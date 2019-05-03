function docode(firstwords)
	local donefirstwords = {}
	local limiter = 0
	
	if (#firstwords > 0) then
		for k,unitdata in ipairs(firstwords) do
			local unitid = unitdata[1]
			local dir = unitdata[2]
			
			local unit = mmf.newObject(unitid)
			local x,y = unit.values[XPOS],unit.values[YPOS]
			local tileid = x + y * roomsizex
			
			--MF_alert("Testing " .. unit.strings[UNITNAME] .. ": " .. tostring(donefirstwords[tileid]) .. ", " .. tostring(dir))
			limiter = limiter + 1
			
			if (limiter > 10000) then
				timedmessage("error - too complicated rules!")
			end
			
			if (donefirstwords[tileid] == nil) or ((donefirstwords[tileid] ~= nil) and (donefirstwords[tileid][dir] == nil)) and (limiter < 10000) then
				local ox,oy = 0,0
				local name = unit.strings[NAME]
				
				local drs = dirs[dir]
				ox = drs[1]
				oy = drs[2]
				
				if (donefirstwords[tileid] == nil) then
					donefirstwords[tileid] = {}
				end
				
				donefirstwords[tileid][dir] = 1
				
				local variations = 1
				local done = false
				local sentences = {}
				local variantcount = {}
				local combo = {}
				
				local finals = {}
				
				local steps = 0
				
				while (done == false) do
					local words = codecheck(unitdata[1],ox*steps,oy*steps,wordunits)
					steps = steps + 1
					
					sentences[steps] = {}
					local sent = sentences[steps]
					
					table.insert(variantcount, #words)
					table.insert(combo, 1)
					
					if (#words > 0) then
						variations = variations * #words
						
						if (variations > #finals) then
							local limitdiff = variations - #finals
							for i=1,limitdiff do
								table.insert(finals, {})
							end
						end
						
						for i,v in ipairs(words) do
							local tile = mmf.newObject(v)
							local tilename = tile.strings[NAME]
							local tiletype = tile.values[TYPE]
							
							if (tile.strings[UNITTYPE] ~= "text") then
								tiletype = 0
							end
							
							table.insert(sent, {tilename, tiletype, v})
						end
					else
						done = true
					end
				end

				if (#sentences > 2) then
					for i=1,variations do
						-- Parser rewrite starts here
						local sent = getsentencevariant(sentences,combo)
						local tokens = {}
						local currentLetters = ""
						local currentLetterIds = {}

						for idx=1, #sentences do
							if (variantcount[idx] > 0) then
								local s = sent[idx]
								local name, type, unitId = s[1], s[2], s[3]
								
								if type == 5 then
									-- Handle Letters. I don't really know how this works, so it probably fails in some edge cases.
									-- But everything I tried works, including the tricks that the vanilla ABC levels use.
									currentLetters = currentLetters .. name
									table.insert(currentLetterIds, unitId)

									local lName, lType, found, secondaryFound = findword(currentLetters, sent[idx + 1] or {-1, -1, -1}, name)

									if secondaryFound then
										-- This seems to handle situations like W[ALL] and GHOSTAR.
										table.insert(firstwords, {sent[idx - 1][3], dir})
									end

									-- As far as I can tell, `found` doesn't mean that we actually found the whole word yet, just that
									-- there are still possible words which our letters might be a prefix of.
									if not found then
										-- No hope for these letters. We represent the failed attempt at tokenizing a word
										-- with a token of type FAILED_LETTERS (-10).
										table.insert(tokens, {name = currentLetters, type = -10, unitId = currentLetterIds, isLetters = true})
										break
									end

									-- We didn't find the whole word yet, but the rest might still be coming.
									if lType == -1 then
										local nextS = sent[idx + 1]
										if nextS == nil or nextS[2] ~= 5 then
											-- Next tile is not a letter, so we won't ever find the whole word.
											table.insert(tokens, {name = currentLetters, type = -10, unitId = currentLetterIds, isLetters = true})
											break
										end
									else
										-- We actually found a word!
										table.insert(tokens, {name = lName, type = lType, unitId = currentLetterIds, isLetters = true})
										currentLetters = ""
										currentLetterIds = {}
									end
								else
									-- unitId is a bad name for this field, sorry. It's actually an array of unit IDs.
									-- (For letters, a token could consist of more than one unit.)
									table.insert(tokens, {name = name, type = type, unitId = {unitId}})
								end
							end
						end

						local parserState = {consumed = 0, tokens = tokens}

						local success, targets, conds, condUnitIds, predicates = activemod.parser.rule(parserState)

						if success then
							-- Find all of the features that this rule will generate. This is the cartesian product of the targets and the predicates.
							for _, target in ipairs(targets) do
								local target, targetUnitIds = target[1], target[2]
								for _, predicate in ipairs(predicates) do
									local verb, effect, predicateUnitIds = predicate[1], predicate[2], predicate[3]

									-- Determine the specific list of text unit IDs for this feature. That is, the unit IDs specific to this
									-- target, the unit IDs specific to this predicate, and all of the unit IDs for the conditions (which
									-- are shared across all features the rule generates.)
									-- This is how the game can cross out only part of a rule if only some of it was blocked.
									local combinedUnitIds = activemod.concat({}, targetUnitIds, condUnitIds, predicateUnitIds)

									-- It is necessary to take a shallow copy of conds here, because addoption and postrules will
									-- mess with these and we don't want them to affect more rules than they should.
									addoption({target, verb, effect}, activemod.concat({}, conds), combinedUnitIds)
								end
							end
						end

						-- If there are tokens left over from the parse attempt, put the last unit that was parsed
						-- back into firstwords.
						-- e.g. BABA IS FLAG IS YOU, we parsed BABA IS FLAG successfully, so put FLAG back into
						-- firstwords so that FLAG IS YOU can be parsed.
						-- e.g. FLAG BABA IS YOU, we failed, consuming 1 token, try again starting from BABA.
						-- e.g. IS BABA IS YOU, we failed, consuming no tokens, try again starting from BABA.

						local newFirstWordIndex = parserState.consumed
						if newFirstWordIndex == 0 and tokens[1].isLetters and #tokens[1].unitId > 1 then
							-- If we started with letters and didn't even manage to get through that, try again
							-- with the first letter missing. This will ensure things like X Y Z B A B A IS YOU will eventually
							-- get to the BABA.
							table.insert(firstwords, {tokens[1].unitId[2], dir})
						else
							if newFirstWordIndex <= 1 then
								newFirstWordIndex = 2
							end

							-- Don't bother if it's the last unit because 1 unit on its own cannot make a rule.
							if newFirstWordIndex < #tokens then
								table.insert(firstwords, {tokens[newFirstWordIndex].unitId[1], dir})
							elseif #tokens >= 2 and tokens[#tokens].type == -10 then
								-- If the last token is failed letters, then the last comment is a lie. Our list of tokens
								-- is incomplete, so there might still be enough to make a new rule.
								table.insert(firstwords, {tokens[#tokens].unitId[1], dir})
							end
						end

						combo = updatecombo(combo,variantcount)
						-- Parser rewrite ends here.
					end
				end
			end
		end
	end
end

local function handleallincondparams(params)
	local alreadyused = {}
	local newparams = {}
	local allfound = false
	
	--alreadyused[target] = 1
	
	for a,b in ipairs(params) do
		if (b ~= "all") then
			alreadyused[b] = 1
			table.insert(newparams, b)
		else
			allfound = true
		end
	end
	
	if allfound then
		for a,mat in pairs(objectlist) do
			if (alreadyused[a] == nil) and (a ~= "group") and (a ~= "all") and (a ~= "text") then
				table.insert(newparams, a)
				alreadyused[a] = 1
			end
		end
	end

	return newparams
end

function addoption(option,conds_,ids,visible,notrule)
	--MF_alert(option[1] .. ", " .. option[2] .. ", " .. option[3])
	
	local visual = true
	
	if (visible ~= nil) then
		visual = visible
	end
	
	local conds = {}
	
	if (conds_ ~= nil) then
		conds = conds_
	else
		print("nil conditions in rule: " .. option[1] .. ", " .. option[2] .. ", " .. option[3])
	end
	
	if (#option == 3) then
		local rule = {option,conds,ids}
		table.insert(features, rule)
		local target = option[1]
		local verb = option[2]
		local effect = option[3]
	
		if (featureindex[effect] == nil) then
			featureindex[effect] = {}
		end
		
		if (featureindex[target] == nil) then
			featureindex[target] = {}
		end
		
		if (featureindex[verb] == nil) then
			featureindex[verb] = {}
		end
		
		table.insert(featureindex[effect], rule)
		
		table.insert(featureindex[verb], rule)
		
		if (target ~= effect) then
			table.insert(featureindex[target], rule)
		end
		
		if visual then
			local visualrule = copyrule(rule)
			table.insert(visualfeatures, visualrule)
		end
		
		if (notrule ~= nil) then
			local notrule_effect = notrule[1]
			local notrule_id = notrule[2]
			
			if (notfeatures[notrule_effect] == nil) then
				notfeatures[notrule_effect] = {}
			end
			
			local nr_e = notfeatures[notrule_effect]
			
			if (nr_e[notrule_id] == nil) then
				nr_e[notrule_id] = {}
			end
			
			local nr_i = nr_e[notrule_id]
			
			table.insert(nr_i, rule)
		end
		
		if (#conds > 0) then
			for i,cond in ipairs(conds) do
				if (cond[1] == "if" or cond[1] == "not if") then
					for _,ifcond in ipairs(cond[2]) do
						ifcond[2] = handleallincondparams(ifcond[2])
						for _,targetcond in ipairs(ifcond[3]) do
							targetcond[2] = handleallincondparams(targetcond[2])
						end
						for _,innercond in ipairs(ifcond[4]) do
							innercond[2] = handleallincondparams(innercond[2])
						end
					end
				elseif (cond[2] ~= nil) then
					if (#cond[2] > 0) then
						cond[2] = handleallincondparams(cond[2])
					end
				end
			end
		end

		local targetnot = string.sub(target, 1, 3)
		local targetnot_ = string.sub(target, 5)
		
		if (targetnot == "not") and (objectlist[targetnot_] ~= nil) then
			for i,mat in pairs(objectlist) do
				if (i ~= "empty") and (i ~= "all") and (i ~= "level") and (i ~= "group") and (i ~= targetnot_) and (i ~= "text") then
					local rule = {i,verb,effect}
					--print(i .. " " .. verb .. " " .. effect)
					local newconds = {}
					for a,b in ipairs(conds) do
						table.insert(newconds, b)
					end
					addoption(rule,newconds,ids,false,{effect,#featureindex[effect]})
				end
			end
		end
		
		if (effect == "all") then
			if (verb ~= "is") then 
				for i,mat in pairs(objectlist) do
					if (i ~= "empty") and (i ~= "all") and (i ~= "level") and (i ~= "group") and (i ~= "text") then
						local rule = {target,verb,i}
						local newconds = {}
						for a,b in ipairs(conds) do
							table.insert(newconds, b)
						end
						addoption(rule,newconds,ids,false)
					end
				end
			end
		end

		if (target == "all") then
			for i,mat in pairs(objectlist) do
				if (i ~= "empty") and (i ~= "all") and (i ~= "level") and (i ~= "group") and (i ~= "text") then
					local rule = {i,verb,effect}
					local newconds = {}
					for a,b in ipairs(conds) do
						table.insert(newconds, b)
					end
					addoption(rule,newconds,ids,false)
				end
			end
		end
	end
end