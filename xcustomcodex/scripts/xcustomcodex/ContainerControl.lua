-- Appended by Xan the Dragon
-- Main controller script for the "Read All" button added by /chest/cdx/chest<slots>.config

require "/scripts/xcustomcodex/LearnCodexRoutine.lua" -- Defines LearnCodex(string name)

function CodexButtonClicked()
	--player.interact("ScriptPane", "/interface/scripted/xcustomcodex/xcodexui.config", player.id())
	local numLearned = 0
	local numAlreadyKnew = 0
	local numErrored = 0
	
	local items = widget.itemGridItems("itemGrid")
	for index, item in pairs(items) do
		local itemName = item.name
		-- Simple test: Does it end in -codex? We can easily scrap items that aren't codexes this way.
		if #itemName > 6 and itemName:sub(-6) == "-codex" then
		
			-- Reiteration: 0 = Learned it, 1 = Didn't learn it (but it was because we already knew it), 2 = Something errored out and we had to abort the process.
			local learnStatus = LearnCodex(itemName)
			if learnStatus == 0 then
				numLearned = numLearned + 1
			elseif learnStatus == 1 then
				numAlreadyKnew = numAlreadyKnew + 1
			elseif learnStatus == 2 then
				numErrored = numErrored + 1
			end
		end
	end
	widget.playSound("/sfx/interface/item_equip.ogg") -- Give the player some feedback that they learned the entries.
end

-- gg ez