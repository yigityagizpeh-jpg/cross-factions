--[[
    client/menu.lua — UI & Menü Sistemi
    ox_lib context menu tabanlı tüm menüler:
    - Boss Menüsü (üye yönetimi, kasa, ittifak, savaş)
    - Gang Bilgisi
    - Leaderboard
    - Turf Listesi
    - Savaş Skoru HUD
--]]

local QBCore = exports['qb-core']:GetCoreObject()

-- ─── War HUD (aktif savaş skoru) ─────────────────────────────────────────────
local WarHUDThread = nil

local function StartWarHUD(warId, g1Kills, g2Kills)
    if WarHUDThread then return end
    WarHUDThread = CreateThread(function()
        while ActiveWarData and ActiveWarData.warId == warId do
            -- ox_lib text UI ile skor göster
            lib.showTextUI(
                ('⚔️ Savaş Skoru: **%d - %d**'):format(
                    ActiveWarData.g1Kills or 0,
                    ActiveWarData.g2Kills or 0
                ),
                { position = 'top-center' }
            )
            Wait(2000)
        end
        lib.hideTextUI()
        WarHUDThread = nil
    end)
end

AddEventHandler('cross-factions:client:updateWarHUD', function()
    if ActiveWarData then
        StartWarHUD(ActiveWarData.warId, 0, 0)
    else
        lib.hideTextUI()
        WarHUDThread = nil
    end
end)

-- ─── Gang Oluştur Menüsü ─────────────────────────────────────────────────────
local function OpenCreateGangMenu()
    local input = lib.inputDialog('Gang Oluştur', {
        { type = 'input', label = 'Gang Adı',     placeholder = 'Örn: Los Santos Ballas', min = Config.GangCreation.MinNameLength, max = Config.GangCreation.MaxNameLength, required = true },
        { type = 'input', label = 'Gang Etiketi', placeholder = 'Örn: LSB', min = 1, max = Config.GangCreation.MaxTagLength, required = true },
        { type = 'color', label = 'Gang Rengi',   default = '#FF0000' },
    })
    if not input then return end
    local name  = input[1]
    local tag   = input[2]
    local color = input[3] or '#FF0000'
    TriggerServerEvent('cross-factions:server:createGang', name, tag, color)
end

-- ─── Boss Menüsü ─────────────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:openBossMenu', function()
    RefreshMyGang(function(data)
        if not data then
            -- Gang yok: oluşturma seçeneği sun
            lib.registerContext({
                id    = 'cf_no_gang_menu',
                title = '🏴 Gang Sistemi',
                options = {
                    {
                        title   = '➕ Gang Oluştur',
                        description = ('Oluşturma ücreti: $%s'):format(Config.GangCreation.RequireMoney and Config.GangCreation.MoneyAmount or 'Ücretsiz'),
                        icon    = 'fas fa-plus',
                        onSelect = function()
                            OpenCreateGangMenu()
                        end,
                    },
                },
            })
            lib.showContext('cf_no_gang_menu')
            return
        end

        local gang     = data.gang
        local myRank   = data.myRank
        local perms    = data.perms
        local members  = data.members or {}
        local rankLabel = Config.GangRanks[myRank] and Config.GangRanks[myRank].label or '?'

        -- Ana boss menüsü
        local options = {
            {
                title   = '👥 Üyeler',
                description = ('%d üye'):format(#members),
                icon    = 'fas fa-users',
                onSelect = function()
                    TriggerEvent('cross-factions:client:openMembersMenu', data)
                end,
            },
            {
                title   = '💰 Gang Kasası',
                description = ('Kasa: $%s'):format(gang.treasury or 0),
                icon    = 'fas fa-coins',
                onSelect = function()
                    TriggerEvent('cross-factions:client:openTreasuryMenu', gang)
                end,
                disabled = not perms.canAccessTreasury,
            },
            {
                title   = '🤝 İttifak Yönetimi',
                icon    = 'fas fa-handshake',
                onSelect = function()
                    TriggerEvent('cross-factions:client:openAllianceMenu')
                end,
                disabled = not perms.canManageWar,
            },
            {
                title   = '⚔️ Savaş Yönetimi',
                icon    = 'fas fa-swords',
                onSelect = function()
                    TriggerEvent('cross-factions:client:openWarMenu')
                end,
                disabled = not perms.canManageWar,
            },
            {
                title   = '📦 Gang Deposu',
                icon    = 'fas fa-box',
                onSelect = function()
                    TriggerServerEvent('cross-factions:server:openStash', 'stash')
                end,
                disabled = not perms.canUseStash,
            },
            {
                title   = '🔫 Silah Deposu',
                icon    = 'fas fa-gun',
                onSelect = function()
                    TriggerServerEvent('cross-factions:server:openStash', 'armory')
                end,
                disabled = not perms.canUseArmory,
            },
            {
                title   = '🚗 Gang Garajı',
                icon    = 'fas fa-car',
                onSelect = function()
                    TriggerEvent('cross-factions:client:openGarageMenu')
                end,
                disabled = not perms.canUseGarage,
            },
            {
                title   = '🚪 Gangdan Ayrıl',
                icon    = 'fas fa-door-open',
                onSelect = function()
                    lib.alertDialog({
                        header  = '⚠️ Gangdan Ayrıl',
                        content = 'Gangdan ayrılmak istediğinize emin misiniz?',
                        centered = true,
                        cancel  = true,
                    }, function(confirm)
                        if confirm == 'confirm' then
                            TriggerServerEvent('cross-factions:server:leaveGang')
                        end
                    end)
                end,
            },
        }

        lib.registerContext({
            id    = 'cf_boss_menu',
            title = ('🏴 %s [%s] — %s'):format(gang.name, gang.tag, rankLabel),
            options = options,
        })
        lib.showContext('cf_boss_menu')
    end)
end)

