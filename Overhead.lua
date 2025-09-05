if not SUPERWOW_VERSION then
	return
end

local Regions
local Plate
local Childs
local ClickAreaWidth
local ClickAreaHeight

local Initialized = 0
local ParentCount = 0
local PlateCount = 0
local ParentWidth = 1
local ParentHeight = 1
local InactiveAlpha = 0.6
local TotemWidth = 32

local _, PlayerGUID = UnitExists("player")

local Registry = {}
local CastEvents = {}

local Backdrop = { bgFile =  "Interface\\BUTTONS\\WHITE8X8", tile = true, tileSize = 8 }

local Totems = {
	["Disease Cleansing Totem"] = "spell_nature_diseasecleansingtotem",
	["Earth Elemental Totem"] = "spell_nature_earthelemental_totem",
	["Earthbind Totem"] = "spell_nature_strengthofearthtotem02",
	["Fire Elemental Totem"] = "spell_fire_elemental_totem",
	["Fire Nova Totem"] = "spell_fire_sealoffire",
	["Fire Resistance Totem"] = "spell_fireresistancetotem_01",
	["Flametongue Totem"] = "spell_nature_guardianward",
	["Frost Resistance Totem"] = "spell_frostresistancetotem_01",
	["Grace of Air Totem"] = "spell_nature_invisibilitytotem",
	["Grounding Totem"] = "spell_nature_groundingtotem",
	["Healing Stream Totem"] = "Inv_spear_04",
	["Magma Totem"] = "spell_fire_selfdestruct",
	["Mana Spring Totem"] = "spell_nature_manaregentotem",
	["Mana Tide Totem"] = "spell_frost_summonwaterelemental",
	["Nature Resistance Totem"] = "spell_nature_natureresistancetotem",
	["Poison Cleansing Totem"] = "spell_nature_poisoncleansingtotem",
	["Searing Totem"] = "spell_fire_searingtotem",
	["Sentry Totem"] = "spell_nature_removecurse",
	["Stoneclaw Totem"] = "spell_nature_stoneclawtotem",
	["Stoneskin Totem"] = "spell_nature_stoneskintotem",
	["Strength of Earth Totem"] = "spell_nature_earthbindtotem",
	["Totem of Wrath"] = "spell_fire_totemofwrath",
	["Tremor Totem"] = "spell_nature_tremortotem",
	["Windfury Totem"] = "spell_nature_windfury",
	["Windwall Totem"] = "spell_nature_earthbind",
	["Wrath of Air Totem"] = "spell_nature_slowingtotem",
}

