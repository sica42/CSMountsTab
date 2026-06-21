---@class CSMounts
CSMounts = CSMounts or {}

---@class CSMounts
local m = CSMounts

m.name = "CSMountTab"
m.short = "CSMT"
m.tagcolor = "FFEBC315"
m.isModern = C_ChatInfo and true or false
m.mountButtons = {}

---@type table<number, MountSpellInfo>
m.mountSpells = {}
m.currentPage = 1
m.delayScan = 4
m.events = {}
m.api = getfenv()


function CSMounts:init()
	self.frame = CreateFrame( "Frame" )
	self.frame:SetScript( "OnEvent", function( _self, event, ... )
		if m.events[ event ] then
			m.events[ event ]( _self, ... )
		end
	end )

	for k, _ in pairs( m.events ) do
		m.frame:RegisterEvent( k )
	end
end

function CSMounts.events:PLAYER_ENTERING_WORLD()
	if m.initDone then return end
	m.initDone = true

	CrusaderStormMountsOptions = CrusaderStormMountsOptions or {}
	m.db = CrusaderStormMountsOptions
	m.db.sort = m.db.sort or "alpha"

	local numTabs = GetNumSpellTabs()
	m.mountsTabIndex = numTabs + 1
	m.api[ "SpellBookSkillLineTab" .. tostring( m.mountsTabIndex ) ]:SetID( 0 )
	SPELLBOOK_PAGENUMBERS[ 0 ] = 1

	hooksecurefunc( "SpellBookFrame_Update", CSMounts.spellBookUpdate )
	hooksecurefunc( "SpellBookSkillLineTab_OnClick", CSMounts.tabClick )

	m.api[ "SLASH_CSMounts1" ] = "/mounts"
	SlashCmdList[ "CSMounts" ] = function( args )
		if args == "sort" then
			if m.db.sort == "alpha" then
				m.db.sort = "speed"
			else
				m.db.sort = "alpha"
			end
			m.info( "Sorting set to " .. (m.db.sort == "alpha" and "alphabetically" or "speed") .. "." )
			m.updateMounts()
			return
		end

		m.info( "Crusader Storm Mounts Tab Usage:", true )
		m.info( "|cffaaaaaa/mounts sort|r - Change sorting", true )
	end

	m.updateMounts()
	m.updateMountButtonDelayed( 4 )
end

function CSMounts.updateMountButtonDelayed( delay )
	m.delayScan = delay
	m.frame:SetScript( "OnUpdate", function( _, elapsed )
		m.delayScan = m.delayScan - elapsed
		if m.delayScan <= 0 then
			m.frame:SetScript( "OnUpdate", nil )
			m.updateMountButton()
		end
	end )
end

function CSMounts.events.ZONE_CHANGED_NEW_AREA()
	m.updateMountButtonDelayed( 1 )
end

function CSMounts.events.LEARNED_SPELL_IN_TAB()
	m.updateMounts()
end

function CSMounts.updateMounts()
	local _, _, offset, numSpells = GetSpellTabInfo( 1 )
	m.mountSpells = {}

	for i = offset + 1, offset + numSpells do
		local spellName, _, _, _, _, _, spellId = GetSpellInfo( i, "SPELL" )
		if not m.isModern then
			local spellLink = GetSpellLink( spellName )
			if spellLink then
				spellId = tonumber( string.match( spellLink, "spell:(%d+)" ) )
			end
		end
		local mountInfo = m.mountInfo[ spellId ]

		if mountInfo then
			tinsert( m.mountSpells, {
				name = spellName,
				slotId = i,
				spellId = spellId,
				mSpeed = mountInfo[ 1 ],
				fSpeed = mountInfo[ 2 ]
			} )
		end
	end

	local sortAlpha = function( a, b )
		return a.name < b.name
	end

	local sortSpeed = function( a, b )
		local a_has_f = a.fSpeed ~= nil
		local b_has_f = b.fSpeed ~= nil

		if a_has_f ~= b_has_f then
			return a_has_f
		end

		local a_speed = a.fSpeed or a.mSpeed or 0
		local b_speed = b.fSpeed or b.mSpeed or 0

		if a_speed ~= b_speed then
			return a_speed > b_speed
		end

		return a.name < b.name
	end

	sort( m.mountSpells, m.db.sort == "alpha" and sortAlpha or sortSpeed )

	if SpellBookFrame:IsVisible() and m.mountsFrame and m.mountsFrame:IsVisible() then
		m.updateMountsTab()
	end
