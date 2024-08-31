fx_version 'bodacious'
author 'Brown Development'
description 'Staff Chat'
game 'gta5'
lua54 'yes'

shared_script 'shared/config.lua'

client_script 'client/main.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

files {
    'ui/app.js',
    'ui/styles.css',
    'ui/web.html',
    'ui/assets/broken-image.png'
}

ui_page 'ui/web.html'

dependency 'oxmysql'

escrow_ignore 'shared/config.lua'