local ClassColors = {
	["WARRIOR"] = { r = 0.78, g = 0.61, b = 0.43, hex = "|cffc79c6e" },
	["MAGE"]    = { r = 0.41, g = 0.8,  b = 0.94, hex = "|cff69ccf0" },
	["ROGUE"]   = { r = 1.0,  g = 0.96, b = 0.41, hex = "|cfffff569" },
	["DRUID"]   = { r = 1.0,  g = 0.49, b = 0.04, hex = "|cffff7d0a" },
	["HUNTER"]  = { r = 0.67, g = 0.83, b = 0.45, hex = "|cffabd473" },
	["SHAMAN"]  = { r = 0.0,  g = 0.44, b = 0.87, hex = "|cff0070de" },
	["PRIEST"]  = { r = 1.0,  g = 1.0,  b = 1.0,  hex = "|cffffffff" },
	["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, hex = "|cff9482c9" },
	["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, hex = "|cfff58cba" },
}

local function IsNamePlate(frame)
	if frame:GetObjectType() ~= "Button" then return false end
	Regions = Plate:GetRegions()
	if not Regions then return false end
	if not Regions.GetObjectType then return false end
	if not Regions.GetTexture then return false end
	if Regions:GetObjectType() ~= "Texture" then return false end
	return Regions:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

local function wipe(table)
	if type(table) ~= "table" then
		return
	end
	for k in pairs(table) do
		table[k] = nil
	end
end

print = print or function(...)
	local size = getn(arg)
	for i = 1, size do
		arg[i] = tostring(arg[i])
	end
	local msg = size > 1 and table.concat(arg, ", ") or tostring(arg[1])
	DEFAULT_CHAT_FRAME:AddMessage(msg)
	return msg
end

local Overhead = CreateFrame("Frame", "OverheadFrame", UIParent)
Overhead:RegisterEvent("UNIT_CASTEVENT")
Overhead:RegisterEvent("PLAYER_ENTER_COMBAT")
Overhead:RegisterEvent("PLAYER_LEAVE_COMBAT")
Overhead.isAttacking = false

Overhead:SetScript("OnEvent", function()
	if event == "UNIT_CASTEVENT" then
		local casterGUID = arg1
		if casterGUID == PlayerGUID then
			return
		end
		-- local targetGUID = arg2
		local eventType = arg3 -- "START", "CAST", "FAIL", "CHANNEL", "MAINHAND", "OFFHAND"
		local spellID = arg4
		local castDuration = arg5
		local spellName, _, icon = SpellInfo(spellID)
		if eventType == "MAINHAND" or eventType == "OFFHAND" then
			return
		end
		if eventType == "CAST" then
			if not CastEvents[casterGUID] or spellID ~= CastEvents[casterGUID].spell then
				return
			end
		end
		if eventType == "START" or eventType == "CHANNEL" then
			if not CastEvents[casterGUID] then
				CastEvents[casterGUID] = {}
			end
			wipe(CastEvents[casterGUID])
			CastEvents[casterGUID].event = eventType
			CastEvents[casterGUID].spellID = spellID
			CastEvents[casterGUID].spellName = spellName
			CastEvents[casterGUID].icon = icon
			CastEvents[casterGUID].startTime = GetTime()
			CastEvents[casterGUID].endTime = castDuration and GetTime() + castDuration / 1000
			CastEvents[casterGUID].duration = castDuration and castDuration / 1000 or nil
		elseif eventType == "FAIL" then
			wipe(CastEvents[casterGUID])
		end
	elseif event == "PLAYER_ENTER_COMBAT" then
		Overhead.isAttacking = true
	elseif event == "PLAYER_LEAVE_COMBAT" then
		Overhead.isAttacking = false
		Overhead.frame = nil
		Overhead.time = nil
	end
end)

local function OnShow()
	this:SetHeight(ParentHeight)
	this:SetWidth(ParentWidth)
	this.unit = this:GetName(1)
	this.overhead.clickArea.unit = this.unit
	if this.unit and UnitIsPlayer(this.unit) then
		this.overhead.healthBar:SetStatusBarColor(this.classColor.r, this.classColor.g, this.classColor.b)
	else
		this.overhead.healthBar:SetStatusBarColor(this.healthBar:GetStatusBarColor())
	end
end

local function OnHide()
	this.unit = nil
	this.overhead.clickArea.unit = nil
end

local function CreatePlate(parent)
	local scale = UIParent:GetEffectiveScale()
	local plateName = "OverheadPlate"..PlateCount
	local guid = parent:GetName(1)
	local _, class = UnitClass(guid)

	local nameplate = CreateFrame("Frame", plateName, parent)
	nameplate:SetWidth(parent:GetWidth())
	nameplate:SetHeight(parent:GetHeight())
	nameplate:SetPoint("CENTER", parent, "CENTER", 0, 12)
	nameplate:SetFrameLevel(parent:GetFrameLevel()+1)
	nameplate:SetScale(scale)
	-- nameplate:SetBackdrop(backdrop)
	-- nameplate:SetBackdropColor(0, 0, 0, 0.5)

	nameplate.parent = parent
	parent.overhead = nameplate

	parent:SetFrameStrata("BACKGROUND")
	parent:SetHeight(ParentHeight)
	parent:SetWidth(ParentWidth)
	parent:SetScript("OnShow", OnShow)
	parent:SetScript("OnHide", OnHide)
	parent:EnableMouse(false)
	parent.unit = guid
	parent.classColor = ClassColors[class]

	local border, highlight, name, level, levelIcon, raidIcon = parent:GetRegions()
	parent.border = border
	parent.highlight = highlight
	parent.name = name
	parent.level = level
	parent.levelIcon = levelIcon
	parent.raidIcon = raidIcon

	parent.healthBar = parent:GetChildren()
	parent.healthBar:Hide()

	nameplate.healthBar = CreateFrame("StatusBar", plateName.."Health", nameplate)
	nameplate.healthBar:SetWidth(parent.healthBar:GetWidth())
	nameplate.healthBar:SetHeight(parent.healthBar:GetHeight())
	local point, relativeTo, relativePoint, x, y = parent.healthBar:GetPoint()
	nameplate.healthBar:SetPoint(point, nameplate, relativePoint, x, y)
	nameplate.healthBar:SetOrientation("HORIZONTAL")
	nameplate.healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	-- nameplate.healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
	nameplate.healthBar:SetFrameLevel(1)

	if parent.unit and UnitIsPlayer(parent.unit) then
		nameplate.healthBar:SetStatusBarColor(parent.classColor.r, parent.classColor.g, parent.classColor.b)
	else
		nameplate.healthBar:SetStatusBarColor(parent.healthBar:GetStatusBarColor())
	end
	nameplate.healthBar:SetMinMaxValues(parent.healthBar:GetMinMaxValues())
	nameplate.healthBar:SetValue(parent.healthBar:GetValue())

	parent.healthBar:SetScript("OnValueChanged", function()
		local unit = parent:GetName(1)
		if unit and UnitIsPlayer(unit) then
			local _, class = UnitClass(unit)
			parent.classColor = ClassColors[class]
			nameplate.healthBar:SetStatusBarColor(parent.classColor.r, parent.classColor.g, parent.classColor.b)
		else
			nameplate.healthBar:SetStatusBarColor(parent.healthBar:GetStatusBarColor())
		end
		nameplate.healthBar:SetMinMaxValues(parent.healthBar:GetMinMaxValues())
		nameplate.healthBar:SetValue(parent.healthBar:GetValue())
	end)

	ClickAreaWidth = parent.healthBar:GetWidth() + 30
	ClickAreaHeight = parent.healthBar:GetHeight() + 8

	nameplate.clickArea = CreateFrame("Button", plateName.."ClickArea", nameplate)
	nameplate.clickArea:SetPoint("TOPLEFT", nameplate.healthBar, "TOPLEFT", -2, 4)
	nameplate.clickArea:SetWidth(ClickAreaWidth)
	nameplate.clickArea:SetHeight(ClickAreaHeight)
	nameplate.clickArea:SetFrameLevel(2)
	-- nameplate.clickArea:SetBackdrop(backdrop)
	-- nameplate.clickArea:SetBackdropColor(0, 1, 0, 0.2)
	nameplate.clickArea:SetScript("OnMouseDown", function()
		if arg1 == "RightButton" then
			MouselookStart()
			Overhead.time = GetTime()
			Overhead.frame = parent
		else
			parent:Click()
			Overhead.frame = nil
			Overhead.time = nil
		end
	end)

	nameplate.clickArea:SetScript("OnEnter", function()
		nameplate:SetFrameStrata("MEDIUM")
		nameplate:SetAlpha(1)
		local r, g, b  = parent.name:GetTextColor()
		if r > 0.9 and g > 0.9 and b > 0.9 then
			parent.name:SetTextColor(1, 1, 0)
		end
		-- SetMouseoverUnit(parent:GetName(1))
		if nameplate.totemIcon:IsShown() then
			nameplate.totemHighlight:Show()
		end
	end)

	nameplate.clickArea:SetScript("OnLeave", function()
		if not nameplate.strata then
			if not SpellIsTargeting() then
				nameplate:SetFrameStrata("BACKGROUND")
			end
			nameplate:SetAlpha(1)
		elseif nameplate.strata then
			nameplate:SetFrameStrata("LOW")
			nameplate:SetAlpha(1)
		else
			nameplate:SetAlpha(InactiveAlpha)
		end
		local r, g, b  = parent.name:GetTextColor()
		if not (r > 0.9 and g < 0.2 and b < 0.2) then
			parent.name:SetTextColor(1, 1, 1)
		end
		nameplate.totemHighlight:Hide()
		-- SetMouseoverUnit()
	end)

	nameplate.glow = nameplate.healthBar:CreateTexture(plateName.."Glow", "BACKGROUND")
	nameplate.glow:SetPoint("CENTER", nameplate.healthBar, "CENTER", 10, 0)
	nameplate.glow:SetTexture("Interface\\AddOns\\Overhead\\Glow")
	nameplate.glow:SetWidth(nameplate.clickArea:GetWidth() * 2)
	nameplate.glow:SetHeight(nameplate.clickArea:GetHeight() * 4)
	nameplate.glow:SetBlendMode("ADD")
	nameplate.glow:SetVertexColor(1, 1, 1, 0.5)
	nameplate.glow:Hide()

	-- nameplate.background = nameplate.healthBar:CreateTexture(plateName.."Background", "BORDER")
	-- nameplate.background:SetPoint("CENTER", nameplate.healthBar, "CENTER", 0, 0)
	-- nameplate.background:SetWidth(nameplate.healthBar:GetWidth())
	-- nameplate.background:SetHeight(nameplate.healthBar:GetHeight())
	-- nameplate.background:SetTexture(0, 0, 0, 1)

	parent.border:SetParent(nameplate.healthBar)
	parent.border:ClearAllPoints()
	parent.border:SetPoint("BOTTOMLEFT", nameplate.healthBar, "BOTTOMLEFT", -5, -6)
	parent.border:SetWidth(nameplate.healthBar:GetWidth() + 32)
	parent.border:SetHeight(nameplate.healthBar:GetHeight() * 2 + 21)
	parent.border:SetDrawLayer("OVERLAY")

	nameplate.highlight = nameplate.clickArea:CreateTexture(nil, "HIGHLIGHT")
	nameplate.highlight:SetWidth(parent.border:GetWidth())
	nameplate.highlight:SetHeight(parent.border:GetHeight())
	nameplate.highlight:SetPoint(parent.border:GetPoint())
	nameplate.highlight:SetTexture(parent.highlight:GetTexture())
	nameplate.highlight:SetAlpha(0.6)
	nameplate.highlight:SetBlendMode("ADD")

	parent.raidIcon:SetParent(nameplate)
	parent.raidIcon:ClearAllPoints()
	parent.raidIcon:SetPoint("RIGHT", nameplate.healthBar, "LEFT", 0, 0)
	parent.raidIcon:SetDrawLayer("OVERLAY")

	parent.level:SetParent(nameplate)
	parent.level:ClearAllPoints()
	parent.level:SetPoint("CENTER", nameplate.healthBar, "RIGHT", 12, 0)
	parent.level:SetDrawLayer("OVERLAY")

	parent.levelIcon:SetParent(nameplate)
	parent.levelIcon:ClearAllPoints()
	parent.levelIcon:SetPoint("LEFT", nameplate.healthBar, "RIGHT", 6, 0)
	parent.levelIcon:SetDrawLayer("OVERLAY")

	parent.name:SetParent(nameplate)
	parent.name:ClearAllPoints()
	parent.name:SetPoint("BOTTOM", nameplate.healthBar, "TOP", 8, 8)
	parent.name:SetDrawLayer("OVERLAY")

	nameplate.elite = nameplate:CreateTexture(nil, "OVERLAY")
	nameplate.elite:SetTexture("Interface\\AddOns\\Overhead\\Elite")
	nameplate.elite:SetPoint("LEFT", nameplate.healthBar, "RIGHT", -6, -5)
	nameplate.elite:SetHeight(42)
	nameplate.elite:SetWidth(78)

	nameplate.castBar = CreateFrame("StatusBar", plateName.."CastBar", nameplate)
	nameplate.castBar:SetWidth(nameplate.healthBar:GetWidth() - 23)
	nameplate.castBar:SetHeight(nameplate.healthBar:GetHeight())
	nameplate.castBar:SetPoint("TOPLEFT", nameplate.healthBar, "BOTTOMLEFT", 22, -4)
	nameplate.castBar:SetOrientation("HORIZONTAL")
	nameplate.castBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	nameplate.castBar:SetStatusBarColor(1, 0.82, 0, 1)
	nameplate.castBar:SetFrameLevel(2)
	nameplate.castBar:Hide()

	nameplate.castBarText = nameplate.castBar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	nameplate.castBarText:SetWidth(nameplate.castBar:GetWidth() - 2)
	nameplate.castBarText:SetHeight(nameplate.castBar:GetHeight())
	nameplate.castBarText:SetPoint("CENTER", nameplate.castBar, "CENTER", 2, 0)

	nameplate.castBarSpark = nameplate.castBar:CreateTexture(nil, "OVERLAY")
	nameplate.castBarSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	nameplate.castBarSpark:SetWidth(32)
	nameplate.castBarSpark:SetHeight(32)
	nameplate.castBarSpark:SetBlendMode("ADD")

	nameplate.castBarBorder = nameplate.castBar:CreateTexture(nil, "ARTWORK")
	nameplate.castBarBorder:SetTexture("Interface\\AddOns\\Overhead\\CastBar")
	nameplate.castBarBorder:SetPoint("CENTER", nameplate.castBar, "CENTER", -9, 0)

	nameplate.castBarIcon = nameplate.castBar:CreateTexture(plateName.."CastBarIconTexture", "OVERLAY")
	nameplate.castBarIcon:SetWidth(13)
	nameplate.castBarIcon:SetHeight(13)
	nameplate.castBarIcon:SetPoint("CENTER", nameplate.castBar, "LEFT", -10, 0)
	nameplate.castBarIcon:SetTexCoord(0.07, 0.9, 0.1, 0.93)
	nameplate.castBarIcon:SetTexture(0)

	nameplate.totemIcon = nameplate:CreateTexture(nil, "BORDER")
	nameplate.totemIcon:SetWidth(TotemWidth)
	nameplate.totemIcon:SetHeight(TotemWidth)
	nameplate.totemIcon:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
	nameplate.totemIcon:SetTexCoord(0.07, 0.90, 0.1, 0.93)
	nameplate.totemIcon:SetTexture("Interface\\Icons\\spell_fire_selfdestruct")
	nameplate.totemIcon:Hide()

	nameplate.totemGlow = nameplate:CreateTexture(nil, "BACKGROUND")
	nameplate.totemGlow:SetTexture("Interface\\AddOns\\Overhead\\Glow")
	nameplate.totemGlow:SetWidth(TotemWidth * 3)
	nameplate.totemGlow:SetHeight(TotemWidth * 3)
	nameplate.totemGlow:SetPoint("CENTER", nameplate.totemIcon)
	nameplate.totemGlow:SetVertexColor(1, 1, 1, 0.4)
	nameplate.totemGlow:Hide()

	nameplate.totemHighlight = nameplate.clickArea:CreateTexture(nil, "HIGHLIGHT")
	nameplate.totemHighlight:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	nameplate.totemHighlight:SetWidth(58)
	nameplate.totemHighlight:SetHeight(58)
	nameplate.totemHighlight:SetPoint("CENTER", nameplate.totemIcon, 1, 1)
	nameplate.totemHighlight:SetBlendMode("ADD")
	nameplate.totemHighlight:SetVertexColor(1, 1, 1, 0.5)
	nameplate.totemHighlight:Hide()

	local castInfo, isTarget, unit, creatureType
	local icon = "spell_fire_selfdestruct"
	local sparkPosition, barValue = 0, 0
	local minimized = false
	local isMouseOver = false

	nameplate:SetScript("OnUpdate", function()
		isTarget = UnitExists("target") and parent:GetAlpha() == 1
		unit = parent:GetName(1)
		creatureType = UnitCreatureType(unit)
		nameplate.clickArea.unit = unit
		parent:EnableMouse(false)
		isMouseOver = GetMouseFocus() == nameplate.clickArea

		if creatureType == "Critter" then
			minimized = true
			nameplate.healthBar:Hide()
			nameplate.highlight:Hide()
			nameplate.totemIcon:Hide()
			nameplate.clickArea:EnableMouse(false)
			parent.level:SetPoint("CENTER", parent.name, "RIGHT", 12, 0)
		elseif creatureType == "Totem" then
			minimized = true
			nameplate.healthBar:Hide()
			nameplate.highlight:Hide()
			parent.level:Hide()
			parent.name:Hide()
			for k, v in pairs(Totems) do
				if strfind(UnitName(unit), k) then
					icon = v
					break
				end
			end
			nameplate.totemIcon:SetTexture("Interface\\Icons\\"..icon)
			nameplate.totemIcon:Show()
			nameplate.clickArea:SetWidth(TotemWidth)
			nameplate.clickArea:SetHeight(TotemWidth)
			nameplate.clickArea:SetPoint("TOPLEFT", nameplate.totemIcon, "TOPLEFT", 0, 0)
			nameplate.clickArea:EnableMouse(true)
		else
			minimized = false
			nameplate.totemIcon:Hide()
			nameplate.healthBar:Show()
			nameplate.highlight:Show()
			parent.level:SetPoint("CENTER", nameplate.healthBar, "RIGHT", 12, 0)
			if UnitClassification(unit) ~= "worldboss" then
				parent.level:Show()
			else
				parent.level:Hide()
			end
			parent.name:Show()
			nameplate.clickArea:SetWidth(ClickAreaWidth)
			nameplate.clickArea:SetHeight(ClickAreaHeight)
			nameplate.clickArea:SetPoint("TOPLEFT", nameplate.healthBar, "TOPLEFT", -2, 4)
			nameplate.clickArea:EnableMouse(true)
		end

		if isTarget and not nameplate.strata then
			nameplate:SetFrameStrata("LOW")
			nameplate.strata = true
			nameplate.glow:Show()
			if nameplate.totemIcon:IsShown() then
				nameplate.totemGlow:Show()
			end
		elseif not isTarget and nameplate.strata then
			nameplate:SetFrameStrata("BACKGROUND")
			nameplate.strata = false
			nameplate.glow:Hide()
			nameplate.totemGlow:Hide()
		end

		if isTarget or not UnitExists("target") or creatureType == "Totem" or isMouseOver then
			nameplate:SetAlpha(1)
		else
			nameplate:SetAlpha(InactiveAlpha)
		end

		if UnitClassification(unit) ~= "normal" then
			nameplate.elite:Show()
		else
			nameplate.elite:Hide()
		end

		if UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) then
			parent.border:SetDesaturated(true)
			nameplate.healthBar:SetStatusBarColor(0.5, 0.5, 0.5)
		else
			parent.border:SetDesaturated(false)
			if unit and UnitIsPlayer(unit) then
				nameplate.healthBar:SetStatusBarColor(parent.classColor.r, parent.classColor.g, parent.classColor.b)
			else
				nameplate.healthBar:SetStatusBarColor(parent.healthBar:GetStatusBarColor())
			end
		end

		if SpellIsTargeting() then
			nameplate.clickArea:EnableMouse(false)
		elseif not minimized then
			nameplate.clickArea:EnableMouse(true)
		end

		if isMouseOver then
			if UnitCanAttack("player", unit) then
				if CheckInteractDistance(unit, 3) then
					SetCursor("ATTACK_CURSOR")
				else
					SetCursor("Interface\\Cursor\\UnableAttack")
				end
			end
		end

		castInfo = CastEvents[unit]
		if castInfo and castInfo.spellID then
			if castInfo.startTime + castInfo.duration < GetTime() then
				wipe(castInfo)
				nameplate.castBar:Hide()
				nameplate.clickArea:SetHeight(ClickAreaHeight)
				return
			elseif castInfo.event == "CAST" or castInfo.event == "FAIL" then
				wipe(castInfo)
				nameplate.castBar:Hide()
				nameplate.clickArea:SetHeight(ClickAreaHeight)
				return
			end
			nameplate.castBar:SetMinMaxValues(castInfo.startTime, castInfo.endTime)
			sparkPosition = 0
			if castInfo.event == "CHANNEL" then
				barValue = castInfo.startTime + (castInfo.endTime  - GetTime())
				nameplate.castBar:SetValue(barValue)
				sparkPosition = ((barValue - castInfo.startTime) / (castInfo.endTime - castInfo.startTime)) *  nameplate.castBar:GetWidth()
			else
				sparkPosition = ((GetTime() - castInfo.startTime) / (castInfo.endTime - castInfo.startTime)) * nameplate.castBar:GetWidth()
				nameplate.castBar:SetValue(GetTime())
			end
			nameplate.castBarSpark:SetPoint("CENTER", nameplate.castBar, "LEFT", sparkPosition, 0)
			nameplate.castBarIcon:SetTexture(castInfo.icon)
			nameplate.castBar:Show()
			nameplate.castBarText:SetText(castInfo.spellName)
			nameplate.clickArea:SetHeight(ClickAreaHeight + nameplate.castBar:GetHeight() + 4)
		else
			nameplate.castBar:Hide()
		end
	end)
end

Overhead:SetScript("OnUpdate", function()
	ParentCount = WorldFrame:GetNumChildren()
	if Initialized < ParentCount then
		Childs = { WorldFrame:GetChildren() }
		for i = Initialized + 1, ParentCount do
			Plate = Childs[i]
			if IsNamePlate(Plate) and not Registry[Plate] then
				CreatePlate(Plate)
				Registry[Plate] = Plate
				PlateCount = PlateCount + 1
			end
		end
		Initialized = ParentCount
	end

	if not Overhead.time or not Overhead.frame then
		return
	end

	if not IsMouselooking() and Overhead.time + 0.5 < GetTime() then
		return
	end

	if not IsMouselooking() then
		Overhead.frame:Click("LeftButton")
		if UnitCanAttack("player", "target") and not Overhead.isAttacking then
			AttackTarget()
			Overhead.frame = nil
			Overhead.time = nil
		end
	end
end)
