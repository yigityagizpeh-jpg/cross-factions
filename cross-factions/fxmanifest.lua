fx_version 'cerulean'
game 'gta5'

name        'cross-factions'
description 'QBCore Gang & Turf War sistemi — GunRP için production-ready'
author      'cross-factions'
version     '1.0.0'

-- Shared scripts (her iki tarafta da yüklenir)
shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/*.lua',
}

-- Client-side scripts
client_scripts {
    'client/main.lua',
    'client/turf.lua',
    'client/spray.lua',
    'client/menu.lua',
}

-- Server-side scripts
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/logs.lua',
    'server/main.lua',
    'server/gang.lua',
    'server/turf.lua',
    'server/war.lua',
    'server/spray.lua',
}

-- Dışa aktarılan fonksiyonlar (diğer scriptlerin kullanımı için)
exports {
    'GetPlayerGang',
    'IsPlayerInGang',
    'GetGangData',
}

-- Dosya izinleri
lua54 'yes'
