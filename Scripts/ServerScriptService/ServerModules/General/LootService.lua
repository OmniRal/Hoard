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

local LootInfo = require(ReplicatedStorage.Source.SharedModules.Info.LootInfo)

local Utility = require(ReplicatedStorage.Source.SharedModules.General.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local PICK_UP_RANGE = 7
local DESPAWN_DROP_LOOT_TIME = 5

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RunThread: thread?

local PlayerLoot: {
    [Player]: {
        Value: number, 
        Loot: {{Name: string, Type: string}}
    }
} = {}

local AllContainers: {
    [Model]: {Collected: boolean, List: {Model}},
} = {}
local AllLoot: {
    [Model]: {Collected: boolean, HasTimer: boolean, Timer: number},
} = {}

local LootFolder: Folder
local DroppedLootFolder: Folder
local TempWallsFolder: Folder

local Assets = ServerStorage.Assets
local LootAssets = Assets.Loot

local LootAvailable = {
    ["Treasure"] = LootAssets.Treasure:GetChildren(),
    ["Gems"] = LootAssets.Gems:GetChildren(),
    ["Coins"] = LootAssets.Coins:GetChildren(),
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

                local IsStable = true
                for x = 1, 10 do
                    task.wait()
                    if Prim.AssemblyLinearVelocity.Magnitude <= 0.1 and Prim.AssemblyAngularVelocity.Magnitude <= 0.1 then continue end
                    IsStable = false
                end

                if not IsStable then continue end
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

-- Tally all the pieces of loot the player has and add it up
local function CalculatePlayerLootValue(Player: Player): number
    if not Player then return 0 end
    local PLData = PlayerLoot[Player]
    if not PLData then return 0 end
    if not PLData.Loot then return 0 end

    local TotalValue = 0
    for _, Data in PLData.Loot do
        if not Data.Name or not Data.Type then continue end
        local Value = LootInfo[Data.Name] or 0
        TotalValue += Value
    end

    PLData.Value = TotalValue
    Remotes.LootService.PlayerLootValueChanged:Fire(Player, TotalValue) -- Send the signal to the player

    return PLData.Value
end

-- Creates an attribute that when set to true, the loot will start flashing before being deleted
local function AddStartCleanAttribute(Loot: Model)
    if not Loot then return end

    local PartData: {[BasePart]: number} = {}
    local Started = false

    Loot:SetAttribute("StartClean", false)
    
    for _, Part in Loot:GetDescendants() do
        if not Part then continue end
        if not Part:isA("BasePart") then continue end
        PartData[Part] = Part.Transparency 
    end

    Loot:GetAttributeChangedSignal("StartClean"):Connect(function() 
        if Started then return end
        Started = true

        local Ghost = false
        for x = 1, 10 do
            Ghost = not Ghost
            for Part, OriginalTransparency in PartData do
                if not Part or not OriginalTransparency then continue end
                Part.Transparency = if not Ghost then OriginalTransparency else OriginalTransparency + ((1 - OriginalTransparency) / 2)
            end
            task.wait(math.clamp(0.5 - ((x - 1) * 0.05), 0.1, 0.5))
            warn(x)
        end

        if not AllLoot[Loot] then return end
        AllLoot[Loot].Collected = true
        AllLoot[Loot] = nil
        Loot:Destroy()
    end)
end

local function TryToCleanLoot()
    for Model, Data in AllLoot do
        if not Model or not Data then continue end
        if not Data.HasTimer or Model:GetAttribute("StartClean") then continue end
        
        Data.Timer -= 1

        if Data.Timer > 0 then continue end
        
        Model:SetAttribute("StartClean", true)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- @Container = Which container to spawn loot in
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
        NewLoot:SetAttribute("LootType", LootChosen)
        NewLoot.Parent = LootFolder

        table.insert(SpawnedLoot, NewLoot)

        task.wait()
    end

    AllContainers[Container] = {Collected = false, List = SpawnedLoot}
    WaitToAnchor(table.clone(SpawnedLoot), TempWalls) -- Anchor all the loot pieces

    Box:Destroy()
end

-- A player trying to pick up a piece of loot
function LootService.RequestPickupLoot(Player: Player, Loot: Model): boolean
    if not Player or not Loot then return false end
    local Alive, _, Root = Utility.Players.CheckAlive(Player)
    if not Alive or not Root or not Loot.PrimaryPart then return false end
    local Distance = (Root.Position - Loot.PrimaryPart.Position).Magnitude
    if Distance > PICK_UP_RANGE then return false end

    -- Make sure player data exists
    if not PlayerLoot[Player] then
        PlayerLoot[Player] = {Value = 0, Loot = {}}
    end

    local PLData = PlayerLoot[Player]

    if Loot:HasTag("LootContainer") then
        -- If the loot is a container, pick up all the pieces from it
        if not AllContainers[Loot] then return false end
        if AllContainers[Loot].Collected then return false end

        AllContainers[Loot].Collected = true
        Loot:SetAttribute("Collected", true)
        
        for _, Piece in AllContainers[Loot].List do
            if not Piece then continue end
            table.insert(PLData.Loot, {Name = Piece.Name, Type = Piece:GetAttribute("LootType")})
            Piece:Destroy()
        end

    else
        -- Pick up an individual piece
        if not AllLoot[Loot] then return false end
        if AllLoot[Loot].Collected then return false end
        
        AllLoot[Loot].Collected = true -- Is collected
        Loot:SetAttribute("Collected", true)

        table.insert(PLData.Loot, {Name = Loot.Name, Type = Loot:GetAttribute("LootType")})
        AllLoot[Loot] = nil
        Loot:Destroy()
    end

    CalculatePlayerLootValue(Player)

    return true
end

function LootService.RequesteDropLoot(Player: Player)
    if not Player then return end
    
    local Alive, _, Root = Utility.Players.CheckAlive(Player)
    if not Alive or not Root then return end

    local PLData = PlayerLoot[Player]
    if not PLData then return end
    if not PLData.Loot then return end

    local LastLoot = PLData.Loot[#PLData.Loot]
    if not LastLoot then return end

    local LootTypeFolder = LootAssets[LastLoot.Type]
    if not LootTypeFolder then return end

    if not LootTypeFolder:FindFirstChild(LastLoot.Name) then return end

    local NewLoot: Model = LootTypeFolder[LastLoot.Name]:Clone()
    if not NewLoot.PrimaryPart then return end

    NewLoot.PrimaryPart.Anchored = false
    NewLoot.PrimaryPart.CollisionGroup = "Loot"
    NewLoot:PivotTo(Root.CFrame * CFrame.new(0, 10, -10) * CFrame.Angles(RNG:NextNumber(-2, 2), RNG:NextNumber(-2, 2), RNG:NextNumber(-2, 2)))
    NewLoot:SetAttribute("LootType", LastLoot.Type)
    NewLoot.Parent = DroppedLootFolder

    WaitToAnchor({NewLoot})

    PLData.Value -= LootInfo[LastLoot.Name]
    Remotes.LootService.PlayerLootValueChanged:Fire(Player, PlayerLoot[Player].Value)

    table.remove(PLData.Loot, #PLData.Loot)
    AllLoot[NewLoot] = {Collected = false, HasTimer = true, Timer = DESPAWN_DROP_LOOT_TIME}

    AddStartCleanAttribute(NewLoot)
end

function LootService.Stop()
    if not RunThread then return end
    task.cancel(RunThread)
    RunThread = nil
end

function LootService.Run()
    LootService.Stop()

    RunThread = task.spawn(function()
        while true do
            task.wait(1)
            TryToCleanLoot()
        end
    end)
end

function LootService:Init()
    LootFolder = New.Instance("Folder", "Loot", Workspace)
    DroppedLootFolder = New.Instance("Folder", "DroppedLoot", Workspace)
    TempWallsFolder = New.Instance("Folder", "TempWalls", Workspace)

    Remotes:CreateToClient("PlayerLootValueChanged", {"number"})

    Remotes:CreateToServer("RequestPickupLoot", {"Model"}, "Returns", function(Player: Player, Loot: Model)
        return LootService.RequestPickupLoot(Player, Loot)
    end)

    Remotes:CreateToServer("RequesteDropLoot", {}, "Returns", function(Player: Player)
        return LootService.RequesteDropLoot(Player)
    end)
end

function LootService:Deferred()
    LootService.SpawnLoot(Workspace.TestMap.Pile)

    LootService.Run()
end

function LootService.PlayerAdded(Player: Player)
    if PlayerLoot[Player] then return end
    PlayerLoot[Player] = {Value = 0, Loot = {}}
end

return LootService