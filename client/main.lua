local callback = { 
    registered = {},
    awaiting = {}
}

local isAuthorized = false 
local appOpen = false

callback.register = function(name, cb)
    callback.registered[name] = cb
end

callback.await = function(name, ...)
    callback.awaiting[name] = false 
    TriggerServerEvent('browns_staffchat:server:callback', name, ...)
    while not callback.awaiting[name] do Citizen.Wait(0) end  
    return table.unpack (callback.awaiting[name])
end

RegisterNetEvent('browns_staffchat:client:callback', function(name, ...)
    local data = callback.registered[name](...)
    TriggerServerEvent('browns_staffchat:server:callbackResponse', name, data)
end)

RegisterNetEvent('browns_staffchat:client:callbackResponse', function(name, data)
    callback.awaiting[name] = data 
end)


RegisterNetEvent('playerSpawned')
AddEventHandler('playerSpawned', function()
    Citizen.Wait(10000)

    isAuthorized, Unreads = callback.await('onPlayerSpawned')

    if not isAuthorized then return end  

    SendNUIMessage({
        type = 'playerLoaded',
        unreads = Unreads
    })
end)

local function openChat ()
    if not isAuthorized then return end  

    if appOpen then return end 

    local username, messages = callback.await('onChatOpen')

    appOpen = true

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'open',
        username = username,
        messages = messages
    })
end

local function newMessage(data, cb)
    local success = callback.await('newMessage', data.message)
    if success then cb('ok') end
end

local function closeApp(_, cb)
    appOpen = false
    SetNuiFocus(false, false)
    cb('ok')
end

local function getLocation(_, cb)
    local x, y, _ = table.unpack(GetEntityCoords(PlayerPedId()))
    cb({ x = x, y = y })
end

local function setWaypoint(data, cb)
    SetNewWaypoint(data.coords.x, data.coords.y)
    cb('ok')
end

local function notify(message, title)
    TriggerEvent('chat:addMessage', {
        color = { 255, 0, 0},
        multiline = true,
        args = {title or 'STAFFCHAT', message}
    })
end


callback.register('onMessage', function(message)
    SendNUIMessage({
        type = 'newMessage',
        message = message 
    })
    return { appOpen }
end)

callback.register('onAuthorized', function()
    isAuthorized = true 

    _, Unreads = callback.await('onPlayerSpawned')

    SendNUIMessage({
        type = 'playerLoaded',
        unreads = Unreads
    })

    notify('You have been added to the staff chat!')

    return { true }
end)

callback.register('onDeAuthorized', function()
    isAuthorized = false 

    SendNUIMessage({ type = 'removeAccess' })

    notify('You have been removed from the staff chat!')


    return { true }
end)

AddEventHandler('onResourceStart', function(r)
    if r == GetCurrentResourceName() then 
        isAuthorized, Unreads = callback.await('onPlayerSpawned')

        if not isAuthorized then return end  
    
        SendNUIMessage({
            type = 'playerLoaded',
            unreads = Unreads
        })
    end
end)


RegisterCommand(config.command, function(source, args)
    if not args[1] then 
        openChat()
        return 
    end

    if args[1] == 'add' then 
        if not args[2] then  
            notify('Error: You must provide a valid server ID of the user you wish to give access to staff chat')
            return 
        else

            local valid, playerId = pcall(tonumber, args[2])

            if not valid then 
                notify('Error: You must provide a valid server ID of the user you wish to give access to staff chat')
                return 
            end

            local success, err = callback.await('addUser', playerId)

            if not success then 
                notify(("Error: %s"):format(err))
                return 
            end

            notify(('You added %s[%d] to Staff Chat!'):format(err, playerId))
        end
    elseif args[1] == 'remove' then 
        if not args[2] then  
            notify('Error: You must provide a valid server ID or license of the user you wish to remove from staff chat')
            return 
        else

            local success, err = callback.await('removeUser', playerId)

            if not success then 
                notify(("Error: %s"):format(err))
                return 
            end

            notify(('You removed %s[%d] from Staff Chat!'):format(err, playerId))
        end
    else
        notify('Please insert a valid action: add or remove')
    end

end)

Citizen.CreateThread(function()
    if config.key.enable then 
        RegisterKeyMapping(config.command, 'open staff chat or manage staff chat users', 'keyboard', config.key.key)
    end
end)


TriggerEvent('chat:addSuggestion', ('/%s'):format(config.command), 'open staff chat or manage staff chat users', {
    { name="action", help="add or remove" },
    { name="identifier", help="the players server ID or license" }
})

RegisterNUICallback('newMessage', newMessage)
RegisterNUICallback('closeApp', closeApp)
RegisterNUICallback('getLocation', getLocation)
RegisterNUICallback('setWaypoint', setWaypoint)