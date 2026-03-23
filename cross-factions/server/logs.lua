--[[
    server/logs.lua — Discord Webhook Log Sistemi
    Tüm önemli işlemler Discord'a loglanır.
    Config.Logs.Enabled = false yapılırsa devre dışı bırakılır.
--]]

---@param title string Log başlığı
---@param description string Log içeriği
---@param color number Discord embed rengi (decimal)
function SendLog(title, description, color)
    if not Config.Logs.Enabled then return end
    if Config.Logs.WebhookURL == 'DISCORD_WEBHOOK_URL_HERE' or Config.Logs.WebhookURL == '' then
        if Config.Debug then
            print('[cross-factions] UYARI: Config.Logs.WebhookURL ayarlanmamış! Discord logları devre dışı.')
        end
        return
    end

    local embed = {
        {
            title       = title,
            description = description,
            color       = color or Config.Logs.Color.Info,
            footer      = {
                text = os.date('%d/%m/%Y %H:%M:%S') .. ' | cross-factions'
            },
        }
    }

    PerformHttpRequest(Config.Logs.WebhookURL, function(err, text, headers)
        if err ~= 200 then
            if Config.Debug then
                print('[cross-factions] Log gönderilemedi. HTTP: ' .. tostring(err))
            end
        end
    end, 'POST', json.encode({
        username   = Config.Logs.BotName,
        avatar_url = Config.Logs.BotAvatar,
        embeds     = embed,
    }), { ['Content-Type'] = 'application/json' })
end

-- Kısayol fonksiyonlar
function LogGang(title, desc)     SendLog(title, desc, Config.Logs.Color.Info)    end
function LogTurf(title, desc)     SendLog(title, desc, Config.Logs.Color.Turf)    end
function LogWar(title, desc)      SendLog(title, desc, Config.Logs.Color.Error)   end
function LogKill(title, desc)     SendLog(title, desc, Config.Logs.Color.Kill)    end
function LogFinance(title, desc)  SendLog(title, desc, Config.Logs.Color.Finance) end
function LogAdmin(title, desc)    SendLog(title, desc, Config.Logs.Color.Warning) end
