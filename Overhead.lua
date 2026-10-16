if not SUPERWOW_VERSION then return end

local CLICK_AREA_WIDTH
local CLICK_AREA_HEIGHT

local numChildrenLastFrame = 0
local numNameplatesCreated = 0
local PARENT_WIDTH = 1
local PARENT_HEIGHT = 1
local ALPHA_INACTIVE = 0.6
local TOTEM_WIDTH = 32


local Registry = {}
local CastEvents = {}

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
	["MAGE"]	= { r = 0.41, g = 0.8,  b = 0.94, hex = "|cff69ccf0" },
	["ROGUE"]   = { r = 1.0,  g = 0.96, b = 0.41, hex = "|cfffff569" },
	["DRUID"]   = { r = 1.0,  g = 0.49, b = 0.04, hex = "|cffff7d0a" },
	["HUNTER"]  = { r = 0.67, g = 0.83, b = 0.45, hex = "|cffabd473" },
	["SHAMAN"]  = { r = 0.0,  g = 0.44, b = 0.87, hex = "|cff0070de" },
	["PRIEST"]  = { r = 1.0,  g = 1.0,  b = 1.0,  hex = "|cffffffff" },
	["WARLOCK"] = { r = 0.58, g = 0.51, b = 0.79, hex = "|cff9482c9" },
	["PALADIN"] = { r = 0.96, g = 0.55, b = 0.73, hex = "|cfff58cba" },
}

local function IsNamePlate(frame)
	if not (frame and frame.GetObjectType) then return false end
	if frame:GetObjectType() ~= "Button" then return false end
	local regions = frame:GetRegions()
	if not (regions and regions.GetObjectType and regions.GetTexture) then return false end
	return regions:GetObjectType() == "Texture" and regions:GetTexture() == "Interface\\Tooltips\\Nameplate-Border"
end

local wipe = table.wipe or function(t)
	if not (t and type(t) == "table") then error("Usage: table.wipe(table)") return end
	for k in pairs(t) do rawset(t, k, nil) end
	table.setn(t, 0)
	return t
end

print = print or function(...)
	for i = 1, arg.n do arg[i] = tostring(arg[i]) end
	DEFAULT_CHAT_FRAME:AddMessage(table.concat(arg, " "))
end

local Overhead = CreateFrame("Frame", "OverheadFrame", UIParent)
Overhead:RegisterEvent("UNIT_CASTEVENT")
Overhead:RegisterEvent("PLAYER_ENTER_COMBAT")
Overhead:RegisterEvent("PLAYER_LEAVE_COMBAT")
Overhead.isAttacking = false
Overhead.frame = nil
Overhead.time = nil

Overhead:SetScript("OnEvent", function()
	if event == "UNIT_CASTEVENT" then
		local casterGUID = arg1
		local _, playerGUID = UnitExists("player")
		if casterGUID == playerGUID then
			return
		end
		-- local targetGUID = arg2
		local eventType = arg3 -- "START", "CAST", "FAIL", "CHANNEL", "MAINHAND", "OFFHAND"
		local spellID = arg4
		local castDuration = (arg5 or 0) / 1000
		local spellName, _, icon = SpellInfo(spellID)
		if eventType == "MAINHAND" or eventType == "OFFHAND" then
			return
		end
		if eventType == "CAST" then
			if not CastEvents[casterGUID] or spellID ~= CastEvents[casterGUID].spellID then
				return
			end
		end
		if eventType == "START" or eventType == "CHANNEL" then
			if not CastEvents[casterGUID] then
				CastEvents[casterGUID] = {}
			else
				wipe(CastEvents[casterGUID])
			end
			local now = GetTime()
			CastEvents[casterGUID].event = eventType
			CastEvents[casterGUID].spellID = spellID
			CastEvents[casterGUID].spellName = spellName
			CastEvents[casterGUID].icon = icon
			CastEvents[casterGUID].startTime = now
			CastEvents[casterGUID].duration = castDuration
			CastEvents[casterGUID].endTime = now + castDuration
		elseif eventType == "FAIL" then
			if CastEvents[casterGUID] then
				wipe(CastEvents[casterGUID])
			end
		end
	elseif event == "PLAYER_ENTER_COMBAT" then
		Overhead.isAttacking = true
	elseif event == "PLAYER_LEAVE_COMBAT" then
		Overhead.isAttacking = false
		Overhead.frame = nil
		Overhead.time = nil
	end
end)

