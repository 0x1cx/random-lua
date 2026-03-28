local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Clean up any previous live copy of this script before starting a new one.
local SCRIPT_ID = "vEx_ESP_System"
if type(_G[SCRIPT_ID]) == "function" then
	pcall(_G[SCRIPT_ID])
end

local player = Players.LocalPlayer
local otherChars = Workspace:WaitForChild("OtherChars")

local TOGGLE_KEY = Enum.KeyCode.T
local UPDATE_INTERVAL = 0.15
local BILLBOARD_SIZE = UDim2.fromOffset(120, 30)

local espEnabled = true
local activeESP = {} -- [Instance] = { billboard, label, root, pendingConn }
local connections = {}

local function resolveRoot(item)
	if not item or not item.Parent then
		return nil
	end

	if item:IsA("BasePart") then
		return item
	end

	return item:FindFirstChildWhichIsA("BasePart", true)
end

local function setAllBillboardsEnabled(enabled)
	for _, record in pairs(activeESP) do
		if record.billboard then
			record.billboard.Enabled = enabled
		end
	end
end

local function destroyRecord(item)
	local record = activeESP[item]
	if not record then
		return
	end

	if record.pendingConn then
		record.pendingConn:Disconnect()
		record.pendingConn = nil
	end

	if record.billboard then
		record.billboard:Destroy()
	end

	activeESP[item] = nil
end

local function createBillboard(item, root)
	local record = activeESP[item]
	if not record then
		record = {}
		activeESP[item] = record
	end

	if record.pendingConn then
		record.pendingConn:Disconnect()
		record.pendingConn = nil
	end

	if record.billboard then
		record.root = root
		record.billboard.Adornee = root
		record.billboard.Parent = root
		return record
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "vEx_Billboard"
	billboard.Size = BILLBOARD_SIZE
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = espEnabled
	billboard.Adornee = root
	billboard.Parent = root

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0
	label.TextSize = 14
	label.TextScaled = false
	label.Font = Enum.Font.GothamSemibold
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = billboard

	record.billboard = billboard
	record.label = label
	record.root = root

	return record
end

local function startPendingWatch(item)
	local record = activeESP[item]
	if not record or record.pendingConn then
		return
	end

	record.pendingConn = item.DescendantAdded:Connect(function(descendant)
		if not activeESP[item] or activeESP[item].billboard then
			return
		end

		if descendant:IsA("BasePart") then
			local root = resolveRoot(item)
			if root then
				createBillboard(item, root)
			end
		end
	end)
end

local function trackItem(item)
	if not item or activeESP[item] then
		return
	end

	activeESP[item] = {}

	local root = resolveRoot(item)
	if root then
		createBillboard(item, root)
		return
	end

	startPendingWatch(item)
end

local function updateTrackedItems()
	local character = player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	local playerPosition = humanoidRootPart and humanoidRootPart.Position or nil

	for item, record in pairs(activeESP) do
		if not item.Parent then
			destroyRecord(item)
		else
			local root = resolveRoot(item)
			if root then
				if not record.billboard then
					createBillboard(item, root)
					record = activeESP[item]
				elseif record.root ~= root then
					record.root = root
					record.billboard.Adornee = root
					record.billboard.Parent = root
				end

				if record.billboard and record.label then
					record.billboard.Enabled = espEnabled
					if playerPosition then
						local distance = math.floor((playerPosition - root.Position).Magnitude)
						record.label.Text = string.format("Item [%d studs]", distance)
					else
						record.label.Text = "Item [?]"
					end
				end
			else
				if record.billboard then
					record.billboard:Destroy()
					record.billboard = nil
					record.label = nil
					record.root = nil
				end

				if not record.pendingConn and (item:IsA("Model") or item:IsA("Folder")) then
					startPendingWatch(item)
				end
			end
		end
	end
end

local toggleConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.KeyCode == TOGGLE_KEY then
		espEnabled = not espEnabled
		setAllBillboardsEnabled(espEnabled)
	end
end)
table.insert(connections, toggleConn)

local addConn = otherChars.ChildAdded:Connect(trackItem)
local remConn = otherChars.ChildRemoved:Connect(destroyRecord)
table.insert(connections, addConn)
table.insert(connections, remConn)

for _, child in ipairs(otherChars:GetChildren()) do
	trackItem(child)
end

local accumulator = 0
local updateConn = RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < UPDATE_INTERVAL then
		return
	end

	accumulator = 0
	updateTrackedItems()
end)
table.insert(connections, updateConn)

_G[SCRIPT_ID] = function()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end

	for item, record in pairs(activeESP) do
		if record.pendingConn then
			record.pendingConn:Disconnect()
		end
		if record.billboard then
			record.billboard:Destroy()
		end
		activeESP[item] = nil
	end

	print("Previous ESP script cleaned up.")
end
