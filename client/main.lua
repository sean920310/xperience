local Xperience = {}

TriggerServerEvent('xperience:server:load')

function Xperience:Init(data)
    local Ranks = self:CheckRanks()
    
    if #Ranks > 0 then
        PrintTable(Ranks)
        return
    end

    self.CurrentXP      = tonumber(data.xp)
    self.CurrentRank    = tonumber(data.rank)

    self:InitialiseUI()

    self.Ready = true

    RegisterCommand('+xperience', function() self:OpenUI() end)
    RegisterCommand('-xperience', function() end)
    RegisterKeyMapping('+xperience', 'Show Rank Bar', 'keyboard', 'z')
end

function Xperience:Load()
    TriggerServerEvent('xperience:server:load')
end


----------------------------------------------------
--                 EVENT CALLBACKS                --
----------------------------------------------------

function Xperience:OnRankChange(data, cb)
    if data.rankUp then
        TriggerEvent("experience:client:rankUp", data.current, data.previous)
    else
        TriggerEvent("experience:client:rankDown", data.current, data.previous)      
    end
        
    local Rank = Config.Ranks[data.current]
    
    if Rank.Action ~= nil and type(Rank.Action) == "function" then
        Rank.Action(data.rankUp, data.previous)
    end
    
    cb('ok')
end

function Xperience:OnSave(data, cb)
    self:SetData(data.xp)

    TriggerServerEvent('xperience:server:save', self.CurrentXP, self.CurrentRank)

    cb('ok')
end


----------------------------------------------------
--                       UI                       --
----------------------------------------------------

function Xperience:InitialiseUI()
    local ranks = self:GetRanksForUI()

    SendNUIMessage({
        xperience_init = true,
        xperience_xp = self:GetXP(),
        xperience_ranks = ranks,
        xperience_width = Config.Width,
        xperience_timeout = Config.Timeout,
        xperience_segments = Config.BarSegments,         
    })
end

function Xperience:OpenUI()
    SendNUIMessage({ xperience_display = true })
end


----------------------------------------------------
--                    SETTERS                     --
----------------------------------------------------

function Xperience:AddXP(xp)
    if not self:Validate(xp) then
        return
    end

    self:SetData(xp)

    SendNUIMessage({
        xperience_add = true,
        xperience_xp = xp      
    })
end

function Xperience:RemoveXP(xp)
    if not self:Validate(xp) then
        return
    end

    local newXP = self:GetXP() - xp

    self:SetData(newXP)

    SendNUIMessage({
        xperience_remove = true,
        xperience_xp = xp      
    })
end

function Xperience:SetXP(xp)
    if not self:Validate(xp) then
        return
    end
    
    self:SetData(xp)
    
    SendNUIMessage({
        xperience_set = true,
        xperience_xp = xp      
    })
end

function Xperience:SetRank(rank)
    rank = tonumber(rank)

    if not rank then
        self:PrintError('Invalid rank (' .. tostring(rank) .. ') passed to SetRank method')
        return
    end

    local newXP = Config.Ranks[rank].XP

    if newXP ~= nil then
        if newXP > self.CurrentXP then
            self:AddXP(newXP - self.CurrentXP)
        elseif newXP < self.CurrentXP then
            self:RemoveXP(self.CurrentXP - newXP)
        end
    end
end

function Xperience:SetData(xp)
    self.CurrentXP = self:LimitXP(xp)
    self.CurrentRank = self:GetRank(xp)
end


----------------------------------------------------
--                    GETTERS                     --
----------------------------------------------------

function Xperience:GetXP()
    return tonumber(self.CurrentXP)
end