local function OnValueChanged()
	local parent = this:GetParent()
	local unit = parent:GetName(1)
	local nameplate = parent.overhead
	if unit and UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local color = ClassColors[class]
		nameplate.healthBar:SetStatusBarColor(color.r, color.g, color.b)
	else
		nameplate.healthBar:SetStatusBarColor(parent.healthBar:GetStatusBarColor())
	end
	nameplate.healthBar:SetMinMaxValues(parent.healthBar:GetMinMaxValues())
	nameplate.healthBar:SetValue(parent.healthBar:GetValue())
end

local function OnMouseDown()
	if arg1 == "RightButton" then
		MouselookStart()
		Overhead.time = GetTime() + 0.5
		Overhead.frame = this:GetParent().parent
	else
		this:GetParent().parent:Click()
		Overhead.frame = nil
		Overhead.time = nil
	end
end

local function OnEnter()
	if SpellIsTargeting() then
		return
	end
	local nameplate = this:GetParent()
	nameplate:SetFrameStrata("MEDIUM")
	nameplate:SetAlpha(1)
	nameplate.name:SetTextColor(1, 1, 0)
	SetMouseoverUnit(nameplate.parent:GetName(1))
	if nameplate.totemIcon:IsShown() then
		nameplate.totemHighlight:Show()
	end
end

local function OnLeave()
	if SpellIsTargeting() then
		return
	end
	local nameplate = this:GetParent()
	local parent = nameplate.parent
	if not nameplate.strata then
		nameplate:SetFrameStrata("BACKGROUND")
		nameplate:SetAlpha(1)
	elseif nameplate.strata then
		nameplate:SetFrameStrata("LOW")
		nameplate:SetAlpha(1)
	else
		nameplate:SetAlpha(ALPHA_INACTIVE)
	end
	if not UnitIsUnit("target", parent.unit or "") then
		nameplate.name:SetTextColor(1, 1, 1)
	end
	nameplate.totemHighlight:Hide()
	SetMouseoverUnit(nil)
end

