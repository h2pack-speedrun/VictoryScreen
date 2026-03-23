local mods = rom.mods
mods['SGG_Modding-ENVY'].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods['SGG_Modding-ModUtil']
chalk = mods['SGG_Modding-Chalk']
reload = mods['SGG_Modding-ReLoad']
local lib = mods['adamant-Modpack_Lib']

config = chalk.auto('config.lua')
public.config = config

local _, revert = lib.createBackupSystem()

-- =============================================================================
-- MODULE DEFINITION
-- =============================================================================

public.definition = {
    id       = "ShowArcanaAndFearVictoryScreen",
    name     = "Show Arcana and Fear on the initial Victory Screen",
    category = "QoL",
    group    = "QoL",
    tooltip  = "Displays the Arcana and Fear victory screen.",
    default  = true,
    dataMutation = false,
}

-- =============================================================================
-- MODULE LOGIC
-- =============================================================================

local MetaUpgradeDisplay = {
    StartY = 895,
    SpacingX = 40,
    SpacingY = 50,
    Columns = 25,
    IconScale = 0.135,
    IconCenterOffsetX = 20,
    Group = "Combat_Menu_TraitTray_Overlay",
    Components = {},
    RefIconScale = 0.21,
    BaseHighlightAnimScale = 0.33,
    BaseTrayHighlightAnimScale = 1.5,
    BasePinIconScale = 0.12,
    BasePinIconFrameScale = 0.4,
    HighlightAnim = "DevCard_Hover",
}

local ShrineUpgradeDisplay = {
    GapAfterMeta = 10,
    SpacingX = 50,
    SpacingY = 50,
    Columns = 17,
    IconScale = 0.2,
    IconCenterOffsetX = 20,
    Group = "Combat_Menu_TraitTray_Overlay",
    Components = {},
    RefIconScale = 0.4,
    BaseHighlightAnimScale = 0.27,
    BaseTrayHighlightAnimScale = 1.4,
    BasePinIconScale = 0.28,
    BasePinIconFrameScale = 0.0,
    HighlightAnim = "GUI\\Screens\\Shrine\\PactHover",
    PipOffsetY = 22,
    PipSpacing = 10,
    PipFilled = "\226\151\143",
    PipEmpty = "\226\151\139",
    PipFontSize = 12,
    PipFilledColor = { 255, 210, 80, 255 },
    PipEmptyColor = { 140, 140, 140, 180 },
}

local function GetTraitTrayScreen()
    return ActiveScreens.TraitTrayScreen
end

local function CreateMetaUpgradeDisplay()
    local display = MetaUpgradeDisplay
    display.Components = {}
    local screen = GetTraitTrayScreen()

    local equippedCards = {}
    for _, row in ipairs(MetaUpgradeDefaultCardLayout) do
        for _, metaUpgradeName in ipairs(row) do
            local metaUpgradeState = GameState.MetaUpgradeState[metaUpgradeName]
            if metaUpgradeState ~= nil and metaUpgradeState.Equipped then
                local cardData = MetaUpgradeCardData[metaUpgradeName]
                if cardData and cardData.Image and cardData.TraitName and HeroHasTrait(cardData.TraitName) then
                    local trait = GetHeroTrait(cardData.TraitName)
                    table.insert(equippedCards, { CardData = cardData, Trait = trait })
                end
            end
        end
    end

    local totalCards = #equippedCards
    if totalCards == 0 then return display.StartY end

    local centerX = ScreenCenterX
    local yOffset = display.StartY
    local cardIndex = 1

    while cardIndex <= totalCards do
        local rowCount = math.min(display.Columns, totalCards - cardIndex + 1)
        local rowWidth = (rowCount - 1) * display.SpacingX
        local rowStartX = centerX - rowWidth / 2

        for i = 0, rowCount - 1 do
            local entry = equippedCards[cardIndex]
            local cardData = entry.CardData
            local xPos = rowStartX + i * display.SpacingX
            local iconX = xPos + display.IconCenterOffsetX

            local icon = CreateScreenComponent({
                Name = "TraitTrayIconButton",
                X = iconX, Y = yOffset,
                Group = display.Group,
                Scale = display.IconScale,
                Animation = cardData.Image,
            })
            SetAlpha({ Id = icon.Id, Fraction = 1.0, Duration = 0.2 })

            if screen then
                local scaleFactor = display.IconScale / display.RefIconScale
                AttachLua({ Id = icon.Id, Table = icon })
                icon.Screen = screen
                icon.OnMouseOverFunctionName = "TraitTrayIconButtonMouseOver"
                icon.OnMouseOffFunctionName = "TraitTrayIconButtonMouseOff"
                icon.Icon = cardData.Image
                icon.IconScale = display.IconScale
                icon.PinIconScale = display.BasePinIconScale * scaleFactor
                icon.PinIconFrameScale = display.BasePinIconFrameScale * scaleFactor
                icon.OffsetX = iconX
                icon.OffsetY = yOffset
                icon.HighlightAnim = display.HighlightAnim
                icon.HighlightAnimScale = display.BaseHighlightAnimScale * scaleFactor
                icon.TrayHighlightAnimScale = display.BaseTrayHighlightAnimScale * scaleFactor
                icon.TraitData = entry.Trait
                screen.Icons[icon.Id] = icon
                UseableOn({ Id = icon.Id })
                CreateTextBox({
                    Id = icon.Id, UseDescription = true,
                    VariableAutoFormat = "BoldFormatGraft",
                    Scale = 0.0, Hide = true,
                })
                ModifyTextBox({ Id = icon.Id, BlockTooltip = true })
            end

            table.insert(display.Components, icon.Id)
            cardIndex = cardIndex + 1
        end
        yOffset = yOffset + display.SpacingY
    end
    return yOffset
