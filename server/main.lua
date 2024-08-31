Citizen.CreateThread(function()
    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `browns_staffchat_messages` (
        `license` longtext DEFAULT NULL,
        `message` longtext DEFAULT NULL,
        `id` int(11) NOT NULL AUTO_INCREMENT,
        PRIMARY KEY (`id`),
        KEY `id` (`id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
    ]])

    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `browns_staffchat_unreads` (
        `license` longtext DEFAULT NULL,
        `unreads` int(11) DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
    ]])

    exports.oxmysql:execute([[
        CREATE TABLE IF NOT EXISTS `browns_staffchat_users` (
        `license` longtext DEFAULT NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
    ]])
end)

local callback = {
    registered = {},
    awaiting = {},
}

local authorizedUsers = {}
local yield = false

callback.register = function(name, cb)
    callback.registered[name] = cb 
end

callback.await = function(name, source, ...)

    if not source then return nil end 
    if not callback.awaiting[tostring(source)] then 
        callback.awaiting[tostring(source)] = {}
    end

    callback.awaiting[tostring(source)][name] = false 

    TriggerClientEvent('browns_staffchat:client:callback', source, name)

    while not callback.awaiting[tostring(source)][name] do Citizen.Wait(0) end

    return table.unpack(callback.awaiting[tostring(source)][name])
end

RegisterNetEvent('browns_staffchat:server:callback', function(name, ...)
    local src = source
    local data = callback.registered[name](src, ...)
    TriggerClientEvent('browns_staffchat:client:callbackResponse', src, name, data)
end)

RegisterNetEvent('browns_staffchat:server:callbackResponse', function(name, data)
    local src = source 
    callback.awaiting[tostring(src)][name] = data
end)


AddEventHandler('playerDropped', function()
    yield = true 

    local src = source 

    for i, v in ipairs(authorizedUsers) do 
        if v and v.source == src then 
            authorizedUsers[i] = nil 
            break 
        end
    end

    yield = false
    
    for k, p in ipairs(playersJoined) do 
        if p and p.source == src then 
            playersJoined[k] = nil 
            break 
        end
    end
end)

callback.register('onPlayerSpawned', function(source)
    local license = GetPlayerIdentifierByType(source, 'license')

    playersJoined[#playersJoined+1] = {
        source = source, 
        license = license
    }

    local playerData = MySQL.query.await('SELECT * FROM browns_staffchat_users WHERE `license` = ?', { license })

    if not playerData or not playerData[1] then 
        local isAceAuthorized = false

        for _, perm in ipairs(config.AcePerms) do 
            if IsPlayerAceAllowed(source, perm) then 
                isAceAuthorized = true 
                break 
            end
        end

        if isAceAuthorized then 
            local newAdmin = MySQL.insert.await('INSERT INTO browns_staffchat_users (license) VALUES (?)', {
                license
            })
            return { true, 0 } 
        end 

        return { false }
    end 

    authorizedUsers[#authorizedUsers+1] = {
        source = source,
        license = license
    }

    local Unreads = MySQL.query.await('SELECT * FROM browns_staffchat_unreads WHERE `license` = ?', { license })

    if not Unreads or not Unreads[1] then return { true, 0 } end 

    return { true, Unreads[1].unreads or 0 }
end)

callback.register('onChatOpen', function(source)

    local license = GetPlayerIdentifierByType(source, 'license')

    local messages = MySQL.query.await('SELECT * FROM browns_staffchat_messages')

    if not messages or not messages[1] then 
        return { GetPlayerName(source), false }
    end

    local chatData = {}

    local placement = 0

    for i = 1, #messages do 
        local message = messages[i]
        local messageType = message.license == license and 'sent' or 'rec'
        local messageData = json.decode(message.message)
        messageData.type = messageType 
        chatData[#chatData+1] = messageData
    end

    local unreads = MySQL.query.await('SELECT * FROM browns_staffchat_unreads WHERE `license` = ?', { license })

    if unreads and unreads[1] then 
        local update = MySQL.update.await('UPDATE browns_staffchat_unreads SET unreads = ? WHERE `license` = ?', {
            0, license
        })
    end

    return { GetPlayerName(source), chatData}
end)

callback.register('newMessage', function(source, message)
    local license = GetPlayerIdentifierByType(source, 'license')
    local save = MySQL.insert.await('INSERT INTO browns_staffchat_messages (license, message) VALUES (?, ?)', {
        license, json.encode(message)
    })

    message.type = 'rec'

    for _, user in ipairs(authorizedUsers) do 
        while yield do Citizen.Wait(0) end  
        if user then 
            local userAppOpen = callback.await('onMessage', user.source, message)
            if not userAppOpen then 

                local unreads = MySQL.query.await('SELECT * FROM browns_staffchat_unreads WHERE `license` = ?', { user.license })

                if not unreads or not unreads[1] then 
                    local insert = MySQL.insert.await('INSERT INTO browns_staffchat_unreads (license, unreads) VALUES (?, ?)', {
                        user.license, 1
                    })
                else
                    local update = MySQL.update.await('UPDATE browns_staffchat_unreads SET unreads = ? WHERE `license` = ?', {
                        unreads[1].unreads + 1, user.license
                    })
                end
            end
        end
    end

    return { true }
end)

callback.register('addUser', function(source, playerId)

    local identifierType

    if not string.find(playerId, 'license') then 
        local valid, id = pcall(tonumber, playerId) 
        if not valid then  
            return { false, 'identifier must be a valid player id or license'}
        end

        playerId = id 
        identifierType = 'serverId'
    else
        identifierType = 'license'
    end

    local invokerLicense = GetPlayerIdentifierByType(source, 'license')

    local isActionAuthorized = MySQL.query.await('SELECT * FROM browns_staffchat_users WHERE `license` = ?', { invokerLicense })

    if not isActionAuthorized or not isActionAuthorized[1] then
        return { false, 'You dont have permissions to do this' }
    end

    local isAceAuthorized = false

    for _, perm in ipairs(config.AcePerms) do 
        if IsPlayerAceAllowed(source, perm) then 
            isAceAuthorized = true 
            break 
        end
    end

    if not isAceAuthorized then 
        return { false, 'You can not modify staff chat users'}
    end

    if identifierType == 'playerId' then
        local isPlayerValid = GetPlayerPed(playerId) or false 

        if not isPlayerValid then return { false, ('No player exists with server ID: %d'):format(playerId) } end
    elseif identifierType == 'license' then 
        local isAlreadyAuth = MySQL.query.await('SELECT * FROM browns_staffchat_users WHERE `license` = ?', { playerId })

        if not isAlreadyAuth or not isAlreadyAuth[1] then  
            return { false, ('Player with license: %s already has staff chat access'):format(playerId) }
        end
    end  

    if identifierType == 'license' then
        local newAdmin = MySQL.insert.await('INSERT INTO browns_staffchat_users (license) VALUES (?)', {
            playerId
        })

        local playerSrc

        for _, v in ipairs(playersJoined) do 
            if v and v.license == playerId then 
                playerSrc = v.source 
                break 
            end
        end

        local addUser = callback.await('onAuthorized', playerSrc)

        return { true, GetPlayerName(playerSrc) } 

    elseif identifierType == 'serverId' then 

        local playerLicense = GetPlayerIdentifierByType(playerId, 'license')

        local newAdmin = MySQL.insert.await('INSERT INTO browns_staffchat_users (license) VALUES (?)', {
            playerLicense
        })

        local addUser = callback.await('onAuthorized', playerId)

        return { true, GetPlayerName(playerId) } 

    end


end)

callback.register('removeUser', function(source, playerId)

    local identifierType

    if not string.find(playerId, 'license') then 
        local valid, id = pcall(tonumber, playerId) 
        if not valid then  
            return { false, 'identifier must be a valid player id or license'}
        end

        playerId = id 
        identifierType = 'serverId'
    else
        identifierType = 'license'
    end

    local invokerLicense = GetPlayerIdentifierByType(source, 'license')

    local isActionAuthorized = MySQL.query.await('SELECT * FROM browns_staffchat_users WHERE `license` = ?', { invokerLicense })

    if not isActionAuthorized or not isActionAuthorized[1] then
        return { false, 'You dont have permissions to do this' }
    end

    if identifierType == 'playerId' then
        local isPlayerValid = GetPlayerPed(playerId) or false 

        if not isPlayerValid then return { false, ('No player exists with server ID: %d'):format(playerId) } end
    elseif identifierType == 'license' then 
        local isAlreadyAuth = MySQL.query.await('SELECT * FROM browns_staffchat_users WHERE `license` = ?', { playerId })

        if not isAlreadyAuth or not isAlreadyAuth[1] then  
            return { false, ('Player with license: %s never had access to staff chat to begin with...'):format(playerId) }
        end
    end  

    local isAceAuthorized = false

    for _, perm in ipairs(config.AcePerms) do 
        if IsPlayerAceAllowed(source, perm) then 
            isAceAuthorized = true 
            break 
        end
    end

    if not isAceAuthorized then 
        return { false, 'You can not modify staff chat users'}
    end


    if identifierType == 'playerId' then 

        local license = GetPlayerIdentifierByType(playerId, 'license')

        exports.oxmysql:execute('DROP FROM browns_staffchat_users WHERE `license` = ?', {
            license
        })

        local removeUser = callback.await('onDeAuthorized', playerId)

        return { true, GetPlayerName(playerId) } 


    elseif identifierType == 'license' then 
        exports.oxmysql:execute('DROP FROM browns_staffchat_users WHERE `license` = ?', {
            playerId
        })

        local playerSrc

        for _, v in ipairs(playersJoined) do 
            if v and v.license == playerId then 
                playerSrc = v.source
            end
        end

        local removeUser = callback.await('onDeAuthorized', playerSrc)

        return { true, GetPlayerName(playerSrc) } 

    end

end)

local function createMessage(message) 
    local resource, resourceName = pcall(GetInvokingResource) 

    if not resource then 
        resourceName = 'Unknown'
    end

    if not message or type(message) ~= 'table' then 
        error(('createMessage: ( param1 => message ) must be a table, received: %s'):format(type(message)))
        return false 
    end

    if not message.name then message.name = 'System' end 

    message.type = 'rec'

    if not message.contentType then  
        error('createMessage: (key => contentType of param1 (message) ) was falsey or does not have an acceptable value')
        return false 
    end

    if message.contentType ~= 'message' and message.contentType ~= 'media' and message.contentType ~= 'location' then 
        error('createMessage: (key => contentType of param1 (message) ) was falsey or does not have an acceptable value')
        return false 
    end

    if not message.data then 
        error('createMessage: (key => data of param1 (message) ) was falsey')
        return false  
    end

    if message.contentType == 'message' then  
        if not message.data.message or type(message.data.message) ~= 'string' then 
            error('createMessage: (key => message of key => data of param1 (message) ) was falsey or does not have valid value type for contentType: message')
            return false 
        end
    elseif message.contentType == 'media' then 
        if not message.data.url or type(message.data.url) ~= 'string' then 
            error('createMessage: (key => url of key => data of param1 (message) ) was falsey or does not have valid value type for contentType: media')
            return false 
        end

        if not message.data.urlType or ( message.data.urlType ~= 'video' and message.data.urlType ~= 'image') then 
            error('createMessage: (key => urlType of key => data of param1 (message) ) was falsey or does not have an acceptable value for contentType: media')
            return false 
        end
    elseif message.contenType == 'location' then 
        if not message.data.coords or type(message.data.coords) ~= 'table' then 
            error('createMessage: (key => coords of key => data of param1 (message) ) was falsey or does not have an acceptable value for contentType: media')
            return false 
        end
        
        local xvalid, x = pcall(type, message.data.coords.x)
        local yvalid, y = pcall(type, message.data.coords.y)

        if not xvalid then 
            error('createMessage: (key => x of key => coords of key => data of param1 (message) ) was falsey or does not have a valid value for contentType: location')
            return false 
        end

        if not yvalid then 
            error('createMessage: (key => y of key => coords of key => data of param1 (message) ) was falsey or does not have a valid value for contentType: location')
            return false 
        end

        if x ~= 'number' then 
            error('createMessage: (key => x of key => coords of key => data of param1 (message) ) was falsey or does not have a valid value type for contentType: location')
            return false 
        end

        if y ~= 'number' then 
            error('createMessage: (key => y of key => coords of key => data of param1 (message) ) was falsey or does not have a valid value type for contentType: location')
            return false 
        end

    end

    local save = MySQL.insert.await('INSERT INTO browns_staffchat_messages (license, message) VALUES (?, ?)', {
        'system', json.encode(message)
    })

    for _, user in ipairs(authorizedUsers) do 
        while yield do Citizen.Wait(0) end  
        if user then 
            local userAppOpen = callback.await('onMessage', user.source, message)
            if not userAppOpen then 

                local unreads = MySQL.query.await('SELECT * FROM browns_staffchat_unreads WHERE `license` = ?', { user.license })

                if not unreads or not unreads[1] then 
                    local insert = MySQL.insert.await('INSERT INTO browns_staffchat_unreads (license, unreads) VALUES (?, ?)', {
                        user.license, 1
                    })
                else
                    local update = MySQL.update.await('UPDATE browns_staffchat_unreads SET unreads = ? WHERE `license` = ?', {
                        unreads[1].unreads + 1, user.license
                    })
                end
            end
        end
    end

    return true 

end

exports('createMessage', createMessage)