local function OnUpdate(self)
	local minimized = false
	local nameplate = self or this
	local parent = nameplate.parent
	local unit = parent:GetName(1)
	local isTarget = UnitIsUnit("target", unit)
	local isMouseOver = GetMouseFocus() == nameplate.clickArea
	local creatureType = UnitCreatureType(unit)
	nameplate.clickArea.unit = unit
	parent:EnableMouse(false)
	nameplate.name:SetText(parent.name:GetText())

	if creatureType == "Critter" then
		minimized = true
		nameplate.healthBar:Hide()
		nameplate.highlight:Hide()
		nameplate.totemIcon:Hide()
		nameplate.clickArea:Hide()
		nameplate.name:Hide()
		parent.level:Hide()
	elseif creatureType == "Totem" then
		minimized = true
		nameplate.healthBar:Hide()
		nameplate.highlight:Hide()
		parent.level:Hide()
		nameplate.name:Hide()
		local icon = "spell_fire_selfdestruct"
		for k, v in pairs(Totems) do
			if string.find(UnitName(unit), k, 1, true) then
				icon = v
				break
			end
		end
		nameplate.totemIcon:SetTexture("Interface\\Icons\\"..icon)
		nameplate.totemIcon:Show()
		nameplate.clickArea:SetWidth(TOTEM_WIDTH)
		nameplate.clickArea:SetHeight(TOTEM_WIDTH)
		nameplate.clickArea:SetPoint("TOPLEFT", nameplate.totemIcon, "TOPLEFT", 0, 0)
		nameplate.clickArea:Show()
	else
		minimized = false
		nameplate.totemIcon:Hide()
		nameplate.healthBar:Show()
		nameplate.highlight:Show()
		parent.level:SetPoint("CENTER", nameplate.healthBar, "RIGHT", 11, 0)
		if UnitClassification(unit) ~= "worldboss" and UnitLevel(unit) > 0 then
			parent.level:Show()
		else
			parent.level:Hide()
		end
		nameplate.name:Show()
		nameplate.clickArea:SetWidth(CLICK_AREA_WIDTH)
		nameplate.clickArea:SetHeight(CLICK_AREA_HEIGHT)
		nameplate.clickArea:SetPoint("TOPLEFT", nameplate.healthBar, "TOPLEFT", -2, 4)
		nameplate.clickArea:Show()
	end

	if isTarget then
		if not nameplate.strata then
			nameplate:SetFrameStrata("LOW")
			nameplate.strata = true
		end
		nameplate.glow:Show()
		nameplate.name:SetTextColor(1, 1, 0)
		if nameplate.totemIcon:IsShown() then
			nameplate.totemGlow:Show()
		end
	else
		if nameplate.strata then
			nameplate:SetFrameStrata("BACKGROUND")
			nameplate.strata = false
		end
		nameplate.glow:Hide()
		nameplate.totemGlow:Hide()
		nameplate.name:SetTextColor(1, 1, 1)
	end

	if UnitExists("mouseover") and not isTarget and UnitIsUnit(unit, "mouseover") and not nameplate.strata then
		nameplate:SetFrameStrata("MEDIUM")
		nameplate.strata = true
		nameplate.name:SetTextColor(1, 1, 0)
	elseif not isTarget and nameplate.strata then
		nameplate:SetFrameStrata("BACKGROUND")
		nameplate.strata = false
		nameplate.name:SetTextColor(1, 1, 1)
	end

	if isTarget or not UnitExists("target") or creatureType == "Totem" or isMouseOver or (UnitExists("mouseover") and UnitIsUnit(unit, "mouseover")) then
		nameplate:SetAlpha(1)
	else
		nameplate:SetAlpha(ALPHA_INACTIVE)
	end

	if UnitClassification(unit) ~= "normal" and not minimized then
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
			local _, class = UnitClass(unit)
			local color = ClassColors[class]
			nameplate.healthBar:SetStatusBarColor(color.r, color.g, color.b)
		else
			nameplate.healthBar:SetStatusBarColor(parent.healthBar:GetStatusBarColor())
		end
	end

	if SpellIsTargeting() then
		nameplate.clickArea:Hide()
	elseif not minimized then
		nameplate.clickArea:Show()
	end

	if isMouseOver then
		if UnitCanAttack("player", unit) then
			if CheckInteractDistance(unit, 3) then
				SetCursor("ATTACK_CURSOR")
			else
				SetCursor("ATTACK_ERROR_CURSOR")
			end
		elseif not SpellIsTargeting() then
			ResetCursor()
		end
	end

	local castInfo = CastEvents[unit]
	if castInfo and castInfo.spellID then
		local now = GetTime()
		local startTime = castInfo.startTime
		local endTime = castInfo.endTime
		local event = castInfo.event
		if (startTime + castInfo.duration < now) or (event == "CAST" or event == "FAIL") then
			wipe(castInfo)
			nameplate.castBar:Hide()
			nameplate.clickArea:SetHeight(CLICK_AREA_HEIGHT)
			return
		end
		nameplate.castBar:SetMinMaxValues(startTime, endTime)
		local sparkPosition, barValue = 0, 0
		if event == "CHANNEL" then
			barValue = startTime + (endTime - now)
			nameplate.castBar:SetValue(barValue)
			sparkPosition = ((barValue - startTime) / (endTime - startTime)) * nameplate.castBar:GetWidth()
		else
			sparkPosition = ((now - startTime) / (endTime - startTime)) * nameplate.castBar:GetWidth()
			nameplate.castBar:SetValue(now)
		end
		nameplate.castBarSpark:SetPoint("CENTER", nameplate.castBar, "LEFT", sparkPosition, 0)
		nameplate.castBarIcon:SetTexture(castInfo.icon)
		nameplate.castBar:Show()
		nameplate.castBarText:SetText(castInfo.spellName)
		nameplate.clickArea:SetHeight(CLICK_AREA_HEIGHT + nameplate.castBar:GetHeight() + 4)
	else
		nameplate.castBar:Hide()
		nameplate.clickArea:SetHeight(CLICK_AREA_HEIGHT)
	end