end

local function CreateShrineUpgradeDisplay(startY)
    local display = ShrineUpgradeDisplay
    display.Components = {}
    local screen = GetTraitTrayScreen()

    local activeShrines = {}
    for _, shrineUpgradeName in ipairs(ShrineUpgradeOrder) do
        local rank = GameState.ShrineUpgrades[shrineUpgradeName] or 0
        if rank >= 1 then
            local upgradeData = MetaUpgradeData[shrineUpgradeName]
            if upgradeData and upgradeData.Icon then
                table.insert(activeShrines, { Data = upgradeData, Rank = rank, Name = shrineUpgradeName })
            end
        end
    end

    local totalShrines = #activeShrines
    if totalShrines == 0 then return end

    local centerX = ScreenCenterX
    local yOffset = startY + display.GapAfterMeta
    local shrineIndex = 1

    while shrineIndex <= totalShrines do
        local rowCount = math.min(display.Columns, totalShrines - shrineIndex + 1)
        local rowWidth = (rowCount - 1) * display.SpacingX
        local rowStartX = centerX - rowWidth / 2

        for i = 0, rowCount - 1 do
            local shrine = activeShrines[shrineIndex]
            local xPos = rowStartX + i * display.SpacingX
            local iconX = xPos + display.IconCenterOffsetX

            local icon = CreateScreenComponent({
                Name = "TraitTrayIconButton",
                X = iconX, Y = yOffset,
                Group = display.Group,
                Scale = display.IconScale,
                Animation = shrine.Data.Icon,
            })
            SetAlpha({ Id = icon.Id, Fraction = 1.0, Duration = 0.2 })

            if screen then
                local scaleFactor = display.IconScale / display.RefIconScale
                AttachLua({ Id = icon.Id, Table = icon })
                icon.Screen = screen
                icon.OnMouseOverFunctionName = "TraitTrayIconButtonMouseOver"
                icon.OnMouseOffFunctionName = "TraitTrayIconButtonMouseOff"
                icon.Icon = shrine.Data.Icon
                icon.IconScale = display.IconScale
                icon.PinIconScale = display.BasePinIconScale * scaleFactor
                icon.PinIconFrameScale = display.BasePinIconFrameScale * scaleFactor
                icon.OffsetX = iconX
                icon.OffsetY = yOffset
                icon.HighlightAnim = display.HighlightAnim
                icon.HighlightAnimScale = display.BaseHighlightAnimScale * scaleFactor
                icon.TrayHighlightAnimScale = display.BaseTrayHighlightAnimScale * scaleFactor
                local componentData = ShallowCopyTable(shrine.Data)
                componentData.Rank = shrine.Rank
                icon.TraitData = componentData
                screen.Icons[icon.Id] = icon
                UseableOn({ Id = icon.Id })
                CreateTextBox({
                    Id = icon.Id, UseDescription = true,
                    VariableAutoFormat = "BoldFormatGraft",
                    Scale = 0.0, Hide = true,
                })
                ModifyTextBox({ Id = icon.Id, BlockTooltip = true })
            end

            table.insert(display.Components, icon.Id)

            local maxRank = #shrine.Data.Ranks
            if maxRank > 0 then
                local totalPipWidth = (maxRank - 1) * display.PipSpacing
                local pipStartX = iconX - totalPipWidth / 2
                for r = 1, maxRank do
                    local pipX = pipStartX + (r - 1) * display.PipSpacing
                    local isFilled = r <= shrine.Rank
                    local pipComponent = CreateScreenComponent({
                        Name = "BlankObstacle",
                        X = pipX, Y = yOffset + display.PipOffsetY,
                        Group = display.Group,
                    })
                    CreateTextBox({
                        Id = pipComponent.Id,
                        Text = isFilled and display.PipFilled or display.PipEmpty,
                        FontSize = display.PipFontSize,
                        Color = isFilled and display.PipFilledColor or display.PipEmptyColor,
                        Font = "P22UndergroundSCMedium",
                        ShadowBlur = 0,
                        ShadowColor = { 0, 0, 0, 255 },
                        ShadowOffset = { 0, 1 },
                        Justification = "Center",
                    })
                    SetAlpha({ Id = pipComponent.Id, Fraction = 1.0, Duration = 0.2 })
                    table.insert(display.Components, pipComponent.Id)
                end
            end

            shrineIndex = shrineIndex + 1
        end
        yOffset = yOffset + display.SpacingY
    end
