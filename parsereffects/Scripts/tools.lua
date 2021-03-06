
local function join(array, func, separator)
	local result = ""
	for _, elem in ipairs(array) do
		local text = func(elem)
		if text ~= nil and text ~= "" then
			if result == "" then
				result = text
			else
				result = result .. separator .. text
			end
		end
	end
	return result
end

local function identity(x)
	return x
end

local function condtostring(cond)
	local text = cond[1]
	if (cond[2] ~= nil and #cond[2] > 0) then
		text = text .. " " .. join(cond[2], identity, " & ")
	end
	return text
end

local function subjecttostring(targets, conds)
	local preconds = join(conds, function (cond)
		if #cond[2] == 0 then
			return condtostring(cond)
		end
	end, " & ")

	local nouns = join(targets, identity, " & ")

	local postconds = join(conds, function (cond)
		if #cond[2] > 0 and cond[1] ~= "if" and cond[2] ~= "not if" then
			return condtostring(cond, false)
		end
	end, " & ")

	return join({preconds, nouns, postconds}, identity, " ")
end

function writerules(parent,name,x_,y_)
	local basex = x_
	local basey = y_
	local linelimit = 12
	
	local x,y = basex,basey
	
	if (#visualfeatures > 0) then
		writetext(langtext("rules") .. ":",0,x,y,name,true,2,true)
	end
	
	local texthide = findfeature("text","is","hide")
	
	local columns = math.floor((#visualfeatures - 1) / linelimit) + 1
	local columnwidth = math.min(screenw - tilesize * 2, columns * tilesize * 10) / columns
	
	if (texthide == nil) then
		for i,rule in ipairs(visualfeatures) do
			local currcolumn = math.floor((i - 1) / linelimit) - (columns * 0.5)
			
			x = basex + columnwidth * currcolumn + columnwidth * 0.5
			y = basey + (((i - 1) % linelimit) + 1) * tilesize * 0.8
			
			local subject = subjecttostring({rule[1][1]}, rule[2])
			if rule.language == "caveman" and rule[1][2] == "is" then
				text = subject .. " " .. rule[1][3] .. "!"
			elseif rule.language == "yoda" then
				text = rule[1][3] .. ", " .. subject .. " " .. rule[1][2]
			elseif rule.language == "clickbait" then
				text = rule[1][2] .. " " .. subject .. " " .. activemod.invertEffect(rule[1][3]) .. "? the answer may surprise you! (it isn't)"
			else
				text = subject .. " " .. rule[1][2] .. " " .. rule[1][3]
			end
			writetext(text,0,x,y,name,true,2,true)
		end
	end
end