function Xperience:GetMaxXP()
    return Config.Ranks[#Config.Ranks].XP
end

function Xperience:GetXPToNextRank()
    local currentRank = self:GetRank()

    return Config.Ranks[currentRank + 1].XP - tonumber(self.CurrentXP)   
end

function Xperience:GetXPToRank(rank)
    local GoalRank = tonumber(rank)
    -- Check for valid rank
    if not GoalRank or (GoalRank < 1 or GoalRank > #Config.Ranks) then
        self:PrintError('Invalid rank ('.. GoalRank ..') passed to GetXPToRank method')
        return
    end

    local goalXP = tonumber(Config.Ranks[GoalRank].XP)

    return goalXP - self.CurrentXP
end

function Xperience:GetRank(xp)
    if xp == nil then
        return tonumber(self.CurrentRank)
    end

    local len = #Config.Ranks
    for rank = 1, len do
        if rank < len then
            if Config.Ranks[rank + 1].XP > tonumber(xp) then
                return rank
            end
        else
            return rank
        end
    end
end

function Xperience:GetMaxRank()
    return #Config.Ranks
end


----------------------------------------------------
--                    UTILITIES                   --
----------------------------------------------------
function Xperience:GetRanksForUI()
    local ranks = {}
    local len = #Config.Ranks

    for i = 1, len do
        ranks[i] = Config.Ranks[i].XP
    end

    return ranks
end

-- Check XP is an integer
function Xperience:Validate(xp)
    xp = tonumber(xp)
    if xp and xp == math.floor(xp) then
        return true
    end
    return false
end

-- Prevent XP from going over / under limits
function Xperience:LimitXP(xp)
    local Max = tonumber(Config.Ranks[#Config.Ranks].XP)

    if xp > Max then
        xp = Max
    elseif xp < 0 then
        xp = 0
    end

    return xp
end

function Xperience:CheckRanks()
    local Limit = #Config.Ranks
    local InValid = {}

    for i = 1, Limit do
        local RankXP = Config.Ranks[i].XP

        if not self:Validate(RankXP) then
            table.insert(InValid, string.format('Rank %s: %s', i,  RankXP))
            self:PrintError(string.format('Invalid XP (%s) for Rank %s', RankXP, i))
        end
        
    end

    return InValid
end

function Xperience:PrintError(message)
    local out = string.format('^1%s Error: ^7%s', GetCurrentResourceName(), message)
    local s = string.rep("=", string.len(out))
    print('^1' .. s)
    print(out)
    print('^1' .. s)  
end


----------------------------------------------------
--                 EVENT HANDLERS                 --
----------------------------------------------------

AddEventHandler('playerSpawned', function(...) Xperience:Load(...) end)

RegisterNetEvent('xperience:client:init')
AddEventHandler('xperience:client:init', function(...) Xperience:Init(...) end)

RegisterNetEvent('xperience:client:addXP')
AddEventHandler('xperience:client:addXP', function(...) Xperience:AddXP(...) end)

RegisterNetEvent('xperience:client:removeXP')
AddEventHandler('xperience:client:removeXP', function(...) Xperience:RemoveXP(...) end)

RegisterNetEvent('xperience:client:setXP')
AddEventHandler('xperience:client:setXP', function(...) Xperience:SetXP(...) end)

RegisterNetEvent('xperience:client:setRank')
AddEventHandler('xperience:client:setRank', function(...) Xperience:SetRank(...) end)

RegisterNUICallback('xperience_rankchange', function(...) Xperience:OnRankChange(...) end)
RegisterNUICallback('xperience_save', function(...) Xperience:OnSave(...) end)


----------------------------------------------------
--                    EXPORTS                     --
----------------------------------------------------

exports('AddXP', function(...) return Xperience:AddXP(...) end)
exports('RemoveXP', function(...) return Xperience:RemoveXP(...) end)
exports('SetXP', function(...) return Xperience:SetXP(...) end)
exports('SetRank', function(...) return Xperience:SetRank(...) end)

exports('GetXP', function(...) return Xperience:GetXP(...) end)
exports('GetMaxXP', function(...) return Xperience:GetMaxXP(...) end)
exports('GetXPToRank', function(...) return Xperience:GetXPToRank(...) end)
exports('GetXPToNextRank', function(...) return Xperience:GetXPToNextRank(...) end)
exports('GetRank', function(...) return Xperience:GetRank(...) end)
exports('GetMaxRank', function(...) return Xperience:GetMaxRank(...) end)