end

local function DestroyDisplays()
    local screen = GetTraitTrayScreen()
    if screen then
        for _, id in ipairs(MetaUpgradeDisplay.Components) do screen.Icons[id] = nil end
        for _, id in ipairs(ShrineUpgradeDisplay.Components) do screen.Icons[id] = nil end
    end
    if #MetaUpgradeDisplay.Components > 0 then
        Destroy({ Ids = MetaUpgradeDisplay.Components })
        MetaUpgradeDisplay.Components = {}
    end
    if #ShrineUpgradeDisplay.Components > 0 then
        Destroy({ Ids = ShrineUpgradeDisplay.Components })
        ShrineUpgradeDisplay.Components = {}
    end
end

local function apply()
end

local function registerHooks()
    modutil.mod.Path.Wrap("OpenRunClearScreen", function(base)
        if lib.isEnabled(config) then
            thread(function()
                wait(0.5)
                local metaEndY = CreateMetaUpgradeDisplay()
                CreateShrineUpgradeDisplay(metaEndY)
            end)
        end
        base()
    end)

    modutil.mod.Path.Wrap("CloseRunClearScreen", function(base, screen)
        if lib.isEnabled(config) then
            DestroyDisplays()
        end
        base(screen)
    end)

    modutil.mod.Path.Wrap("TraitTrayScreenRemoveItems", function(base, screen)
        if not lib.isEnabled(config) then return base(screen) end

        local savedIcons = {}
        for _, id in ipairs(MetaUpgradeDisplay.Components) do
            if screen.Icons[id] then
                savedIcons[id] = screen.Icons[id]
                screen.Icons[id] = nil
            end
        end
        for _, id in ipairs(ShrineUpgradeDisplay.Components) do
            if screen.Icons[id] then
                savedIcons[id] = screen.Icons[id]
                screen.Icons[id] = nil
            end
        end

        base(screen)

        for id, icon in pairs(savedIcons) do
            screen.Icons[id] = icon
        end
    end)
end

-- =============================================================================
-- Wiring
-- =============================================================================

public.definition.apply = apply
public.definition.revert = revert

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(function()
        import_as_fallback(rom.game)
        registerHooks()
        if lib.isEnabled(config) then apply() end
        if public.definition.dataMutation and not mods['adamant-Modpack_Core'] then
            SetupRunData()
        end
    end)
end)

local uiCallback = lib.standaloneUI(public.definition, config, apply, revert)
rom.gui.add_to_menu_bar(uiCallback)
