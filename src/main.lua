local mods = rom.mods
mods['SGG_Modding-ENVY'].auto()

---@diagnostic disable: lowercase-global
rom = rom
_PLUGIN = _PLUGIN
game = rom.game
modutil = mods['SGG_Modding-ModUtil']
chalk = mods['SGG_Modding-Chalk']
reload = mods['SGG_Modding-ReLoad']
local lib = mods['adamant-Modpack_Lib'].public

config = chalk.auto('config.lua')
public.config = config

local backup, restore = lib.createBackupSystem()

-- =============================================================================
-- MODULE DEFINITION
-- =============================================================================

public.definition = {
    id       = "ShowArcanaAndFearVictoryScreen",
    name     = "Show Arcana and Fear on the initial Victory Screen",
    category = "QoLSettings",
    group    = "QoL",
    tooltip  = "Displays the Arcana and Fear victory screen.",
    default  = true,
    dataMutation = false,
}

-- =============================================================================
-- MODULE LOGIC
-- =============================================================================

local function apply()
end

local function registerHooks()
    modutil.mod.Path.Wrap("OpenRunClearScreen", function(base)
        if config.Enabled then
            thread(function()
                wait(0.5)
                local metaEndY = CreateMetaUpgradeDisplay()
                CreateShrineUpgradeDisplay(metaEndY)
            end)
        end
        base()
    end)

    modutil.mod.Path.Wrap("CloseRunClearScreen", function(base, screen)
        if config.Enabled then
            DestroyDisplays()
        end
        base(screen)
    end)

    modutil.mod.Path.Wrap("TraitTrayScreenRemoveItems", function(base, screen)
        if not config.Enabled then return base(screen) end

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

public.definition.enable = apply
public.definition.disable = restore

local loader = reload.auto_single()

modutil.once_loaded.game(function()
    loader.load(function()
        import_as_fallback(rom.game)
        registerHooks()
        if config.Enabled then apply() end
        if public.definition.dataMutation and not mods['adamant-Core'] then
            SetupRunData()
        end
    end)
end)

lib.standaloneUI(public.definition, config, apply, restore)
