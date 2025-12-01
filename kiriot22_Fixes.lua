-- Full ESP Module with Smooth Health Bars and Proper Removal
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local cam = workspace.CurrentCamera
local plr = Players.LocalPlayer

local ESP = {
    Enabled = false,
    Boxes = false,
    HealthBars = false, -- toggle for health bars
    Names = false,
    Tracers = false,
    TeamMates = false,
    Players = false,
    BoxShift = CFrame.new(0,-1.5,0),
    BoxSize = Vector3.new(4,6,0),
    Thickness = 2,
    AttachShift = 1,
    Color = Color3.fromRGB(0,255,0),
    Objects = setmetatable({}, {__mode="kv"}),
    Overrides = {},
    AutoRemove = true
}

local function safeDisconnect(conn)
    if conn and typeof(conn)=="RBXScriptConnection" then
        pcall(function() conn:Disconnect() end)
    end
end

local function Draw(obj, props)
    local ok,new = pcall(function() return Drawing.new(obj) end)
    if not ok or not new then return nil end
    props = props or {}
    for i,v in pairs(props) do pcall(function() new[i]=v end) end
    return new
end

function ESP:GetTeam(p)
    local ov = self.Overrides.GetTeam
    if ov then return ov(p) end
    return p and p.Team
end

function ESP:IsTeamMate(p)
    local ov = self.Overrides.IsTeamMate
    if ov then return ov(p) end
    return self:GetTeam(p)==self:GetTeam(plr)
end

function ESP:GetColor(obj)
    local ov = self.Overrides.GetColor
    if ov then return ov(obj) end
    local p = self:GetPlrFromChar(obj)
    return p and self.Color or Color3.fromRGB(0,255,0)
end

function ESP:GetPlrFromChar(char)
    local ov = self.Overrides.GetPlrFromChar
    if ov then return ov(char) end
    return Players:GetPlayerFromCharacter(char)
end

function ESP:Toggle(bool)
    self.Enabled = bool
    if not bool then
        for obj,box in pairs(self.Objects) do
            if box and box.Remove then
                pcall(function() box:Remove() end)
            end
        end
        self.Objects = setmetatable({}, {__mode="kv"})
    end
end

function ESP:GetBox(obj)
    return self.Objects[obj]
end

