-- OmniRal

local ResourceService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")
local MapInfo = require(ReplicatedStorage.Source.SharedModules.Info.MapInfo)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local New = require(ReplicatedStorage.Source.Pronghorn.New)

local CoreGameService = require(ServerScriptService.Source.ServerModules.Top.CoreGameService)

local ResourceModules = {
    Tree = {},
    Rock = {},
    Crystal = {},
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local SPAWN_TEST_RESOURCES = true

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RunConnection: thread? = nil

local Resources: {
    [Model]: {MaxHealth: number, Chopped: boolean, RespawnAt: number, TowerPlaced: boolean?}
} = {}

local ResourcesFolder: Folder -- Contains the tree, rock and crystal models
local PickupsFolder: Folder -- Contains the pieces of wood, rock and crystal the player can pick up

local Assets = ServerStorage.Assets
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function CheckForTestMap()
    if not SPAWN_TEST_RESOURCES then return end

    local Folder = Workspace:FindFirstChild("ResourceSpawns")
    if not Folder then return end

    ResourceService.SpawnResources("TestMap", Folder)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Destroys a resource where a tower is going to be placed
-- @ThisModel = The model of the tree, rock or crystal being used to place the tree on
-- @UsePlayerResources = Instead of using the teams resource pool to pay the cost, it pulls from the players'
function ResourceService.PlaceTowerOnResource(ThisModel: Model, BuildCost: {Tree: number, Rock: number, Crystal: number}, UsePlayerResources: boolean?)
    local ThisTree = Resources[ThisModel]
    if not ThisTree then return end
    if not string.find(ThisModel.Name, "Tree") then return end -- Right now it only works on trees

    ThisTree.TowerPlaced = true
    ThisModel:SetAttribute("TowerPlaced", true) -- Prevents it from spawning pick ups
    ThisModel:SetAttribute("Health", 0)
end

-- Spawn the resources for one specific map
function ResourceService.SpawnResources(MapName: string, Folder: Folder)
    assert(Assets.Maps:FindFirstChild(MapName), MapName .. " doesn't exist!")

    for _, Spawn in Folder:GetChildren() do
        local TypeName = string.gsub(Spawn.Name, "Spawn", "")
        if TypeName ~= "Tree" and TypeName ~= "Rock" and TypeName ~= "Crystal" then continue end
        if not Assets.Maps[MapName]:FindFirstChild(TypeName .. "s") then continue end

        local AllModels = Assets.Maps[MapName][TypeName .. "s"]:GetChildren()

        local ThisModule = ResourceModules[TypeName][MapName .. TypeName]
        local ThisModel = AllModels[RNG:NextInteger(1, #AllModels)]
        local ThisPickup = Assets.Maps[MapName].Pickups[TypeName] :: Model
        if not ThisModule or not ThisModel or not ThisPickup then continue end

        local HealthRange, RespawnRange = MapInfo[MapName][TypeName .. "Health"], MapInfo[MapName][TypeName .. "Respawn"]
        if not HealthRange or not RespawnRange then continue end

        local MaxHealth = math.ceil(RNG:NextInteger(HealthRange.Min, HealthRange.Max))

        local NewModel = ThisModel:Clone() :: Model
        NewModel:PivotTo(Spawn.CFrame * CFrame.new(0, -0.5, 0))
        NewModel.Parent = ResourcesFolder

        NewModel:SetAttribute("Ready", false)
        NewModel:SetAttribute("Health", MaxHealth)
        NewModel:SetAttribute("AnimationRunning", false)
        if TypeName == "Tree" then
            NewModel:SetAttribute("TowerPlaced", false)
        end

        NewModel:GetAttributeChangedSignal("Health"):Connect(function()
            if NewModel:GetAttribute("Health") > 0 then return end
            if not Resources[NewModel] then return end

            if NewModel:GetAttribute("TowerPlaced") then return end

            Resources[NewModel].RespawnAt = os.clock() + RNG:NextNumber(RespawnRange.Min, RespawnRange.Max)
            Resources[NewModel].Chopped = true

            local CopyPickup = ThisPickup:Clone()
            CopyPickup:PivotTo(NewModel.PrimaryPart.CFrame * CFrame.new(0, 3, 0))
            CopyPickup.Parent = PickupsFolder

            CopyPickup.PrimaryPart.AssemblyLinearVelocity = Vector3.new(
                RNG:NextInteger(10, 15) * (RNG:NextInteger(0, 1) * 2 - 1), 
                RNG:NextInteger(30, 40), 
                RNG:NextInteger(10, 15) * (RNG:NextInteger(0, 1) * 2 - 1))
        end)

        ThisModule.Set(NewModel, MaxHealth)
        Spawn:Destroy()

        Resources[NewModel] = {MaxHealth = MaxHealth, Chopped = false, RespawnAt = 0}

        NewModel:SetAttribute("Ready", true)
    end
end

function ResourceService.Stop()
    if not RunConnection then return end
    task.cancel(RunConnection)
    RunConnection = nil
end

-- Handles respawning of resources
function ResourceService.Run()
    ResourceService.Stop()

    RunConnection = task.spawn(function()
        while true do
            task.wait(1)
            
            for Model, Data in Resources do
                if not Model or not Data then continue end

                if not Data.TowerPlaced then continue end
                if not Data.Chopped then continue end

                if os.clock() < Data.RespawnAt then continue end

                Data.Chopped = false
                Model:SetAttribute("Health", Data.MaxHealth)
            end
        end
    end)
end

function ResourceService:Init()
    -- Get all the individual resource modules

    for _, Folder in script:GetChildren() do
        if not Folder:IsA("Folder") or not string.find(Folder.Name, "Modules") then continue end
        
        for _, Module in Folder:GetChildren() do
            local TypeName = string.gsub(Folder.Name, "Modules", "")
            if not ResourceModules[TypeName] then continue end

            ResourceModules[TypeName][Module.Name] = require(Module)
        end
    end

    warn(ResourceModules)
end

function ResourceService.Deferred()
    ResourcesFolder = New.Instance("Folder", Workspace, "Resources")
    PickupsFolder = New.Instance("Folder", Workspace, "Pickups")

    CheckForTestMap()
    ResourceService.Run()
end

return ResourceService