fx_version 'cerulean'
game 'gta5'

author 'Sun Fish Game Team'
description 'ESX魚機遊戲 - 完整復刻現實魚機功能'
version '1.0.0'

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/room.lua',
    'server/game.lua'
}

client_scripts {
    'client/main.lua',
    'client/ui.lua',
    'client/game.lua',
    'client/effects.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/sounds/*.ogg',
    'html/images/*.png',
    'html/images/*.jpg'
}

dependencies {
    'es_extended',
    'oxmysql'
} 