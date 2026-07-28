-- ============================================
-- AUTO MAIL SYSTEM V4 (Green Theme) - DUPLEX SEND
-- ขนาด 594x420 ธีมเขียว โมเดิร์น
-- + ค้นหาผู้เล่นแบบ Global
-- + ส่งแบบ Duplex (2 รายการ/รอบ) เพื่อให้ส่งได้มากกว่า 9999 ต่อรอบ
-- ============================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================
-- โหลด Networking Module
-- ============================================
local Networking
local success, err = pcall(function()
    Networking = require(ReplicatedStorage:WaitForChild("SharedModules"):WaitForChild("Networking"))
end)

if not success then
    warn("ไม่พบ Networking Module: " .. tostring(err))
    return
end

local Mailbox = Networking.Mailbox
local isSending = false
local SelectedItems = {}
local InventoryItems = {}
local expandedCategories = {}

-- Drag variables
local isDragging = false
local dragInput, dragStart, startPos

-- ============================================
-- ตัวแปรระบบค้นหาผู้เล่น
-- ============================================
local selectedPlayer = nil
local searchDebounce = false

-- ============================================
-- ฟังก์ชันดึง Inventory
-- ============================================
function GetMyInventory()
    local items = {}
    
    local success, PlayerStateClient = pcall(function()
        return require(ReplicatedStorage:WaitForChild("ClientModules"):WaitForChild("PlayerStateClient"))
    end)
    
    if success and PlayerStateClient then
        local LocalReplica = PlayerStateClient:GetLocalReplica()
        if LocalReplica and LocalReplica.Data and LocalReplica.Data.Inventory then
            local Inventory = LocalReplica.Data.Inventory
            
            local categories = {
                Trowels = "Trowels",
                Seeds = "Seeds", 
                Sprinklers = "Sprinklers",
                WateringCans = "WateringCans",
                Mushrooms = "Mushrooms",
                Gnomes = "Gnomes",
                Raccoons = "Raccoons",
                Crates = "Crates",
                SeedPacks = "SeedPacks",
                Props = "Props"
            }
            
            for category, catName in pairs(categories) do
                if Inventory[category] then
                    for name, count in pairs(Inventory[category]) do
                        if count > 0 then
                            table.insert(items, {
                                Category = catName,
                                ItemKey = name,
                                Count = count,
                                DisplayName = name
                            })
                        end
                    end
                end
            end
            
            if Inventory.Pets then
                for id, data in pairs(Inventory.Pets) do
                    if data and not data.Equipped then
                        table.insert(items, {
                            Category = "Pets",
                            ItemKey = id,
                            Count = 1,
                            DisplayName = data.Name or id,
                            PetData = data
                        })
                    end
                end
            end
        end
    end
    
    return items
end

-- ============================================
-- CONFIG
-- ============================================
local MAX_ITEM_PER_SEND = 9999
local MAX_SPLIT = 20
local MAX_PER_ROUND = MAX_ITEM_PER_SEND * MAX_SPLIT

-- ============================================
-- 🔥 หา Item ใน Inventory
-- ============================================
function GetItemCount(category, itemKey)
    for _, item in ipairs(InventoryItems) do
        if item.Category == category and item.ItemKey == itemKey then
            return item.Count or 0
        end
    end
    return 0
end

-- ============================================
-- SEND BATCH (Split ไม่จำกัด)
-- ============================================
function SendBatchMail(targetUserId, items, note)
    if isSending then return false end
    if not targetUserId or targetUserId <= 0 then return false end
    if not items or #items == 0 then return false end

    isSending = true

    local batchData = {}

    for _, item in ipairs(items) do
        local count = item.Count or 1

        -- 🔥 split ไม่จำกัด
        while count > 0 do
            local sendAmount = math.min(count, MAX_ITEM_PER_SEND)

            table.insert(batchData, {
                Category = item.Category,
                ItemKey = item.ItemKey,
                Count = sendAmount
            })

            count = count - sendAmount
        end
    end

    local success = pcall(function()
        Mailbox.SendBatch:Fire(targetUserId, batchData, note or "")
    end)

    isSending = false
    return success
end

-- ============================================
-- SEND SINGLE
-- ============================================
function SendSingleMail(targetUserId, category, itemKey, count, note)
    local items = {
        {Category = category, ItemKey = itemKey, Count = count or 1}
    }
    return SendBatchMail(targetUserId, items, note)
end

-- ============================================
-- 🔥 SEND หลายรอบ + เช็คของก่อนส่ง
-- ============================================
function SendItemMulti(targetUserId, category, itemKey, totalAmount, note, onProgress)
    totalAmount = math.floor(totalAmount or 0)
    if totalAmount <= 0 then
        return 0, 0, 0
    end

    -- 🔥 เช็คของที่มีจริง
    local haveAmount = GetItemCount(category, itemKey)

    if haveAmount <= 0 then
        warn("ไม่มีของนี้ใน inventory")
        return 0, 0, 0
    end

    -- 🔥 ถ้าใส่เกิน → ตัดให้เท่าที่มี
    if totalAmount > haveAmount then
        warn("จำนวนเกิน ปรับเป็นสูงสุดที่มี: " .. haveAmount)
        totalAmount = haveAmount
    end

    local totalRounds = math.ceil(totalAmount / MAX_PER_ROUND)
    local remaining = totalAmount

    local successRounds = 0
    local failRounds = 0
    local roundIndex = 0

    while remaining > 0 do
        roundIndex = roundIndex + 1

        local roundAmount = math.min(remaining, MAX_PER_ROUND)

        if onProgress then
            onProgress(roundIndex, totalRounds, roundAmount)
        end

        local ok = SendSingleMail(targetUserId, category, itemKey, roundAmount, note)

        if ok then
            successRounds = successRounds + 1
        else
            failRounds = failRounds + 1
        end

        remaining = remaining - roundAmount
        task.wait(0.15)
    end

    return successRounds, failRounds, totalRounds
