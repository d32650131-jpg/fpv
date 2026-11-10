-- fpv_drone.lua — FPV kamikaze drone, executor payload
-- loader:
-- loadstring(game:HttpGet("https://raw.githubusercontent.com/<you>/<repo>/main/fpv_drone.lua"))()

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Workspace         = game:GetService("Workspace")

local LP      = Players.LocalPlayer
local Camera  = Workspace.CurrentCamera
local Mouse   = LP:GetMouse()

local DRONE_SPEED    = 180
local TURN_SPEED     = 6
local BOMB_RADIUS    = 28
local BOMB_DAMAGE    = 500
local DRONE_LIFETIME = 25
local FUSE_ON_IMPACT = 0.05

if getgenv().__FPV_DRONE_GUI then
    getgenv().__FPV_DRONE_GUI:Destroy()
end

local gui = Instance.new("ScreenGui")
gui.Name = "FPVDrone"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = gethui and gethui() or game:GetService("CoreGui")
getgenv().__FPV_DRONE_GUI = gui

local frame = Instance.new("Frame", gui)
frame.Size = UDim2.new(0, 220, 0, 120)
frame.Position = UDim2.new(0, 24, 0.5, -60)
frame.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel", frame)
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Text = "FPV DRONE"
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(230, 230, 240)
title.TextSize = 14

local btn = Instance.new("TextButton", frame)
btn.Size = UDim2.new(1, -24, 0, 36)
btn.Position = UDim2.new(0, 12, 0, 36)
btn.BackgroundColor3 = Color3.fromRGB(47, 130, 255)
btn.Text = "SPAWN DRONE"
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.GothamBold
btn.TextSize = 14
btn.AutoButtonColor = true
Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

local info = Instance.new("TextLabel", frame)
info.Size = UDim2.new(1, -24, 0, 36)
info.Position = UDim2.new(0, 12, 0, 78)
info.BackgroundTransparency = 1
info.TextWrapped = true
info.Font = Enum.Font.Gotham
info.TextSize = 11
info.TextColor3 = Color3.fromRGB(160, 170, 185)
info.Text = "W/S thrust  |  Mouse aim  |  LMB / Space detonate  |  Q exit"

local activeDrone
local function cleanup()
    if activeDrone then
        pcall(function() activeDrone:Destroy() end)
        activeDrone = nil
    end
    Camera.CameraType = Enum.CameraType.Custom
    if LP.Character and LP.Character:FindFirstChildOfClass("Humanoid") then
        Camera.CameraSubject = LP.Character:FindFirstChildOfClass("Humanoid")
    end
end

local function detonate(drone, pos)
    if not drone or not drone.Parent then return end
    local ex = Instance.new("Explosion")
    ex.Position = pos
    ex.BlastRadius = BOMB_RADIUS
    ex.BlastPressure = 0
    ex.DestroyJointRadiusPercent = 0
    ex.ExplosionType = Enum.ExplosionType.NoCraters
    ex.Parent = Workspace

    ex.Hit:Connect(function(part, dist)
        local model = part:FindFirstAncestorOfClass("Model")
        if not model then return end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 then
            local falloff = 1 - math.clamp(dist / BOMB_RADIUS, 0, 1)
            hum:TakeDamage(BOMB_DAMAGE * (0.5 + 0.5 * falloff))
        end
    end)

    cleanup()
end

