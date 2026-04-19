-- OmniRal


local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CustomEnum = require(ReplicatedStorage.Source.SharedModules.Info.CustomEnum)

local TowerInfo: {[string]: {
    DisplayName: string,

    Stats: {
        {Damage: number, Range: number, Cooldown: number, UpgradeCost: {Tree: number, Rock: number, Crystal: number}}
    },

    BuildCost: {Tree: number, Rock: number, Crystal: number},

    BuildTimeline: CustomEnum.BuildTimeline,
}} = {}

TowerInfo["TestTower"] = {
    DisplayName = "Test Tower",
    
    Stats = {
        {Damage = 10, Range = 40, Cooldown = 1, UpgradeCost = {Tree = 1, Rock = 1, Crystal = 1}},
        {Damage = 15, Range = 50, Cooldown = 0.75, UpgradeCost = {Tree = 1, Rock = 1, Crystal = 1}},
        {Damage = 20, Range = 60, Cooldown = 0.5, UpgradeCost = {Tree = 1, Rock = 1, Crystal = 1}}
    },

    BuildCost = {Tree = 2, Rock = 3, Crystal = 1},

    BuildTimeline = {
        MaxKeyframes = 45,
        Scaler = 1,

        Parts = {
            [1] = {
                Name = "Base",
                Start = {Frame = 1, CF = CFrame.new(0, -1, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(12, 0.0001, 12)},
                End = {Frame = 10, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(12, 2, 12)}
            },
            [2] = {
                Name = "Tower",
                Start = {Frame = 11, CF = CFrame.new(0, -6, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(10, 0.0001, 10)},
                End = {Frame = 20, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(10, 12, 10)}
            },
            [3] = {
                Name = "Top",
                Start = {Frame = 21, CF = CFrame.new(0, -1, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(12, 0.0001, 12)},
                End = {Frame = 30, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(12, 2, 12)}
            },
            [4] = {
                Name = "Shooter",
                Start = {Frame = 31, CF = CFrame.new(0, -1, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(6, 0.0001, 10)},
                End = {Frame = 40, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(6, 2, 10)}
            },
            [5] = {
                Name = "Seat",
                Start = {Frame = 41, CF = CFrame.new(0, -0.05, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 0.0001, 2)},
                End = {Frame = 45, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 0.1, 2)}
            },
        }
    }
}

--[[
TowerInfo["TestTower_Old"] = {
    DisplayName = "Test Tower",

    Stats = {
        {Damage = 10, Range = 40, Cooldown = 1},
        {Damage = 15, Range = 50, Cooldown = 0.75},
        {Damage = 20, Range = 60, Cooldown = 0.5}
    },

    BuildTimeline = {
        MaxKeyframes = 40,
        Scaler = 1,

        Parts = {
            [1] = {
                Name = "Base",
                Start = {Frame = 1, CF = CFrame.new(0, -1, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(8, 0.001, 8)}, 
                End = {Frame = 10, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(8, 2, 8)},
            },
            [2] = {
                Name = "Pillar_1",
                Start = {Frame = 10, CF = CFrame.new(0, -3, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 0.001, 2)}, 
                End = {Frame = 20, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 6, 2)},
            },
            [3] = {
                Name = "Pillar_2",
                Start = {Frame = 15, CF = CFrame.new(0, -3, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 0.001, 2)}, 
                End = {Frame = 25, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 6, 2)},
            },
            [4] = {
                Name = "Pillar_3",
                Start = {Frame = 20, CF = CFrame.new(0, -3, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 0.001, 2)}, 
                End = {Frame = 30, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 6, 2)},
            },
            [5] = {
                Name = "Pillar_4",
                Start = {Frame = 25, CF = CFrame.new(0, -3, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 0.001, 2)}, 
                End = {Frame = 35, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 6, 2)},
            },
            
            [6] = {
                Name = "Pillar_5",
                PivotOffset = CFrame.new(0, 2, 0),
                Attached = {To = "Pillar_1", CF = CFrame.new(0, 2, 0)},
                Start = {Frame = 20, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(-math.pi, 0, 0), Size = Vector3.new(2, 6, 2)}, 
                End = {Frame = 30, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(-math.pi / 2, 0, 0), Size = Vector3.new(2, 6, 2)},
                Easing = {Style = "Bounce", Direction = "Out", Details = {}}
            },

            [7] = {
                Name = "Tooth_1",
                Attached = {To = "Pillar_5", CF = CFrame.new(0, 0.5, -1)},
                Start = {Frame = 25, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 1, 0.01)},
                End = {Frame = 35, CF = CFrame.new(0, 0, -0.5), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 1, 1)}
            },

            [8] = {
                Name = "Tooth_2",
                Attached = {To = "Pillar_5", CF = CFrame.new(0, 2.5, -1)},
                Start = {Frame = 28, CF = CFrame.new(0, 0, 0), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 1, 0.01)},
                End = {Frame = 38, CF = CFrame.new(0, 0, -1), Angles = Vector3.new(0, 0, 0), Size = Vector3.new(2, 1, 2)}
            }
        }
    }
}
]]

return TowerInfo