-- ─── Üye Yönetimi Menüsü ─────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:openMembersMenu', function(data)
    local members = data.members or {}
    local perms   = data.perms
    local options = {}

    if perms.canInvite then
        options[#options + 1] = {
            title   = '➕ Oyuncu Davet Et',
            icon    = 'fas fa-user-plus',
            onSelect = function()
                local input = lib.inputDialog('Oyuncu Davet', {
                    { type = 'number', label = 'Sunucu ID', required = true },
                })
                if not input or not input[1] then return end
                TriggerServerEvent('cross-factions:server:invitePlayer', tonumber(input[1]))
            end,
        }
    end

    for _, member in ipairs(members) do
        local rankLabel = Config.GangRanks[member.rankIndex] and Config.GangRanks[member.rankIndex].label or '?'
        local memberOptions = {}

        if perms.canPromote then
            memberOptions[#memberOptions + 1] = {
                title   = '⬆️ Terfi Ettir',
                onSelect = function()
                    local newRank = member.rankIndex + 1
                    if newRank > 4 then  -- Lider (5) olmak için ayrı mekanizma
                        Notify('Bu üyeyi daha fazla terfi ettiremezsiniz.', 'error')
                        return
                    end
                    TriggerServerEvent('cross-factions:server:setMemberRank', member.citizenid, newRank)
                end,
            }
            memberOptions[#memberOptions + 1] = {
                title   = '⬇️ Düşür',
                onSelect = function()
                    local newRank = member.rankIndex - 1
                    if newRank < 1 then return end
                    TriggerServerEvent('cross-factions:server:setMemberRank', member.citizenid, newRank)
                end,
            }
        end

        if perms.canKick then
            memberOptions[#memberOptions + 1] = {
                title   = '🚫 Gangdan At',
                onSelect = function()
                    lib.alertDialog({
                        header  = '⚠️ Üyeyi At',
                        content = ('%s adlı üyeyi gangdan atmak istiyor musunuz?'):format(member.name),
                        centered = true,
                        cancel  = true,
                    }, function(confirm)
                        if confirm == 'confirm' then
                            TriggerServerEvent('cross-factions:server:kickMember', member.citizenid)
                        end
                    end)
                end,
            }
        end

        if data.myRank == 5 then  -- Sadece lider devredebilir
            memberOptions[#memberOptions + 1] = {
                title   = '👑 Liderliği Devret',
                onSelect = function()
                    lib.alertDialog({
                        header  = '👑 Liderlik Transferi',
                        content = ('%s adlı üyeye liderliği devretmek istiyor musunuz?'):format(member.name),
                        centered = true,
                        cancel  = true,
                    }, function(confirm)
                        if confirm == 'confirm' then
                            TriggerServerEvent('cross-factions:server:transferLeadership', member.citizenid)
                        end
                    end)
                end,
            }
        end

        if #memberOptions > 0 then
            options[#options + 1] = {
                title       = member.name,
                description = rankLabel,
                icon        = 'fas fa-user',
                menu        = 'cf_member_' .. member.citizenid,
            }
            lib.registerContext({
                id    = 'cf_member_' .. member.citizenid,
                title = member.name .. ' — ' .. rankLabel,
                menu  = 'cf_boss_menu',
                options = memberOptions,
            })
        else
            options[#options + 1] = {
                title       = member.name,
                description = rankLabel,
                icon        = 'fas fa-user',
                disabled    = true,
            }
        end
    end

    lib.registerContext({
        id    = 'cf_members_menu',
        title = '👥 Üyeler',
        menu  = 'cf_boss_menu',
        options = options,
    })
    lib.showContext('cf_members_menu')
