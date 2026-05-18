-- OmniRal

local LootController = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Remotes = require(ReplicatedStorage.Source.Pronghorn.Remotes)
local LootUI = require(StarterPlayer.StarterPlayerScripts.Source.General.MainUIController.LootUI)
local Utility = require(ReplicatedStorage.Source.SharedModules.General.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local SEARCH_LOOT_RATE = 0.1
local PICK_UP_RANGE = 7
local LOOT_DROP_COOLDOWN = 0.25

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LootService = Remotes.LootService

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local LocalPlayer = Players.LocalPlayer

local RunHeartbeat: RBXScriptConnection? = nil
local LastSearchLootCheck = os.clock()
local LastLootDropAttempt = os.clock()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function SearchForLootToPickup(Root: BasePart)
    if not Root then return end

    local Containers = CollectionService:GetTagged("LootContainer")

    -- 1st check loot containers
    for _, Container : Model in Containers do
        if not Container then continue end
        if not Container.PrimaryPart then continue end
        if Container:GetAttribute("NotReady") or Container:GetAttribute("Collected") then continue end
        if (Root.Position - Container.PrimaryPart.Position).Magnitude > PICK_UP_RANGE then continue end

        local Success = LootService:RequestPickupLoot(Container)
        if Success then
            -- Maybe something happens here?
        end

        return
    end

    -- 2nd, check individual pieces

    -- 3rd, check dropped loot
    for _, Loot: Model in Workspace.DroppedLoot:GetChildren() do
        if not Loot then continue end
        if not Loot.PrimaryPart then continue end
        if Loot:GetAttribute("NotReady") or Loot:GetAttribute("Collected") then continue end
        if (Root.Position - Loot.PrimaryPart.Position).Magnitude > PICK_UP_RANGE then continue end

        local Success = LootService:RequestPickupLoot(Loot)
        if Success then

        end

        return
    end
end

local function AttemptDropLoot(_, InputState: Enum.UserInputState, InputObject: InputObject)
    if InputState ~= Enum.UserInputState.Begin then return end
    if os.clock() < LastLootDropAttempt + LOOT_DROP_COOLDOWN then return end

    LastLootDropAttempt = os.clock()
    LootService:RequestDropLoot()
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function LootController.ToggleControls(SetTo: boolean)
    if SetTo then
        ContextActionService:BindAction("DropLoot", AttemptDropLoot, false, Enum.KeyCode.E)
    
    else
        ContextActionService:UnbindAction("DropLoot")
    end
end

function LootController.Stop()
    if not RunHeartbeat then return end
    
    RunHeartbeat:Disconnect()
    RunHeartbeat = nil
end

function LootController.Run()
   LootController.Stop()

   RunHeartbeat = RunService.Heartbeat:Connect(function(DeltaTime: number) 
       if os.clock() < LastSearchLootCheck + SEARCH_LOOT_RATE then return end
       local Alive, _, Root = Utility.Players.CheckAlive(LocalPlayer)
       if not Alive or not Root then return end
       
       LastSearchLootCheck = os.clock()
       SearchForLootToPickup(Root) 
   end)
end

function LootController:Init()
end

function LootController:Deferred()
    LootController.Run()

    LootService.PlayerLootValueChanged:Connect(function(NewValue: number)
        LootUI.UpdateLootCount(NewValue)
    end)
end

return LootController