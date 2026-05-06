-- OmniRal

local Utility = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Utility.ChangeModelTransparency(Model: Model, To: number, Ignore: {string}?, GetDescendants: boolean?)
    if not Model then return end
    
    local List
    if not GetDescendants then
        List = Model:GetChildren()
    else
        List = Model:GetDescendants()
    end
    
    for _, Part in List do
        local IgnorePart = false
        if Ignore then
            for _, Name in Ignore do
                if Part.Name ~= Name then continue end
                IgnorePart = true
                break
            end
        end
        if IgnorePart then continue end
        if not Part:IsA("BasePart") then continue end

        if To >= 1 then
            Part:SetAttribute("OriginalTransparency", Part.Transparency)
            Part.Transparency = To
        elseif To <= 0 then
            if Part:GetAttribute("OriginalTransparency") ~= nil then
                Part.Transparency = Part:GetAttribute("OriginalTransparency")
            else
                Part.Transparency = 0
            end
        else
            Part.Transparency = To
        end

        for _, Image in Part:GetChildren() do
            if not Image then continue end
            if not Image:IsA("Decal") and not Image:IsA("Texture") then continue end
            if To >= 1 then
                Image:SetAttribute("OriginalTransparency", Image.Transparency)
                Image.Transparency = To
            elseif To <= 0 then
                if Image:GetAttribute("OriginalTransparency") ~= nil then
                    Image.Transparency = Image:GetAttribute("OriginalTransparency")
                else
                    Image.Transparency = 0
                end
            else
                Image.Transparency = To
            end 
        end
    end
end

function Utility.CreateDot(CF: CFrame, Size: Vector3, Shape: Enum.PartType, Color: Color3?, Duration: number?, Parent: Instance?)
    local Dot = Instance.new("Part")
    Dot.Name = "Dot"
    Dot.Anchored = true
    Dot.CanCollide = false
    Dot.CanQuery = false
    Dot.CanTouch = false
    Dot.CFrame = CF
    Dot.Material = Enum.Material.Neon
    Dot.Size = Size or Vector3.new(2, 2, 2)
    Dot.Shape = Shape
    Dot.Color = Color or Color3.fromRGB(230, 30, 40)
    Dot.Parent = Parent or Workspace

    if Duration then
        Debris:AddItem(Dot, Duration)
    end

    return Dot
end

function Utility:GetAnimationSpeedFromAttackSpeed(AttackSpeed: number)
    return AttackSpeed / 100
end

function Utility:CheckForItems(List: {}, From: CFrame, Range: number)
    for _, Item: Model in Workspace.Items:GetChildren() do
        if not Item then continue end
        if table.find(List, Item) then continue end

        local Root = Item.PrimaryPart
        if not Root then continue end

        local Distance = (From.Position - Root.Position).Magnitude
        if Distance > Range then continue end

        table.insert(List, Item)
    end

    return List
end

function Utility:Init()
    -- Require all the children modules
    for _, Module in script:GetChildren() do
        if not Module:IsA("ModuleScript") then continue end
        Utility[Module.Name] = require(Module)
    end
end

function Utility:Deferred()
end

return Utility