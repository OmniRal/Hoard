-- OmniRal

local EnemyService = {}

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
--local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Modules
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local EnemyInfo = require(ReplicatedStorage.Source.SharedModules.Info.EnemyInfo)

local Utility = require(ReplicatedStorage.Source.SharedModules.General.Utility)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local MAX_POINTS = 100
local LETTERS = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}
local LETTER_COLORS = {
    Color3.fromRGB(0, 162, 255),
    Color3.fromRGB(0, 255, 42),
    Color3.fromRGB(255, 72, 0),
    Color3.fromRGB(143, 58, 255),
    Color3.fromRGB(252, 255, 58),
    Color3.fromRGB(234, 74, 255),
    Color3.fromRGB(255, 137, 58),

    Color3.fromRGB(71, 187, 255),
    Color3.fromRGB(72, 255, 102),
    Color3.fromRGB(255, 123, 71),
    Color3.fromRGB(174, 112, 255),
    Color3.fromRGB(253, 255, 125),
    Color3.fromRGB(244, 160, 255),
    Color3.fromRGB(255, 182, 133),

    Color3.fromRGB(0, 107, 168),
    Color3.fromRGB(0, 180, 30),
    Color3.fromRGB(167, 47, 0),
    Color3.fromRGB(92, 25, 179),
    Color3.fromRGB(165, 168, 0),
    Color3.fromRGB(165, 37, 182),
    Color3.fromRGB(151, 76, 25),

    Color3.fromRGB(180, 227, 255),
    Color3.fromRGB(170, 255, 184),
    Color3.fromRGB(255, 196, 172),
    Color3.fromRGB(219, 191, 255),
    Color3.fromRGB(254, 255, 205),
    Color3.fromRGB(244, 160, 255),
    Color3.fromRGB(255, 223, 202),
}

local SHOW_PATH = true

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Remotes
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Variables
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local FinalPoint: Vector3? = nil
local Path: {
	[string]: {Pos: Vector3, [string]: {Vector3} }
} = {}

local Enemies: {
	[Model]: {
		CanMove: boolean, 
		PathPoints: {Vector3},
		TotalPathTime: number,
		PathTimePassed: number,
		LastCFrame: CFrame,
		MoveSpeed: number,
	}
} = {}
local EnemyFolder: Folder

local RunHeartbeat: RBXScriptConnection? = nil

local Assets = ServerStorage.Assets
local RNG = Random.new()

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Private Functions
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

function CubicBezier(T, P0, P1, P2, P3): Vector3
	local OneMinusT = 1 - T
	return OneMinusT^3 * P0 
		+ 3 * OneMinusT^2 * T * P1 
		+ 3 * OneMinusT * T^2 * P2 
		+ T^3 * P3
end

