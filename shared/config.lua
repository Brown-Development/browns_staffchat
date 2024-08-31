config = {}

config.command = 'scm' -- command to open staffchat & add or remove staff
config.key = { -- key settings
    enable = true, -- enable press key to open staffchat>
    key = 'K' -- key
}

--  players with these ace perms will auto have staffchat access
-- they will also be able to remove or add members from staff chat
config.AcePerms = { 
    'group.admin',
    'group.management',
    'group.developer',
    'command'
}