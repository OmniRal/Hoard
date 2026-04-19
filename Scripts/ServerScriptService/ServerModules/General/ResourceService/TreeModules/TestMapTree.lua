-- OmniRal

local TestMapTree = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Debris = game:GetService("Debris")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local MapInfo = require(ReplicatedStorage.Source.SharedModules.Info.MapInfo)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local MAP_NAME = "TestMap"

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Clean up old tweens
local function StopOldTweens(Tweens: {Tween})
    if #Tweens <= 0 then return end

    for _, OldTween in Tweens do
        if not OldTween then continue end
        OldTween:Pause() -- Using pause because it does not trigger Completed
    end

    table.clear(Tweens)
end

-- When the resource reaches 0 health
local function DestroyAnimation(Model: Model, Tweens: {Tween})
    StopOldTweens(Tweens)

    Model:SetAttribute("Ready", false)
    Model:SetAttribute("AnimationRunning", true)

    for x = 1, 3 do
        local Leaves = Model:FindFirstChild("Leaves_" .. x) :: BasePart
        if not Leaves then continue end

        local Copy = Leaves:Clone()
        Copy.Name = "CopyLeaves"
        Copy.Anchored = false
        Copy.CanCollide = false
        Copy.CanQuery = false
        Copy.CanTouch = false
        Copy.AssemblyLinearVelocity = Vector3.new(RNG:NextInteger(-10, 10), RNG:NextInteger(20, 30), RNG:NextInteger(-10, 10))
        Copy.AssemblyAngularVelocity = Vector3.new(0, RNG:NextInteger(-30, 30), 0)
        Copy.Parent = Workspace

        Debris:AddItem(Copy, 3) -- Incase they somehow don't fall into the abyss

        Leaves.CanCollide = false
        Leaves.CanQuery = false
        Leaves.CanTouch = false
        Leaves.Transparency = 1
    end

    task.wait(0.25)
    Model:SetAttribute("AnimationRunning", false)
end

local function RespawnAnimation(Model: Model, Tweens: {Tween})
    StopOldTweens(Tweens)

    Model:SetAttribute("AnimationRunning", true)

    for x = 1, 3 do
        local Leaves = Model:FindFirstChild("Leaves_" .. x) :: BasePart
        if not Leaves then continue end

        local OriginalSize = Leaves.Size
        Leaves.CanCollide = true
        Leaves.CanQuery = true
        Leaves.CanTouch = true
        Leaves.Size = Vector3.new(0.1, 0.1, 0.1)
        Leaves.Transparency = 0
        
        local GrowTween = TweenService:Create(Leaves, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = OriginalSize})
        GrowTween.Completed:Connect(function()
            if x ~= 3 then return end
            Model:SetAttribute("AnimationRunning", false)
            Model:SetAttribute("Ready", true)
        end)
        GrowTween:Play()

        table.insert(Tweens, GrowTween)
    end

    Model:SetAttribute("Ready", true)
end

-- When the resource loses some health (but not dead)
local function ShakeAnimation(Model: Model, Tweens: {Tween})
    StopOldTweens(Tweens)

    for x = 1, 3 do
        local Leaves = Model:FindFirstChild("Leaves_" .. x) :: BasePart
        if not Leaves then continue end

        local OriginalCF = Leaves.CFrame
        Leaves.CFrame *= CFrame.Angles(math.rad(RNG:NextInteger(-10, 10)), math.rad(RNG:NextInteger(-180, 180)), math.rad(RNG:NextInteger(-10, 10)))
        
        local ShakeTween = TweenService:Create(Leaves, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {CFrame = OriginalCF})
        ShakeTween.Completed:Connect(function()
            if x ~= 3 then return end
            Model:SetAttribute("AnimationRunning", false)
        end)
        ShakeTween:Play()

        table.insert(Tweens, ShakeTween)
    end
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function TestMapTree.Set(Model: Model, MaxHealth: number)
    if not Model then return end
    if not MapInfo[MAP_NAME] then return end

    local LastHealth = Model:GetAttribute("Health")
    
    local Tweens: {Tween} = {}

    Model:GetAttributeChangedSignal("Health"):Connect(function()
        local Health = Model:GetAttribute("Health")
        
        if Health <= 0 then
            DestroyAnimation(Model, Tweens)
        
        elseif Health >= MaxHealth then
            if Model:GetAttribute("Ready") then return end

            RespawnAnimation(Model, Tweens)

        else
            if Health < LastHealth then
                if not Model:GetAttribute("Ready") then return end
                if Model:GetAttribute("AnimationRunning") then return end
                
                ShakeAnimation(Model, Tweens)
            end
        end

        LastHealth = Health
    end)
end

return TestMapTree