
local parser = {}

local FAILED_LETTERS = -10
local NOUN = 0
local VERB = 1
local PROP = 2
local PRECOND = 3
local NOT = 4
local LETTER = 5
local AND = 6
local POSTCOND = 7

function parser.printState(state)
	local printString = ""
	for idx, token in ipairs(state.tokens) do
		if idx == state.consumed + 1 then
			printString = printString .. "> "
		end
		printString = printString .. token.name .. " "
	end

	if state.consumed >= #state.tokens then
		printString = printString .. ">"
	end

	print(printString)
end

-- Consume the first token and return its name and type. Add its ID to unitIdList.
local function consume(state, unitIdList)
	if state.consumed >= #state.tokens then
		return nil
	end
	state.consumed = state.consumed + 1
	local token = state.tokens[state.consumed]
	table.insert(unitIdList, token.unitId)
	return token.name, token.type
end

local function contains(needle, haystack)
	if type(haystack) == "number" then
		return needle == haystack
	end

	for _, x in ipairs(haystack) do
		if x == needle then
			return true
		end
	end
	return false
end

-- Check that the token exists and is one of the specified types. `types` can be
-- either a single type or an array of types.
local function checkToken(state, idx, types)
	local token = state.tokens[state.consumed + idx]
	return token ~= nil and contains(token.type, types)
end

-- As above, but we first skip past all of the NOTs.
local function checkFirstNonNotToken(state, startingIdx, types)
	for idx = state.consumed + startingIdx, #state.tokens do
		local token = state.tokens[idx]
		if token.type ~= NOT then
			return contains(token.type, types)
		end
	end
	return false
end

function parser.rule(state)
	local success, targets, conds, condUnitIds, predicates = parser.englishRule(state)
	if success then
		return true, targets, conds, condUnitIds, predicates, nil
	end

	if featureindex["yoda"] ~= nil then
		state.consumed = 0
		success, targets, conds, condUnitIds, predicates = parser.yodaRule(state)
		-- Only allow the rule if every consumed token IS YODA
		if success then
			for i = 1, state.consumed do
				for _, unitId in ipairs(state.tokens[i].unitId) do
					local unit = mmf.newObject(unitId)
					if not hasfeature(getname(unit), "is", "yoda", unitId) then
						success = false
						break
					end
				end

				if not success then
					break
				end
			end

			if success then
				return true, targets, conds, condUnitIds, predicates, "yoda"
			end
		end
	end

	if featureindex["caveman"] ~= nil then
		state.consumed = 0
		success, targets, conds, condUnitIds, predicates = parser.cavemanRule(state)
		-- Only allow the rule if every consumed token IS YODA
		if success then
			for i = 1, state.consumed do
				for _, unitId in ipairs(state.tokens[i].unitId) do
					local unit = mmf.newObject(unitId)
					if not hasfeature(getname(unit), "is", "caveman", unitId) then
						success = false
						break
					end
				end

				if not success then
					break
				end
			end

			if success then
				return true, targets, conds, condUnitIds, predicates, "caveman"
			end
		end
	end

	return false
end

local function getVerbParamTypes(verb)
	local realName = unitreference["text_" .. verb]
	local wValues = changes[realName]
	if wValues == nil then
		wValues = tileslist[realName]
	end

	if wValues == nil then
		return NOUN
	end

	if wValues.operatortype == "verb_all" then
		return {NOUN, PROP}
	end
	return NOUN
end

function parser.englishRule(state)
	local done, targets, conds, condUnitIds = parser.subject(state)
	if done then
		return false
	end

	local done2, predicates = parser.predicates(state)

	if #predicates == 0 then
		return false
	end

	return true, targets, conds, condUnitIds, predicates
end

function parser.yodaRule(state)
	-- We don't know what the allowed verb param types are yet, because we don't know
	-- what the verb is. For now, allow everything, then we will check them later on.
	local done, effects = parser.andSeparatedListWithSeparateIdLists(state, {NOUN, PROP})

	if done then
		return false
	end

	local done, targets, conds, condUnitIds = parser.subject(state)
	if done then
		return false
	end

	-- Yoda rule can only have one verb.
	if not checkToken(state, 1, VERB) then
		return false
	end

	local verbIds = {}
	local verb = consume(state, verbIds)
	local paramTypes = getVerbParamTypes(verb)
	local predicates = {}

	for _, data in ipairs(effects) do
		local effect, unitIds, type = data[1], data[2], data[3]
		-- Finally check the verb params.
		if not contains(type, paramTypes) then
			return false
		end
		table.insert(predicates, {verb, effect, activemod.concat(unitIds, verbIds)})
	end

	return true, targets, conds, condUnitIds, predicates
end

function parser.cavemanRule(state)
	local done, targets, conds, condUnitIds = parser.subject(state)
	if done then
		return false
	end

	local done, effects = parser.andSeparatedListWithSeparateIdLists(state, {NOUN, PROP})
	if done then
		return false
	end

	local predicates = {}
	for _, data in ipairs(effects) do
		table.insert(predicates, {"is", data[1], data[2]})
	end

	return true, targets, conds, condUnitIds, predicates
end

