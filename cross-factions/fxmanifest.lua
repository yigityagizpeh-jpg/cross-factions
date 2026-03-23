fx_version 'cerulean'
game 'gta5'

name        'cross-factions'
description 'QBCore Faction / Territory / War Sistemi'
author      'cross-factions'
version     '1.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
}

lua54 'yes'
