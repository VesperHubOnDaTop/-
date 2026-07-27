-- ============================================
-- AUTO MAIL SYSTEM V8 (Complete) - WITH AUTO CLAIM
-- เพิ่ม Auto Claim Mail Toggle
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
local isClaiming = false
local SelectedItems = {}
local InventoryItems = {}
local expandedCategories = {}
local mailCount = 0
local autoClaimEnabled = false -- 🔥 สถานะ Auto Claim
local autoClaimTask = nil -- 🔥 Task สำหรับ Auto Claim

-- Drag variables
local isDragging = false
local dragInput, dragStart, startPos

-- ============================================
-- ตัวแปรระบบค้นหาผู้เล่น
-- ============================================
local selectedPlayer = nil
local searchDebounce = false
local itemSearchText = ""

-- ============================================
-- ประกาศตัวแปร GUI
-- ============================================
local statusLabel = nil
local batchInfoLabel = nil
local mailBadge = nil
local claimAllBtn = nil
local claimSingleBtn = nil
local autoClaimBtn = nil -- 🔥 ปุ่ม Auto Claim
local sendBtn = nil
local totalLabel = nil
local selectedLabel = nil
local searchBox = nil
local itemSearchBox = nil
local selectedDisplay = nil
local avatarImage = nil
local selectedName = nil
local selectedDisplayName = nil
local globalBadge = nil
local resultsContainer = nil
local amountBox = nil
local noteBox = nil
local categoryList = nil
local itemList = nil
local mainFrame = nil
local screenGui = nil

-- ============================================
-- CONFIG
-- ============================================
local MAX_ITEM_PER_SEND = 9999
local MAX_SPLIT = 20
local MAX_PER_ROUND = MAX_ITEM_PER_SEND * MAX_SPLIT

-- ============================================
-- 🔥 ฟังก์ชันอัปเดต Status
-- ============================================
local function UpdateStatus(text, color)
    if statusLabel then
        statusLabel.Text = text
        if color then
            statusLabel.TextColor3 = color
        end
    end
end

-- ============================================
-- 🔥 ฟังก์ชันอัปเดต Batch Info
-- ============================================
local function UpdateBatchInfo()
    local totalCount = 0
    for _, item in ipairs(SelectedItems) do
        totalCount = totalCount + (item.Count or 1)
    end
    
    if batchInfoLabel then
        if totalCount > 0 then
            local rounds = math.ceil(totalCount / MAX_PER_ROUND)
            batchInfoLabel.Text = string.format("%d (รอบ %d)", totalCount, rounds)
            batchInfoLabel.TextColor3 = rounds > 1 and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(200, 200, 100)
        else
            batchInfoLabel.Text = ""
        end
    end
end

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
-- 🔥 หาจำนวนของที่มีจริง
-- ============================================
function GetRealItemCount(category, itemKey)
    for _, item in ipairs(InventoryItems) do
        if item.Category == category and item.ItemKey == itemKey then
            return item.Count or 0
        end
    end
    return 0
end

-- ============================================
-- 🔥 CLAIM MAIL SYSTEM
-- ============================================

-- 🔥 เช็คเมลทั้งหมด
function CheckAllMail()
    local success, inbox = pcall(function()
        return Mailbox.OpenInbox:Fire()
    end)
    
    if not success or not inbox then
        return {}, 0
    end
    
    local mailList = {}
    local count = 0
    
    for id, data in pairs(inbox) do
        if type(data) == "table" then
            local hasItems = false
            if data.Items and type(data.Items) == "table" and #data.Items > 0 then
                hasItems = true
            elseif data.Category and data.ItemName then
                hasItems = true
            elseif data.Kind == "GuildReward" then
                hasItems = true
            end
            
            if hasItems then
                table.insert(mailList, {
                    id = id,
                    data = data,
                    from = data.FromName or data.From or "Unknown",
                    note = data.Note or ""
                })
                count = count + 1
            end
        end
    end
    
    return mailList, count
end

