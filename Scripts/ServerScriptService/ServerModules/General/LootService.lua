-- OmniRal

local LootService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local New = require(ReplicatedStorage.Source.Pronghorn.New)

local QueueService = require(ServerScriptService.Source.ServerModules.General.QueueService)
local Utility = require(ReplicatedStorage.Source.SharedModules.General.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Assets = ServerStorage.Assets
local LootAssets = Assets.Loot

local LootAvailable = {
    ["Treasure"] = LootAssets.Treasure:GetChildren(),
    ["Gems"] = LootAssets.Gems:GetChildren(),
    ["Coins"] = LootAssets.Coins:GetChildren(),
}

local LootFolder: Folder
local TempWallsFolder: Folder

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Creates walls around a box part
-- The box part acts as the placement area where loot can spawn in
-- The walls prevent the look from falling out of it
local function AddWallsAroundBox(Box: BasePart): {BasePart}
    local Walls = {}
    
    for Side = -1, 1, 2 do
        local Wall = New.Instance("Part", TempWallsFolder, "Wall", 
        {Anchored = true, Material = Enum.Material.SmoothPlastic, Transparency = 0.5, Size = Vector3.new(Box.Size.X, Box.Size.Y, 1), CFrame = Box.CFrame * CFrame.new(0, 0, (Box.Size.Z / 2 + 0.5) * Side )})
        Wall.CollisionGroup = "LootWalls"
        table.insert(Walls, Wall)
    end

    for Side = -1, 1, 2 do
        local Wall = New.Instance("Part", TempWallsFolder, "Wall", 
        {Anchored = true, Material = Enum.Material.SmoothPlastic, Transparency = 0.5, Size = Vector3.new(1, Box.Size.Y, Box.Size.Z), CFrame = Box.CFrame * CFrame.new((Box.Size.X / 2 + 0.5) * Side , 0, 0)})
        Wall.CollisionGroup = "LootWalls"
        table.insert(Walls, Wall)
    end

    return Walls
end

local function CheckLootExists(Loot: Model): boolean
    if not Loot then return false end
    if not Loot.PrimaryPart then return false end
    return true, Loot.PrimaryPart
end

-- Anchors the loot once it stops moving; keep lag down
-- @List = A table containing all the loot models to check
-- @TempWalls = An optional table containing temp walls around the loot. Added for convenient clean up
local function WaitToAnchor(List: {Model}, TempWalls: {Part}?)
    if not List then return end

    -- Separate thread
    task.spawn(function()
        while true do
            task.wait(0.1)
            for x = #List, 1, -1 do
                local Loot = List[x]
                local Exists, Prim = CheckLootExists(Loot)
                if not Exists then
                    table.remove(List, x)
                    continue
                end
                if Prim.Anchored then continue end
                if Prim.AssemblyLinearVelocity.Magnitude > 0.1 or Prim.AssemblyAngularVelocity.Magnitude > 0.1 then continue end
                Prim.Anchored = true
                table.remove(List, x)
            end

            if #List > 0 then continue end

            if not TempWalls then return end

            -- If there's any temp walls, destroy them
            for _, Wall in TempWalls do
                if not Wall then continue end
                Wall:Destroy()
            end
        end
    end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function LootService.SpawnLoot(Container: Model)
    if not Container then return end
    local LootTypes, Specific, Box = Container:FindFirstChild("LootTypes"), Container:FindFirstChild("Specific"), Container:FindFirstChild("Box")
    local Amount = Container:GetAttribute("Amount") :: NumberRange
    if not LootTypes or not Specific or not Container.PrimaryPart then return end

    -- Get loop types
    local LootOptions = Utility.Roll.ConvertFolderToOptions(LootTypes)
    if not LootOptions then return end

    local TempWalls = AddWallsAroundBox(Box)
    local Total = RNG:NextInteger(Amount.Min, Amount.Max)
    local SpawnedLoot = {}

    for x = 1, Total do
        -- Pick a loot type
        local LootChosen = Utility.Roll.Pick(LootOptions)
        if not LootChosen then return end
        if not LootAvailable[LootChosen] then return end

        -- Pick a random model of the specific loot type
        local RandLoot = LootAvailable[LootChosen][RNG:NextInteger(1, #LootAvailable[LootChosen])]
        if not RandLoot then return end

        local NewLoot: Model = RandLoot:Clone()
        if not NewLoot.PrimaryPart then return end

        NewLoot.PrimaryPart.Anchored = false
        NewLoot.PrimaryPart.CollisionGroup = "Loot"
        NewLoot:PivotTo(
            Box.CFrame * CFrame.new(RNG:NextNumber(-Box.Size.X / 3, Box.Size.X / 3), Box.Size.Y / 2, RNG:NextNumber(-Box.Size.Z / 3, Box.Size.Z / 3))
            * CFrame.Angles(RNG:NextNumber(-2, 2), RNG:NextNumber(-2, 2), RNG:NextNumber(-2, 2))
        )
        NewLoot.Parent = LootFolder

        table.insert(SpawnedLoot, NewLoot)

        task.wait()
    end

    WaitToAnchor(SpawnedLoot, TempWalls)

    Box:Destroy()
end

function LootService:Init()
    LootFolder = New.Instance("Folder", "Loot", Workspace)
    TempWallsFolder = New.Instance("Folder", "TempWalls", Workspace)

    Remotes:CreateToServer("RequestPickupLoot", {"Model"}, "Reliable", function(Player: Player, Loot: Model)
    
    end)
end

function LootService:Deferred()
    LootService.SpawnLoot(Workspace.TestMap.Pile)
end

return LootService