end

---@param self CheckButton
function CSMounts.tabClick( self )
	if not self then return end
	local id = (not m.isModern and type( self ) == "number") and self or self:GetID()

	if id ~= 0 then
		_G[ "SpellBookSkillLineTab" .. tostring( m.mountsTabIndex ) ]:SetChecked( false )
	end
end

function CSMounts.spellBookUpdate()
	m.updateMountsTab()

	if getn( m.mountSpells ) > 0 then
		local tab = _G[ "SpellBookSkillLineTab" .. m.mountsTabIndex ]

		tab:SetNormalTexture( "Interface\\Icons\\Ability_Mount_RidingHorse" )
		tab:SetScript( "OnEnter", function( self )
			GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )
			GameTooltip:SetText( "Mounts", NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b )
			GameTooltip:Show()
		end )
		tab:Show()
	end
end

function CSMounts.updateMountsTab()
	if m.delayScan > 0 then
		m.updateMounts()
	end

	if SpellBookFrame.selectedSkillLine == 0 then
		if not m.mountsFrame then
			m.createMountsFrame()
		end

		for i = 1, SPELLS_PER_PAGE do
			local sBtn = m.mountButtons[ i ].secureBtn
			local index = i + ((m.currentPage - 1) * SPELLS_PER_PAGE)
			if m.mountSpells[ index ] then
				local mountInfo = m.getMountSpellInfo( index )

				sBtn:SetAttribute( "type", "spell" )
				sBtn:SetAttribute( "spell", mountInfo.name )
				sBtn:SetAttribute( "shift-spell*", "" )
				sBtn:SetAttribute( "ctrl-spell*", "" )
				sBtn:Enable()

				if mountInfo.name == m.db.favMount or mountInfo.name == m.db.favFlying then
					sBtn:SetHighlightTexture( [[Interface\Buttons\CheckButtonHilight]] )
					sBtn:GetHighlightTexture():SetVertexColor( 1, 1, 1, 1 )
					sBtn:LockHighlight()
				else
					sBtn:SetHighlightTexture( [[Interface\Buttons\ButtonHilight-Square]], "ADD" )
					if m.isSkinned then
						if m.isModern then
							sBtn:GetHighlightTexture():SetColorTexture( 1, 1, 1, 0.3 )
						else
							sBtn:GetHighlightTexture():SetTexture( 1, 1, 1, 0.3 )
						end
					end
					sBtn:UnlockHighlight()
				end
			else
				sBtn:SetAttribute( "spell", "" )
				sBtn:Disable()
			end
			m.MountSpellButton_UpdateButton( m.mountButtons[ i ] )
		end

		if m.count( m.mountSpells ) > SPELLS_PER_PAGE * m.currentPage then
			m.mountsFrame.btnNext:Enable()
		else
			m.mountsFrame.btnNext:Disable()
		end

		if m.currentPage and m.currentPage > 1 then
			m.mountsFrame.btnPrev:Enable()
		else
			m.mountsFrame.btnPrev:Disable()
		end
		m.mountsFrame.labelPage:SetFormattedText( PAGE_NUMBER, m.currentPage or 1 )

		_G[ "SpellBookPageText" ]:Hide()
		m.mountsFrame:Show()
		m.isMountsTab = true
	else
		if m.mountsFrame then m.mountsFrame:Hide() end
		m.isMountsTab = false
		_G[ "SpellBookPageText" ]:Show()
	end
end