local function buildDrone()
    cleanup()

    local char = LP.Character or LP.CharacterAdded:Wait()
    local hrp  = char:WaitForChild("HumanoidRootPart")

    local body = Instance.new("Part")
    body.Name = "FPVBody"
    body.Size = Vector3.new(2, 0.6, 2)
    body.Material = Enum.Material.Metal
    body.Color = Color3.fromRGB(25, 25, 30)
    body.CanCollide = false
    body.Massless = true
    body.Anchored = false
    body.TopSurface = Enum.SurfaceType.Smooth
    body.BottomSurface = Enum.SurfaceType.Smooth
    body.CFrame = hrp.CFrame * CFrame.new(0, 4, -6)
    body.Parent = Workspace

    local warhead = Instance.new("Part", body)
    warhead.Name = "Warhead"
    warhead.Shape = Enum.PartType.Ball
    warhead.Size = Vector3.new(1.2, 1.2, 1.2)
    warhead.Color = Color3.fromRGB(140, 20, 20)
    warhead.Material = Enum.Material.Neon
    warhead.CanCollide = false
    warhead.Massless = true
    local weld = Instance.new("WeldConstraint", warhead)
    weld.Part0 = body
    weld.Part1 = warhead
    warhead.CFrame = body.CFrame * CFrame.new(0, -0.6, 0)

    for i, off in ipairs({
        Vector3.new( 1.4, 0.2,  1.4),
        Vector3.new(-1.4, 0.2,  1.4),
        Vector3.new( 1.4, 0.2, -1.4),
        Vector3.new(-1.4, 0.2, -1.4),
    }) do
        local rotor = Instance.new("Part", body)
        rotor.Shape = Enum.PartType.Cylinder
        rotor.Size = Vector3.new(0.1, 1.6, 1.6)
        rotor.Color = Color3.fromRGB(40, 40, 50)
        rotor.Material = Enum.Material.SmoothPlastic
        rotor.CanCollide = false
        rotor.Massless = true
        local w = Instance.new("WeldConstraint", rotor)
        w.Part0 = body
        w.Part1 = rotor
        rotor.CFrame = body.CFrame * CFrame.new(off) * CFrame.Angles(0, 0, math.rad(90))
    end

    local bv = Instance.new("BodyVelocity", body)
    bv.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    bv.Velocity = Vector3.zero

    local bg = Instance.new("BodyGyro", body)
    bg.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    bg.P = 3e4
    bg.D = 500
    bg.CFrame = body.CFrame

    local light = Instance.new("PointLight", warhead)
    light.Color = Color3.fromRGB(255, 80, 60)
    light.Range = 10
    light.Brightness = 2

    Camera.CameraType = Enum.CameraType.Scriptable
    Camera.FieldOfView = 95

    activeDrone = body

    local thrust = 0
    local alive = true

    local inputCon = UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Q then
            cleanup()
        elseif input.KeyCode == Enum.KeyCode.Space
            or input.UserInputType == Enum.UserInputType.MouseButton1 then
            detonate(body, body.Position)
        end
    end)

    local touchCon = body.Touched:Connect(function(hit)
        if hit:IsDescendantOf(char) then return end
        task.wait(FUSE_ON_IMPACT)
        detonate(body, body.Position)
    end)

    local spawnedAt = tick()

    local stepCon
    stepCon = RunService.RenderStepped:Connect(function(dt)
        if not alive or not body.Parent then
            stepCon:Disconnect()
            inputCon:Disconnect()
            touchCon:Disconnect()
            return
        end

        if tick() - spawnedAt > DRONE_LIFETIME then
            detonate(body, body.Position)
            return
        end

        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            thrust = math.min(thrust + dt * 2, 1)
        elseif UserInputService:IsKeyDown(Enum.KeyCode.S) then
            thrust = math.max(thrust - dt * 2, -0.4)
        else
            thrust = thrust * (1 - dt * 1.2)
        end

        local aim = Mouse.Hit.Position
        local look = CFrame.lookAt(body.Position, aim)
        bg.CFrame = bg.CFrame:Lerp(look, math.clamp(dt * TURN_SPEED, 0, 1))

        bv.Velocity = look.LookVector * (DRONE_SPEED * thrust)

        local back = body.CFrame * CFrame.new(0, 1.2, 4.5)
        Camera.CFrame = CFrame.lookAt(back.Position, body.Position + look.LookVector * 20)
    end)

    body.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            alive = false
        end
    end)
end

btn.MouseButton1Click:Connect(buildDrone)

UserInputService.InputBegan:Connect(function(i, gp)
    if gp then return end
    if i.KeyCode == Enum.KeyCode.RightBracket then
        buildDrone()
    end
end)

LP.CharacterAdded:Connect(cleanup)
