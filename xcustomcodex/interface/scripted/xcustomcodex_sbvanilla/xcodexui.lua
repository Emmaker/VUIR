-- Custom Codex UI by Xan the Dragon // Eti the Spirit [RBX 18406183]
-- Proposed by Sayter, approved of by Xan
-- And then made by Xan


-- Because starbound needs to up their game, like damn

-- To reference any ScrollArea children widgets in Lua scripts (widget.* table) use the following format: <ScrollArea name>.<Children widget name>.

local print, warn, error, assertwarn, assert, tostring; -- Specify these as locals
require "/scripts/xcustomcodex/LoggingOverride.lua" -- tl;dr I can use print, warn, error, assert, and assertwarn

---------------------------
------ TEMPLATE DATA ------
---------------------------

-- This is the text that displays on the "Ambiguous Race" button.
local TEXT_AMBIGUOUS_BUTTON = "?"

-- A template for one of the buttons displayed in the list of codex entries.
-- This template is no longer used. It was only used when name abbreviations were displayed in place of images.
local TEMPLATE_CODEX_ENTRY_BUTTON = {
	type = "button",
	caption = "",
	textAlign = "center",
	base = "/interface/scripted/xcustomcodex_sbvanilla/codexbutton.png",
	hover = "/interface/scripted/xcustomcodex_sbvanilla/codexbuttonhover.png",
	pressed = "/interface/scripted/xcustomcodex_sbvanilla/codexbuttonhover.png",
	callback = "ListButtonClicked",
	pressedOffset = { 0, 0 }
}

-- This template data is only created on GUI instantiation.
-- This may be a better fit for simply having in the raw .config file itself.
local TEMPLATE_CODEX_RACE_CATEGORY = {
	type = "list",
	callback = "RaceButtonClicked",
	schema = {
		selectedBG = "/interface/scripted/xcustomcodex_sbvanilla/racebuttonhover.png",
		unselectedBG = "/interface/scripted/xcustomcodex_sbvanilla/racebutton.png",
		spacing = { 0, 0 },
		memberSize = { 24, 24 },
		listTemplate = {
			constBG = {
				type = "image",
				file = "/interface/scripted/xcustomcodex_sbvanilla/racebutton.png",
				pressedOffset = { 0, 0 },
			},
			raceIcon = {
				type = "image",
				file = "",
				pressedOffset = { 0, 0 },
				zlevel = 1
			},
			raceButton = {
				type = "button",
				caption = "",
				textAlign = "center",
				base = "/interface/scripted/xcustomcodex_sbvanilla/racebutton.png",
				hover = "/interface/scripted/xcustomcodex_sbvanilla/racebuttonhover.png",
				pressed = "/interface/scripted/xcustomcodex_sbvanilla/racebuttonhover.png",
				callback = "null",
				pressedOffset = { 0, 0 },
			},
			buttonLabel = {
				type = "label",
				value = "",
				hAnchor = "mid",
				vAnchor = "mid",
				position = {12, 12},
				pressedOffset = { 0, 0 },
				zLevel = 2
			}
		}
	}
}

-----------------------
------ CORE DATA ------
-----------------------

-- Data binding [X] codex button to [Y] codex JSON
local CodexButtonBindings = {}

-- A registry of the categories we already have created in the GUI.
local ExistingCategoryButtons = {}

-- The current page we're on in the codex.
local CurrentPage = 1

-- The currently open codex entry.
local CurrentCodex = nil

-- Is the next/prev button enabled? This exists because Starbound literally has a `setButtonEnabled` but NOT a `getButtonEnabled`. Intelligence 100000000000000000000000
local NextButtonEnabled = false
local PrevButtonEnabled = false

------------------------------
------ HELPER FUNCTIONS ------
------------------------------

-- Receives a list of pages as well as the current page index.
-- Using this information, it updates the enabled status of the next and previous buttons.
-- It then updates the display text at the bottom to read "Page X of Y"
-- Finally, it alters the displayed text for said page in the UI so that you can read the new page.
local function UpdateBasedOnPage(pages, currentPage)
	local numPages = #pages
	local nextEnabled = currentPage < numPages
	local prevEnabled = currentPage > 1
	
	widget.setButtonEnabled("nextButton", nextEnabled)
	widget.setButtonEnabled("prevButton", prevEnabled)
	widget.setFontColor("nextButton", nextEnabled and "#FFFFFF" or "#666666")
	widget.setFontColor("prevButton", prevEnabled and "#FFFFFF" or "#666666")
	
	NextButtonEnabled = nextEnabled
	PrevButtonEnabled = prevEnabled
	
	widget.setText("currentPageLabel", "Page " .. currentPage .. " of " .. numPages)
	
	local pageText = pages[currentPage]
	widget.setText("codexText.textElement", pageText)
end