function CSMounts.createMountsFrame()
	---@class MountsFrame: Frame
	local frame = CreateFrame( "Frame", nil, _G[ "SpellBookFrame" ] ) --, "BackdropTemplate" )
	frame:SetAllPoints()
	frame:SetFrameLevel( _G[ "SpellBookFrame" ]:GetFrameLevel() + 10 )

	for i = 1, SPELLS_PER_PAGE do
		local btn = m.createMountSpellButton( frame, i )
		tinsert( m.mountButtons, btn )
		if i == 1 then
			btn:SetPoint( "TOPLEFT", frame, "TOPLEFT", 34, -85 )
		elseif i == 7 then
			btn:SetPoint( "TOPLEFT", m.mountButtons[ 1 ], "TOPLEFT", 157, 0 )
		else
			btn:SetPoint( "TOPLEFT", m.mountButtons[ i - 1 ], "BOTTOMLEFT", 0, -14 )
		end
		btn:Show()
	end

	local btnPrev = CreateFrame( "Button", "SpellbookMountsPagePrev", frame )
	btnPrev:SetWidth( 32 )
	btnPrev:SetHeight( 32 )
	btnPrev:SetPoint( "CENTER", frame, "BOTTOMLEFT", 50, 105 )
	btnPrev:SetNormalTexture( [[Interface\Buttons\UI-SpellbookIcon-PrevPage-Up]] )
	btnPrev:SetPushedTexture( [[Interface\Buttons\UI-SpellbookIcon-PrevPage-Down]] )
	btnPrev:SetDisabledTexture( [[Interface\Buttons\UI-SpellbookIcon-PrevPage-Disabled]] )
	btnPrev:SetHighlightTexture( [[Interface\Buttons\UI-Common-MouseHilight]], "ADD" )
	btnPrev:SetScript( "OnClick", m.btnPrevOnClick )
	frame.btnPrev = btnPrev

	local btnNext = CreateFrame( "Button", "SpellbookMountsPageNext", frame )
	btnNext:SetWidth( 32 )
	btnNext:SetHeight( 32 )
	btnNext:SetPoint( "CENTER", frame, "BOTTOMLEFT", 314, 105 )
	btnNext:SetNormalTexture( [[Interface\Buttons\UI-SpellbookIcon-NextPage-Up]] )
	btnNext:SetPushedTexture( [[Interface\Buttons\UI-SpellbookIcon-NextPage-Down]] )
	btnNext:SetDisabledTexture( [[Interface\Buttons\UI-SpellbookIcon-NextPage-Disabled]] )
	btnNext:SetHighlightTexture( [[Interface\Buttons\UI-Common-MouseHilight]], "ADD" )
	btnNext:SetScript( "OnClick", m.btnNextOnClick )
	frame.btnNext = btnNext

	local labelPage = frame:CreateFontString( "SpellbookMountsPageText", "ARTWORK", "GameFontNormal" )
	labelPage:SetWidth( 102 )
	labelPage:SetHeight( 0 )
	labelPage:SetPoint( "BOTTOM", frame, "BOTTOM", -14, 96 )
	frame.labelPage = labelPage

	m.mountsFrame = frame
	m.skinElvUI()
end