end)

-- ─── Kasa Menüsü ─────────────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:openTreasuryMenu', function(gang)
    lib.registerContext({
        id    = 'cf_treasury_menu',
        title = ('💰 Gang Kasası — $%s'):format(gang.treasury or 0),
        menu  = 'cf_boss_menu',
        options = {
            {
                title   = '⬆️ Para Yatır',
                icon    = 'fas fa-arrow-up',
                onSelect = function()
                    local input = lib.inputDialog('Kasa Para Yatır', {
                        { type = 'number', label = 'Miktar ($)', required = true, min = 1 },
                    })
                    if not input or not input[1] then return end
                    TriggerServerEvent('cross-factions:server:depositTreasury', tonumber(input[1]))
                end,
            },
            {
                title   = '⬇️ Para Çek',
                icon    = 'fas fa-arrow-down',
                onSelect = function()
                    local input = lib.inputDialog('Kasadan Para Çek', {
                        { type = 'number', label = 'Miktar ($)', required = true, min = 1 },
                    })
                    if not input or not input[1] then return end
                    TriggerServerEvent('cross-factions:server:withdrawTreasury', tonumber(input[1]))
                end,
            },
        },
    })
    lib.showContext('cf_treasury_menu')
end)

-- ─── İttifak Menüsü ──────────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:openAllianceMenu', function()
    QBCore.Functions.TriggerCallback('cross-factions:cb:getRelations', function(relations)
        local options = {}

        -- Mevcut ittifaklar
        for _, ally in ipairs(relations.allies or {}) do
            options[#options + 1] = {
                title       = '🤝 ' .. ally.name,
                description = 'Aktif İttifak',
                icon        = 'fas fa-handshake',
                onSelect    = function()
                    lib.alertDialog({
                        header  = '⚠️ İttifakı Boz',
                        content = (ally.name .. ' ile ittifakı bozmak istiyor musunuz?'),
                        centered = true,
                        cancel  = true,
                    }, function(confirm)
                        if confirm == 'confirm' then
                            TriggerServerEvent('cross-factions:server:breakAlliance', ally.gangId)
                        end
                    end)
                end,
            }
        end

        -- Yeni ittifak teklifi
        options[#options + 1] = {
            title   = '➕ İttifak Teklif Et',
            icon    = 'fas fa-plus',
            onSelect = function()
                local input = lib.inputDialog('İttifak Teklifi', {
                    { type = 'number', label = 'Hedef Gang ID', required = true },
                })
                if not input or not input[1] then return end
                TriggerServerEvent('cross-factions:server:sendAllianceRequest', tonumber(input[1]))
            end,
        }

        lib.registerContext({
            id    = 'cf_alliance_menu',
            title = '🤝 İttifak Yönetimi',
            menu  = 'cf_boss_menu',
            options = options,
        })
        lib.showContext('cf_alliance_menu')
    end)
end)

