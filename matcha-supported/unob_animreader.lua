--[[
    USAGE:
    -- LocalPlayer
    local tracker = AnimationTracker.new(LocalPlayer.Character, "You", Color3.new(0,1,0))
    tracker:Start()
    
    -- Other player
    local p = game.Players:FindFirstChild("Target")
    local t = AnimationTracker.new(p.Character, p.Name, Color3.new(1,0,0))
    t.onNewAnimation = function(id, name) print("Attack detected:", name) end
    t:Start()
    
    -- NPC
    local boss = workspace.NPCs.Boss
    AnimationTracker.new(boss, "Boss", Color3.new(1,0,1)):Start()
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local AnimationTracker = {}
AnimationTracker.__index = AnimationTracker

local KnownOffsets = {
    ClassDescriptor = 0x18,
    ClassDescriptorToClassName = 0x8,
    Name = 0xB0,
    AnimationId = 0xD0,
    NodeNext = 0x10,
    ActiveAnimations = nil,
    TimePosition = 0xE8,
}

local ActiveTrackers = {}

local function ReadString(address)
    if not address or address <= 4096 then return nil end
    local s, v = pcall(memory_read, "string", address)
    return s and v or nil
end

local function ReadPointer(address)
    if not address or address <= 4096 then return nil end
    local s, v = pcall(memory_read, "uintptr_t", address)
    return s and v and v > 4096 and v or nil
end

local function ReadFloat(address)
    if not address or address <= 4096 then return nil end
    local s, v = pcall(memory_read, "float", address)
    return s and v or nil
end

local function GetClassName(addr)
    if not addr or addr <= 4096 then return "Invalid" end
    local desc = ReadPointer(addr + KnownOffsets.ClassDescriptor)
    if desc then
        local namePtr = ReadPointer(desc + KnownOffsets.ClassDescriptorToClassName)
        return ReadString(namePtr) or "Unknown"
    end
    return "Error"
end

local function AutoDetectActiveAnimationsOffset(animatorAddress)
    print("Scanning for ActiveAnimations offset...")
    for offset = 0x600, 0xA00, 0x8 do
        local listHead = ReadPointer(animatorAddress + offset)
        if listHead then
            local firstNode = ReadPointer(listHead)
            if firstNode and firstNode ~= listHead then
                local track = ReadPointer(firstNode + KnownOffsets.NodeNext)
                if track and GetClassName(track) == "AnimationTrack" then
                    print(string.format("Found ActiveAnimations at 0x%X", offset))
                    return offset
                end
            end
        end
    end
    warn("Autodetect failed")
    return nil
end

local function GetAnimationData(track)
    if not track then return nil, nil, nil end
    local animPtr = ReadPointer(track + KnownOffsets.AnimationId)
    if animPtr and GetClassName(animPtr) == "Animation" then
        local id = ReadString(ReadPointer(animPtr + KnownOffsets.AnimationId))
        local name = ReadString(ReadPointer(animPtr + KnownOffsets.Name))
        local time = ReadFloat(track + KnownOffsets.TimePosition)
        return id, name, time
    end
    return nil, nil, nil
end

local function GetAnimatorAddress(char)
    if not char then return nil end
    local hum = char:FindFirstChild("Humanoid")
    local animator = hum and hum:FindFirstChild("Animator")
    return animator and animator.Address or nil
end

local function GetPlayingAnimationTracks(animatorAddr)
    if not animatorAddr or not KnownOffsets.ActiveAnimations then return {} end
    local listHead = ReadPointer(animatorAddr + KnownOffsets.ActiveAnimations)
    if not listHead then return {} end
    local node = ReadPointer(listHead)
    if not node or node == listHead then return {} end
    local tracks, i = {}, 0
    while node and node ~= 0 and node ~= listHead and i < 100 do
        i = i + 1
        local trackPtr = ReadPointer(node + KnownOffsets.NodeNext)
        if trackPtr and GetClassName(trackPtr) == "AnimationTrack" then
            table.insert(tracks, trackPtr)
        end
        node = ReadPointer(node)
    end
    return tracks
end

local function GetPosition(model)
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.Position end
    for _, p in ipairs(model:GetChildren()) do
        if p:IsA("BasePart") then return p.Position end
    end
end

function AnimationTracker.new(character, targetName, espColor)
    local addr = GetAnimatorAddress(character)
    if not addr then warn("[AnimTracker] No Animator for", targetName) return nil end
    
    if not KnownOffsets.ActiveAnimations then
        KnownOffsets.ActiveAnimations = AutoDetectActiveAnimationsOffset(addr)
        if not KnownOffsets.ActiveAnimations then return nil end
    end
    
    print(string.format("Tracking %s | Animator: 0x%X", targetName, addr))
    
    local nameDraw = Drawing.new("Text")
    nameDraw.Size = 16; nameDraw.Center = true; nameDraw.Outline = true
    nameDraw.Color = espColor or Color3.new(1,0,0); nameDraw.Visible = false
    
    local statDraw = Drawing.new("Text")
    statDraw.Size = 13; statDraw.Center = true; statDraw.Outline = true
    statDraw.Color = Color3.new(1,1,0); statDraw.Visible = false
    
    return setmetatable({
        _addr = addr,
        _name = targetName,
        _char = character,
        _last = {},
        _active = {},
        _nameDraw = nameDraw,
        _statDraw = statDraw,
        _running = false,
        onNewAnimation = nil,
        onStopAnimation = nil,
    }, AnimationTracker)
end

function AnimationTracker:Update()
    local current = GetPlayingAnimationTracks(self._addr)
    local map = {}
    for _, t in ipairs(current) do map[t] = true end
    
    for _, t in ipairs(current) do
        if not self._last[t] then
            local id, name, time = GetAnimationData(t)
            self._active[t] = {id = id, name = name, start = tick()}
            print(string.format("[%s] + NEW: %s | %s", self._name, name or "Unknown", id or "nil"))
            if self.onNewAnimation then self.onNewAnimation(id, name, time) end
        end
    end
    
    for t in pairs(self._last) do
        if not map[t] then
            local a = self._active[t]
            local dur = a and (tick() - a.start) or 0
            print(string.format("[%s] - STOP: %s (%.2fs)", self._name, a and a.name or "?", dur))
            if self.onStopAnimation and a then self.onStopAnimation(a.id, a.name, dur) end
            self._active[t] = nil
        end
    end
    
    self._last = map
end

function AnimationTracker:UpdateESP()
    if not self._char or not self._char.Parent then
        self._nameDraw.Visible = false; self._statDraw.Visible = false; return
    end
    local pos = GetPosition(self._char)
    if not pos then return end
    local screen, on = WorldToScreen(pos)
    if not on then self._nameDraw.Visible = false; self._statDraw.Visible = false; return end
    
    self._nameDraw.Position = Vector2.new(screen.X, screen.Y - 40)
    self._nameDraw.Text = self._name
    self._nameDraw.Visible = true
    
    local names = {}
    for _, a in pairs(self._active) do table.insert(names, a.name or "?") end
    if #names > 0 then
        self._statDraw.Position = Vector2.new(screen.X, screen.Y - 25)
        self._statDraw.Text = table.concat(names, ", ")
        self._statDraw.Visible = true
    else
        self._statDraw.Visible = false
    end
end

function AnimationTracker:Start()
    if self._running then return end
    self._running = true
    table.insert(ActiveTrackers, self)
    
    task.spawn(function()
        local count = 0
        while self._running and self._char.Parent do
            task.wait(0.1)
            self:Update()
            count = count + 1
            if count % 50 == 0 then
                local c = 0 for _ in pairs(self._active) do c = c + 1 end
                print(string.format("[%s] Active: %d", self._name, c))
            end
        end
        self:Destroy()
    end)
end

function AnimationTracker:Stop() self._running = false end
function AnimationTracker:Destroy() self:Stop() self._nameDraw:Remove() self._statDraw:Remove() end

RunService.RenderStepped:Connect(function()
    for _, t in ipairs(ActiveTrackers) do t:UpdateESP() end
end)

task.spawn(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local tracker = AnimationTracker.new(char, LocalPlayer.Name, Color3.new(0,1,0))
    if tracker then tracker:Start() end
end)

return AnimationTracker