-- OmniRal

local LootService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local New = require(ReplicatedStorage.Source.Pronghorn.New)

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
local LootFolder = Assets.Loot

local LootAvailable = {
    ["Treasure"] = LootFolder.Treasure:GetChildren(),
    ["Gems"] = LootFolder.Gems:GetChildren(),
    ["Coins"] = LootFolder.Coins:GetChildren(),
}

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
        local Wall = New.Instance("Part", Box.Parent, "Wall", 
        {Anchored = true, Material = Enum.Material.SmoothPlastic, Size = Vector3.new(Box.Size.X, Box.Size.Y, 1), CFrame = Box.CFrame * CFrame.new(0, 0, (Box.Size.Z / 2 + 0.5) * Side )})
        table.insert(Walls, Wall)
    end

    for Side = -1, 1, 2 do
        local Wall = New.Instance("Part", Box.Parent, "Wall", 
        {Anchored = true, Material = Enum.Material.SmoothPlastic, Size = Vector3.new(1, Box.Size.Y, Box.Size.Z), CFrame = Box.CFrame * CFrame.new((Box.Size.X / 2 + 0.5) * Side , 0, 0)})
        table.insert(Walls, Wall)
    end

    return Walls
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function LootService.SpawnLoot(Container: Model)
    if not Container then return end
    local LootTypes, Specific, Box = Container:FindFirstChild("LootTypes"), Container:FindFirstChild("Specific"), Container:FindFirstChild("Box")
    local Amount = Container:GetAttribute("Amount") :: NumberRange
    if not LootTypes or not Specific or not Container.PrimaryPart then return end

    local LootOptions = Utility.ConvertFolderToOptions(LootTypes)
    if not LootOptions then return end

    local LootChosen = Utility.RollPick(LootOptions)
    if not LootChosen then return end
    if not LootAvailable[LootChosen] then return end

    local RandLoot = LootAvailable[LootChosen][RNG:NextInteger(1, #LootAvailable[LootChosen])]
    if not RandLoot then return end

    local TempWalls = AddWallsAroundBox(Box)

    local Total = RNG:NextInteger(Amount.Min, Amount.Max)

    for x = 1, Total do
        local NewLoot: Model = RandLoot:Clone()
        if not NewLoot.PrimaryPart then return end

        NewLoot.PrimaryPart.Anchored = false
        NewLoot:PivotTo(
            Box.CFrame * CFrame.new(RNG:NextNumber(-Box.Size.X / 3, Box.Size.X / 3), Box.Size.Y / 2, RNG:NextNumber(-Box.Size.Z / 3, Box.Size.Z / 3))
            * CFrame.Angles(RNG:NextNumber(-2, 2), RNG:NextNumber(-2, 2), RNG:NextNumber(-2, 2))
        )
        NewLoot.Parent = Workspace
        task.wait(0.1)
    end

    if #TempWalls > 0 then
        for _, Wall in TempWalls do
            if not Wall then continue end
            Wall:Destroy()
        end
    end

    Box:Destroy()
end

function LootService:Init()
end

function LootService:Deferred()
    LootService.SpawnLoot(Workspace.TestMap.Pile)
end

return LootService