-- Parse (NOT*) and return either "not " is there was an odd number
-- of nots or "" otherwise. Add the ID of the nots to unitIdList.
function parser.nots(state, unitIdList)
	local isNot = false
	while checkToken(state, 1, NOT) do
		isNot = not isNot
		consume(state, unitIdList)
	end
	if isNot then
		return "not "
	end
	return ""
end

function parser.subject(state)
	local condUnitIds = {}
	local preConds = parser.preConds(state, condUnitIds)

	local done, targets = parser.andSeparatedListWithSeparateIdLists(state, NOUN)
	if done then
		return true, {}, {}, {}
	end

	local done2, postConds = parser.postConds(state, condUnitIds)
	if done2 then
		return true, {}, {}, {}
	end

	return false, targets, activemod.concat(preConds, postConds), condUnitIds
end

function parser.preConds(state, unitIdList)
	if checkFirstNonNotToken(state, 1, PRECOND) then
		-- Vanilla actually doesn't support multiple preconds, probably because it
		-- only has one precond anyway (Lonely). But we might as well support multiple.
		local done, condNames = parser.andSeparatedList(state, PRECOND, unitIdList)
		local result = {}
		for _, cond in ipairs(condNames) do
			table.insert(result, {cond, {}})
		end
		return result
	end
	return {}
end

-- Parse nots <types> (AND nots <types>)*
-- e.g. parser.andSeparatedListWithSeparateIdLists(state, {NOUN}) parses one or more nouns separated by AND.
-- There must be at least one, otherwise we are done.
-- Returns array of string and adds all unit IDs to the list.
function parser.andSeparatedList(state, types, unitIdList)
	if not checkFirstNonNotToken(state, 1, types) then
		return true, {}
	end
	local result = {parser.nots(state, unitIdList) .. consume(state, unitIdList)}

	while true do
		if not (checkToken(state, 1, AND) and checkFirstNonNotToken(state, 2, types)) then
			return false, result
		end
		consume(state, unitIdList) -- AND
		table.insert(result, parser.nots(state, unitIdList) .. consume(state, unitIdList))
	end
end

-- As above, but returns array of {name, unitIdList, type} with separate ID lists for each parsed item.
function parser.andSeparatedListWithSeparateIdLists(state, types)
	if not checkFirstNonNotToken(state, 1, types) then
		return true, {}
	end

	local unitIdList = {}
	local prefix = parser.nots(state, unitIdList)
	local item, itemType = consume(state, unitIdList)
	local result = {{prefix .. item, unitIdList, itemType}}

	while true do
		if not (checkToken(state, 1, AND) and checkFirstNonNotToken(state, 2, types)) then
			return false, result
		end

		unitIdList = {}
		consume(state, unitIdList) -- AND
		prefix = parser.nots(state, unitIdList)
		item, itemType = consume(state, unitIdList)
		table.insert(result, {prefix .. item, unitIdList, itemType})
	end
end

-- local function flattenAndSeparatedList(andSeparatedList, unitIdList)
-- 	local result = {}
-- 	for _, entry in ipairs(andSeparatedList) do
-- 		local word, unitIds = entry[1], entry[2]
-- 		table.insert(result, word)
-- 		for _, unitId in ipairs(unitIds) do
-- 			table.insert(unitIdList, unitId)
-- 		end
-- 	end
-- 	return result
-- end

function parser.postConds(state, unitIdList)
	if not checkFirstNonNotToken(state, 1, POSTCOND) then
		return false, {}
	end

	local prefix, cond = parser.nots(state, unitIdList), consume(state, unitIdList)
	local done, params = parser.andSeparatedList(state, {NOUN}, unitIdList)
	if done then
		return true, {}
	end
	local postConds = {{prefix .. cond, params}}

	while true do
		if not (checkToken(state, 1, AND) and checkFirstNonNotToken(state, 2, POSTCOND)) then
			return false, postConds
		end
		consume(state, unitIdList) -- AND
		prefix, cond = parser.nots(state, unitIdList), consume(state, unitIdList)
		done, params = parser.andSeparatedList(state, {NOUN}, unitIdList)
		if done then
			return true, {}
		end

		table.insert(postConds, {prefix .. cond, params})
	end
end

function parser.predicates(state)
	if not checkToken(state, 1, VERB) then
		return true, {}
	end

	local predicates = {}

	local verbUnitIds = {}
	local verb = consume(state, verbUnitIds)
	local done, andSeparatedList = parser.andSeparatedListWithSeparateIdLists(state, getVerbParamTypes(verb))
	if done then
		return true, {}
	end

	for _, param in ipairs(andSeparatedList) do
		local effect, effectUnitIds = param[1], param[2]
		table.insert(predicates, {verb, effect, activemod.concat(effectUnitIds, verbUnitIds)})
	end

	while true do
		if not (checkToken(state, 1, AND) and checkToken(state, 2, VERB)) then
			return false, predicates
		end
		verbUnitIds = {}
		consume(state, verbUnitIds) -- AND
		verb = consume(state, verbUnitIds)
		done, andSeparatedList = parser.andSeparatedListWithSeparateIdLists(state, getVerbParamTypes(verb))
		if done then
			return true, predicates
		end

		for _, param in ipairs(andSeparatedList) do
			local effect, effectUnitIds = param[1], param[2]
			table.insert(predicates, {verb, effect, activemod.concat(effectUnitIds, verbUnitIds)})
		end
	end
end

return parser