end

local function OnShow(self)
	local parent = self or this
	parent:SetHeight(PARENT_HEIGHT)
	parent:SetWidth(PARENT_WIDTH)
	parent.unit = parent:GetName(1)
	OnUpdate(parent.overhead)
end

local function CreatePlate(parent)
	local scale = UIParent:GetEffectiveScale()
	local guid = parent:GetName(1)

	local nameplate = CreateFrame("Frame", "OverheadPlate"..numNameplatesCreated, parent)
	nameplate:SetWidth(parent:GetWidth())
	nameplate:SetHeight(parent:GetHeight())
	nameplate:SetPoint("CENTER", parent, "CENTER", 0, 12)
	nameplate:SetFrameLevel(parent:GetFrameLevel()+1)
	nameplate:SetScale(scale)

	nameplate.parent = parent
	parent.overhead = nameplate

	parent:SetFrameStrata("BACKGROUND")
	parent:SetHeight(PARENT_HEIGHT)
	parent:SetWidth(PARENT_WIDTH)
	parent:SetScript("OnShow", OnShow)
	parent:EnableMouse(false)
	parent.unit = guid

	local border, highlight, name, level, levelIcon, raidIcon = parent:GetRegions()
	parent.border = border
	parent.highlight = highlight
	parent.name = name
	parent.level = level
	parent.levelIcon = levelIcon
	parent.raidIcon = raidIcon

	parent.name:Hide()
	parent.healthBar = parent:GetChildren()
	parent.healthBar:Hide()

	nameplate.healthBar = CreateFrame("StatusBar", "$parentHealth", nameplate)
	nameplate.healthBar:SetWidth(parent.healthBar:GetWidth())
	nameplate.healthBar:SetHeight(parent.healthBar:GetHeight())
	local point, relativeTo, relativePoint, x, y = parent.healthBar:GetPoint()
	nameplate.healthBar:SetPoint(point, nameplate, relativePoint, x, y)
	nameplate.healthBar:SetOrientation("HORIZONTAL")
	-- nameplate.healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	nameplate.healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
	nameplate.healthBar:SetFrameLevel(1)
	nameplate.healthBar:SetStatusBarColor(parent.healthBar:GetStatusBarColor())
	nameplate.healthBar:SetMinMaxValues(parent.healthBar:GetMinMaxValues())
	nameplate.healthBar:SetValue(parent.healthBar:GetValue())

	parent.healthBar:SetScript("OnValueChanged", OnValueChanged)

	CLICK_AREA_WIDTH = parent.healthBar:GetWidth() + 30
	CLICK_AREA_HEIGHT = parent.healthBar:GetHeight() + 8

	nameplate.clickArea = CreateFrame("Button", "$parentClickArea", nameplate)
	nameplate.clickArea:SetPoint("TOPLEFT", nameplate.healthBar, "TOPLEFT", -2, 4)
	nameplate.clickArea:SetWidth(CLICK_AREA_WIDTH)
	nameplate.clickArea:SetHeight(CLICK_AREA_HEIGHT)
	nameplate.clickArea:SetFrameLevel(2)
	nameplate.clickArea:SetScript("OnMouseDown", OnMouseDown)
	nameplate.clickArea:SetScript("OnEnter", OnEnter)
	nameplate.clickArea:SetScript("OnLeave", OnLeave)

	nameplate.glow = nameplate.healthBar:CreateTexture("$parentGlow", "BACKGROUND")
	nameplate.glow:SetPoint("CENTER", nameplate.healthBar, "CENTER", 10, 0)
	nameplate.glow:SetTexture("Interface\\AddOns\\Overhead\\Glow")
	nameplate.glow:SetWidth(nameplate.clickArea:GetWidth() * 2)
	nameplate.glow:SetHeight(nameplate.clickArea:GetHeight() * 4)
	nameplate.glow:SetBlendMode("ADD")
	nameplate.glow:SetVertexColor(1, 1, 1, 0.5)
	nameplate.glow:Hide()

	-- nameplate.background = nameplate.healthBar:CreateTexture("$parentBackground", "BORDER")
	-- nameplate.background:SetPoint("CENTER", nameplate.healthBar, "CENTER", 0, 0)
	-- nameplate.background:SetWidth(nameplate.healthBar:GetWidth())
	-- nameplate.background:SetHeight(nameplate.healthBar:GetHeight())
	-- nameplate.background:SetTexture(0, 0, 0, 0.45)

	parent.border:SetParent(nameplate.healthBar)
	parent.border:ClearAllPoints()
	parent.border:SetPoint("BOTTOMLEFT", nameplate.healthBar, "BOTTOMLEFT", -5, -6)
	parent.border:SetWidth(nameplate.healthBar:GetWidth() + 31)
	parent.border:SetHeight(nameplate.healthBar:GetHeight() * 2 + 21)
	parent.border:SetDrawLayer("OVERLAY")

	nameplate.highlight = nameplate.clickArea:CreateTexture("$parentHighlight", "HIGHLIGHT")
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
	parent.level:SetPoint("CENTER", nameplate.healthBar, "RIGHT", 11, 0)
	parent.level:SetDrawLayer("OVERLAY")

	parent.levelIcon:SetParent(nameplate)
	parent.levelIcon:ClearAllPoints()
	parent.levelIcon:SetPoint("LEFT", nameplate.healthBar, "RIGHT", 4, 0)
	parent.levelIcon:SetDrawLayer("OVERLAY")

	nameplate.name = nameplate:CreateFontString("$parentName", "OVERLAY", "GameFontHighlightLarge")
	nameplate.name:SetText(parent.name:GetText())
	nameplate.name:SetFont(parent.name:GetFont())
	nameplate.name:SetShadowOffset(1.5, -1.5)
	nameplate.name:SetJustifyH("CENTER")
	nameplate.name:SetPoint("BOTTOM", nameplate.healthBar, "TOP", 8, 4)

	nameplate.elite = nameplate:CreateTexture("$parentElite", "OVERLAY")
	nameplate.elite:SetTexture("Interface\\AddOns\\Overhead\\Elite")
	nameplate.elite:SetPoint("LEFT", nameplate.healthBar, "RIGHT", -6, -5)
	nameplate.elite:SetHeight(42)
	nameplate.elite:SetWidth(78)

	nameplate.castBar = CreateFrame("StatusBar", "$parentCastBar", nameplate)
	nameplate.castBar:SetWidth(nameplate.healthBar:GetWidth() - 23)
	nameplate.castBar:SetHeight(nameplate.healthBar:GetHeight())
	nameplate.castBar:SetPoint("TOPLEFT", nameplate.healthBar, "BOTTOMLEFT", 22, -4)
	nameplate.castBar:SetOrientation("HORIZONTAL")
	nameplate.castBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	nameplate.castBar:SetStatusBarColor(1, 0.82, 0, 1)
	nameplate.castBar:SetFrameLevel(2)
	nameplate.castBar:Hide()

	nameplate.castBarText = nameplate.castBar:CreateFontString("$parentCastBarText", "ARTWORK", "GameFontHighlightSmall")
	nameplate.castBarText:SetWidth(nameplate.castBar:GetWidth() - 2)
	nameplate.castBarText:SetHeight(nameplate.castBar:GetHeight())
	nameplate.castBarText:SetPoint("CENTER", nameplate.castBar, "CENTER", 2, 0)

	nameplate.castBarSpark = nameplate.castBar:CreateTexture("$parentCastBarSpark", "OVERLAY")
	nameplate.castBarSpark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	nameplate.castBarSpark:SetWidth(32)
	nameplate.castBarSpark:SetHeight(32)
	nameplate.castBarSpark:SetBlendMode("ADD")

	-- nameplate.castBarBackground = nameplate.castBar:CreateTexture("$parentCastBarBackground", "BACKGROUND")
	-- nameplate.castBarBackground:SetAllPoints()
	-- nameplate.castBarBackground:SetTexture(0, 0, 0, 0.45)

	nameplate.castBarBorder = nameplate.castBar:CreateTexture("$parentCastBarBorder", "ARTWORK")
	nameplate.castBarBorder:SetTexture("Interface\\AddOns\\Overhead\\CastBar")
	nameplate.castBarBorder:SetPoint("CENTER", nameplate.castBar, "CENTER", -9, 0)

	nameplate.castBarIcon = nameplate.castBar:CreateTexture("$parentCastBarIcon", "OVERLAY")
	nameplate.castBarIcon:SetWidth(13)
	nameplate.castBarIcon:SetHeight(13)
	nameplate.castBarIcon:SetPoint("CENTER", nameplate.castBar, "LEFT", -10, 0)
	nameplate.castBarIcon:SetTexCoord(0.07, 0.9, 0.1, 0.93)
	nameplate.castBarIcon:SetTexture(0)

	nameplate.totemIcon = nameplate:CreateTexture("$parentTotemIcon", "BORDER")
	nameplate.totemIcon:SetWidth(TOTEM_WIDTH)
	nameplate.totemIcon:SetHeight(TOTEM_WIDTH)
	nameplate.totemIcon:SetPoint("CENTER", nameplate, "CENTER", 0, 0)
	nameplate.totemIcon:SetTexCoord(0.07, 0.90, 0.1, 0.93)
	nameplate.totemIcon:SetTexture("Interface\\Icons\\spell_fire_selfdestruct")
	nameplate.totemIcon:Hide()

	nameplate.totemGlow = nameplate:CreateTexture("$parentTotemGlow", "BACKGROUND")
	nameplate.totemGlow:SetTexture("Interface\\AddOns\\Overhead\\Glow")
	nameplate.totemGlow:SetWidth(TOTEM_WIDTH * 3)
	nameplate.totemGlow:SetHeight(TOTEM_WIDTH * 3)
	nameplate.totemGlow:SetPoint("CENTER", nameplate.totemIcon)
	nameplate.totemGlow:SetVertexColor(1, 1, 1, 0.4)
	nameplate.totemGlow:Hide()

	nameplate.totemHighlight = nameplate.clickArea:CreateTexture("$parentTotemHighlight", "HIGHLIGHT")
	nameplate.totemHighlight:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	nameplate.totemHighlight:SetWidth(58)
	nameplate.totemHighlight:SetHeight(58)
	nameplate.totemHighlight:SetPoint("CENTER", nameplate.totemIcon, 1, 1)
	nameplate.totemHighlight:SetBlendMode("ADD")
	nameplate.totemHighlight:SetVertexColor(1, 1, 1, 0.5)
	nameplate.totemHighlight:Hide()

	nameplate:SetScript("OnUpdate", OnUpdate)
	return nameplate
end

Overhead:SetScript("OnUpdate", function()
	local numChildren = WorldFrame:GetNumChildren()
	if numChildrenLastFrame < numChildren then
		local childs = { WorldFrame:GetChildren() }
		for i = numChildrenLastFrame + 1, numChildren do
			local parent = childs[i]
			if IsNamePlate(parent) and not Registry[parent] then
				numNameplatesCreated = numNameplatesCreated + 1
				Registry[parent] = CreatePlate(parent)
			end
		end
		numChildrenLastFrame = numChildren
	end

	if Overhead.time and Overhead.frame and not IsMouselooking() and Overhead.time >= GetTime() then
		Overhead.frame:Click("LeftButton")
		if UnitCanAttack("player", "target") and not Overhead.isAttacking and (not IsMounted() or CheckInteractDistance("target", 3)) then
			AttackTarget()
		end
		Overhead.frame = nil
		Overhead.time = nil
	end
end)
