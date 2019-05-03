
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
local IF = 10
local QUANTIFIER = 11

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

-- Consume the first token and return its name. Add its ID to unitIdList.
local function consume(state, unitIdList)
	if state.consumed >= #state.tokens then
		return nil
	end
	state.consumed = state.consumed + 1
	local token = state.tokens[state.consumed]
	table.insert(unitIdList, token.unitId)
	return token.name
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

-- As above, but checks the name.
local function checkTokenName(state, idx, name)
	local token = state.tokens[state.consumed + idx]
	return token ~= nil and token.name == name
end

-- As above, but we first skip past all of the NOTs.
local function checkFirstNonNotToken(state, startingIdx, types)
	for idx = state.consumed + startingIdx, #state.tokens do
		local token = state.tokens[idx]
		if token.type ~= NOT then
			return contains(token.type, types), idx
		end
	end
	return false, nil
end

function parser.rule(state)
	local done, targets, conds, condUnitIds = parser.subject(state)
	if done then
		return false
	end

	local done2, predicates = parser.predicates(state)

	if #predicates == 0 then
		return false
	end

	if done2 then
		return true, targets, conds, condUnitIds, predicates
	end

	local done3, ifConds = parser.ifConds(state, condUnitIds)
	if ifConds ~= nil then
		table.insert(conds, ifConds)
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
function parser.andSeparatedList(state, types, unitIdList, isIfCondParams)
	if not checkFirstNonNotToken(state, 1, types) then
		return true, {}
	end
	local result = {parser.nots(state, unitIdList) .. consume(state, unitIdList)}

	while true do
		local isCorrectType, idx = checkFirstNonNotToken(state, 2, types)
		if not (checkToken(state, 1, AND) and isCorrectType) then
			return false, result
		end

		-- In this situation: IF A IS ON B > AND C IS LONELY
		-- We don't want to consume the AND C.
		if isIfCondParams then
			local testToken = state.tokens[idx + 1]
			if testToken ~= nil and (testToken.name == "is" or testToken.type == POSTCOND) then
				return false, result
			end
		end

		consume(state, unitIdList) -- AND
		table.insert(result, parser.nots(state, unitIdList) .. consume(state, unitIdList))
	end
end

-- As above, but returns array of {name, unitIdList} with separate ID lists for each parsed item.
function parser.andSeparatedListWithSeparateIdLists(state, types)
	if not checkFirstNonNotToken(state, 1, types) then
		return true, {}
	end
	local unitIdList = {}
	local result = {{parser.nots(state, unitIdList) .. consume(state, unitIdList), unitIdList}}

	while true do
		if not (checkToken(state, 1, AND) and checkFirstNonNotToken(state, 2, types)) then
			return false, result
		end
		unitIdList = {}
		consume(state, unitIdList) -- AND
		table.insert(result, {parser.nots(state, unitIdList) .. consume(state, unitIdList), unitIdList})
	end
end

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

function parser.ifConds(state, unitIdList)
	if not checkToken(state, 1, IF) then
		return false, nil
	end

	local ifConds = {}
	while true do
		if not checkToken(state, 1, {IF, AND}) then
			return false, {"if", ifConds}
		end

		local newUnitIds = {}
		consume(state, newUnitIds) -- AND / IF

		local done, newIfCond = parser.ifCond(state, newUnitIds)
		if newIfCond ~= nil then
			table.insert(ifConds, newIfCond)
			activemod.concat(unitIdList, newUnitIds)
		end

		if done then
			if #ifConds == 0 then
				return true, nil
			end
			return true, {"if", ifConds}
		end
	end
end

function parser.ifCond(state, unitIdList)
	local quantifier = ""
	if checkFirstNonNotToken(state, 1, QUANTIFIER) then
		quantifier = parser.nots(state, unitIdList) .. consume(state, unitIdList)
	end

	local done, parsedTargets, conds, condUnitIds = parser.subject(state)
	if done then
		return true, nil
	end

	local targets = {}
	for _, data in ipairs(parsedTargets) do
		table.insert(targets, data[1])
		activemod.concat(unitIdList, data[2])
	end
	activemod.concat(unitIdList, condUnitIds)

	if not checkTokenName(state, 1, "is") then
		return true, nil
	end
	consume(state, unitIdList) -- is

	local done2, ifPredicates = parser.ifPredicates(state, unitIdList)
	if #ifPredicates == 0 then
		return true, nil
	end

	return done2, {quantifier, targets, conds, ifPredicates}
end

function parser.ifPredicates(state, unitIdList)
	if not checkFirstNonNotToken(state, 1, {PROP, PRECOND, POSTCOND}) then
		return true, {}
	end

	local ifPredicates = {}
	local thisPredicateUnitIds = {}

	while true do
		if checkFirstNonNotToken(state, 1, PROP) then
			table.insert(ifPredicates, {parser.nots(state, thisPredicateUnitIds) .. "cg5with", {consume(state, thisPredicateUnitIds)}})

		elseif checkFirstNonNotToken(state, 1, PRECOND) then
			table.insert(ifPredicates, {parser.nots(state, thisPredicateUnitIds) .. consume(state, thisPredicateUnitIds), {}})

		elseif checkFirstNonNotToken(state, 1, POSTCOND) then
			local postCond = parser.nots(state, thisPredicateUnitIds) .. consume(state, thisPredicateUnitIds)
			local done, nouns = parser.andSeparatedList(state, NOUN, thisPredicateUnitIds, true)
			if done then
				return true, ifPredicates
			end
			table.insert(ifPredicates, {postCond, nouns})
		end

		activemod.concat(unitIdList, thisPredicateUnitIds)
		thisPredicateUnitIds = {}

		if not (checkToken(state, 1, AND) and checkFirstNonNotToken(state, 2, {PROP, PRECOND, POSTCOND})) then
			return false, ifPredicates
		end
		consume(state, thisPredicateUnitIds) -- AND
	end
end


return parser