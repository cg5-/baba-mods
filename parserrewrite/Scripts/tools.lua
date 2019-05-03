
-- Modify writerules to support multiple pre-conds properly
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
		for i,rules in ipairs(visualfeatures) do
			local currcolumn = math.floor((i - 1) / linelimit) - (columns * 0.5)
			
			x = basex + columnwidth * currcolumn + columnwidth * 0.5
			y = basey + (((i - 1) % linelimit) + 1) * tilesize * 0.8
			
			local text = ""
			local preconds = ""
			local rule = rules[1]
			
			text = text .. rule[1] .. " "
			
			local conds = rules[2]
			if (#conds > 0) then
				for a,cond in ipairs(conds) do
					local middlecond = true
					
					if (cond[2] == nil) or ((cond[2] ~= nil) and (#cond[2] == 0)) then
						middlecond = false
					end
					
					if middlecond then
						text = text .. cond[1] .. " "
						
						if (cond[2] ~= nil) then
							if (#cond[2] > 0) then
								for c,d in ipairs(cond[2]) do
									text = text .. d .. " "
									
									if (#cond[2] > 1) and (c ~= #cond[2]) then
										text = text .. "& "
									end
								end
							end
						end
						
						if (a < #conds) then
							text = text .. "& "
						end
					else
						if preconds == "" then
							preconds = cond[1] .. " "
						else
							preconds = preconds .. "& " .. cond[1] .. " "
						end
					end
				end
			end
			
			text = preconds .. text .. rule[2] .. " " .. rule[3]
			
			writetext(text,0,x,y,name,true,2,true)
		end
	end
end