-- ─── Savaş Menüsü ────────────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:openWarMenu', function()
    QBCore.Functions.TriggerCallback('cross-factions:cb:getRelations', function(relations)
        local options = {}

        -- Aktif savaşlar
        for _, enemy in ipairs(relations.enemies or {}) do
            options[#options + 1] = {
                title       = '⚔️ ' .. enemy.name,
                description = ('Skor: %d - %d'):format(enemy.myKills, enemy.theirKills),
                icon        = 'fas fa-swords',
                disabled    = true,
            }
        end

        -- Yeni savaş ilanı
        options[#options + 1] = {
            title   = '🚨 Savaş İlan Et',
            icon    = 'fas fa-flag',
            onSelect = function()
                local input = lib.inputDialog('Savaş İlanı', {
                    { type = 'number', label = 'Hedef Gang ID', required = true },
                })
                if not input or not input[1] then return end
                TriggerServerEvent('cross-factions:server:declareWar', tonumber(input[1]))
            end,
        }

        lib.registerContext({
            id    = 'cf_war_menu',
            title = '⚔️ Savaş Yönetimi',
            menu  = 'cf_boss_menu',
            options = options,
        })
        lib.showContext('cf_war_menu')
    end)
end)

-- ─── Garaj Menüsü (stub) ─────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:openGarageMenu', function()
    Notify('Garaj sistemi yakında eklenecek!', 'inform')
end)

-- ─── Gang Bilgi Menüsü ────────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:openGangInfo', function()
    RefreshMyGang(function(data)
        if not data then
            Notify(T('no_gang'), 'error')
            return
        end
        local gang = data.gang
        local rankLabel = Config.GangRanks[data.myRank] and Config.GangRanks[data.myRank].label or '?'

        lib.registerContext({
            id    = 'cf_ganginfo_menu',
            title = ('🏴 %s [%s]'):format(gang.name, gang.tag),
            options = {
                { title = 'Rütbeniz', description = rankLabel,              icon = 'fas fa-medal',  disabled = true },
                { title = 'Seviye',   description = tostring(gang.level),   icon = 'fas fa-star',   disabled = true },
                { title = 'İtibar',   description = tostring(gang.reputation), icon = 'fas fa-trophy', disabled = true },
                { title = 'Kasa',     description = ('$%s'):format(gang.treasury), icon = 'fas fa-coins', disabled = true },
            },
        })
        lib.showContext('cf_ganginfo_menu')
    end)
end)

-- ─── Leaderboard Menüsü ───────────────────────────────────────────────────────
AddEventHandler('cross-factions:client:openLeaderboard', function()
    QBCore.Functions.TriggerCallback('cross-factions:cb:getLeaderboard', function(board)
        local options = {}

        if not board or #board == 0 then
            options[1] = { title = 'Henüz veri yok.', disabled = true }
        else
            for _, entry in ipairs(board) do
                options[#options + 1] = {
                    title       = ('#%d — %s'):format(entry.rank, entry.gangName),
                    description = ('Kill: %d | İtibar: %d'):format(entry.kills, entry.reputation),
                    icon        = entry.rank == 1 and 'fas fa-crown' or 'fas fa-medal',
                    disabled    = true,
                }
            end
        end

        lib.registerContext({
            id    = 'cf_leaderboard_menu',
            title = '🏆 Haftalık Gang Sıralaması',
            options = options,
        })
        lib.showContext('cf_leaderboard_menu')
    end)
end)

-- ─── Turf Listesi Menüsü ─────────────────────────────────────────────────────
RegisterCommand('turflist', function()
    QBCore.Functions.TriggerCallback('cross-factions:cb:getTurfStates', function(states)
        local options = {}
        for _, turf in ipairs(Config.Turfs) do
            local state = states and states[turf.id] or {}
            local ownerName = state.owner and '?' or T('turf_no_owner')
            -- TODO: gang name lookup by ID (sunucudan gang listesi alınmalı)
            local status = state.isCapturing and '🔴 Savaşta' or (state.owner and '🟢 Sahipli' or '⚪ Sahipsiz')
            options[#options + 1] = {
                title       = turf.name,
                description = ('%s | Sahip: %s | Gelir: $%d/saat'):format(status, ownerName, turf.income),
                icon        = 'fas fa-map-marker-alt',
                disabled    = true,
            }
        end

        lib.registerContext({
            id    = 'cf_turf_list',
            title = '🗺️ Turf Bölgeleri',
            options = options,
        })
        lib.showContext('cf_turf_list')
    end)
end, false)
