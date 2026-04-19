-- OmniRal

local BuilderService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)
local TowerInfo = require(ReplicatedStorage.Source.SharedModules.Info.TowerInfo)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Types
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

type PartData = {
    [number]: {
        Part: BasePart,
        BaseCF: CFrame,
        BuildData: CustomEnum.PartBuildData,
        OtherPart: BasePart?,
    }
}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function EaseIn(A: number, Style: CustomEnum.EasingStyle, Details: any): number
    if Style == "Sine" then
        return 1 - math.cos((A * math.pi) / 2)

    elseif Style == "Quad" then
        return A * A

    elseif Style == "Cubic" then
        return A * A * A

    elseif Style == "Quint" then
        return A * A * A * A * A

    elseif Style == "Back" then
        local C = Details and Details.Overshoot or 1.70158
        return (C + 1) * A * A * A - C * A * A

    elseif Style == "Bounce" then
        return 1 - EaseOut(1 - A, Style)  -- Bounce In is just flipped Bounce Out

    elseif Style == "Elastic" then
        local C = Details and Details.Oscillations or (2 * math.pi) / 3
        if A == 0 then return 0 end
        if A == 1 then return 1 end
        return -(2 ^ (10 * A - 10)) * math.sin((A * 10 - 10.75) * C)

    end

    return A
end

function EaseOut(A: number, Style: CustomEnum.EasingStyle, Details: any): number
    if Style == "Sine" then
        return math.sin((A * math.pi) / 2)

    elseif Style == "Quad" then
        return 1 - (1 - A) * (1 - A)

    elseif Style == "Cubic" then
        return 1 - (1 - A) ^ 3

    elseif Style == "Quint" then
        return 1 - (1 - A) ^ 5

    elseif Style == "Back" then
        local C = Details and Details.Overshoot or 1.70158
        return 1 + (C + 1) * (A - 1) ^ 3 + C * (A - 1) ^ 2

    elseif Style == "Bounce" then
        local N, D = 7.5625, 2.75
        if A < 1 / D then
            return N * A * A
        elseif A < 2 / D then
            A -= 1.5 / D
            return N * A * A + 0.75
        elseif A < 2.5 / D then
            A -= 2.25 / D
            return N * A * A + 0.9375
        else
            A -= 2.625 / D
            return N * A * A + 0.984375
        end

    elseif Style == "Elastic" then
        local C = Details and Details.Oscillations or (2 * math.pi) / 3
        if A == 0 then return 0 end
        if A == 1 then return 1 end
        return (2 ^ (-10 * A)) * math.sin((A * 10 - 0.75) * C) + 1

    end

    return A
end

local function ApplyEasing(Alpha: number, Style: CustomEnum.EasingStyle, Direction: CustomEnum.EasingDirection, Details: any): number
    if not Style or not Direction then return Alpha end

    if Direction == "In" then
        return EaseIn(Alpha, Style, Details)

    elseif Direction == "Out" then
        return EaseOut(Alpha, Style, Details)

    elseif Direction == "InOut" then
        if Alpha < 0.5 then
            return EaseIn(Alpha * 2, Style) / 2
        else
            return 1 - EaseIn((1 - Alpha) * 2, Style) / 2
        end
    end

    return Alpha
end

-- Lerp the angles individually; using vectors so angles can be explicitly defined and not be converted to quaternions
local function LerpAngles(A: Vector3, B: Vector3, Alpha: number): CFrame
    return CFrame.Angles(
        A.X + (B.X - A.X) * Alpha,
        A.Y + (B.Y - A.Y) * Alpha,
        A.Z + (B.Z - A.Z) * Alpha
    )
end