function ESP:Add(obj, options)
    if not obj then return end
    options = options or {}
    if not obj.Parent and not options.RenderInNil then return end
    if self:GetBox(obj) then pcall(function() self:GetBox(obj):Remove() end) end

    local primary = options.PrimaryPart or (obj.ClassName=="Model" and (obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart"))) or (obj:IsA("BasePart") and obj)
    local player = options.Player or Players:GetPlayerFromCharacter(obj)
    local color = options.Color or self:GetColor(obj)

    local box = setmetatable({
        Name = options.Name or obj.Name,
        Type = "Box",
        Color = color,
        Size = options.Size or self.BoxSize,
        Object = obj,
        Player = player,
        PrimaryPart = primary,
        Components = {},
        IsEnabled = options.IsEnabled,
        Temporary = options.Temporary,
        ColorDynamic = options.ColorDynamic,
        RenderInNil = options.RenderInNil,
        _conns = {},
        HealthSmooth = 1,
        HealthAlpha = 1
    }, {__index={}})

    -- Quad
    box.Components["Quad"] = Draw("Quad",{Thickness=self.Thickness,Color=box.Color,Transparency=1,Filled=false,Visible=self.Enabled and self.Boxes})
    -- Name
    box.Components["Name"] = Draw("Text",{Text=box.Name,Color=box.Color,Center=true,Outline=true,Size=19,Visible=self.Enabled and self.Names})
    box.Components["Distance"] = Draw("Text",{Color=box.Color,Center=true,Outline=true,Size=19,Visible=self.Enabled and self.Names})
    box.Components["Tracer"] = Draw("Line",{Thickness=self.Thickness,Color=box.Color,Transparency=1,Visible=self.Enabled and self.Tracers})
    -- Health bar BG
    box.Components["HealthBG"] = Draw("Line",{Thickness=3,Color=Color3.fromRGB(0,0,0),Transparency=1,Visible=self.Enabled and self.HealthBars})
    -- Health bar
    box.Components["Health"] = Draw("Line",{Thickness=3,Color=Color3.fromRGB(0,255,0),Transparency=1,Visible=self.Enabled and self.HealthBars})

    self.Objects[obj] = box

    local function trackConnection(conn) table.insert(box._conns,conn); return conn end

    if obj and obj:IsA("Instance") then
        trackConnection(obj.AncestryChanged:Connect(function(_, parent) if not parent and ESP.AutoRemove~=false then box:Remove() end end))
        trackConnection(obj:GetPropertyChangedSignal("Parent"):Connect(function() if obj.Parent==nil and ESP.AutoRemove~=false then box:Remove() end end))
        if obj.Destroying then trackConnection(obj.Destroying:Connect(function() box:Remove() end)) end
    end

    local hum = obj:FindFirstChildOfClass("Humanoid")
    if hum then trackConnection(hum.Died:Connect(function() task.defer(function() if ESP.AutoRemove~=false then box:Remove() end end) end)) end
    if player then
        trackConnection(player.CharacterRemoving:Connect(function(char) if char==obj and ESP.AutoRemove~=false then box:Remove() end end))
        trackConnection(Players.PlayerRemoving:Connect(function(rem)
            if rem==player and ESP.AutoRemove~=false then
                for o,b in pairs(ESP.Objects) do
                    if b and b.Player==rem then pcall(function() b:Remove() end) end
                end
            end
        end))
    end
    return box
end

-- Character management
local function CharAdded(char)
    local p = Players:GetPlayerFromCharacter(char)
    if not p then return end
    if not char:FindFirstChild("HumanoidRootPart") then
        local ev
        ev = char.ChildAdded:Connect(function(c)
            if c.Name=="HumanoidRootPart" then
                safeDisconnect(ev)
                ESP:Add(char,{Name=p.Name,Player=p,PrimaryPart=c})
            end
        end)
    else
        ESP:Add(char,{Name=p.Name,Player=p,PrimaryPart=char.HumanoidRootPart})
    end
end

local function OnCharacterRemoving(char)
    local box = ESP:GetBox(char)
    if box then pcall(function() box:Remove() end) end
end

local function PlayerAdded(p)
    p.CharacterRemoving:Connect(OnCharacterRemoving)
    p.CharacterAdded:Connect(CharAdded)
    if p.Character then CharAdded(p.Character) end
end

Players.PlayerAdded:Connect(PlayerAdded)
for _,v in pairs(Players:GetPlayers()) do
    if v ~= plr then PlayerAdded(v) end
end

-- Render Loop
RunService.RenderStepped:Connect(function()
    cam = workspace.CurrentCamera
    for _, box in pairs(ESP.Objects) do
        if not box or not box.PrimaryPart then box:Remove() continue end
        local cf = box.PrimaryPart.CFrame
        if ESP.FaceCamera then cf=CFrame.new(cf.p,cam.CFrame.p) end
        local size = box.Size
        local locs = {
            TopLeft = cf*ESP.BoxShift*CFrame.new(size.X/2,size.Y/2,0),
            TopRight = cf*ESP.BoxShift*CFrame.new(-size.X/2,size.Y/2,0),
            BottomLeft = cf*ESP.BoxShift*CFrame.new(size.X/2,-size.Y/2,0),
            BottomRight = cf*ESP.BoxShift*CFrame.new(-size.X/2,-size.Y/2,0),
            TagPos = cf*ESP.BoxShift*CFrame.new(0,size.Y/2,0),
            Torso = cf*ESP.BoxShift
        }

        -- Quad/Box
        if box.Components.Quad then
            local TL,Vis1=cam:WorldToViewportPoint(locs.TopLeft.p)
            local TR,Vis2=cam:WorldToViewportPoint(locs.TopRight.p)
            local BL,Vis3=cam:WorldToViewportPoint(locs.BottomLeft.p)
            local BR,Vis4=cam:WorldToViewportPoint(locs.BottomRight.p)
            box.Components.Quad.Visible = ESP.Enabled and ESP.Boxes and (Vis1 or Vis2 or Vis3 or Vis4)
            if box.Components.Quad.Visible then
                box.Components.Quad.PointA = Vector2.new(TR.X,TR.Y)
                box.Components.Quad.PointB = Vector2.new(TL.X,TL.Y)
                box.Components.Quad.PointC = Vector2.new(BL.X,BL.Y)
                box.Components.Quad.PointD = Vector2.new(BR.X,BR.Y)
                box.Components.Quad.Color = box.Color
            end
        end

        -- Name & Distance
        if box.Components.Name and box.Components.Distance then
            local TagPos,Vis=cam:WorldToViewportPoint(locs.TagPos.p)
            box.Components.Name.Visible = ESP.Enabled and ESP.Names and Vis
            box.Components.Distance.Visible = ESP.Enabled and ESP.Names and Vis
            if Vis then
                box.Components.Name.Position = Vector2.new(TagPos.X,TagPos.Y)
                box.Components.Name.Text = box.Name
                box.Components.Distance.Position = Vector2.new(TagPos.X,TagPos.Y+14)
                box.Components.Distance.Text = math.floor((cam.CFrame.p-cf.p).Magnitude).."m away"
            end
        end

        -- Health Bars
        local hum = box.Object:FindFirstChildOfClass("Humanoid")
        if hum and box.Components.Health and box.Components.HealthBG then
            local percent = math.clamp(hum.Health/hum.MaxHealth,0,1)
            box.HealthSmooth = box.HealthSmooth + (percent-box.HealthSmooth)*0.1
            local targetAlpha = (ESP.Enabled and ESP.HealthBars) and 1 or 0
            box.HealthAlpha = box.HealthAlpha + (targetAlpha-box.HealthAlpha)*0.1

            local TL,BL = cam:WorldToViewportPoint(locs.TopLeft.p), cam:WorldToViewportPoint(locs.BottomLeft.p)
            local top = Vector2.new(TL.X-6,TL.Y)
            local bottom = Vector2.new(BL.X-6,BL.Y)

            box.Components.HealthBG.Visible = box.HealthAlpha>0
            box.Components.Health.Visible = box.HealthAlpha>0
            local height = bottom.Y-top.Y
            local newY = bottom.Y-(height*box.HealthSmooth)
            box.Components.HealthBG.From = top
            box.Components.HealthBG.To = bottom
            box.Components.HealthBG.Color = Color3.fromRGB(0,0,0)
            box.Components.Health.From = Vector2.new(top.X,bottom.Y)
            box.Components.Health.To = Vector2.new(top.X,newY)
            box.Components.Health.Color = Color3.fromRGB(255*(1-box.HealthSmooth),255*box.HealthSmooth,0):Lerp(Color3.new(0,0,0),1-box.HealthAlpha)
        elseif box.Components.Health then
            box.Components.Health.Visible=false
            box.Components.HealthBG.Visible=false
        end
    end
end)

return ESP