end

-- ส่งไอเทมแบบ Duplex พร้อมแสดงสถานะ (สำหรับจำนวนมากกว่า 19998)
function SendItemDuplex(targetUserId, category, itemKey, totalAmount, note, onProgress)
    totalAmount = math.floor(totalAmount or 0)
    if totalAmount <= 0 then
        return 0, 0, 0
    end

    local totalRounds = math.ceil(totalAmount / MAX_PER_ROUND)
    local remaining = totalAmount
    local roundIndex = 0
    local successRounds = 0
    local failRounds = 0

    while remaining > 0 do
        roundIndex = roundIndex + 1
        local roundAmount = math.min(MAX_PER_ROUND, remaining)
        
        if onProgress then
            onProgress(roundIndex, totalRounds, roundAmount)
        end

        local ok = SendSingleMail(targetUserId, category, itemKey, roundAmount, note)
        if ok then
            successRounds = successRounds + 1
        else
            failRounds = failRounds + 1
        end

        remaining = remaining - roundAmount
        task.wait(0.15)
    end

    return successRounds, failRounds, totalRounds
end

-- ============================================
-- ระบบค้นหาผู้เล่น (Global)
-- ============================================
function SearchPlayers(searchText)
    if searchText == "" or searchText == nil then
        return {}
    end
    
    local results = {}
    local searchLower = string.lower(searchText)
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player then
            local nameLower = string.lower(p.Name)
            local displayLower = string.lower(p.DisplayName)
            
            if string.find(nameLower, searchLower, 1, true) or 
               string.find(displayLower, searchLower, 1, true) then
                table.insert(results, {
                    UserId = p.UserId,
                    Name = p.Name,
                    DisplayName = p.DisplayName,
                    Player = p
                })
            end
        end
    end
    
    return results
end

function SearchPlayerGlobal(username)
    if not username or username == "" then
        return nil
    end

    local success, userId = pcall(function()
        return Players:GetUserIdFromNameAsync(username)
    end)

    if success and userId then
        local nameSuccess, correctName = pcall(function()
            return Players:GetNameFromUserIdAsync(userId)
        end)

        return {
            UserId = userId,
            Name = nameSuccess and correctName or username,
            DisplayName = nameSuccess and correctName or username,
            Player = nil,
            IsGlobal = true
        }
    end

    return nil
end

function GetPlayerThumbnail(userId)
    local success, thumb = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
    end)
    if success and thumb then
        return thumb
    end
    return "rbxassetid://0"
end

-- ============================================
-- Category Icons & Colors (Green Theme)
-- ============================================
local CATEGORY_ICONS = {
    Trowels = "🔧",
    Seeds = "🌱",
    Sprinklers = "💧",
    WateringCans = "🪣",
    Mushrooms = "🍄",
    Gnomes = "🧙",
    Raccoons = "🦝",
    Crates = "📦",
    SeedPacks = "🎒",
    Props = "🎨",
    Pets = "🐾"
}

local CATEGORY_COLORS = {
    Trowels = Color3.fromRGB(100, 200, 150),
    Seeds = Color3.fromRGB(80, 220, 80),
    Sprinklers = Color3.fromRGB(80, 200, 220),
    WateringCans = Color3.fromRGB(80, 220, 200),
    Mushrooms = Color3.fromRGB(200, 180, 100),
    Gnomes = Color3.fromRGB(150, 200, 100),
    Raccoons = Color3.fromRGB(150, 180, 150),
    Crates = Color3.fromRGB(200, 200, 100),
    SeedPacks = Color3.fromRGB(200, 180, 80),
    Props = Color3.fromRGB(200, 150, 100),
    Pets = Color3.fromRGB(255, 200, 100)
}

