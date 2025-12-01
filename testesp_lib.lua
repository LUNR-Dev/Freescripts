-- Basic Box ESP Library (Module)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Drawing = Drawing -- Assume Drawing is available

local ESP = {}
ESP.__index = ESP

-- Settings
ESP.Enabled = false      -- Main switch
ESP.Boxes = true         -- Box ESP toggle
ESP.BoxColor = Color3.fromRGB(0, 255, 0)
ESP.BoxThickness = 2
ESP.BoxSize = Vector3.new(4,6,0)
ESP.Objects = setmetatable({}, {__mode="kv"})

-- Utility function to create a box
local function DrawBox()
    local box = Drawing.new("Quad")
    box.Visible = false
    box.Color = ESP.BoxColor
    box.Thickness = ESP.BoxThickness
    box.Filled = false
    return box
end

-- Add a player to ESP
function ESP.AddPlayer(player)
    if not player then return end

    local function TrackCharacter(char)
        -- Remove old box if it exists
        if ESP.Objects[player] and ESP.Objects[player].Box then
            ESP.Objects[player].Box.Visible = false
        end

        -- Find PrimaryPart (HumanoidRootPart or fallback)
        local function GetPrimaryPart()
            return char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart or char:FindFirstChildWhichIsA("BasePart")
        end

        local box = DrawBox()
        ESP.Objects[player] = {Box = box, Character = char, GetPrimaryPart = GetPrimaryPart}

        -- Remove box if character is completely gone
        char.AncestryChanged:Connect(function(_, parent)
            if not parent then
                box.Visible = false
                ESP.Objects[player] = nil
            end
        end)
    end

    if player.Character then
        TrackCharacter(player.Character)
    end
    player.CharacterAdded:Connect(TrackCharacter)
end

-- Remove all ESP boxes
function ESP.ClearAll()
    for _, obj in pairs(ESP.Objects) do
        if obj.Box then
            obj.Box.Visible = false
        end
    end
end

-- Main ESP toggle
function ESP.SetEnabled(enabled)
    ESP.Enabled = enabled
    if not enabled then
        ESP.ClearAll()
    else
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= Players.LocalPlayer then
                ESP.AddPlayer(player)
            end
        end
    end
end

-- Box ESP toggle
function ESP.SetBoxes(enabled)
    ESP.Boxes = enabled
    for _, data in pairs(ESP.Objects) do
        if data.Box then
            data.Box.Visible = enabled
        end
    end
end

-- Automatically add new players
Players.PlayerAdded:Connect(function(player)
    if ESP.Enabled and player ~= Players.LocalPlayer then
        ESP.AddPlayer(player)
    end
end)

-- Smooth update loop (always updates boxes when enabled)
RunService.RenderStepped:Connect(function()
    if not ESP.Enabled or not ESP.Boxes then return end
    local cam = Workspace.CurrentCamera

    for player, data in pairs(ESP.Objects) do
        local box = data.Box
        local char = data.Character
        if not box or not char or not char.Parent then
            box.Visible = false
            ESP.Objects[player] = nil
        else
            local primaryPart = data.GetPrimaryPart()
            if primaryPart then
                local cf = primaryPart.CFrame
                local size = ESP.BoxSize
                local topLeft = cf*CFrame.new(size.X/2,size.Y/2,0)
                local topRight = cf*CFrame.new(-size.X/2,size.Y/2,0)
                local bottomLeft = cf*CFrame.new(size.X/2,-size.Y/2,0)
                local bottomRight = cf*CFrame.new(-size.X/2,-size.Y/2,0)

                local tl, visible1 = cam:WorldToViewportPoint(topLeft.Position)
                local tr, visible2 = cam:WorldToViewportPoint(topRight.Position)
                local bl, visible3 = cam:WorldToViewportPoint(bottomLeft.Position)
                local br, visible4 = cam:WorldToViewportPoint(bottomRight.Position)

                box.Visible = (visible1 or visible2 or visible3 or visible4) and ESP.Boxes
                if box.Visible then
                    box.PointA = Vector2.new(tr.X, tr.Y)
                    box.PointB = Vector2.new(tl.X, tl.Y)
                    box.PointC = Vector2.new(bl.X, bl.Y)
                    box.PointD = Vector2.new(br.X, br.Y)
                end
            else
                box.Visible = false
            end
        end
    end
end)

return ESP