-- 🔥 รับเมลทั้งหมด
function ClaimAllMail()
    if isClaiming then
        UpdateStatus("⏳ กำลังรับเมลอยู่...", Color3.fromRGB(255, 200, 100))
        return
    end
    
    local success, inbox = pcall(function()
        return Mailbox.OpenInbox:Fire()
    end)
    
    if not success or not inbox then
        UpdateStatus("❌ เปิดกล่องจดหมายล้มเหลว!", Color3.fromRGB(255, 150, 150))
        return
    end
    
    local totalGifts = 0
    for id, data in pairs(inbox) do
        if type(data) == "table" then
            totalGifts = totalGifts + 1
        end
    end
    
    if totalGifts == 0 then
        UpdateStatus("📭 ไม่มีเมลรอรับ!", Color3.fromRGB(200, 200, 200))
        return
    end
    
    isClaiming = true
    UpdateStatus("📬 กำลังรับเมลทั้งหมด " .. totalGifts .. " รายการ...", Color3.fromRGB(255, 200, 100))
    
    if claimAllBtn then
        claimAllBtn.Text = "⏳ กำลังรับ..."
        claimAllBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
    end
    
    local claimSuccess, claimResult = pcall(function()
        return Mailbox.ClaimAll:Fire()
    end)
    
    if claimSuccess then
        UpdateStatus("✅ รับเมลทั้งหมด " .. totalGifts .. " รายการสำเร็จ!", Color3.fromRGB(150, 255, 150))
    else
        UpdateStatus("❌ รับเมลล้มเหลว: " .. tostring(claimResult), Color3.fromRGB(255, 150, 150))
    end
    
    isClaiming = false
    
    if claimAllBtn then
        claimAllBtn.Text = "📬 รับทั้งหมด"
        claimAllBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 50)
    end
    
    UpdateMailCount()
end

-- 🔥 รับเมลทีละ 1
function ClaimSingleMail()
    if isClaiming then
        UpdateStatus("⏳ กำลังรับเมลอยู่...", Color3.fromRGB(255, 200, 100))
        return
    end
    
    local success, inbox = pcall(function()
        return Mailbox.OpenInbox:Fire()
    end)
    
    if not success or not inbox then
        UpdateStatus("❌ เปิดกล่องจดหมายล้มเหลว!", Color3.fromRGB(255, 150, 150))
        return
    end
    
    local totalGifts = 0
    local firstMailId = nil
    local firstName = "Unknown"
    
    for id, data in pairs(inbox) do
        if type(data) == "table" then
            totalGifts = totalGifts + 1
            if firstMailId == nil then
                firstMailId = id
                firstName = data.FromName or data.From or "Unknown"
            end
        end
    end
    
    if totalGifts == 0 then
        UpdateStatus("📭 ไม่มีเมลรอรับ!", Color3.fromRGB(200, 200, 200))
        return
    end
    
    isClaiming = true
    UpdateStatus("📬 กำลังรับจาก: " .. firstName, Color3.fromRGB(255, 200, 100))
    
    if claimSingleBtn then
        claimSingleBtn.Text = "⏳ กำลังรับ..."
        claimSingleBtn.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
    end
    
    local claimSuccess = pcall(function()
        return Mailbox.Claim:Fire(firstMailId)
    end)
    
    if claimSuccess then
        UpdateStatus("✅ รับเมลจาก " .. firstName .. " สำเร็จ!", Color3.fromRGB(150, 255, 150))
    else
        UpdateStatus("❌ รับเมลจาก " .. firstName .. " ล้มเหลว!", Color3.fromRGB(255, 150, 150))
    end
    
    if claimSingleBtn then
        claimSingleBtn.Text = "📬 1"
        claimSingleBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
    end
    
    isClaiming = false
    UpdateMailCount()
end

-- 🔥 อัปเดตจำนวนเมล
function UpdateMailCount()
    local success, inbox = pcall(function()
        return Mailbox.OpenInbox:Fire()
    end)
    
    if not success or not inbox then
        mailCount = 0
        if mailBadge then
            mailBadge.Text = "📭"
            mailBadge.TextColor3 = Color3.fromRGB(150, 150, 200)
        end
        if claimAllBtn then
            claimAllBtn.Text = "📭 ไม่มีเมล"
        end
        return
    end
    
    local totalGifts = 0
    for id, data in pairs(inbox) do
        if type(data) == "table" then
            totalGifts = totalGifts + 1
        end
    end
    
    mailCount = totalGifts
    
    if mailBadge then
        if mailCount > 0 then
            mailBadge.Text = "📬 " .. mailCount
            mailBadge.TextColor3 = Color3.fromRGB(255, 200, 100)
        else
            mailBadge.Text = "📭"
            mailBadge.TextColor3 = Color3.fromRGB(150, 150, 200)
        end
    end
    
    if claimAllBtn then
        if mailCount > 0 then
            claimAllBtn.Text = "📬 รับทั้งหมด"
        else
            claimAllBtn.Text = "📭 ไม่มีเมล"
        end
    end
end

-- 🔥 SEND BATCH
function SendBatchMail(targetUserId, items, note)
    if isSending then return false end
    if not targetUserId or targetUserId <= 0 then return false end
    if not items or #items == 0 then return false end

    local validItems = {}
    local hasError = false
    
    for _, item in ipairs(items) do
        local realCount = GetRealItemCount(item.Category, item.ItemKey)
        local requestedCount = item.Count or 1
        
        if realCount <= 0 then
            UpdateStatus(string.format("⚠️ ไม่มี %s ใน Inventory!", item.ItemKey), Color3.fromRGB(255, 200, 100))
            hasError = true
        elseif requestedCount > realCount then
            UpdateStatus(string.format("⚠️ %s มี %d ชิ้น (ปรับจาก %d)", item.ItemKey, realCount, requestedCount), Color3.fromRGB(255, 200, 100))
            table.insert(validItems, {
                Category = item.Category,
                ItemKey = item.ItemKey,
                Count = realCount
            })
        else
            table.insert(validItems, {
                Category = item.Category,
                ItemKey = item.ItemKey,
                Count = requestedCount
            })
        end
    end
    
    if hasError and #validItems == 0 then
        return false
    end

    isSending = true

    local batchData = {}

    for _, item in ipairs(validItems) do
        local count = item.Count or 1

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