local function ScrubTimeline(Model: Model, CachedPartData: PartData, Keyframe: number, MaxKeyframes: number, Scaler: number?)
    if not Model or not CachedPartData or not Keyframe or not MaxKeyframes then return end

    Scaler = Scaler or 1

    for _, Data in ipairs(CachedPartData) do
        local Part = Data.Part
        if not Part then continue end

        -- Ignore parts who aren't ready yet
        if Keyframe < Data.BuildData.Start.Frame * Scaler then
            Part.Transparency = 1
            continue
        end

        Part.Transparency = Data.BuildData.End.Transparency or 0

        -- Get easing stuff
        local Alpha = math.clamp((Keyframe - (Data.BuildData.Start.Frame * Scaler)) / ((Data.BuildData.End.Frame - Data.BuildData.Start.Frame) * Scaler), 0, 1)
        if Data.BuildData.Easing then
            Alpha = ApplyEasing(Alpha, Data.BuildData.Easing.Style, Data.BuildData.Easing.Direction, Data.BuildData.Easing.Details)
        end

        local StartCF = Data.BuildData.Start.CF
        local EndCF = Data.BuildData.End.CF
        local FinalRotation = LerpAngles(Data.BuildData.Start.Angles, Data.BuildData.End.Angles, Alpha)

        if not Data.BuildData.Attached then
            Part.CFrame = (Data.BaseCF * StartCF):Lerp(Data.BaseCF * EndCF, Alpha) * FinalRotation * (Data.BuildData.PivotOffset or CFrame.new(0, 0, 0))

        elseif Data.BuildData.Attached and Data.BuildData.Attached.To and Data.OtherPart then
            Part.CFrame = (Data.OtherPart.CFrame * Data.BuildData.Attached.CF * StartCF):Lerp(Data.OtherPart.CFrame * Data.BuildData.Attached.CF * EndCF, Alpha) * FinalRotation * (Data.BuildData.PivotOffset or CFrame.new(0, 0, 0))
        end

        Part.Size = Data.BuildData.Start.Size:Lerp(Data.BuildData.End.Size, Alpha)
    end
end

local function TestTowerSet()
    BuilderService.SetModel(Workspace.TestTower, TowerInfo.TestTower.BuildTimeline, true, 1)

    local Lower, Raise = Workspace:WaitForChild("Lower"), Workspace:WaitForChild("Raise")

    local function InsideButton(Root: BasePart, Button: BasePart): boolean
        if not Root or not Button then return false end

        local RelativeCF = Button.CFrame:PointToObjectSpace(Root.Position)
        if math.abs(RelativeCF.X) <= Button.Size.X / 2 and Root.Position.Y > Button.Position.Y and math.abs(RelativeCF.Z) <= Button.Size.Z / 2 then
            return true
        end

        return false
    end

    RunService.Heartbeat:Connect(function() 
        for _, Player in Players:GetPlayers() do
            if not Player then continue end
            if not Player.Character then continue end
            local Root = Player.Character:FindFirstChild("HumanoidRootPart")
            if not Root then continue end

            if InsideButton(Root, Lower) then
                Workspace.TestTower.Keyframe.Value = math.clamp(Workspace.TestTower.Keyframe.Value - 0.1, 1, 45)
            end
            if InsideButton(Root, Raise) then
                Workspace.TestTower.Keyframe.Value = math.clamp(Workspace.TestTower.Keyframe.Value + 0.1, 1, 45)
            end
        end
    end)
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 
function BuilderService.SetModel(Model: Model, Timeline: CustomEnum.BuildTimeline, PlayAnim: boolean?, PlayDelay: number?)
    assert(Model, "Model is missing!")
    assert(Timeline, "Timeline is missing!")

    -- This controls the animation timeline
    local Keyframe = Instance.new("NumberValue")
    Keyframe.Name = "Keyframe"
    Keyframe.Value = 1
    Keyframe.Parent = Model

    local CachedPartData: PartData = {}

    -- Store all the parts origin cframes and their build data
    for Num, Data in ipairs(Timeline.Parts) do
        local Part = Model:FindFirstChild(Data.Name, true) :: BasePart
        if not Part then continue end
        if Data.Attached and Data.Attached.To then
            local OtherPart = Model:FindFirstChild(Data.Attached.To, true)
            if not OtherPart then continue end
            CachedPartData[Num] = {Part = Part, BaseCF = Part.CFrame, BuildData = Data, OtherPart = OtherPart}
        else
            CachedPartData[Num] = {Part = Part, BaseCF = Part.CFrame, BuildData = Data}
        end
    end

    -- Trigger it here
    Keyframe.Changed:Connect(function() 
        if Keyframe.Value < 1 or Keyframe.Value > Timeline.MaxKeyframes * (Timeline.Scaler or 1) then
            Keyframe.Value = math.clamp(Keyframe.Value, 1, Timeline.MaxKeyframes * (Timeline.Scaler or 1))
            return
        end

        ScrubTimeline(Model, CachedPartData, Keyframe.Value, Timeline.MaxKeyframes, Timeline.Scaler or 1)
    end)

    if not PlayAnim then return end
    task.delay(PlayDelay or 1, function()
        game:GetService("TweenService"):Create(Keyframe, TweenInfo.new(3), {Value = Timeline.MaxKeyframes * (Timeline.Scaler or 1)}):Play()
    end)
end

function BuilderService:Deferred()
    TestTowerSet()
end

return BuilderService