function CSMounts.createMountSpellButton( parent, id )
	local btn = CreateFrame( "CheckButton", "MountSpellButton" .. tostring( id ), parent )
	btn:SetID( id )
	btn:SetWidth( 37 )
	btn:SetHeight( 37 )

	local normalTex = btn:CreateTexture( "$parentNormalTexture" )
	normalTex:SetTexture( [[Interface\Buttons\UI-Quickslot2]] )
	normalTex:SetWidth( 64 )
	normalTex:SetHeight( 64 )
	normalTex:SetPoint( "CENTER", btn, "CENTER", 0, 0 )
	btn:SetNormalTexture( normalTex )
	btn:SetPushedTexture( [[Interface\Buttons\UI-Quickslot-Depress]] )

	local highlightTex = btn:CreateTexture( "$parentHighlight" )
	highlightTex:SetTexture( [[Interface\Buttons\CheckButtonHilight]] )
	btn:SetHighlightTexture( highlightTex, "ADD" )

	local checkedTex = btn:CreateTexture()
	checkedTex:SetTexture( [[Interface\Buttons\CheckButtonHilight]] )
	checkedTex:SetBlendMode( "ADD" )
	btn:SetCheckedTexture( checkedTex )

	local bg = btn:CreateTexture( "$parentBackground", "BACKGROUND" )
	bg:SetTexture( [[Interface\Spellbook\UI-Spellbook-SpellBackground]] )
	bg:SetWidth( 64 )
	bg:SetHeight( 64 )
	bg:SetPoint( "TOPLEFT", btn, "TOPLEFT", -3, 3 )

	local icon = btn:CreateTexture( "$parentIconTexture", "BORDER" )
	icon:SetAllPoints()

	local labelSpellName = btn:CreateFontString( "$parentSpellName", "BORDER", "GameFontNormal" )
	labelSpellName:SetJustifyH( "LEFT" )
	labelSpellName:SetWidth( 103 )
	labelSpellName:SetHeight( 0 )
	labelSpellName:SetPoint( "LEFT", btn, "RIGHT", 4, 0 )

	local labelSubSpellName = btn:CreateFontString( "$parentSubSpellName", "BORDER", "SubSpellFont" )
	labelSubSpellName:SetJustifyH( "LEFT" )
	labelSubSpellName:SetWidth( 79 )
	labelSubSpellName:SetHeight( 6 )
	labelSubSpellName:SetPoint( "TOPLEFT", labelSpellName, "BOTTOMLEFT", 0, -2 )
	btn.SpellSubName = labelSubSpellName

	local sBtn = CreateFrame( "Button", nil, btn, "SecureActionButtonTemplate" )
	sBtn:SetAllPoints()
	sBtn:SetPushedTexture( [[Interface\Buttons\UI-Quickslot-Depress]] )
	sBtn:SetHighlightTexture( [[Interface\Buttons\ButtonHilight-Square]], "ADD" )
	sBtn:SetID( id )

	sBtn:HookScript( "OnClick", m.MountSpellButton_OnClick )
	sBtn:SetScript( "OnEnter", m.MountSpellButton_OnEnter )
	sBtn:SetScript( "OnLeave", m.MountSpellButton_OnLeave )
	sBtn:SetScript( "OnDragStart", m.MountSpellButton_OnDrag )
	sBtn:RegisterForDrag( "LeftButton" )
	sBtn:SetFrameLevel( btn:GetFrameLevel() + 1 )

	btn.secureBtn = sBtn
	CSMounts.MountSpellButton_UpdateButton( btn )

	return btn
end

function CSMounts.btnPrevOnClick()
	m.currentPage = m.currentPage - 1
	m.updateMountsTab()
end

function CSMounts.btnNextOnClick()
	m.currentPage = m.currentPage + 1
	m.updateMountsTab()
end

---@class SpellButton: CheckButton
---@field SpellName FontString
---@field SpellSubName FontString
---@field shine Frame
---@field isPassive number?

---@param self SpellButton
function CSMounts.MountSpellButton_UpdateButton( self )
	local slot = m.MountSpellBook_GetSpellBookSlot( self )
	local name = self:GetName()
	local iconTexture = m.api[ name .. "IconTexture" ]
	local spellString = m.api[ name .. "SpellName" ]
	local subSpellString = m.api[ name .. "SubSpellName" ]
	local texture
	if (slot) then
		texture = GetSpellTexture( slot, SpellBookFrame.bookType )
	end

	if not texture or (strlen( texture ) == 0) then
		iconTexture:Hide()
		spellString:Hide()
		subSpellString:Hide()
		self:SetChecked( false )
		self:Disable()
		return
	else
		self:Enable()
	end

	local mountInfo = m.getMountSpellInfo( self:GetID() + ((m.currentPage - 1) * SPELLS_PER_PAGE) )

	iconTexture:SetTexture( texture )
	iconTexture:Show()

	spellString:SetText( mountInfo.name )
	spellString:SetPoint( "LEFT", self, "RIGHT", 5, spellString:GetStringHeight() > 14 and 6 or 3 )
	spellString:Show()

	local subSpellName = ""
	if mountInfo.fSpeed then
		subSpellName = string.format( "Flying %d%%", mountInfo.fSpeed )
	else
		subSpellName = string.format( "Mount %d%%", mountInfo.mSpeed )
	end

	subSpellString:SetText( subSpellName )
	subSpellString:Show()
