# Browns Staff Chat by Brown Developmenmt

Personal Discord: bwobrown
Discord Server: https://discord.gg/VHKrTaWUaH

# DO NOT RESTART THE SCRIPT WHILE THE SERVER IS LIVE IT WILL NOT WORK

**Adding Users**

/[command_name] add [serverId]

**Removing Users**

/[command_name] remove, [serverId]

**Players with ace perms: group.admin, group.management, or commands will auto have access**

# Exports (server sided)

---@param message [object | table]

exports.browns_staffchat:createMessage (message)

name: username [string] (default: "System")

contentType: message type [string] ("message", "media", or "location")

data: [object | table] => 
message: message [string] (only required if contyentType == 'message')
coords: [object | table ] [x: float, y: float] (only required if contentType == 'location')
url: link [string] (only required if contentType == 'media')
urlType: media type [string] ['image' or 'video'] (only required if contentType == 'media')

