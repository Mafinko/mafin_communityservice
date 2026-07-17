fx_version 'cerulean'
games { 'gta5' }


author 'Mafin'
description 'Mafin Community Service ESX/QB'

version '1.0.0'
lua54 'yes'

shared_scripts {
	'@ox_lib/init.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
	'config.lua',
	'server/main.lua'
}

client_scripts {
	'config.lua',
	'client/main.lua'
}

ui_page 'html/index.html'

files {
	'html/index.html',
	'html/style.css',
	'html/app.js'
}
