local ADDON_NAME = ...

local Armoire = CreateFrame("Frame")
local DB
local MAX_VISIBLE_SETS = 10
local ICON_TEXTURE = "Interface\\AddOns\\Armoire\\armoire-icon-256.png"

local EQUIPMENT_SLOTS = {
    { id = INVSLOT_HEAD, name = "Head" },
    { id = INVSLOT_NECK, name = "Neck" },
    { id = INVSLOT_SHOULDER, name = "Shoulder" },
    { id = INVSLOT_BACK, name = "Back" },
    { id = INVSLOT_CHEST, name = "Chest" },
    { id = INVSLOT_BODY, name = "Shirt" },
    { id = INVSLOT_TABARD, name = "Tabard" },
    { id = INVSLOT_WRIST, name = "Wrist" },
    { id = INVSLOT_HAND, name = "Hands" },
    { id = INVSLOT_WAIST, name = "Waist" },
    { id = INVSLOT_LEGS, name = "Legs" },
    { id = INVSLOT_FEET, name = "Feet" },
    { id = INVSLOT_FINGER1, name = "Finger 1" },
    { id = INVSLOT_FINGER2, name = "Finger 2" },
    { id = INVSLOT_TRINKET1, name = "Trinket 1" },
    { id = INVSLOT_TRINKET2, name = "Trinket 2" },
    { id = INVSLOT_MAINHAND, name = "Main Hand" },
    { id = INVSLOT_OFFHAND, name = "Off Hand" },
    { id = INVSLOT_RANGED, name = "Ranged" },
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cffb48cffArmoire:|r " .. tostring(message))
end

local function Trim(value)
    return (value or ""):match("^%s*(.-)%s*$")
end

local function Normalize(value)
    return string.lower(Trim(value))
end

local function GetItemID(link)
    if not link then
        return nil
    end

    return tonumber(link:match("item:(%d+)"))
end

local function GetContainerItemLinkCompat(bag, slot)
    if C_Container and C_Container.GetContainerItemLink then
        return C_Container.GetContainerItemLink(bag, slot)
    end

    return GetContainerItemLink(bag, slot)
end

local function GetContainerNumSlotsCompat(bag)
    if C_Container and C_Container.GetContainerNumSlots then
        return C_Container.GetContainerNumSlots(bag) or 0
    end

    return GetContainerNumSlots(bag) or 0
end

local function BagHasItemLink(link)
    if not link then
        return false
    end

    for bag = 0, NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlotsCompat(bag) do
            if GetContainerItemLinkCompat(bag, slot) == link then
                return true
            end
        end
    end

    return false
end

local function FindEquippedItemSlot(link, targetSlotID)
    if not link then
        return nil
    end

    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        if slotInfo.id ~= targetSlotID and GetInventoryItemLink("player", slotInfo.id) == link then
            return slotInfo.id
        end
    end

    return nil
end

local function FindSet(name)
    local key = Normalize(name)
    if key == "" then
        return nil
    end

    for _, set in ipairs(DB.sets) do
        if Normalize(set.name) == key then
            return set
        end
    end

    return nil
end

local function SortSets()
    table.sort(DB.sets, function(a, b)
        return string.lower(a.name) < string.lower(b.name)
    end)
end

local function EnsureDB()
    if type(ArmoireDB) ~= "table" then
        ArmoireDB = {}
    end

    if type(ArmoireDB.sets) ~= "table" then
        ArmoireDB.sets = {}
    end

    if ArmoireDB.showCharacterButton == nil then
        ArmoireDB.showCharacterButton = true
    end

    DB = ArmoireDB
end

local function CountSetSlots(set)
    local count = 0
    for _ in pairs(set.slots or {}) do
        count = count + 1
    end
    return count
end

local function SetTextureColor(texture, r, g, b, a)
    if texture.SetColorTexture then
        texture:SetColorTexture(r, g, b, a)
    else
        texture:SetTexture(r, g, b, a)
    end
end

function Armoire:SaveSet(name)
    name = Trim(name)
    if name == "" then
        Print("Give the set a name first.")
        return
    end

    local set = FindSet(name)
    if not set then
        set = { name = name, slots = {} }
        table.insert(DB.sets, set)
    else
        set.name = name
        set.slots = {}
    end

    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local link = GetInventoryItemLink("player", slotInfo.id)
        if link then
            set.slots[tostring(slotInfo.id)] = {
                link = link,
                itemID = GetItemID(link),
            }
        end
    end

    SortSets()
    DB.selectedSet = set.name
    self:RefreshUI()
    Print("Saved \"" .. name .. "\" with " .. CountSetSlots(set) .. " items.")
end

function Armoire:DeleteSet(name)
    local key = Normalize(name)
    if key == "" then
        Print("Usage: /armoire delete <set name>")
        return
    end

    for index, set in ipairs(DB.sets) do
        if Normalize(set.name) == key then
            table.remove(DB.sets, index)
            if Normalize(DB.selectedSet) == key then
                DB.selectedSet = DB.sets[1] and DB.sets[1].name or nil
            end
            self:RefreshUI()
            Print("Deleted \"" .. set.name .. "\".")
            return
        end
    end

    Print("No set named \"" .. tostring(name) .. "\".")
end

function Armoire:ConfirmDeleteSet(name)
    local set = FindSet(name)
    if not set then
        if Normalize(name) == "" then
            Print("Usage: /armoire delete <set name>")
        else
            Print("No set named \"" .. tostring(name) .. "\".")
        end
        return
    end

    StaticPopup_Show("ARMOIRE_CONFIRM_DELETE_SET", set.name, nil, set.name)
end

StaticPopupDialogs.ARMOIRE_CONFIRM_DELETE_SET = {
    text = "Delete equipment set \"%s\"?",
    button1 = DELETE,
    button2 = CANCEL,
    OnAccept = function(self, setName)
        Armoire:DeleteSet(setName)
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

function Armoire:EquipSet(name)
    local set = FindSet(name)
    if not set then
        Print("No set named \"" .. tostring(name) .. "\".")
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        DB.pendingSet = set.name
        Print("Queued \"" .. set.name .. "\" until combat ends.")
        return
    end

    local equipped = 0
    local missing = {}

    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        local item = set.slots and set.slots[tostring(slotInfo.id)]
        if item and item.link then
            local currentLink = GetInventoryItemLink("player", slotInfo.id)
            if currentLink ~= item.link then
                if BagHasItemLink(item.link) then
                    EquipItemByName(item.link, slotInfo.id)
                    equipped = equipped + 1
                else
                    local equippedSlotID = FindEquippedItemSlot(item.link, slotInfo.id)
                    if equippedSlotID and self:MoveEquippedItem(equippedSlotID, slotInfo.id) then
                        equipped = equipped + 1
                    else
                        table.insert(missing, slotInfo.name)
                    end
                end
            end
        end
    end

    if equipped > 0 then
        Print("Equipping \"" .. set.name .. "\".")
    else
        Print("\"" .. set.name .. "\" is already equipped or has no available swaps.")
    end

    if #missing > 0 then
        Print("Missing items for: " .. table.concat(missing, ", ") .. ".")
    end
end

function Armoire:ListSets()
    if #DB.sets == 0 then
        Print("No sets yet. Equip gear, enter a name, then click Save New.")
        return
    end

    Print("Saved sets:")
    for _, set in ipairs(DB.sets) do
        Print(" - " .. set.name .. " (" .. CountSetSlots(set) .. " items)")
    end
end

function Armoire:GetSelectedSet()
    local selected = FindSet(DB and DB.selectedSet)
    if selected then
        return selected
    end

    if DB and DB.sets and DB.sets[1] then
        DB.selectedSet = DB.sets[1].name
        return DB.sets[1]
    end

    return nil
end

function Armoire:SelectSet(name)
    local set = FindSet(name)
    DB.selectedSet = set and set.name or nil
    self:RefreshUI()
end

function Armoire:MoveEquippedItem(sourceSlotID, targetSlotID)
    if CursorHasItem and CursorHasItem() then
        Print("Clear your cursor before equipping a set.")
        return false
    end

    PickupInventoryItem(sourceSlotID)
    PickupInventoryItem(targetSlotID)

    if CursorHasItem and CursorHasItem() then
        PickupInventoryItem(sourceSlotID)
    end

    return not (CursorHasItem and CursorHasItem())
end

function Armoire:SaveFramePosition()
    if not self.frame or not DB then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = self.frame:GetPoint(1)
    DB.framePosition = {
        point = point,
        relativePoint = relativePoint,
        xOfs = xOfs,
        yOfs = yOfs,
    }
end

function Armoire:RestoreFramePosition()
    if not self.frame or not DB or type(DB.framePosition) ~= "table" then
        return
    end

    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        DB.framePosition.point or "CENTER",
        UIParent,
        DB.framePosition.relativePoint or "CENTER",
        tonumber(DB.framePosition.xOfs) or 0,
        tonumber(DB.framePosition.yOfs) or 0
    )
end

function Armoire:PositionNearCharacterFrame()
    if CharacterFrame and CharacterFrame:IsShown() then
        self.frame:ClearAllPoints()
        self.frame:SetPoint("LEFT", CharacterFrame, "RIGHT", 8, 0)
    end
end

function Armoire:ClampListOffset()
    if not DB then
        return 0
    end

    local setCount = DB.sets and #DB.sets or 0
    local maxOffset = math.max(0, setCount - MAX_VISIBLE_SETS)
    local offset = tonumber(DB.listOffset) or 0

    if offset < 0 then
        offset = 0
    elseif offset > maxOffset then
        offset = maxOffset
    end

    DB.listOffset = offset
    return offset
end

function Armoire:CreateInset(parent, name, left, top, width, height, title)
    local panel = CreateFrame("Frame", name, parent, "BackdropTemplate")
    panel:SetSize(width, height)
    panel:SetPoint("TOPLEFT", left, top)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    panel:SetBackdropColor(0.04, 0.04, 0.05, 0.84)
    panel:SetBackdropBorderColor(0.45, 0.36, 0.22, 0.85)

    if title then
        panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        panel.title:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 8, 2)
        panel.title:SetText(title)
    end

    return panel