function SendSingleMail(targetUserId, category, itemKey, count, note)
    local realCount = GetRealItemCount(category, itemKey)
    
    if realCount <= 0 then
        UpdateStatus(string.format("⚠️ ไม่มี %s ใน Inventory!", itemKey), Color3.fromRGB(255, 200, 100))
        return false
    end
    
    local sendCount = count or 1
    if sendCount > realCount then
        UpdateStatus(string.format("⚠️ %s มี %d ชิ้น (ปรับจาก %d)", itemKey, realCount, sendCount), Color3.fromRGB(255, 200, 100))
        sendCount = realCount
    end
    
    local items = {
        {Category = category, ItemKey = itemKey, Count = sendCount}
    }
    return SendBatchMail(targetUserId, items, note)
end

-- ============================================
-- 🔥 AUTO CLAIM MAIL (ทำงานอัตโนมัติ)
-- ============================================
function AutoClaimLoop()
    while autoClaimEnabled and screenGui and screenGui.Parent do
        local mailList, total = CheckAllMail()
        
        if total > 0 then
            UpdateStatus("🤖 Auto Claim: พบ " .. total .. " เมล กำลังรับ...", Color3.fromRGB(255, 200, 100))
            
            local success, result = pcall(function()
                return Mailbox.ClaimAll:Fire()
            end)
            
            if success then
                UpdateStatus("🤖 Auto Claim: รับเมล " .. total .. " รายการสำเร็จ!", Color3.fromRGB(150, 255, 150))
            else
                UpdateStatus("🤖 Auto Claim: ล้มเหลว!", Color3.fromRGB(255, 150, 150))
            end
            
            UpdateMailCount()
        else
            -- ไม่มีเมล เช็คใหม่ใน 30 วินาที
            if autoClaimEnabled then
                UpdateStatus("🤖 Auto Claim: ไม่มีเมล รอตรวจสอบ...", Color3.fromRGB(200, 200, 200))
            end
        end
        
        -- รอ 30 วินาที แล้วเช็คใหม่
        for i = 1, 30 do
            if not autoClaimEnabled or not screenGui or not screenGui.Parent then
                return
            end
            task.wait(1)
        end
    end
end

-- 🔥 เปิด/ปิด Auto Claim
function ToggleAutoClaim()
    autoClaimEnabled = not autoClaimEnabled
    
    if autoClaimEnabled then
        -- เปิด Auto Claim
        if autoClaimBtn then
            autoClaimBtn.Text = "⏸️ Auto Claim: ON"
            autoClaimBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            autoClaimBtn.BackgroundTransparency = 0.1
        end
        UpdateStatus("🤖 Auto Claim เปิดใช้งานแล้ว!", Color3.fromRGB(150, 255, 150))
        
        -- เริ่มลูป Auto Claim
        if autoClaimTask then
            task.cancel(autoClaimTask)
            autoClaimTask = nil
        end
        autoClaimTask = task.spawn(AutoClaimLoop)
    else
        -- ปิด Auto Claim
        if autoClaimBtn then
            autoClaimBtn.Text = "▶️ Auto Claim: OFF"
            autoClaimBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
            autoClaimBtn.BackgroundTransparency = 0.3
        end
        UpdateStatus("⏸️ Auto Claim ปิดแล้ว", Color3.fromRGB(200, 200, 200))
        
        if autoClaimTask then
            task.cancel(autoClaimTask)
            autoClaimTask = nil
        end
    end
end