-- This method is a bit complicated.
-- It goes through all of the chars of a given name (arg 1) and picks out the uppercase levels.
-- The second argument, existingAbbreviations, is a table of data this function has already spit out. More on this in the body of the function.
-- The third argument is used by this function only which is for recursive calling and the disambiguation method, which ties into ^.
-- The last argument is the maximum string length from this function.
local function GetNameAbbreviation(name, existingAbbreviations, startSub, maxLen)
	-- Start out by getting default values.
	local maxLen = maxLen or 4
	local startSub = startSub or 1
	
	-- Now we want to make sure our maximum length is also not going to be longer than the text since this will throw an error.
	local newAvailableMax = math.min(maxLen, #name)
	
	-- Likewise, if our disambiguation string (which is where we grab more letters from the start of the name) is longer than the actual text, just return what we can and abort.
	if startSub > newAvailableMax then
		return name:sub(1, newAvailableMax)
	end
	
	-- So now, we start out our returned abbreviation with the first [startSub] characters of the name.
	local abv = name:sub(1, startSub)
	for i = 2, #name do
		-- Starting from the second character onward, we test if each char is uppercase as well as alphabetical.
		local chr = name:sub(i, i)
		
		-- Bet you didn't know you could use > and < on strings, did you?
		if chr:upper() == chr and (chr:upper() >= "A" and chr:upper() <= "Z") then
			-- If it is uppercase and alphabetical, add it to the abbreviation.
			abv = abv .. chr
		end
		
		-- And if the length of this abbreviation is equal to or exceeds the maximum available length, we need to abort and return immediately -- disambiguation isn't possible.
		if #abv >= maxLen then
			return abv
		end
	end
	
	-- If we have made it here, we have gotten an appropriate abbreviation for the name (e.g. "A" for "Apex")
	-- Now we need to look at our other outputs from this function in the race button population cycle.
	-- What if we also have an Avian codex? That starts with "A" too, and would result in the same abbreviation!
	for index, abbreviation in ipairs(existingAbbreviations) do
		if abv == abbreviation then
			-- So if we meet this condition, we see that "Oh, our result right now is something this function has already given!"
			-- So we tell it to give the result of calling this function again, with one more added to startSub.
			-- This means that Avian will now return "Av" (one character after the first is now included), and since this is different than "A" for Apex, this condition won't run again...
			return GetNameAbbreviation(name, existingAbbreviations, startSub + 1)
		end
	end
	-- And we'll make it here.
	return abv
end

-- Gets the first element in a dictionary-style table (where the keys are non-numeric)
function GetFirstInTable(tbl)
	-- Basically just run one iteration and immediately return the first value.
	for _, value in pairs(tbl) do
		return value
	end
end

-------------------------------
------ PRIMARY FUNCTIONS ------
-------------------------------


-- Creates a button on the left-hand list to view this codex.
-- This is only called when we select a category (so that the buttons pertaining to the various codex entries for said category are created)
local function CreateButtonToReadCodex(codexData, codexFileInfo, index)
	-- Create a unique button name.
	local buttonName = "cdx_" .. codexData.id
	
	-- Grab our button template and populate the necessary data.
	local button = TEMPLATE_CODEX_ENTRY_BUTTON
	button.caption = codexData.title or "ERR_NO_TITLE"
	button.position = {0, index * -22}
	
	-- Now let's store this button's existence.
	CodexButtonBindings[buttonName] = codexData
	widget.addChild("codexList", button, buttonName)
	
	--print("Button " .. buttonName .. " added to codex list children.")
end

-- Sets the title text to the codex's title, resets the page to the given page number (or 1 if it was not specified), then calls UpdateBasedOnPage.
-- This also populates the "CurrentCodex" field.
local function OpenCodex(codexData, page)
	CurrentPage = page or 1
	widget.setText("codexTitle", codexData.title)
	UpdateBasedOnPage(codexData.contentPages, CurrentPage)
	CurrentCodex = codexData
end

-- This is run when we click on a category button.
local function PopulateCodexEntriesForCategory(targetSpecies, speciesName)
	-- First off, let's clean up the list of old codex entries in case we had a previous category open already.
	widget.removeAllChildren("codexList")
	
	-- Update the display data to reflect on the new category we have selected. Remember, speciesName will be "Ambiguous" for the category that has no associated race.
	widget.setText("codexListRace", "Selected Category: " .. speciesName)
	
	-- We're going to iterate through our known codex entries again. Same thing, get the entries or a default empty table.
	local knownCodexEntries = player.getProperty("xcodex.knownCodexEntries") or {}
	
	-- NEW UPDATE: Alphabetical sorting on these too.
	-- To accomplish this we need to go over the elements and create "pseudo-buttons". We can then use table.sort to order these.
	local codexDataRegistry = {}
	for index = 1, #knownCodexEntries do
		local codexInfo = knownCodexEntries[index]
		-- {codexRawName, codexJsonPath}
		
		-- Same test as in PopulateCategories. Make sure the codex isn't one we no longer have access to in the game files.
		local rawCodexData = nil
		local exists = pcall(function ()
			rawCodexData = root.assetJson(codexInfo[2] .. codexInfo[1] .. ".codex")
		end)
		
		if exists then
			local codexSpecies = rawCodexData.species or ""
			-- Is the category of this codex the same as the category we want to push?
			if codexSpecies == targetSpecies then
				--print("Creating button for codex " .. tostring(codexInfo[1]))
				
				-- Did we specify a longCodexPages key, and more importantly, does that key have content (if it's empty, we might be using it as a placeholder!)
				if rawCodexData.longContentPages ~= nil and #rawCodexData.longContentPages > 0 then
					-- Yep! Let's replace the contentPages value we have stored here internally.
					rawCodexData.contentPages = rawCodexData.longContentPages
				end
				
				-- Now we need the title of this codex.
				local displayName = rawCodexData.title
				table.insert(codexDataRegistry, {displayName, {rawCodexData, codexInfo}})
				
			end
		end
	end
	
	-- Now let's call table.sort to get this done easily.
	table.sort(codexDataRegistry, function (alpha, bravo)
		local aName = alpha[1]
		local bName = bravo[1]
		
		-- Yes, it is possible to use < and > (and similar) on strings.
		-- Specifically < and > are used for alphabetical order. How convenient!
		return aName < bName
	end)
	
	for index = 1, #codexDataRegistry do
		local dataEntry = codexDataRegistry[index]
		local info = dataEntry[2]
		CreateButtonToReadCodex(info[1], info[2], index)
	end
end

-- Populates all of the data for the left-most part of the menu where the buttons representing the available races are located.
local function PopulateCategories()
	-- Let's access our known codex entries, or give an empty table if we haven't defined it yet.
	local knownCodexEntries = player.getProperty("xcodex.knownCodexEntries") or {}
	
	-- I want to order the buttons alphabetically.
	local buttonInfo = {}
	local existingAbbreviations = {}
	
	-- Create a new list element.
	local listTemplate = TEMPLATE_CODEX_RACE_CATEGORY
	widget.addChild("racialCategoryList", listTemplate, "racelist")
	
	-- Iterate through our known codex entries.
	for index = 1, #knownCodexEntries do
		local codexInfo = knownCodexEntries[index]
		-- codexInfo = {codexRawName, codexJsonPath}
		-- So for instance, {"protectorate2", "/codex/human/"}
		
		-- Our first test is very important! What if we had a modded codex and have since uninstalled the applicable mod?
		local rawCodexData = nil
		local exists = pcall(function ()
			-- This pcall will attempt to use root.assetJson to read the raw codex file. It will error (and subsequently return false) if this codex file no longer exists.
			rawCodexData = root.assetJson(codexInfo[2] .. codexInfo[1] .. ".codex")
		end)
		
		-- If the codex entry exists in the current context then we need to process it some more.
		if exists then
			-- The display name is the text shown on the button in the event that no race icon could be found. This is the text created via the GetNameAbbreviation function. It may not always be populated.
			local displayName = ""
			
			-- This is the species data included in the codex, or an empty string if it's not included as part of the codex.
			local codexSpecies = rawCodexData.species or ""
			
			-- The actual race name is the literal *display name* of the race from the .species file. Its default value is "Ambiguous".
			-- This value is given to the menu to display text that reflects on what the current selected category is. The "Ambiguous" category is for things without an associated race.
			local actualRaceName = "Ambiguous"
			
			-- Raw JSON of the .species file.
			local speciesData
			
			-- The first available preview image for the specified race, gathered via the race's defined genders (which must exist for a functional race).
			-- inb4 angry feminist because all the icons are male due to most ppl defining male first. ecksdee.
			local firstAvailableGenderImage = ""
			
			if codexSpecies ~= "" then
				-- First off -- Is the species specified? If it is, we need to see if we can find the .species file.
				local speciesDataExists = pcall(function ()
					-- Same thing as the rawCodexData thing above. This will work, or error and return false.
					speciesData = root.assetJson("/species/" .. codexSpecies .. ".species")
				end)
				if speciesDataExists then
					-- If we've made it here, the species data exists.
					local speciesDisplayData = speciesData.charCreationTooltip
					if speciesDisplayData and speciesDisplayData.title and #speciesDisplayData.title >= 1 then
						-- If this is true, the species' display name is adequately populated.
						-- This is where we MAY need to edit displayName. First things first -- Do we have an available image?
						local firstGender = GetFirstInTable(speciesData.genders)
						firstAvailableGenderImage = firstGender.characterImage or ""
						
						-- Uh-oh! We don't. We'll have to fall back to using an abbreviation.
						if firstAvailableGenderImage == "" then
							displayName = GetNameAbbreviation(speciesDisplayData.title, existingAbbreviations)
							table.insert(existingAbbreviations, displayName)
						end
						
						-- Oh, and populate the display name of the race. That one's important.
						actualRaceName = speciesDisplayData.title
					end
				end
			end
			
			-- Have we already made a button for this race? The player is probably going to have more than one codex entry for a given race.
			if not ExistingCategoryButtons[actualRaceName] then
			
				-- If we make it here, no, we don't already have a button. Tell Starbound to add a new list element.
				local newElement = widget.addListItem("racialCategoryList.racelist")
				
				-- Again, test if we had species data.
				if speciesData ~= nil then
					-- If we do, we need to set the pictures, so long as we actually have them
					if firstAvailableGenderImage ~= "" then
						-- print("Setting race image to", firstAvailableGenderImage)
						--widget.setImage("racialCategoryList.racelist." .. tostring(newElement) .. ".raceIcon", genderTable.characterImage)
						widget.setButtonImages("racialCategoryList.racelist." .. tostring(newElement) .. ".raceButton", 
							{
								base = firstAvailableGenderImage,
								hover = firstAvailableGenderImage .. "?brightness=30",
								pressed = firstAvailableGenderImage .. "?brightness=30",
								disabled = ""
							}
						)
					else
						-- We don't have the pictures! Let's use the displayName.
						-- print("Setting race image to nothing and using the abbreviated display name instead, which is", displayName)
						widget.setText("racialCategoryList.racelist." .. tostring(newElement) .. ".buttonLabel", displayName)
					end
				else
					--print("Could not set button icon -- race doesn't exist (this is the ambiguous table) or the race was unable to resolve an appropriate icon.")
					widget.setText("racialCategoryList.racelist." .. tostring(newElement) .. ".buttonLabel", TEXT_AMBIGUOUS_BUTTON)
				end
				
				-- Lastly, let's set the data of this specific new list element (the cumulative representation of the picture, display name, and button elements) to the actual race name.
				-- We use this data to associate buttons with actual race categories.
				widget.setData("racialCategoryList.racelist." .. tostring(newElement), {actualRaceName})
				
				-- Now populate this data.
				ExistingCategoryButtons[actualRaceName] = codexSpecies
			end
		end
	end
end

-----------------------
------ CALLBACKS ------
-----------------------

-- Run when a button for the codex list is clicked, that is, the title of an actual codex in the list of available known titles.
function ListButtonClicked(widgetName, widgetData)
	-- Do we have button data bindings for this button? If so, call OpenCodex with that data.
	-- Said data is the raw JSON of the codex file (including any edits we've made here on the fly, e.g. the longContentPages value population)
	local data = CodexButtonBindings[widgetName]
	if data then OpenCodex(data) end
end

-- Run when one of the racial category buttons are clicked.
function RaceButtonClicked(widgetName, widgetData)
	local itemId = widget.getListSelected("racialCategoryList.racelist")
	
	-- Now get the data associated with said list item. This was set near the bottom of PopulateCategories()
	local actualRaceName = widget.getData("racialCategoryList.racelist." .. tostring(itemId))[1]
	
	local codexSpecies = ExistingCategoryButtons[actualRaceName]
	if codexSpecies then PopulateCodexEntriesForCategory(codexSpecies, actualRaceName) end
end

-- Run when the "Previous Page" button is clicked.
function PreviousButtonClicked(widgetName, widgetData)
	if not PrevButtonEnabled then return end
	CurrentPage = CurrentPage - 1
	UpdateBasedOnPage(CurrentCodex.contentPages, CurrentPage)
end

-- Run when the "Next Page" button is clicked.
function NextButtonClicked(widgetName, widgetData)
	if not NextButtonEnabled then return end
	CurrentPage = CurrentPage + 1
	UpdateBasedOnPage(CurrentCodex.contentPages, CurrentPage)
end

------------------------------
------ LOADER FUNCTIONS ------
------------------------------

-- Added by InitUtility. Runs *after* init but *before* the first update() call.
function postinit()
	print, warn, error, assertwarn, assert, tostring = CreateLoggingOverride("[High-Fidelity Codex GUI]")
	
	-- Set UI to appear completely disabled, disabling the next and previous buttons.
	widget.setButtonEnabled("nextButton", false)
	widget.setButtonEnabled("prevButton", false)
	widget.setFontColor("nextButton", "#666666")
	widget.setFontColor("prevButton", "#666666")
	
	PopulateCategories()
end


-- Yes, this goes down here. Don't move it or you will break it.
require "/scripts/xcustomcodex/InitializationUtility.lua"