end

function Armoire:GetSetSummary(set)
    if not set then
        return ""
    end

    local present = {}
    for _, slotInfo in ipairs(EQUIPMENT_SLOTS) do
        if set.slots and set.slots[tostring(slotInfo.id)] then
            table.insert(present, slotInfo.name)
        end
    end

    if #present == 0 then
        return "No equipment slots saved."
    end

    return table.concat(present, ", ")
end

function Armoire:CreateUI()
    local frame = CreateFrame("Frame", "ArmoireFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(460, 436)
    frame:SetPoint("CENTER")
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        Armoire:SaveFramePosition()
    end)
    frame:Hide()

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("LEFT", frame.TitleBg, "LEFT", 8, 0)
    frame.title:SetText("Armoire Equipment Sets")

    frame.portrait = frame:CreateTexture(nil, "ARTWORK")
    frame.portrait:SetSize(36, 36)
    frame.portrait:SetPoint("TOPLEFT", 14, -28)
    frame.portrait:SetTexture(ICON_TEXTURE)
    frame.portrait:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    frame.nameBox:SetSize(260, 24)
    frame.nameBox:SetPoint("TOPLEFT", 60, -38)
    frame.nameBox:SetAutoFocus(false)
    frame.nameBox:SetMaxLetters(32)

    frame.saveButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.saveButton:SetSize(104, 24)
    frame.saveButton:SetPoint("LEFT", frame.nameBox, "RIGHT", 8, 0)
    frame.saveButton:SetText("Save New")
    frame.saveButton:SetScript("OnClick", function()
        Armoire:SaveSet(frame.nameBox:GetText())
        frame.nameBox:ClearFocus()
    end)

    frame.help = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.help:SetPoint("TOPLEFT", frame.nameBox, "BOTTOMLEFT", 0, -7)
    frame.help:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    frame.help:SetJustifyH("LEFT")
    frame.help:SetText("Enter a name to save your current gear. Select a set below to manage it.")

    frame.listPanel = self:CreateInset(frame, nil, 18, -124, 198, 248, "Saved Sets")
    frame.detailPanel = self:CreateInset(frame, nil, 228, -124, 214, 248, "Selected Set")

    frame.rows = {}
    for index = 1, MAX_VISIBLE_SETS do
        local row = CreateFrame("Button", nil, frame.listPanel)
        row:SetSize(178, 22)
        row:SetPoint("TOPLEFT", 10, -10 - ((index - 1) * 23))

        row.highlight = row:CreateTexture(nil, "BACKGROUND")
        row.highlight:SetAllPoints()
        SetTextureColor(row.highlight, 0.96, 0.76, 0.24, 0.18)
        row.highlight:Hide()

        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.name:SetPoint("LEFT", 8, 0)
        row.name:SetWidth(126)
        row.name:SetJustifyH("LEFT")

        row.count = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.count:SetPoint("RIGHT", -8, 0)
        row.count:SetJustifyH("RIGHT")

        frame.rows[index] = row
    end

    frame.prevButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.prevButton:SetSize(26, 22)
    frame.prevButton:SetPoint("TOPLEFT", frame.listPanel, "BOTTOMLEFT", 8, -7)
    frame.prevButton:SetText("<")
    frame.prevButton:SetScript("OnClick", function()
        DB.listOffset = (tonumber(DB.listOffset) or 0) - MAX_VISIBLE_SETS
        Armoire:RefreshUI()
    end)

    frame.nextButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.nextButton:SetSize(26, 22)
    frame.nextButton:SetPoint("LEFT", frame.prevButton, "RIGHT", 4, 0)
    frame.nextButton:SetText(">")
    frame.nextButton:SetScript("OnClick", function()
        DB.listOffset = (tonumber(DB.listOffset) or 0) + MAX_VISIBLE_SETS
        Armoire:RefreshUI()
    end)

    frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.empty:SetPoint("TOPLEFT", frame.listPanel, "TOPLEFT", 12, -14)
    frame.empty:SetPoint("RIGHT", frame.listPanel, "RIGHT", -12, 0)
    frame.empty:SetJustifyH("LEFT")
    frame.empty:SetText("No saved sets yet.\n\nEquip gear, enter a name above, then save it.")

    frame.selectedTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.selectedTitle:SetPoint("TOPLEFT", frame.detailPanel, "TOPLEFT", 14, -15)
    frame.selectedTitle:SetPoint("RIGHT", frame.detailPanel, "RIGHT", -14, 0)
    frame.selectedTitle:SetJustifyH("LEFT")

    frame.selectedDetails = frame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    frame.selectedDetails:SetPoint("TOPLEFT", frame.selectedTitle, "BOTTOMLEFT", 0, -8)
    frame.selectedDetails:SetPoint("RIGHT", frame.detailPanel, "RIGHT", -14, 0)
    frame.selectedDetails:SetJustifyH("LEFT")

    frame.slotSummary = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.slotSummary:SetPoint("TOPLEFT", frame.selectedDetails, "BOTTOMLEFT", 0, -12)
    frame.slotSummary:SetPoint("RIGHT", frame.detailPanel, "RIGHT", -14, 0)
    frame.slotSummary:SetJustifyH("LEFT")
    frame.slotSummary:SetHeight(78)

    frame.equipButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.equipButton:SetSize(174, 22)
    frame.equipButton:SetPoint("BOTTOM", frame.detailPanel, "BOTTOM", 0, 62)
    frame.equipButton:SetText("Equip Set")
    frame.equipButton:SetScript("OnClick", function()
        local set = Armoire:GetSelectedSet()
        if set then
            Armoire:EquipSet(set.name)
        end
    end)

    frame.updateButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.updateButton:SetSize(174, 22)
    frame.updateButton:SetPoint("TOPLEFT", frame.equipButton, "BOTTOMLEFT", 0, -7)
    frame.updateButton:SetText("Update From Current")
    frame.updateButton:SetScript("OnClick", function()
        local set = Armoire:GetSelectedSet()
        if set then
            Armoire:SaveSet(set.name)
        end
    end)

    frame.deleteButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.deleteButton:SetSize(174, 22)
    frame.deleteButton:SetPoint("TOPLEFT", frame.updateButton, "BOTTOMLEFT", 0, -7)
    frame.deleteButton:SetText("Delete Set")
    frame.deleteButton:SetScript("OnClick", function()
        local set = Armoire:GetSelectedSet()
        if set then
            Armoire:ConfirmDeleteSet(set.name)
        end
    end)

    frame.more = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.more:SetPoint("BOTTOMLEFT", 18, 18)
    frame.more:SetPoint("RIGHT", frame, "RIGHT", -18, 0)
    frame.more:SetJustifyH("LEFT")

    self.frame = frame
    self:RestoreFramePosition()