-- ============================================
-- สร้าง GUI
-- ============================================
local function CreateGUI()
    local oldGui = playerGui:FindFirstChild("AutoMailGUI")
    if oldGui then oldGui:Destroy() end
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoMailGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main Frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 594, 0, 420)
    mainFrame.Position = UDim2.new(0.5, -297, 0.5, -210)
    mainFrame.BackgroundColor3 = Color3.fromRGB(8, 35, 18)
    mainFrame.BackgroundTransparency = 0.05
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    
    -- Gradient
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(15, 55, 25)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(5, 25, 12))
    })
    gradient.Rotation = 90
    gradient.Parent = mainFrame
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Glow Border
    local glowBorder = Instance.new("Frame")
    glowBorder.Size = UDim2.new(1, 0, 1, 0)
    glowBorder.BackgroundTransparency = 1
    glowBorder.BorderSizePixel = 2
    glowBorder.BorderColor3 = Color3.fromRGB(60, 200, 80)
    glowBorder.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    glowBorder.BorderMode = Enum.BorderMode.Outline
    glowBorder.ZIndex = 0
    glowBorder.Parent = mainFrame
    
    local glowCorner = Instance.new("UICorner")
    glowCorner.CornerRadius = UDim.new(0, 12)
    glowCorner.Parent = glowBorder
    
    -- Title Bar
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 36)
    titleBar.BackgroundColor3 = Color3.fromRGB(15, 55, 25)
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -80, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Text = "🌿 Auto Mail V4 (Duplex Mode)"
    titleLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = titleBar
    
    -- Close Button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -36, 0, 4)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BackgroundTransparency = 0.5
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    closeBtn.TouchTap:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Drag System
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            isDragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
        end
    end)
    
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            isDragging = false
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if isDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                          input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Left Panel
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0, 140, 1, -42)
    leftPanel.Position = UDim2.new(0, 6, 0, 40)
    leftPanel.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
    leftPanel.BackgroundTransparency = 0.3
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = mainFrame
    
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 8)
    leftCorner.Parent = leftPanel
    
    local leftTitle = Instance.new("TextLabel")
    leftTitle.Size = UDim2.new(1, 0, 0, 26)
    leftTitle.Text = "📂 หมวดหมู่"
    leftTitle.TextColor3 = Color3.fromRGB(120, 255, 150)
    leftTitle.TextSize = 11
    leftTitle.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    leftTitle.BorderSizePixel = 0
    leftTitle.Font = Enum.Font.GothamBold
    leftTitle.Parent = leftPanel
    
    local leftTitleCorner = Instance.new("UICorner")
    leftTitleCorner.CornerRadius = UDim.new(0, 8)
    leftTitleCorner.Parent = leftTitle
    
    local categoryList = Instance.new("ScrollingFrame")
    categoryList.Size = UDim2.new(1, -4, 1, -32)
    categoryList.Position = UDim2.new(0, 2, 0, 30)
    categoryList.BackgroundTransparency = 1
    categoryList.CanvasSize = UDim2.new(0, 0, 0, 0)
    categoryList.ScrollBarThickness = 2
    categoryList.ScrollBarImageColor3 = Color3.fromRGB(60, 200, 80)
    categoryList.Parent = leftPanel
    
    local catListLayout = Instance.new("UIListLayout")
    catListLayout.Padding = UDim.new(0, 2)
    catListLayout.Parent = categoryList
    
    -- Right Panel
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(1, -156, 1, -42)
    rightPanel.Position = UDim2.new(0, 150, 0, 40)
    rightPanel.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
    rightPanel.BackgroundTransparency = 0.3
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = mainFrame
    
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 8)
    rightCorner.Parent = rightPanel
    
    -- Recipient Section
    local recipientFrame = Instance.new("Frame")
    recipientFrame.Size = UDim2.new(1, -8, 0, 52)
    recipientFrame.Position = UDim2.new(0, 4, 0, 4)
    recipientFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    recipientFrame.BorderSizePixel = 0
    recipientFrame.Parent = rightPanel
    
    local recCorner = Instance.new("UICorner")
    recCorner.CornerRadius = UDim.new(0, 6)
    recCorner.Parent = recipientFrame
    
    local recLabel = Instance.new("TextLabel")
    recLabel.Size = UDim2.new(0, 55, 0, 14)
    recLabel.Position = UDim2.new(0, 6, 0, 1)
    recLabel.Text = "👤 ผู้รับ:"
    recLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    recLabel.TextSize = 10
    recLabel.BackgroundTransparency = 1
    recLabel.Font = Enum.Font.GothamBold
    recLabel.Parent = recipientFrame
    
    local searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -80, 0, 20)
    searchBox.Position = UDim2.new(0, 4, 0, 17)
    searchBox.Text = ""
    searchBox.PlaceholderText = "🔍 ค้นหาผู้เล่น... (Enter = ค้นหาทั่วโลก)"
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.PlaceholderColor3 = Color3.fromRGB(120, 200, 140)
    searchBox.TextSize = 11
    searchBox.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    searchBox.BorderSizePixel = 0
    searchBox.ClearTextOnFocus = true
    searchBox.Font = Enum.Font.Gotham
    searchBox.Parent = recipientFrame
    
    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 4)
    searchCorner.Parent = searchBox
    
    local selectedDisplay = Instance.new("Frame")
    selectedDisplay.Size = UDim2.new(1, -8, 0, 28)
    selectedDisplay.Position = UDim2.new(0, 4, 0, 39)
    selectedDisplay.BackgroundColor3 = Color3.fromRGB(18, 52, 28)
    selectedDisplay.BorderSizePixel = 0
    selectedDisplay.Visible = false
    selectedDisplay.Parent = recipientFrame
    
    local selectedCorner = Instance.new("UICorner")
    selectedCorner.CornerRadius = UDim.new(0, 4)
    selectedCorner.Parent = selectedDisplay
    
    local avatarImage = Instance.new("ImageLabel")
    avatarImage.Size = UDim2.new(0, 20, 0, 20)
    avatarImage.Position = UDim2.new(0, 4, 0, 4)
    avatarImage.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    avatarImage.BackgroundTransparency = 0.5
    avatarImage.BorderSizePixel = 0
    avatarImage.Parent = selectedDisplay
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 10)
    avatarCorner.Parent = avatarImage
    
    local selectedName = Instance.new("TextLabel")
    selectedName.Size = UDim2.new(1, -60, 0, 13)
    selectedName.Position = UDim2.new(0, 28, 0, 1)
    selectedName.Text = ""
    selectedName.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectedName.TextSize = 10
    selectedName.TextXAlignment = Enum.TextXAlignment.Left
    selectedName.BackgroundTransparency = 1
    selectedName.Font = Enum.Font.GothamBold
    selectedName.Parent = selectedDisplay
    
    local selectedDisplayName = Instance.new("TextLabel")
    selectedDisplayName.Size = UDim2.new(1, -60, 0, 10)
    selectedDisplayName.Position = UDim2.new(0, 28, 0, 15)
    selectedDisplayName.Text = ""
    selectedDisplayName.TextColor3 = Color3.fromRGB(150, 220, 170)
    selectedDisplayName.TextSize = 8
    selectedDisplayName.TextXAlignment = Enum.TextXAlignment.Left
    selectedDisplayName.BackgroundTransparency = 1
    selectedDisplayName.Font = Enum.Font.Gotham
    selectedDisplayName.Parent = selectedDisplay

    local globalBadge = Instance.new("TextLabel")
    globalBadge.Size = UDim2.new(0, 42, 0, 12)
    globalBadge.Position = UDim2.new(1, -66, 0, 8)
    globalBadge.Text = "🌐 GLOBAL"
    globalBadge.TextColor3 = Color3.fromRGB(255, 220, 120)
    globalBadge.TextSize = 7
    globalBadge.BackgroundColor3 = Color3.fromRGB(60, 45, 10)
    globalBadge.BorderSizePixel = 0
    globalBadge.Font = Enum.Font.GothamBold
    globalBadge.Visible = false
    globalBadge.Parent = selectedDisplay

    local globalBadgeCorner = Instance.new("UICorner")
    globalBadgeCorner.CornerRadius = UDim.new(0, 3)
    globalBadgeCorner.Parent = globalBadge
    
    local clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 18, 0, 18)
    clearBtn.Position = UDim2.new(1, -22, 0, 5)
    clearBtn.Text = "✕"
    clearBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearBtn.TextSize = 9
    clearBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    clearBtn.BackgroundTransparency = 0.5
    clearBtn.BorderSizePixel = 0
    clearBtn.Font = Enum.Font.GothamBold
    clearBtn.Parent = selectedDisplay
    
    local clearCorner = Instance.new("UICorner")
    clearCorner.CornerRadius = UDim.new(0, 9)
    clearCorner.Parent = clearBtn
    
    clearBtn.MouseButton1Click:Connect(function()
        selectedPlayer = nil
        selectedDisplay.Visible = false
        searchBox.Text = ""
        UpdateSearchResults()
    end)
    clearBtn.TouchTap:Connect(function()
        clearBtn.MouseButton1Click:Fire()
    end)
    
    local resultsContainer = Instance.new("Frame")
    resultsContainer.Size = UDim2.new(1, -8, 0, 0)
    resultsContainer.Position = UDim2.new(0, 4, 0, 39)
    resultsContainer.BackgroundTransparency = 1
    resultsContainer.ClipsDescendants = true
    resultsContainer.Parent = recipientFrame
    
    local resultsLayout = Instance.new("UIListLayout")
    resultsLayout.Padding = UDim.new(0, 2)
    resultsLayout.Parent = resultsContainer
    
    -- Controls
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Size = UDim2.new(1, -8, 0, 26)
    controlsFrame.Position = UDim2.new(0, 4, 0, 60)
    controlsFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    controlsFrame.BorderSizePixel = 0
    controlsFrame.Parent = rightPanel
    
    local controlsCorner = Instance.new("UICorner")
    controlsCorner.CornerRadius = UDim.new(0, 6)
    controlsCorner.Parent = controlsFrame
    
    local qtyLabel = Instance.new("TextLabel")
    qtyLabel.Size = UDim2.new(0, 25, 1, 0)
    qtyLabel.Position = UDim2.new(0, 4, 0, 0)
    qtyLabel.Text = "×"
    qtyLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    qtyLabel.TextSize = 12
    qtyLabel.BackgroundTransparency = 1
    qtyLabel.Font = Enum.Font.GothamBold
    qtyLabel.Parent = controlsFrame
    
    local amountBox = Instance.new("TextBox")
    amountBox.Size = UDim2.new(0, 28, 0, 18)
    amountBox.Position = UDim2.new(0, 26, 0, 4)
    amountBox.Text = "1"
    amountBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    amountBox.TextSize = 11
    amountBox.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    amountBox.BorderSizePixel = 0
    amountBox.Font = Enum.Font.Gotham
    amountBox.Parent = controlsFrame
    
    local amountCorner = Instance.new("UICorner")
    amountCorner.CornerRadius = UDim.new(0, 4)
    amountCorner.Parent = amountBox
    
    -- ปุ่มจำนวน แบบ Duplex (เพิ่ม 19998)
    local quickAmounts = {"1", "5", "10", "19998"}
    for i, val in ipairs(quickAmounts) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, val == "19998" and 38 or 22, 0, 18)
        btn.Position = UDim2.new(0, 58 + (i-1) * (val == "19998" and 42 or 26), 0, 4)
        btn.Text = val
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = val == "19998" and 7 or 9
        btn.BackgroundColor3 = val == "19998" and Color3.fromRGB(40, 160, 60) or Color3.fromRGB(18, 52, 28)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.Parent = controlsFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 3)
        btnCorner.Parent = btn
        
        btn.MouseButton1Click:Connect(function()
            amountBox.Text = val
        end)
        btn.TouchTap:Connect(function()
            amountBox.Text = val
        end)
    end
    
    local noteBox = Instance.new("TextBox")
    noteBox.Size = UDim2.new(0, 100, 0, 18)
    noteBox.Position = UDim2.new(1, -104, 0, 4)
    noteBox.Text = ""
    noteBox.PlaceholderText = "✏️ ข้อความ..."
    noteBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    noteBox.PlaceholderColor3 = Color3.fromRGB(120, 200, 140)
    noteBox.TextSize = 10
    noteBox.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    noteBox.BorderSizePixel = 0
    noteBox.Font = Enum.Font.Gotham
    noteBox.Parent = controlsFrame
    
    local noteCorner = Instance.new("UICorner")
    noteCorner.CornerRadius = UDim.new(0, 4)
    noteCorner.Parent = noteBox
    
    -- Stats
    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(1, -8, 0, 20)
    statsFrame.Position = UDim2.new(0, 4, 0, 90)
    statsFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = rightPanel
    
    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 6)
    statsCorner.Parent = statsFrame
    
    local totalLabel = Instance.new("TextLabel")
    totalLabel.Size = UDim2.new(0, 75, 1, 0)
    totalLabel.Position = UDim2.new(0, 6, 0, 0)
    totalLabel.Text = "📊 ทั้งหมด: 0"
    totalLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    totalLabel.TextSize = 9
    totalLabel.TextXAlignment = Enum.TextXAlignment.Left
    totalLabel.BackgroundTransparency = 1
    totalLabel.Font = Enum.Font.Gotham
    totalLabel.Parent = statsFrame
    
    local selectedLabel = Instance.new("TextLabel")
    selectedLabel.Size = UDim2.new(0, 75, 1, 0)
    selectedLabel.Position = UDim2.new(0, 85, 0, 0)
    selectedLabel.Text = "✅ เลือก: 0"
    selectedLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    selectedLabel.TextSize = 9
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Font = Enum.Font.Gotham
    selectedLabel.Parent = statsFrame
    
    -- Batch Info (แสดง Duplex)
    local batchInfoLabel = Instance.new("TextLabel")
    batchInfoLabel.Size = UDim2.new(0, 60, 1, 0)
    batchInfoLabel.Position = UDim2.new(0, 164, 0, 0)
    batchInfoLabel.Text = ""
    batchInfoLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
    batchInfoLabel.TextSize = 8
    batchInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    batchInfoLabel.BackgroundTransparency = 1
    batchInfoLabel.Font = Enum.Font.Gotham
    batchInfoLabel.Parent = statsFrame
    
    local actionBtns = {"✅ ทั้งหมด", "🗑️ ล้าง", "🔄 รีเฟรช"}
    local actionColors = {Color3.fromRGB(0, 160, 70), Color3.fromRGB(180, 45, 45), Color3.fromRGB(40, 120, 60)}
    for i, text in ipairs(actionBtns) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 52, 0, 14)
        btn.Position = UDim2.new(1, -165 + (i-1) * 57, 0, 3)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 8
        btn.BackgroundColor3 = actionColors[i]
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.Parent = statsFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 3)
        btnCorner.Parent = btn
        
        if i == 1 then
            btn.MouseButton1Click:Connect(function()
                SelectedItems = {}
                for _, item in ipairs(InventoryItems) do
                    table.insert(SelectedItems, item)
                end
                selectedLabel.Text = "✅ เลือก: " .. #SelectedItems
                UpdateBatchInfo()
                BuildCategoryList()
            end)
            btn.TouchTap:Connect(function() btn.MouseButton1Click:Fire() end)
        elseif i == 2 then
            btn.MouseButton1Click:Connect(function()
                SelectedItems = {}
                selectedLabel.Text = "✅ เลือก: 0"
                UpdateBatchInfo()
                BuildCategoryList()
            end)
            btn.TouchTap:Connect(function() btn.MouseButton1Click:Fire() end)
        else
            btn.MouseButton1Click:Connect(function()
                statusLabel.Text = "🔄 โหลด..."
                statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                task.wait(0.3)
                BuildCategoryList()
                statusLabel.Text = "✅ รีเฟรชสำเร็จ!"
                statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
            end)
            btn.TouchTap:Connect(function() btn.MouseButton1Click:Fire() end)
        end
    end
    
    -- Item List
    local itemList = Instance.new("ScrollingFrame")
    itemList.Size = UDim2.new(1, -8, 1, -118)
    itemList.Position = UDim2.new(0, 4, 0, 114)
    itemList.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
    itemList.BackgroundTransparency = 0.3
    itemList.BorderSizePixel = 0
    itemList.CanvasSize = UDim2.new(0, 0, 0, 0)
    itemList.ScrollBarThickness = 3
    itemList.ScrollBarImageColor3 = Color3.fromRGB(60, 200, 80)
    itemList.Parent = rightPanel
    
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 6)
    listCorner.Parent = itemList
    
    local itemLayout = Instance.new("UIListLayout")
    itemLayout.Padding = UDim.new(0, 2)
    itemLayout.Parent = itemList
    
    -- Bottom
    local bottomFrame = Instance.new("Frame")
    bottomFrame.Size = UDim2.new(1, -8, 0, 32)
    bottomFrame.Position = UDim2.new(0, 4, 1, -36)
    bottomFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    bottomFrame.BorderSizePixel = 0
    bottomFrame.Parent = rightPanel
    
    local bottomCorner = Instance.new("UICorner")
    bottomCorner.CornerRadius = UDim.new(0, 6)
    bottomCorner.Parent = bottomFrame
    
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 140, 1, 0)
    statusLabel.Position = UDim2.new(0, 6, 0, 0)
    statusLabel.Text = "✅ พร้อมใช้งาน (Duplex)"
    statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    statusLabel.TextSize = 9
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = bottomFrame
    
    local sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0, 110, 0, 24)
    sendBtn.Position = UDim2.new(1, -116, 0, 4)
    sendBtn.Text = "🚀 ส่งทั้งหมด"
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendBtn.TextSize = 12
    sendBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
    sendBtn.BorderSizePixel = 0
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.Parent = bottomFrame
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 6)
    sendCorner.Parent = sendBtn
    
    -- ============================================
    -- ฟังก์ชันหลัก
    -- ============================================
    
    function UpdateBatchInfo()
        local totalCount = 0
        for _, item in ipairs(SelectedItems) do
            totalCount = totalCount + (item.Count or 1)
        end
        
        if totalCount > 0 then
            local rounds = math.ceil(totalCount / MAX_PER_ROUND)
            batchInfoLabel.Text = string.format("📦 %d (%d รอบ Duplex)", totalCount, rounds)
            batchInfoLabel.TextColor3 = rounds > 1 and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(200, 200, 100)
        else
            batchInfoLabel.Text = ""
        end
    end

    function UpdateSearchResults()
        for _, child in ipairs(resultsContainer:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local searchText = searchBox.Text
        if searchText == "" or #searchText < 2 then
            resultsContainer.Size = UDim2.new(1, 0, 0, 0)
            return
        end
        
        local results = SearchPlayers(searchText)
        if #results == 0 then
            resultsContainer.Size = UDim2.new(1, 0, 0, 0)
            return
        end
        
        resultsContainer.Size = UDim2.new(1, 0, 0, #results * 26 + 4)
        
        for _, result in ipairs(results) do
            local row = Instance.new("TextButton")
            row.Size = UDim2.new(1, 0, 0, 24)
            row.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
            row.BorderSizePixel = 0
            row.Parent = resultsContainer
            
            local rowCorner = Instance.new("UICorner")
            rowCorner.CornerRadius = UDim.new(0, 4)
            rowCorner.Parent = row
            
            local avatar = Instance.new("ImageLabel")
            avatar.Size = UDim2.new(0, 18, 0, 18)
            avatar.Position = UDim2.new(0, 3, 0, 3)
            avatar.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
            avatar.BackgroundTransparency = 0.5
            avatar.BorderSizePixel = 0
            avatar.Parent = row
            
            local avatarCorner2 = Instance.new("UICorner")
            avatarCorner2.CornerRadius = UDim.new(0, 9)
            avatarCorner2.Parent = avatar
            
            task.spawn(function()
                local thumb = GetPlayerThumbnail(result.UserId)
                avatar.Image = thumb
            end)
            
            local nameText = Instance.new("TextLabel")
            nameText.Size = UDim2.new(1, -40, 0, 12)
            nameText.Position = UDim2.new(0, 26, 0, 1)
            nameText.Text = result.DisplayName
            nameText.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameText.TextSize = 10
            nameText.TextXAlignment = Enum.TextXAlignment.Left
            nameText.BackgroundTransparency = 1
            nameText.Font = Enum.Font.GothamBold
            nameText.Parent = row
            
            local usernameText = Instance.new("TextLabel")
            usernameText.Size = UDim2.new(1, -40, 0, 10)
            usernameText.Position = UDim2.new(0, 26, 0, 12)
            usernameText.Text = "@" .. result.Name
            usernameText.TextColor3 = Color3.fromRGB(150, 220, 170)
            usernameText.TextSize = 7
            usernameText.TextXAlignment = Enum.TextXAlignment.Left
            usernameText.BackgroundTransparency = 1
            usernameText.Font = Enum.Font.Gotham
            usernameText.Parent = row
            
            row.MouseButton1Click:Connect(function()
                SelectPlayer(result)
            end)
            row.TouchTap:Connect(function()
                SelectPlayer(result)
            end)
        end
    end

    function PerformFullSearch()
        local searchText = searchBox.Text
        if searchText == "" or searchText:match("^%s*$") then
            statusLabel.Text = "⚠️ พิมพ์ชื่อผู้เล่นก่อน!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end

        local inServerResults = SearchPlayers(searchText)
        if #inServerResults > 0 then
            SelectPlayer(inServerResults[1])
            return
        end

        statusLabel.Text = "🌐 ไม่พบในเซิร์ฟเวอร์ กำลังค้นหาทั่วโลก..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)

        local globalResult = SearchPlayerGlobal(searchText)
        if globalResult then
            SelectPlayer(globalResult)
        else
            statusLabel.Text = "❌ ไม่พบผู้เล่นชื่อ: " .. searchText
            statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
        end
    end
    
    function SelectPlayer(result)
        selectedPlayer = result
        selectedDisplay.Visible = true
        selectedName.Text = result.DisplayName
        selectedDisplayName.Text = "@" .. result.Name
        globalBadge.Visible = result.IsGlobal == true

        avatarImage.Image = ""
        
        task.spawn(function()
            local thumb = GetPlayerThumbnail(result.UserId)
            if selectedPlayer == result then
                avatarImage.Image = thumb
            end
        end)
        
        resultsContainer.Size = UDim2.new(1, 0, 0, 0)
        for _, child in ipairs(resultsContainer:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        searchBox.Text = result.DisplayName
        if result.IsGlobal then
            statusLabel.Text = "🌐 เลือก (Global): " .. result.DisplayName
        else
            statusLabel.Text = "✅ เลือก: " .. result.DisplayName
        end
        statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    end
    
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        if searchDebounce then return end
        searchDebounce = true
        
        if selectedPlayer and searchBox.Text == selectedPlayer.DisplayName then
            searchDebounce = false
            return
        end
        
        selectedPlayer = nil
        selectedDisplay.Visible = false
        globalBadge.Visible = false
        
        task.wait(0.2)
        UpdateSearchResults()
        searchDebounce = false
    end)

    searchBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            PerformFullSearch()
        end
    end)
    
    -- ================================
    -- Build Category List
    -- ================================
    function BuildCategoryList()
        for _, child in ipairs(categoryList:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        for _, child in ipairs(itemList:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        InventoryItems = GetMyInventory()
        
        local grouped = {}
        for _, item in ipairs(InventoryItems) do
            if not grouped[item.Category] then
                grouped[item.Category] = {}
            end
            table.insert(grouped[item.Category], item)
        end
        
        local sortedCategories = {}
        for cat, _ in pairs(grouped) do
            table.insert(sortedCategories, cat)
        end
        table.sort(sortedCategories)
        
        local totalItems = 0
        for _, item in ipairs(InventoryItems) do
            totalItems = totalItems + 1
        end
        totalLabel.Text = "📊 ทั้งหมด: " .. totalItems
        
        local leftHeight = 0
        local rightHeight = 0
        
        for _, catName in ipairs(sortedCategories) do
            local items = grouped[catName]
            if not items or #items == 0 then continue end
            
            local isExpanded = expandedCategories[catName] or false
            
            local catBtn = Instance.new("TextButton")
            catBtn.Size = UDim2.new(1, -2, 0, 26)
            catBtn.Text = CATEGORY_ICONS[catName] .. " " .. catName .. " (" .. #items .. ")"
            catBtn.TextColor3 = CATEGORY_COLORS[catName] or Color3.fromRGB(150, 255, 150)
            catBtn.TextSize = 10
            catBtn.TextXAlignment = Enum.TextXAlignment.Left
            catBtn.BackgroundColor3 = isExpanded and Color3.fromRGB(18, 52, 28) or Color3.fromRGB(10, 30, 16)
            catBtn.BorderSizePixel = 0
            catBtn.Font = Enum.Font.Gotham
            catBtn.Parent = categoryList
            
            local catCorner = Instance.new("UICorner")
            catCorner.CornerRadius = UDim.new(0, 4)
            catCorner.Parent = catBtn
            
            leftHeight = leftHeight + 26 + 2
            
            catBtn.MouseButton1Click:Connect(function()
                expandedCategories[catName] = not expandedCategories[catName]
                BuildCategoryList()
            end)
            catBtn.TouchTap:Connect(function()
                catBtn.MouseButton1Click:Fire()
            end)
            
            if isExpanded then
                for _, item in ipairs(items) do
                    local row = Instance.new("Frame")
                    row.Size = UDim2.new(1, -2, 0, 26)
                    row.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
                    row.BorderSizePixel = 0
                    row.Parent = itemList
                    
                    local rowCorner = Instance.new("UICorner")
                    rowCorner.CornerRadius = UDim.new(0, 4)
                    rowCorner.Parent = row
                    
                    local checkBtn = Instance.new("TextButton")
                    checkBtn.Size = UDim2.new(0, 20, 0, 20)
                    checkBtn.Position = UDim2.new(0, 2, 0, 3)
                    checkBtn.Text = "☐"
                    checkBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                    checkBtn.TextSize = 11
                    checkBtn.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
                    checkBtn.BorderSizePixel = 0
                    checkBtn.Parent = row
                    
                    local checkCorner = Instance.new("UICorner")
                    checkCorner.CornerRadius = UDim.new(0, 3)
                    checkCorner.Parent = checkBtn
                    
                    local isSelected = false
                    
                    for _, selected in ipairs(SelectedItems) do
                        if selected == item then
                            isSelected = true
                            checkBtn.Text = "☑"
                            checkBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
                            row.BackgroundColor3 = Color3.fromRGB(18, 52, 28)
                            break
                        end
                    end
                    
                    local nameLabel = Instance.new("TextLabel")
                    nameLabel.Size = UDim2.new(0, 120, 1, 0)
                    nameLabel.Position = UDim2.new(0, 26, 0, 0)
                    nameLabel.Text = item.DisplayName
                    nameLabel.TextColor3 = Color3.fromRGB(220, 255, 220)
                    nameLabel.TextSize = 10
                    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                    nameLabel.BackgroundTransparency = 1
                    nameLabel.Font = Enum.Font.Gotham
                    nameLabel.Parent = row
                    
                    local amtLabel = Instance.new("TextLabel")
                    amtLabel.Size = UDim2.new(0, 35, 1, 0)
                    amtLabel.Position = UDim2.new(0, 150, 0, 0)
                    amtLabel.Text = "x" .. item.Count
                    amtLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
                    amtLabel.TextSize = 9
                    amtLabel.TextXAlignment = Enum.TextXAlignment.Left
                    amtLabel.BackgroundTransparency = 1
                    amtLabel.Font = Enum.Font.Gotham
                    amtLabel.Parent = row
                    
                    -- Send One (Duplex)
                    local sendOneBtn = Instance.new("TextButton")
                    sendOneBtn.Size = UDim2.new(0, 38, 0, 16)
                    sendOneBtn.Position = UDim2.new(1, -42, 0, 5)
                    sendOneBtn.Text = "ส่ง 1"
                    sendOneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                    sendOneBtn.TextSize = 8
                    sendOneBtn.BackgroundColor3 = Color3.fromRGB(35, 130, 55)
                    sendOneBtn.BorderSizePixel = 0
                    sendOneBtn.Font = Enum.Font.GothamBold
                    sendOneBtn.Parent = row
                    
                    local sendOneCorner = Instance.new("UICorner")
                    sendOneCorner.CornerRadius = UDim.new(0, 3)
                    sendOneCorner.Parent = sendOneBtn
                    
                    sendOneBtn.MouseButton1Click:Connect(function()
                        if not selectedPlayer then
                            statusLabel.Text = "⚠️ เลือกผู้รับก่อน!"
                            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                            return
                        end
                        local amt = tonumber(amountBox.Text) or 1
                        if amt <= 0 then
                            statusLabel.Text = "⚠️ จำนวนไม่ถูกต้อง!"
                            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                            return
                        end

                        local targetUserId = selectedPlayer.UserId
                        local note = noteBox.Text

                        -- Duplex Send
                        if amt <= MAX_PER_ROUND then
                            task.spawn(function()
                                local ok = SendSingleMail(targetUserId, item.Category, item.ItemKey, amt, note)
                                if ok then
                                    statusLabel.Text = "✅ ส่ง " .. item.DisplayName .. " x" .. amt .. " สำเร็จ! (Duplex)"
                                    statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
                                else
                                    statusLabel.Text = "❌ ส่งล้มเหลว!"
                                    statusLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
                                end
                            end)
                        else
                            -- มากกว่า 19998 แบ่งเป็นหลายรอบ Duplex
                            task.spawn(function()
                                local successBatches, failBatches, totalBatches = SendItemDuplex(
                                    targetUserId, item.Category, item.ItemKey, amt, note,
                                    function(batchIndex, totalB, batchAmt)
                                        statusLabel.Text = string.format("⏳ %s รอบ %d/%d (%d ชิ้น) [Duplex]", 
                                            item.DisplayName, batchIndex, totalB, batchAmt)
                                        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                                    end
                                )
                                if failBatches == 0 then
                                    statusLabel.Text = string.format("✅ ส่ง %s x%d สำเร็จ! (%d รอบ Duplex)", 
                                        item.DisplayName, amt, totalBatches)
                                    statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
                                else
                                    statusLabel.Text = string.format("⚠️ %s: สำเร็จ %d/%d รอบ", 
                                        item.DisplayName, successBatches, totalBatches)
                                    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                                end
                            end)
                        end
                    end)
                    sendOneBtn.TouchTap:Connect(function()
                        sendOneBtn.MouseButton1Click:Fire()
                    end)
                    
                    checkBtn.MouseButton1Click:Connect(function()
                        isSelected = not isSelected
                        if isSelected then
                            checkBtn.Text = "☑"
                            checkBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
                            row.BackgroundColor3 = Color3.fromRGB(18, 52, 28)
                            table.insert(SelectedItems, item)
                        else
                            checkBtn.Text = "☐"
                            checkBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                            row.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
                            for i, selected in ipairs(SelectedItems) do
                                if selected == item then
                                    table.remove(SelectedItems, i)
                                    break
                                end
                            end
                        end
                        selectedLabel.Text = "✅ เลือก: " .. #SelectedItems
                        UpdateBatchInfo()
                    end)
                    checkBtn.TouchTap:Connect(function()
                        checkBtn.MouseButton1Click:Fire()
                    end)
                    
                    rightHeight = rightHeight + 26 + 2
                end
            end
        end
        
        categoryList.CanvasSize = UDim2.new(0, 0, 0, leftHeight + 10)
        itemList.CanvasSize = UDim2.new(0, 0, 0, rightHeight + 10)
        
        selectedLabel.Text = "✅ เลือก: " .. #SelectedItems
        UpdateBatchInfo()
    end
    
    -- ================================
    -- Send All (Duplex)
    -- ================================
    function SendAllSelected()
        if #SelectedItems == 0 then
            statusLabel.Text = "⚠️ เลือกไอเท็มก่อน!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end
        
        if not selectedPlayer then
            statusLabel.Text = "⚠️ เลือกผู้รับก่อน!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
            return
        end
        
        local amt = tonumber(amountBox.Text) or 1
        local note = noteBox.Text or ""
        
        sendBtn.Text = "⏳ กำลังส่ง (Duplex)..."
        sendBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 0)
        statusLabel.Text = "⏳ กำลังส่งแบบ Duplex..."
        statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
        
        local successCount = 0
        local failCount = 0
        local totalRounds = 0

        for i, item in ipairs(SelectedItems) do
            if amt <= MAX_PER_ROUND then
                statusLabel.Text = string.format("⏳ %d/%d: %s (Duplex)", i, #SelectedItems, item.DisplayName)
                local ok = SendSingleMail(selectedPlayer.UserId, item.Category, item.ItemKey, amt, note)
                if ok then
                    successCount = successCount + 1
                else
                    failCount = failCount + 1
                end
                totalRounds = totalRounds + 1
                task.wait(0.15)
            else
                -- มากกว่า 19998 แบ่งเป็นหลายรอบ Duplex
                local successB, failB, totalB = SendItemDuplex(
                    selectedPlayer.UserId, item.Category, item.ItemKey, amt, note,
                    function(batchIndex, totalBatches, batchAmt)
                        statusLabel.Text = string.format("⏳ %d/%d: %s (รอบ %d/%d Duplex)", 
                            i, #SelectedItems, item.DisplayName, batchIndex, totalBatches)
                    end
                )
                successCount = successCount + successB
                failCount = failCount + failB
                totalRounds = totalRounds + totalB
            end
        end
        
        sendBtn.Text = "🚀 ส่งทั้งหมด"
        sendBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
        statusLabel.Text = string.format("✅ Duplex เสร็จ! สำเร็จ %d ล้มเหลว %d (รวม %d รอบ)", 
            successCount, failCount, totalRounds)
        statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
        
        SelectedItems = {}
        selectedLabel.Text = "✅ เลือก: 0"
        UpdateBatchInfo()
        BuildCategoryList()
    end
    
    sendBtn.MouseButton1Click:Connect(SendAllSelected)
    sendBtn.TouchTap:Connect(function() sendBtn.MouseButton1Click:Fire() end)
    
    -- ================================
    -- เริ่มต้น
    -- ================================
    
    statusLabel.Text = "🔄 โหลด..."
    statusLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    task.wait(0.3)
    BuildCategoryList()
    statusLabel.Text = "✅ พร้อมใช้งาน! (Duplex Mode)"
    statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    
    print("✅ Auto Mail V4 (Duplex Mode) พร้อมใช้งาน!")
    print("📌 ส่งแบบ Duplex: สูงสุด 19,998 ชิ้น/รอบ")
    print("📌 ใช้ 2 รายการใน 1 รอบ: 9,999 + 9,999")
end

-- ============================================
-- รัน GUI
-- ============================================
task.wait(1)
CreateGUI()