-- ============================================
-- ระบบค้นหาผู้เล่น
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
-- Category Icons & Colors
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
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoMailGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- Main Frame
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, 650, 0, 490)
    mainFrame.Position = UDim2.new(0.5, -325, 0.3, -245)
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
    titleLabel.Size = UDim2.new(1, -160, 1, 0)
    titleLabel.Position = UDim2.new(0, 12, 0, 0)
    titleLabel.Text = "🌿 Auto Mail V8 (Auto Claim)"
    titleLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = titleBar
    
    -- Mail Badge
    mailBadge = Instance.new("TextLabel")
    mailBadge.Size = UDim2.new(0, 50, 1, 0)
    mailBadge.Position = UDim2.new(1, -100, 0, 0)
    mailBadge.Text = "📭"
    mailBadge.TextColor3 = Color3.fromRGB(150, 150, 200)
    mailBadge.TextSize = 14
    mailBadge.BackgroundTransparency = 1
    mailBadge.Font = Enum.Font.GothamBold
    mailBadge.TextXAlignment = Enum.TextXAlignment.Right
    mailBadge.Parent = titleBar
    
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
    leftPanel.Size = UDim2.new(0, 130, 1, -42)
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
    
    categoryList = Instance.new("ScrollingFrame")
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
    rightPanel.Size = UDim2.new(1, -146, 1, -42)
    rightPanel.Position = UDim2.new(0, 140, 0, 40)
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
    
    searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -80, 0, 20)
    searchBox.Position = UDim2.new(0, 4, 0, 17)
    searchBox.Text = ""
    searchBox.PlaceholderText = "🔍 ค้นหาผู้เล่น... (Enter = ทั่วโลก)"
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
    
    -- Selected Player
    selectedDisplay = Instance.new("Frame")
    selectedDisplay.Size = UDim2.new(1, -8, 0, 28)
    selectedDisplay.Position = UDim2.new(0, 4, 0, 39)
    selectedDisplay.BackgroundColor3 = Color3.fromRGB(18, 52, 28)
    selectedDisplay.BorderSizePixel = 0
    selectedDisplay.Visible = false
    selectedDisplay.Parent = recipientFrame
    
    local selectedCorner = Instance.new("UICorner")
    selectedCorner.CornerRadius = UDim.new(0, 4)
    selectedCorner.Parent = selectedDisplay
    
    avatarImage = Instance.new("ImageLabel")
    avatarImage.Size = UDim2.new(0, 20, 0, 20)
    avatarImage.Position = UDim2.new(0, 4, 0, 4)
    avatarImage.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    avatarImage.BackgroundTransparency = 0.5
    avatarImage.BorderSizePixel = 0
    avatarImage.Parent = selectedDisplay
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 10)
    avatarCorner.Parent = avatarImage
    
    selectedName = Instance.new("TextLabel")
    selectedName.Size = UDim2.new(1, -60, 0, 13)
    selectedName.Position = UDim2.new(0, 28, 0, 1)
    selectedName.Text = ""
    selectedName.TextColor3 = Color3.fromRGB(255, 255, 255)
    selectedName.TextSize = 10
    selectedName.TextXAlignment = Enum.TextXAlignment.Left
    selectedName.BackgroundTransparency = 1
    selectedName.Font = Enum.Font.GothamBold
    selectedName.Parent = selectedDisplay
    
    selectedDisplayName = Instance.new("TextLabel")
    selectedDisplayName.Size = UDim2.new(1, -60, 0, 10)
    selectedDisplayName.Position = UDim2.new(0, 28, 0, 15)
    selectedDisplayName.Text = ""
    selectedDisplayName.TextColor3 = Color3.fromRGB(150, 220, 170)
    selectedDisplayName.TextSize = 8
    selectedDisplayName.TextXAlignment = Enum.TextXAlignment.Left
    selectedDisplayName.BackgroundTransparency = 1
    selectedDisplayName.Font = Enum.Font.Gotham
    selectedDisplayName.Parent = selectedDisplay

    globalBadge = Instance.new("TextLabel")
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
    
    resultsContainer = Instance.new("Frame")
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
    
    amountBox = Instance.new("TextBox")
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
    
    local quickAmounts = {"1", "5", "10", "100", "500"}
    for i, val in ipairs(quickAmounts) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, val == "500" and 28 or 22, 0, 18)
        btn.Position = UDim2.new(0, 58 + (i-1) * (val == "500" and 32 or 26), 0, 4)
        btn.Text = val
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = val == "500" and 8 or 9
        btn.BackgroundColor3 = val == "500" and Color3.fromRGB(40, 160, 60) or Color3.fromRGB(18, 52, 28)
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
    
    noteBox = Instance.new("TextBox")
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
    
    -- 🔥 Item Search Box
    local itemSearchFrame = Instance.new("Frame")
    itemSearchFrame.Size = UDim2.new(1, -8, 0, 22)
    itemSearchFrame.Position = UDim2.new(0, 4, 0, 90)
    itemSearchFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    itemSearchFrame.BorderSizePixel = 0
    itemSearchFrame.Parent = rightPanel
    
    local itemSearchCorner = Instance.new("UICorner")
    itemSearchCorner.CornerRadius = UDim.new(0, 6)
    itemSearchCorner.Parent = itemSearchFrame
    
    local itemSearchLabel = Instance.new("TextLabel")
    itemSearchLabel.Size = UDim2.new(0, 25, 1, 0)
    itemSearchLabel.Position = UDim2.new(0, 4, 0, 0)
    itemSearchLabel.Text = "🔍"
    itemSearchLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    itemSearchLabel.TextSize = 12
    itemSearchLabel.BackgroundTransparency = 1
    itemSearchLabel.Font = Enum.Font.Gotham
    itemSearchLabel.Parent = itemSearchFrame
    
    itemSearchBox = Instance.new("TextBox")
    itemSearchBox.Size = UDim2.new(1, -32, 1, -4)
    itemSearchBox.Position = UDim2.new(0, 28, 0, 2)
    itemSearchBox.Text = ""
    itemSearchBox.PlaceholderText = "🔍 ค้นหาไอเท็ม..."
    itemSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemSearchBox.PlaceholderColor3 = Color3.fromRGB(120, 200, 140)
    itemSearchBox.TextSize = 10
    itemSearchBox.BackgroundTransparency = 1
    itemSearchBox.BorderSizePixel = 0
    itemSearchBox.ClearTextOnFocus = true
    itemSearchBox.Font = Enum.Font.Gotham
    itemSearchBox.Parent = itemSearchFrame
    
    local clearSearchBtn = Instance.new("TextButton")
    clearSearchBtn.Size = UDim2.new(0, 20, 0, 16)
    clearSearchBtn.Position = UDim2.new(1, -22, 0, 3)
    clearSearchBtn.Text = "✕"
    clearSearchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearSearchBtn.TextSize = 9
    clearSearchBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    clearSearchBtn.BackgroundTransparency = 0.5
    clearSearchBtn.BorderSizePixel = 0
    clearSearchBtn.Font = Enum.Font.GothamBold
    clearSearchBtn.Visible = false
    clearSearchBtn.Parent = itemSearchFrame
    
    local clearSearchCorner = Instance.new("UICorner")
    clearSearchCorner.CornerRadius = UDim.new(0, 9)
    clearSearchCorner.Parent = clearSearchBtn
    
    clearSearchBtn.MouseButton1Click:Connect(function()
        itemSearchBox.Text = ""
        clearSearchBtn.Visible = false
        itemSearchText = ""
        BuildCategoryList()
    end)
    clearSearchBtn.TouchTap:Connect(function()
        clearSearchBtn.MouseButton1Click:Fire()
    end)
    
    -- Stats
    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(1, -8, 0, 24)
    statsFrame.Position = UDim2.new(0, 4, 0, 116)
    statsFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = rightPanel
    
    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 6)
    statsCorner.Parent = statsFrame
    
    totalLabel = Instance.new("TextLabel")
    totalLabel.Size = UDim2.new(0, 60, 1, 0)
    totalLabel.Position = UDim2.new(0, 4, 0, 0)
    totalLabel.Text = "📊 ทั้งหมด: 0"
    totalLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    totalLabel.TextSize = 9
    totalLabel.TextXAlignment = Enum.TextXAlignment.Left
    totalLabel.BackgroundTransparency = 1
    totalLabel.Font = Enum.Font.Gotham
    totalLabel.Parent = statsFrame
    
    selectedLabel = Instance.new("TextLabel")
    selectedLabel.Size = UDim2.new(0, 60, 1, 0)
    selectedLabel.Position = UDim2.new(0, 68, 0, 0)
    selectedLabel.Text = "✅ เลือก: 0"
    selectedLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    selectedLabel.TextSize = 9
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Font = Enum.Font.Gotham
    selectedLabel.Parent = statsFrame
    
    -- Batch Info Label
    batchInfoLabel = Instance.new("TextLabel")
    batchInfoLabel.Size = UDim2.new(0, 70, 1, 0)
    batchInfoLabel.Position = UDim2.new(0, 132, 0, 0)
    batchInfoLabel.Text = ""
    batchInfoLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
    batchInfoLabel.TextSize = 8
    batchInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    batchInfoLabel.BackgroundTransparency = 1
    batchInfoLabel.Font = Enum.Font.Gotham
    batchInfoLabel.Parent = statsFrame
    
    -- 🔥 Auto Claim Toggle (อยู่แถว stats)
    autoClaimBtn = Instance.new("TextButton")
    autoClaimBtn.Size = UDim2.new(0, 90, 0, 18)
    autoClaimBtn.Position = UDim2.new(1, -190, 0, 3)
    autoClaimBtn.Text = "▶️ Auto Claim: OFF"
    autoClaimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoClaimBtn.TextSize = 8
    autoClaimBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
    autoClaimBtn.BackgroundTransparency = 0.3
    autoClaimBtn.BorderSizePixel = 0
    autoClaimBtn.Font = Enum.Font.GothamBold
    autoClaimBtn.Parent = statsFrame
    
    local autoClaimCorner = Instance.new("UICorner")
    autoClaimCorner.CornerRadius = UDim.new(0, 4)
    autoClaimCorner.Parent = autoClaimBtn
    
    autoClaimBtn.MouseEnter:Connect(function()
        TweenService:Create(autoClaimBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
    end)
    autoClaimBtn.MouseLeave:Connect(function()
        TweenService:Create(autoClaimBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
    end)
    
    autoClaimBtn.MouseButton1Click:Connect(function()
        ToggleAutoClaim()
    end)
    autoClaimBtn.TouchTap:Connect(function()
        autoClaimBtn.MouseButton1Click:Fire()
    end)
    
    -- Action Buttons
    local actionBtns = {"✅ ทั้งหมด", "🗑️ ล้าง", "🔄 รีเฟรช"}
    local actionColors = {Color3.fromRGB(0, 160, 70), Color3.fromRGB(180, 45, 45), Color3.fromRGB(40, 120, 60)}
    for i, text in ipairs(actionBtns) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 42, 0, 16)
        btn.Position = UDim2.new(1, -(12 + (3-i) * 46), 0, 4)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 7
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
                if selectedLabel then
                    selectedLabel.Text = "✅ เลือก: " .. #SelectedItems
                end
                UpdateBatchInfo()
                BuildCategoryList()
            end)
            btn.TouchTap:Connect(function() btn.MouseButton1Click:Fire() end)
        elseif i == 2 then
            btn.MouseButton1Click:Connect(function()
                SelectedItems = {}
                if selectedLabel then
                    selectedLabel.Text = "✅ เลือก: 0"
                end
                UpdateBatchInfo()
                BuildCategoryList()
            end)
            btn.TouchTap:Connect(function() btn.MouseButton1Click:Fire() end)
        else
            btn.MouseButton1Click:Connect(function()
                UpdateStatus("🔄 โหลด...", Color3.fromRGB(255, 200, 100))
                task.wait(0.3)
                BuildCategoryList()
                UpdateMailCount()
                UpdateStatus("✅ รีเฟรชสำเร็จ!", Color3.fromRGB(150, 255, 150))
            end)
            btn.TouchTap:Connect(function() btn.MouseButton1Click:Fire() end)
        end
    end
    
    -- Item List
    itemList = Instance.new("ScrollingFrame")
    itemList.Size = UDim2.new(1, -8, 1, -164)
    itemList.Position = UDim2.new(0, 4, 0, 144)
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
    bottomFrame.Size = UDim2.new(1, -8, 0, 36)
    bottomFrame.Position = UDim2.new(0, 4, 1, -40)
    bottomFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    bottomFrame.BorderSizePixel = 0
    bottomFrame.Parent = rightPanel
    
    local bottomCorner = Instance.new("UICorner")
    bottomCorner.CornerRadius = UDim.new(0, 6)
    bottomCorner.Parent = bottomFrame
    
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 140, 1, 0)
    statusLabel.Position = UDim2.new(0, 6, 0, 0)
    statusLabel.Text = "✅ พร้อมใช้งาน"
    statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    statusLabel.TextSize = 9
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = bottomFrame
    
    claimSingleBtn = Instance.new("TextButton")
    claimSingleBtn.Size = UDim2.new(0, 40, 0, 24)
    claimSingleBtn.Position = UDim2.new(1, -280, 0, 6)
    claimSingleBtn.Text = "📬 1"
    claimSingleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimSingleBtn.TextSize = 9
    claimSingleBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
    claimSingleBtn.BackgroundTransparency = 0.3
    claimSingleBtn.BorderSizePixel = 0
    claimSingleBtn.Font = Enum.Font.GothamBold
    claimSingleBtn.Parent = bottomFrame
    
    local claimSingleCorner = Instance.new("UICorner")
    claimSingleCorner.CornerRadius = UDim.new(0, 4)
    claimSingleCorner.Parent = claimSingleBtn
    
    claimSingleBtn.MouseEnter:Connect(function()
        TweenService:Create(claimSingleBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
    end)
    claimSingleBtn.MouseLeave:Connect(function()
        TweenService:Create(claimSingleBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
    end)
    
    claimSingleBtn.MouseButton1Click:Connect(function()
        ClaimSingleMail()
    end)
    claimSingleBtn.TouchTap:Connect(function()
        claimSingleBtn.MouseButton1Click:Fire()
    end)
    
    claimAllBtn = Instance.new("TextButton")
    claimAllBtn.Size = UDim2.new(0, 60, 0, 24)
    claimAllBtn.Position = UDim2.new(1, -216, 0, 6)
    claimAllBtn.Text = "📬 รับทั้งหมด"
    claimAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimAllBtn.TextSize = 9
    claimAllBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 50)
    claimAllBtn.BackgroundTransparency = 0.3
    claimAllBtn.BorderSizePixel = 0
    claimAllBtn.Font = Enum.Font.GothamBold
    claimAllBtn.Parent = bottomFrame
    
    local claimAllCorner = Instance.new("UICorner")
    claimAllCorner.CornerRadius = UDim.new(0, 4)
    claimAllCorner.Parent = claimAllBtn
    
    claimAllBtn.MouseEnter:Connect(function()
        TweenService:Create(claimAllBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
    end)
    claimAllBtn.MouseLeave:Connect(function()
        TweenService:Create(claimAllBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
    end)
    
    claimAllBtn.MouseButton1Click:Connect(function()
        ClaimAllMail()
    end)
    claimAllBtn.TouchTap:Connect(function()
        claimAllBtn.MouseButton1Click:Fire()
    end)
    
    sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0, 100, 0, 26)
    sendBtn.Position = UDim2.new(1, -108, 0, 5)
    sendBtn.Text = "🚀 ส่ง"
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendBtn.TextSize = 12
    sendBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
    sendBtn.BorderSizePixel = 0
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.Parent = bottomFrame
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 4)
    sendCorner.Parent = sendBtn
    
    -- ================================
    -- ฟังก์ชันหลัก
    -- ================================
    
    function UpdateSearchResults()
        if not resultsContainer then return end
        
        for _, child in ipairs(resultsContainer:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        if not searchBox then return end
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
        if not searchBox then return end
        local searchText = searchBox.Text
        if searchText == "" or searchText:match("^%s*$") then
            UpdateStatus("⚠️ พิมพ์ชื่อผู้เล่นก่อน!", Color3.fromRGB(255, 200, 100))
            return
        end

        local inServerResults = SearchPlayers(searchText)
        if #inServerResults > 0 then
            SelectPlayer(inServerResults[1])
            return
        end

        UpdateStatus("🌐 ไม่พบในเซิร์ฟเวอร์ กำลังค้นหาทั่วโลก...", Color3.fromRGB(255, 200, 100))

        local globalResult = SearchPlayerGlobal(searchText)
        if globalResult then
            SelectPlayer(globalResult)
        else
            UpdateStatus("❌ ไม่พบผู้เล่นชื่อ: " .. searchText, Color3.fromRGB(255, 150, 150))
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
            UpdateStatus("🌐 เลือก (Global): " .. result.DisplayName, Color3.fromRGB(150, 255, 150))
        else
            UpdateStatus("✅ เลือก: " .. result.DisplayName, Color3.fromRGB(150, 255, 150))
        end
    end
    
    if searchBox then
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
    end
    
    -- 🔥 Item Search
    if itemSearchBox then
        itemSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
            itemSearchText = itemSearchBox.Text or ""
            if itemSearchText ~= "" then
                clearSearchBtn.Visible = true
            else
                clearSearchBtn.Visible = false
            end
            BuildCategoryList()
        end)
    end
    
    -- ================================
    -- Build Category List
    -- ================================
    function BuildCategoryList()
        if not categoryList or not itemList then return end
        
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
        
        -- 🔥 กรองตามคำค้นหา
        local filteredItems = {}
        local searchLower = string.lower(itemSearchText)
        
        for _, item in ipairs(InventoryItems) do
            if searchLower == "" then
                table.insert(filteredItems, item)
            else
                local displayLower = string.lower(item.DisplayName)
                local categoryLower = string.lower(item.Category)
                if string.find(displayLower, searchLower, 1, true) or 
                   string.find(categoryLower, searchLower, 1, true) then
                    table.insert(filteredItems, item)
                end
            end
        end
        
        local grouped = {}
        for _, item in ipairs(filteredItems) do
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
        for _, item in ipairs(filteredItems) do
            totalItems = totalItems + 1
        end
        if totalLabel then
            totalLabel.Text = "📊 ทั้งหมด: " .. totalItems
        end
        
        local leftHeight = 0
        local rightHeight = 0
        
        if #sortedCategories == 0 then
            local emptyLabel = Instance.new("TextLabel")
            emptyLabel.Size = UDim2.new(1, 0, 0, 50)
            emptyLabel.Text = "🔍 ไม่พบไอเท็มที่ค้นหา"
            emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
            emptyLabel.TextSize = 14
            emptyLabel.BackgroundTransparency = 1
            emptyLabel.Font = Enum.Font.Gotham
            emptyLabel.Parent = itemList
            itemList.CanvasSize = UDim2.new(0, 0, 0, 55)
            return
        end
        
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
                    
                    local sendOneBtn = Instance.new("TextButton")
                    sendOneBtn.Size = UDim2.new(0, 38, 0, 16)
                    sendOneBtn.Position = UDim2.new(1, -42, 0, 5)
                    sendOneBtn.Text = "ส่ง"
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
                            UpdateStatus("⚠️ เลือกผู้รับก่อน!", Color3.fromRGB(255, 200, 100))
                            return
                        end
                        local amt = tonumber(amountBox.Text) or 1
                        if amt <= 0 then
                            UpdateStatus("⚠️ จำนวนไม่ถูกต้อง!", Color3.fromRGB(255, 200, 100))
                            return
                        end

                        local targetUserId = selectedPlayer.UserId
                        local note = noteBox.Text

                        task.spawn(function()
                            local ok = SendSingleMail(targetUserId, item.Category, item.ItemKey, amt, note)
                            if ok then
                                UpdateStatus("✅ ส่ง " .. item.DisplayName .. " x" .. amt .. " สำเร็จ!", Color3.fromRGB(150, 255, 150))
                            else
                                UpdateStatus("❌ ส่งล้มเหลว!", Color3.fromRGB(255, 150, 150))
                            end
                        end)
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
                        if selectedLabel then
                            selectedLabel.Text = "✅ เลือก: " .. #SelectedItems
                        end
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
        
        if selectedLabel then
            selectedLabel.Text = "✅ เลือก: " .. #SelectedItems
        end
        UpdateBatchInfo()
    end
    
    -- ================================
    -- Send All
    -- ================================
    function SendAllSelected()
        if #SelectedItems == 0 then
            UpdateStatus("⚠️ เลือกไอเท็มก่อน!", Color3.fromRGB(255, 200, 100))
            return
        end
        
        if not selectedPlayer then
            UpdateStatus("⚠️ เลือกผู้รับก่อน!", Color3.fromRGB(255, 200, 100))
            return
        end
        
        local amt = tonumber(amountBox.Text) or 1
        local note = noteBox.Text or ""
        
        if sendBtn then
            sendBtn.Text = "⏳ กำลังส่ง..."
            sendBtn.BackgroundColor3 = Color3.fromRGB(200, 130, 0)
        end
        UpdateStatus("⏳ กำลังส่ง...", Color3.fromRGB(255, 200, 100))
        
        local successCount = 0
        local failCount = 0

        for i, item in ipairs(SelectedItems) do
            local realCount = GetRealItemCount(item.Category, item.ItemKey)
            local sendAmount = amt
            
            if realCount <= 0 then
                UpdateStatus(string.format("⚠️ ไม่มี %s ใน Inventory!", item.DisplayName), Color3.fromRGB(255, 200, 100))
                failCount = failCount + 1
                if i < #SelectedItems then
                    task.wait(0.15)
                end
                do end
            else
                if sendAmount > realCount then
                    UpdateStatus(string.format("⚠️ %s มี %d ชิ้น (ปรับจาก %d)", item.DisplayName, realCount, sendAmount), Color3.fromRGB(255, 200, 100))
                    sendAmount = realCount
                end
                
                UpdateStatus(string.format("⏳ %d/%d: %s x%d", i, #SelectedItems, item.DisplayName, sendAmount), Color3.fromRGB(255, 200, 100))
                
                local ok = SendSingleMail(selectedPlayer.UserId, item.Category, item.ItemKey, sendAmount, note)
                if ok then
                    successCount = successCount + 1
                else
                    failCount = failCount + 1
                end
                
                task.wait(0.15)
            end
        end
        
        if sendBtn then
            sendBtn.Text = "🚀 ส่ง"
            sendBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
        end
        UpdateStatus(string.format("✅ เสร็จ! สำเร็จ %d ล้มเหลว %d", successCount, failCount), Color3.fromRGB(150, 255, 150))
        
        SelectedItems = {}
        if selectedLabel then
            selectedLabel.Text = "✅ เลือก: 0"
        end
        UpdateBatchInfo()
        BuildCategoryList()
    end
    
    if sendBtn then
        sendBtn.MouseButton1Click:Connect(SendAllSelected)
        sendBtn.TouchTap:Connect(function() sendBtn.MouseButton1Click:Fire() end)
    end
    
    -- ================================
    -- เริ่มต้น
    -- ================================
    
    UpdateStatus("🔄 โหลด...", Color3.fromRGB(255, 200, 100))
    task.wait(0.3)
    BuildCategoryList()
    UpdateMailCount()
    UpdateStatus("✅ พร้อมใช้งาน!", Color3.fromRGB(150, 255, 150))
    
    -- Auto refresh ทุก 30 วินาที
    task.spawn(function()
        while screenGui and screenGui.Parent do
            task.wait(30)
            UpdateMailCount()
        end
    end)
    
    print("✅ Auto Mail V8 (Auto Claim) พร้อมใช้งาน!")
    print("📌 รับเมล: กด '📬 1' = รับทีละเมล, '📬 รับทั้งหมด' = รับทั้งหมด")
    print("📌 Auto Claim: กดปุ่ม '▶️ Auto Claim: OFF' เพื่อเปิดใช้งาน")
    print("📌 ระบบจะตัดจำนวนให้อัตโนมัติหากใส่เกินที่มี")
    print("📌 ค้นหาไอเท็ม: พิมพ์ชื่อในช่องค้นหาด้านล่าง")
end

-- ============================================
-- รัน GUI
-- ============================================
task.wait(1)
CreateGUI()