-- Finds branched paths from a node, and picks a random one for the next path
local function PickNextBranch(ThisNode: string): string?
	local NodeInfo = Path[ThisNode]
	assert(NodeInfo, "No node named " .. ThisNode)

	local Options: {string} = {}

	for Name, Path in NodeInfo do
		if type(Path) ~= "table" then continue end
		table.insert(Options, Name)
	end

	if #Options <= 0 then return end

	return Options[RNG:NextInteger(1, #Options)]
end

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Creates a path from the nodes inside of a specific folder
function EnemyService.CreatePath(From: Folder)
	-- There will only ever be one round (map) running at a time
	table.clear(Path)

	for Num, Letter in ipairs(LETTERS) do
		if not From:FindFirstChild(Letter .. 1) then break end

		local Color = LETTER_COLORS[Num] -- Only for the dots when SHOW_PATH is true

		for x = 1, MAX_POINTS do
			local Node = From:FindFirstChild(Letter .. x) :: BasePart
			if not Node then break end

			Path[Node.Name] = {Pos = Node.Position}

			local BeamFound = false

			for _, Beam: Beam in Node:GetChildren() do
				if not Beam then continue end
				if not Beam:IsA("Beam") then continue end
				local A_0, A_1 = Beam.Attachment0, Beam.Attachment1
				if not A_0 or not A_1 then continue end

				local NextNode = A_1.Parent
				if not NextNode then continue end

				BeamFound = true
				Path[Node.Name][NextNode.Name] = {}

				local P0, P3 = A_0.WorldPosition, A_1.WorldPosition
				local Dir_0, Dir_1 = A_0.WorldAxis, A_1.WorldAxis
				local Curve_0, Curve_1 = Beam.CurveSize0, Beam.CurveSize1
				local P1 = P0 + Dir_0 * Curve_0
				local P2 = P3 - Dir_1 * Curve_1

				for T = 0, 1 - 0.1, 0.1 do
					local Point = CubicBezier(T, P0, P1, P2, P3)
					table.insert(Path[Node.Name][NextNode.Name], Point)

					if not SHOW_PATH then continue end

					Utility.CreateDot(CFrame.new(Point), Vector3.new(1, 1, 1), Enum.PartType.Ball, Color)
				end
			end

			if BeamFound then continue end

			FinalPoint = Node.Position
		end
	end

	From:Destroy()
end

function EnemyService.Stop()
	if not RunHeartbeat then return end
	RunHeartbeat:Disconnect()
	RunHeartbeat = nil
end

function EnemyService.Run()
	EnemyService.Stop() -- Make sure another heartbeat isn't running

	RunHeartbeat = RunService.Heartbeat:Connect(function(DeltaTime: number)
		-- Move all the enemies
		for Enemy, Info in Enemies do
			if not Enemy or not Info then continue end
			if not Info.CanMove then continue end
			if not Info.PathPoints or not Info.TotalPathTime then continue end

			Info.PathTimePassed += (DeltaTime * Info.MoveSpeed)

			if Info.PathTimePassed >= Info.TotalPathTime then
				-- Enemy has reached the fortress
				Enemies[Enemy] = nil
				Enemy:Destroy()
				-- TODO: Damage the fortress
				continue
			end
			
			local TargetDistance = math.min(Info.PathTimePassed, Info.TotalPathTime)
			local CurrentDistance = 0
			local SegmentDistance = 0
			local CurrentPoint, NextPoint = nil, nil

			-- Figure out which point the enemy is currently on
			for x = 1, #Info.PathPoints - 1 do
				CurrentPoint = Info.PathPoints[x]
				NextPoint = Info.PathPoints[x + 1]

				SegmentDistance = (CurrentPoint - NextPoint).Magnitude
				if CurrentDistance + SegmentDistance >= TargetDistance then break end

				CurrentDistance += SegmentDistance
			end

			-- Position the enemy
			local CurrentPosition = CurrentPoint:Lerp(NextPoint, math.clamp((TargetDistance - CurrentDistance) / SegmentDistance, 0, 1))
			local Direction = (NextPoint - CurrentPosition).Unit

			local TargetCFrame = Info.LastCFrame:Lerp(CFrame.new(CurrentPosition, CurrentPosition + Direction), 0.05)

			Enemy:PivotTo(TargetCFrame)
			Info.LastCFrame = TargetCFrame
		end
	end)
end

function EnemyService.SpawnNew(EnemyName: string, StartNode: string)
	local MyEnemyInfo, Model = EnemyInfo[EnemyName], Assets.Enemies:FindFirstChild(EnemyName)
	local NodeInfo = Path[StartNode]
	assert(MyEnemyInfo and Model, "Missing enemy info or asset model for " .. EnemyName)
	assert(NodeInfo, "No start node named " .. StartNode)

	local NewModel = Model:Clone()
	NewModel.Parent = EnemyFolder

	Enemies[NewModel] = {
		CanMove = false,
		PathPoints = {},
		TotalPathTime = 0,
		PathTimePassed = 0,
		LastCFrame = CFrame.new(0, 0, 0),
		MoveSpeed = MyEnemyInfo.MoveSpeed
	}

	-- Construct path for the enemy to travel
	local CurrentNode = StartNode

	for _ = 1, MAX_POINTS do
		local NextNode = PickNextBranch(CurrentNode)
		if not NextNode then
			-- Should have reached the end
			break
		
		else
			-- Add the points from this branch
			for _, Point in ipairs(Path[CurrentNode][NextNode]) do
				table.insert(Enemies[NewModel].PathPoints, Point)
			end
		end

		CurrentNode = NextNode
	end

	-- Calculate total travel time for the whole path
	for x = 1, #Enemies[NewModel].PathPoints - 1 do
		Enemies[NewModel].TotalPathTime += (Enemies[NewModel].PathPoints[x] - Enemies[NewModel].PathPoints[x + 1]).Magnitude
	end

	NewModel:PivotTo(CFrame.new(Enemies[NewModel].PathPoints[1], Enemies[NewModel].PathPoints[2])) -- StartNode, first node on the branch
	Enemies[NewModel].LastCFrame = NewModel:GetPivot()

	local MoveAnim = Instance.new("Animation")
	MoveAnim.AnimationId = "rbxassetid://" .. MyEnemyInfo.Animations["Move"].ID
	local Track: AnimationTrack = NewModel.AnimationController.Animator:LoadAnimation(MoveAnim)
	Track:Play(nil, nil, RNG:NextNumber(MyEnemyInfo.AnimSpeed / 2, MyEnemyInfo.AnimSpeed) )

	-- Add keyframe connections
	Track.KeyframeReached:Connect(function(Keyframe: string)
		if not Enemies[NewModel] then return end
		if Keyframe == "StartMoving" then
			Enemies[NewModel].CanMove = true
		elseif Keyframe == "StopMoving" then
			Enemies[NewModel].CanMove = false
		end
	end)
end

function EnemyService:Init()
	EnemyFolder = Instance.new("Folder")
	EnemyFolder.Name = "Enemies"
	EnemyFolder.Parent = Workspace
end

function EnemyService:Deferred()
	EnemyService.CreatePath(Workspace.PathPoints) -- For testing

	EnemyService.Run()
	
	task.spawn(function()
		local Options = {"A1", "C1"}
		while true do
			EnemyService.SpawnNew("TestEnemy", Options[RNG:NextInteger(1, #Options)])
			task.wait(5)
		end
	end)
end

return EnemyService