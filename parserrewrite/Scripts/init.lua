
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

function mod.load(dir)
	loadscript(dir .. "rules")
	loadscript(dir .. "tools")
	loadscript(dir .. "conditions")
	mod.inspect = loadscript(dir .. "inspect")
	mod.parser = loadscript(dir .. "parser")
end

function mod.unload(dir)
	loadscript("Data/rules")
	loadscript("Data/tools")
	loadscript("Data/conditions")
end

return mod