end

---@param self Button
function CSMounts.MountSpellButton_OnClick( self )
	if (IsModifiedClick( "CHATLINK" )) then
		local mountInfo = m.getMountSpellInfo( self:GetID() + ((m.currentPage - 1) * SPELLS_PER_PAGE) )

		if (MacroFrameText and MacroFrameText:HasFocus()) then
			ChatEdit_InsertLink( mountInfo.name );
		else
			ChatEdit_InsertLink( GetSpellLink( mountInfo.slotId, SpellBookFrame.bookType ) )
		end
	elseif IsControlKeyDown() then
		local mountInfo = m.getMountSpellInfo( self:GetID() + ((m.currentPage - 1) * SPELLS_PER_PAGE) )
		m.db[ mountInfo.fSpeed and "favFlying" or "favMount" ] = mountInfo.name
		m.updateMountButton()
		m.updateMountsTab()
	end
end

---@param self Button
function CSMounts.MountSpellButton_OnEnter( self )
	local slot = m.MountSpellBook_GetSpellBookSlot( self )
	if not slot then return end

	GameTooltip:SetOwner( self, "ANCHOR_RIGHT" );
	if m.isModern then
		GameTooltip:SetSpellBookItem( slot, SpellBookFrame.bookType )
	else
		---@diagnostic disable-next-line: undefined-field
		GameTooltip:SetSpell( slot, SpellBookFrame.bookType )
	end
	GameTooltip:Show()
end

function CSMounts.MountSpellButton_OnLeave()
	GameTooltip:Hide()
end

---@param self Button
function CSMounts.MountSpellButton_OnDrag( self )
	local btn = self:GetParent() ---@cast btn CheckButton

	if btn then
		local slot = m.MountSpellBook_GetSpellBookSlot( self );
		if (not slot or slot > MAX_SPELLS or not _G[ btn:GetName() .. "IconTexture" ]:IsShown()) then
			return
		end
		btn:SetChecked( false )
		if m.isModern then
			PickupSpellBookItem( slot, SpellBookFrame.bookType )
		else
			PickupSpell( slot, SpellBookFrame.bookType )
		end
	end
end

function CSMounts.updateMountButton()
	if not m.btnMount then
		m.btnMount = CreateFrame( "Button", "MountFav", UIParent, "SecureActionButtonTemplate" )
		m.btnMount:SetAttribute( "type", "spell" )
	end

	m.btnMount:SetAttribute( "spell", IsFlyableArea() and m.db.favFlying or m.db.favMount )
end

---@class MountSpellInfo
---@field name string
---@field slotId number
---@field spellId number
---@field mSpeed number
---@field fSpeed number?

---@param slot number
---@return MountSpellInfo
function CSMounts.getMountSpellInfo( slot )
	local pos = 0
	for _, v in pairs( m.mountSpells ) do
		if v.slotId then
			pos = pos + 1
			if pos == slot then
				return v
			end
		end
	end
	return {}
end

---@param btn Button
---@return number?, string?
function CSMounts.MountSpellBook_GetSpellBookSlot( btn )
	local id = btn:GetID()
	local mountInfo = m.getMountSpellInfo( id + ((m.currentPage - 1) * SPELLS_PER_PAGE) )

	if mountInfo.slotId then
		return mountInfo.slotId, "spell"
	end

	return nil, nil
end