end

function Armoire:RefreshUI()
    if not self.frame then
        return
    end

    local sets = DB and DB.sets or {}
    local offset = self:ClampListOffset()
    local selectedSet = self:GetSelectedSet()
    self.frame.empty:SetShown(#sets == 0)

    for index, row in ipairs(self.frame.rows) do
        local set = sets[offset + index]
        if set then
            local setName = set.name
            local isSelected = selectedSet and selectedSet.name == setName
            row:Show()
            row.name:SetText(setName)
            row.count:SetText(CountSetSlots(set))
            row.highlight:SetShown(isSelected)
            if isSelected then
                row.name:SetTextColor(1, 0.82, 0)
                row.count:SetTextColor(1, 0.82, 0)
            else
                row.name:SetTextColor(1, 1, 1)
                row.count:SetTextColor(0.55, 0.55, 0.55)
            end
            row:SetScript("OnClick", function()
                Armoire:SelectSet(setName)
            end)
        else
            row:Hide()
        end
    end

    if selectedSet then
        self.frame.selectedTitle:SetText(selectedSet.name)
        self.frame.selectedDetails:SetText(CountSetSlots(selectedSet) .. " saved equipment slots")
        self.frame.slotSummary:SetText(self:GetSetSummary(selectedSet))
        self.frame.equipButton:Enable()
        self.frame.updateButton:Enable()
        self.frame.deleteButton:Enable()
    else
        self.frame.selectedTitle:SetText("No set selected")
        self.frame.selectedDetails:SetText("Create a set from your currently equipped gear.")
        self.frame.slotSummary:SetText("")
        self.frame.equipButton:Disable()
        self.frame.updateButton:Disable()
        self.frame.deleteButton:Disable()
    end

    self.frame.prevButton:SetShown(#sets > MAX_VISIBLE_SETS)
    self.frame.nextButton:SetShown(#sets > MAX_VISIBLE_SETS)
    if offset > 0 then
        self.frame.prevButton:Enable()
    else
        self.frame.prevButton:Disable()
    end

    if offset + MAX_VISIBLE_SETS < #sets then
        self.frame.nextButton:Enable()
    else
        self.frame.nextButton:Disable()
    end

    if #sets > #self.frame.rows then
        local firstVisible = offset + 1
        local lastVisible = math.min(offset + MAX_VISIBLE_SETS, #sets)
        self.frame.more:SetText("Showing " .. firstVisible .. "-" .. lastVisible .. " of " .. #sets .. " sets.")
    else
        self.frame.more:SetText("/armoire save, equip, delete, list, show, hide")
    end
end

function Armoire:ToggleUI(anchorToCharacter)
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        if anchorToCharacter and not (DB and DB.framePosition) then
            self:PositionNearCharacterFrame()
        end
        self.frame:Show()
        self:RefreshUI()
    end
end

function Armoire:CreateCharacterButton()
    if self.characterButton or not DB or not DB.showCharacterButton then
        return
    end

    local parent = PaperDollFrame or CharacterFrame
    if not parent then
        return
    end

    local button = CreateFrame("Button", "ArmoireCharacterButton", parent)
    button:SetSize(32, 32)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -36, -44)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(20, 20)
    button.icon:SetPoint("TOPLEFT", 7, -6)
    button.icon:SetTexture(ICON_TEXTURE)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.border = button:CreateTexture(nil, "OVERLAY")
    button.border:SetSize(54, 54)
    button.border:SetPoint("TOPLEFT", 0, 0)
    button.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button.pushed = button:CreateTexture(nil, "OVERLAY")
    button.pushed:SetSize(24, 24)
    button.pushed:SetPoint("TOPLEFT", 5, -4)
    button.pushed:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    button.pushed:SetAlpha(0.45)
    button.pushed:Hide()

    button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
    button.highlight:SetSize(31, 31)
    button.highlight:SetPoint("TOPLEFT", 1, -1)
    button.highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button.highlight:SetBlendMode("ADD")

    button:SetScript("OnMouseDown", function(self)
        self.icon:SetPoint("TOPLEFT", 8, -7)
        self.pushed:Show()
    end)
    button:SetScript("OnMouseUp", function(self)
        self.icon:SetPoint("TOPLEFT", 7, -6)
        self.pushed:Hide()
    end)

    button:SetScript("OnClick", function()
        Armoire:ToggleUI(true)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Armoire")
        GameTooltip:AddLine("Open saved equipment sets.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function(self)
        self.icon:SetPoint("TOPLEFT", 7, -6)
        self.pushed:Hide()
        GameTooltip:Hide()
    end)

    self.characterButton = button
end

function Armoire:HandleSlash(input)
    input = Trim(input)
    local command, rest = input:match("^(%S*)%s*(.-)$")
    command = Normalize(command)

    if command == "" or command == "show" then
        self.frame:Show()
        self:RefreshUI()
    elseif command == "hide" then
        self.frame:Hide()
    elseif command == "toggle" then
        self:ToggleUI()
    elseif command == "save" then
        self:SaveSet(rest)
    elseif command == "equip" then
        self:EquipSet(rest)
    elseif command == "delete" or command == "del" or command == "remove" then
        self:ConfirmDeleteSet(rest)
    elseif command == "list" then
        self:ListSets()
    else
        Print("Commands: /armoire, /armoire save <name>, /armoire equip <name>, /armoire delete <name>, /armoire list")
    end
end

Armoire:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON_NAME then
        EnsureDB()
        self:CreateUI()
        self:CreateCharacterButton()
        self:RefreshUI()

        SLASH_ARMOIRE1 = "/armoire"
        SLASH_ARMOIRE2 = "/arm"
        SlashCmdList.ARMOIRE = function(input)
            Armoire:HandleSlash(input)
        end

        Print("Loaded. Type /armoire to manage gear sets.")
    elseif event == "ADDON_LOADED" and arg1 == "Blizzard_CharacterFrame" then
        self:CreateCharacterButton()
    elseif event == "PLAYER_REGEN_ENABLED" and DB and DB.pendingSet then
        local pendingSet = DB.pendingSet
        DB.pendingSet = nil
        self:EquipSet(pendingSet)
    elseif event == "PLAYER_LOGIN" then
        self:CreateCharacterButton()
    end
end)

Armoire:RegisterEvent("ADDON_LOADED")
Armoire:RegisterEvent("PLAYER_LOGIN")
Armoire:RegisterEvent("PLAYER_REGEN_ENABLED")