function CSMounts.skinElvUI()
	local E = unpack( ElvUI )

	if E then
		local S = E:GetModule( 'Skins' )
		if not (E.private.skins.blizzard.enable and E.private.skins.blizzard.spellbook) then return end
		m.isSkinned = true

		m.api[ "SpellbookMountsPageText" ]:SetTextColor( 1, 1, 1 )
		if m.isModern then
			m.api[ "SpellbookMountsPageText" ]:Point( 'BOTTOM', -10, 87 )
			m.api[ "SpellbookMountsPagePrev" ]:Point( 'BOTTOMRIGHT', m.mountsFrame, 'BOTTOMRIGHT', -73, 87 )
			m.api[ "SpellbookMountsPageNext" ]:Point( 'TOPLEFT', m.api[ "SpellbookMountsPagePrev" ], 'TOPLEFT', 30, 0 )
		else
			m.api[ "SpellbookMountsPageText" ]:Point( "CENTER", m.mountsFrame, "BOTTOMLEFT", 185, 0 )
			m.api[ "SpellbookMountsPagePrev" ]:Point( "CENTER", m.mountsFrame, "BOTTOMLEFT", 30, 100 )
			m.api[ "SpellbookMountsPageNext" ]:Point( "CENTER", m.mountsFrame, "BOTTOMLEFT", 330, 100 )
		end

		S:HandleNextPrevButton( m.api[ "SpellbookMountsPagePrev" ] )
		m.api[ "SpellbookMountsPagePrev" ]:Size( 24 )

		S:HandleNextPrevButton( m.api[ "SpellbookMountsPageNext" ] )
		m.api[ "SpellbookMountsPageNext" ]:Size( 24 )

		for i = 1, SPELLS_PER_PAGE do
			local button = m.api[ 'MountSpellButton' .. i ]
			local icon = m.api[ 'MountSpellButton' .. i .. 'IconTexture' ]
			local highlight = button.secureBtn:GetHighlightTexture()

			for y = 1, button:GetNumRegions() do
				local region = select( y, button:GetRegions() )
				if region:GetObjectType() == 'Texture' then
					if region:GetTexture() ~= [[Interface\Buttons\ActionBarFlyoutButton]] then
						region:SetTexture( nil )
					end
				end
			end

			if m.isModern then
				button.SpellSubName:SetTextColor( 0.6, 0.6, 0.6 )
			else
				button.SpellSubName:SetTextColor( 1, 1, 1, 1 )
			end
			icon:SetTexCoord( unpack( E.TexCoords ) )
			if m.isModern then
				highlight:SetColorTexture( 1, 1, 1, 0.3 )
			else
				highlight:SetTexture( 1, 1, 1, 0.3 )
			end
			button.secureBtn:SetPushedTexture( nil )

			if m.isModern then
				if i == 1 then
					S:HandlePointXY( button, 28, -55 )
				elseif i == 7 then
					S:HandlePointXY( button, 163, 0 )
				else
					S:HandlePointXY( button, 0, -20 )
				end
			else
				if i == 1 then
					button:Point( "TOPLEFT", m.mountsFrame, "TOPLEFT", 25, -75 )
				elseif i == 7 then
					button:Point( "TOPLEFT", m.mountButtons[ 1 ], "TOPLEFT", 167, 0 )
				else
					button:Point( "TOPLEFT", m.mountButtons[ i - 1 ], "BOTTOMLEFT", 0, -17 )
				end
			end
		end
	end
end

---@param message string
---@param short boolean?
function CSMounts.info( message, short )
	local tag = string.format( "|c%s%s|r", m.tagcolor, short and m.short or m.name )
	DEFAULT_CHAT_FRAME:AddMessage( string.format( "%s: %s", tag, message ) )
end

---@param t table
---@return number
function CSMounts.count( t )
	local count = 0
	for _ in pairs( t ) do
		count = count + 1
	end

	return count
end

---@param value string|number
---@param t table
---@param extract_field string?
function CSMounts.find( value, t, extract_field )
	if type( t ) ~= "table" or m.count( t ) == 0 then return nil end

	for i, v in pairs( t ) do
		local val = extract_field and v[ extract_field ] or v
		if val == value then return v, i end
	end

	return nil
end

CSMounts:init()
