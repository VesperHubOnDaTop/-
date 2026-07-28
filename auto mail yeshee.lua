-- ============================================
-- AUTO MAIL SYSTEM V17.2 (Optimized + Local Functions)
-- Mobile Ready + Draggable Toggle + History
-- ============================================

-- ============================================
-- 🔥 โหลด Services
-- ============================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ============================================
-- 🔥 โหลด Networking Module
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

-- ============================================
-- 🔥 โหลดโมดูลคำนวณราคา
-- ============================================
local FruitValueCalc
local SeedData
local MutationData
local SellValueData

pcall(function()
    FruitValueCalc = require(ReplicatedStorage.SharedModules.FruitValueCalc)
    SeedData = require(ReplicatedStorage.SharedModules.SeedData)
    MutationData = require(ReplicatedStorage.SharedModules.MutationData)
    SellValueData = require(ReplicatedStorage.SharedModules.SellValueData)
end)

-- ============================================
-- 🔥 ตัวแปรหลัก (Localized)
-- ============================================
local isSending = false
local isClaiming = false
local SelectedItems = {}
local InventoryItems = {}
local expandedCategories = {}
local mailCount = 0
local autoClaimEnabled = false
local autoClaimTask = nil
local selectedFruitInfo = nil
local isGUIVisible = true
local currentTab = "mail"

-- Drag variables สำหรับ Toggle
local isToggleDragging = false
local toggleDragStart = nil
local toggleStartPos = nil
local toggleButton = nil

-- Drag variables สำหรับ Main Frame
local isDragging = false
local dragInput = nil
local dragStart = nil
local startPos = nil

-- ตัวแปรระบบค้นหา
local selectedPlayer = nil
local searchDebounce = false
local itemSearchText = ""

-- ============================================
-- 🔥 ประวัติการส่ง
-- ============================================
local sendHistory = {}
local MAX_HISTORY = 50

-- ============================================
-- 🔥 ประกาศตัวแปร GUI (Localized)
-- ============================================
local statusLabel = nil
local batchInfoLabel = nil
local mailBadge = nil
local claimAllBtn = nil
local claimSingleBtn = nil
local autoClaimBtn = nil
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
local clearBtn = nil
local clearSearchBtn = nil

-- ตัวแปรแสดงราคาผลไม้
local priceDisplayFrame = nil
local fruitNameLabel = nil
local pricePerUnitLabel = nil
local totalPriceLabel = nil
local countLabel = nil
local sizeLabel = nil

-- ตัวแปร History
local historyContainer = nil
local historyList = nil
local historyBadge = nil
local tabMail = nil
local tabHistory = nil

-- ============================================
-- 🔥 CONFIG
-- ============================================
local MAX_ITEM_PER_SEND = 9999
local MAX_SPLIT = 20
local MAX_PER_ROUND = MAX_ITEM_PER_SEND * MAX_SPLIT

-- ============================================
-- 🔥 รายชื่อผลไม้
-- ============================================
local FRUIT_LIST = {
    "Carrot", "Tomato", "Apple", "Gold", "Star Fruit",
    "Mushroom", "Dragon's Breath", "Venus Fly Trap",
    "Venom Spitter", "Fire Fern", "Sun Bloom",
    "Hypno Bloom", "Mega", "Moon Bloom", "Rainbow",
    "Tulip", "Pomegranate", "Strawberry", "Bamboo"
}

-- ============================================
-- 🔥 รายชื่อเมล็ดพันธุ์ (ไม่ใช่ผลไม้)
-- ============================================
local SEED_ONLY = {
    "Dragon's Breath",  -- เมล็ดพันธุ์ Dragon's Breath (ไม่ใช่ผล)
    "Venus Fly Trap",   -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Venom Spitter",    -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Fire Fern",        -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Sun Bloom",        -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Hypno Bloom",      -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Mega",             -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Moon Bloom",       -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Rainbow",          -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Tulip",            -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Pomegranate",      -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Strawberry",       -- เมล็ดพันธุ์ (ไม่ใช่ผล)
    "Bamboo",           -- เมล็ดพันธุ์ (ไม่ใช่ผล)
}

-- ============================================
-- 🔥 Category Icons & Colors
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
-- 🔥 ฟังก์ชันช่วยเหลือ (Localized)
-- ============================================
local function GetPlayerThumbnail(userId)
    local success, thumb = pcall(function()
        return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
    end)
    if success and thumb then
        return thumb
    end
    return "rbxassetid://0"
end

local function GetCurrentPlayerThumb()
    return GetPlayerThumbnail(player.UserId)
end

-- ============================================
-- 🔥 ฟังก์ชันดึงผลไม้จาก Backpack
-- ============================================
local function GetFruitsFromBackpack()
    local fruits = {}
    local backpack = player:FindFirstChild("Backpack")
    
    if not backpack then
        return fruits
    end
    
    for _, item in ipairs(backpack:GetChildren()) do
        if item:IsA("Tool") then
            local name = item.Name
            
            local isFruit = false
            local fruitName = name
            
            for _, fName in ipairs(FRUIT_LIST) do
                if string.find(name, fName) then
                    isFruit = true
                    fruitName = fName
                    break
                end
            end
            
            if isFruit then
                local mutation = "Normal"
                local size = 1
                local sizeStr = ""
                
                local mutationMatch = string.match(name, "%[(.-)%]")
                if mutationMatch and not string.match(mutationMatch, "kg") then
                    mutation = mutationMatch
                end
                
                local sizeMatch = string.match(name, "%[(%d+%.?%d*)kg%]")
                if sizeMatch then
                    size = tonumber(sizeMatch) or 1
                    sizeStr = sizeMatch .. "kg"
                end
                
                table.insert(fruits, {
                    name = fruitName,
                    fullName = name,
                    mutation = mutation,
                    size = size,
                    sizeStr = sizeStr,
                    displayName = name,
                    category = "🍎 Fruits",
                    IsFruit = true,
                    Count = 1,
                    Item = item
                })
            end
        end
    end
    
    return fruits
end

-- ============================================
-- 🔥 ฟังก์ชันคำนวณราคาผลไม้
-- ============================================
local function GetFruitPrice(fruitName, sizeMultiplier, mutation, tax)
    if not FruitValueCalc then
        return 0
    end
    
    sizeMultiplier = sizeMultiplier or 1
    mutation = mutation or "Normal"
    tax = tax or 0
    
    local success, price = pcall(function()
        return FruitValueCalc(fruitName, sizeMultiplier, mutation, player, tax)
    end)
    
    if success and type(price) == "number" then
        return price
    end
    return 0
end

local function GetFruitPriceInfo(fruitName)
    local normalPrice = GetFruitPrice(fruitName, 1, "Normal", 0)
    local bigPrice = GetFruitPrice(fruitName, 5, "Normal", 0)
    local hugePrice = GetFruitPrice(fruitName, 10, "Normal", 0)
    
    return {
        normal = normalPrice,
        big = bigPrice,
        huge = hugePrice
    }
end

-- ============================================
-- 🔥 ฟังก์ชันดึง Inventory
-- ============================================
local function GetMyInventory()
    local items = {}
    
    -- 1. ดึงผลไม้จาก Backpack
    local fruits = GetFruitsFromBackpack()
    for _, fruit in ipairs(fruits) do
        local price = GetFruitPrice(fruit.name, fruit.size or 1, fruit.mutation or "Normal", 0)
        table.insert(items, {
            Category = "🍎 Fruits",
            ItemKey = fruit.fullName,
            Count = 1,
            DisplayName = fruit.displayName,
            IsFruit = true,
            Price = price,
            FruitData = fruit
        })
    end
    
    -- 2. ดึงจาก Inventory
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
                Props = "Props",
                Stickers = "Stickers",
                Trophies = "Trophies",
                Eggs = "Eggs",
                Rakes = "Rakes",
                Ladders = "Ladders"
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
            
            -- ดึงเมล็ดพันธุ์ (Seed)
            if Inventory.Seeds then
                for name, count in pairs(Inventory.Seeds) do
                    if count > 0 then
                        local isFruitSeed = false
                        for _, fName in ipairs(FRUIT_LIST) do
                            if name == fName then
                                isFruitSeed = true
                                break
                            end
                        end
                        
                        if not isFruitSeed then
                            local isSeed = false
                            for _, sName in ipairs(SEED_ONLY) do
                                if name == sName then
                                    isSeed = true
                                    break
                                end
                            end
                            
                            if isSeed then
                                table.insert(items, {
                                    Category = "Seeds",
                                    ItemKey = name,
                                    Count = count,
                                    DisplayName = name .. " 🌱",
                                    IsSeed = true
                                })
                            end
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
            batchInfoLabel.Text = string.format("📦 %d", totalCount)
            batchInfoLabel.TextColor3 = rounds > 1 and Color3.fromRGB(255, 200, 100) or Color3.fromRGB(200, 200, 100)
        else
            batchInfoLabel.Text = ""
        end
    end
end

-- ============================================
-- 🔥 หาจำนวนของที่มีจริง
-- ============================================
local function GetRealItemCount(category, itemKey)
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
local function CheckAllMail()
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

local function ClaimAllMail()
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

local function ClaimSingleMail()
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

local function UpdateMailCount()
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

-- ============================================
-- 🔥 SEND BATCH
-- ============================================
local function SendBatchMail(targetUserId, items, note)
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

local function SendSingleMail(targetUserId, category, itemKey, count, note)
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
-- 🔥 AUTO CLAIM MAIL
-- ============================================
local function AutoClaimLoop()
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
            if autoClaimEnabled then
                UpdateStatus("🤖 Auto Claim: ไม่มีเมล รอตรวจสอบ...", Color3.fromRGB(200, 200, 200))
            end
        end
        
        for i = 1, 30 do
            if not autoClaimEnabled or not screenGui or not screenGui.Parent then
                return
            end
            task.wait(1)
        end
    end
end

local function ToggleAutoClaim()
    autoClaimEnabled = not autoClaimEnabled
    
    if autoClaimEnabled then
        if autoClaimBtn then
            autoClaimBtn.Text = "⏸️ ON"
            autoClaimBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
            autoClaimBtn.BackgroundTransparency = 0.1
            autoClaimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        UpdateStatus("🤖 Auto Claim เปิดใช้งานแล้ว!", Color3.fromRGB(150, 255, 150))
        
        if autoClaimTask then
            task.cancel(autoClaimTask)
            autoClaimTask = nil
        end
        autoClaimTask = task.spawn(AutoClaimLoop)
    else
        if autoClaimBtn then
            autoClaimBtn.Text = "▶️ OFF"
            autoClaimBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
            autoClaimBtn.BackgroundTransparency = 0.3
            autoClaimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        end
        UpdateStatus("⏸️ Auto Claim ปิดแล้ว", Color3.fromRGB(200, 200, 200))
        
        if autoClaimTask then
            task.cancel(autoClaimTask)
            autoClaimTask = nil
        end
    end
end

-- ============================================
-- 🔥 Toggle GUI (เปิด/ปิด + ลากได้)
-- ============================================
local function ToggleGUI()
    isGUIVisible = not isGUIVisible
    mainFrame.Visible = isGUIVisible
    if toggleButton then
        toggleButton.Text = isGUIVisible and "📭" or "📬"
        toggleButton.BackgroundColor3 = isGUIVisible and Color3.fromRGB(40, 180, 70) or Color3.fromRGB(180, 45, 45)
    end
end

-- ============================================
-- 🔥 ระบบค้นหาผู้เล่น
-- ============================================
local function SearchPlayers(searchText)
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

local function SearchPlayerGlobal(username)
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

-- ============================================
-- 🔥 ฟังก์ชันหลักสำหรับ GUI
-- ============================================
local function PerformFullSearch()
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

local function SelectPlayer(result)
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

local function UpdateSearchResults()
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
    
    resultsContainer.Size = UDim2.new(1, 0, 0, #results * 24 + 4)
    
    for _, result in ipairs(results) do
        local row = Instance.new("TextButton")
        row.Size = UDim2.new(1, 0, 0, 22)
        row.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
        row.BackgroundTransparency = 0.3
        row.BorderSizePixel = 0
        row.Parent = resultsContainer
        
        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 4)
        rowCorner.Parent = row
        
        row.MouseEnter:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()
        end)
        row.MouseLeave:Connect(function()
            TweenService:Create(row, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
        end)
        
        local avatar = Instance.new("ImageLabel")
        avatar.Size = UDim2.new(0, 18, 0, 18)
        avatar.Position = UDim2.new(0, 2, 0, 2)
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
        nameText.Position = UDim2.new(0, 24, 0, 0)
        nameText.Text = result.DisplayName
        nameText.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameText.TextSize = 10
        nameText.TextXAlignment = Enum.TextXAlignment.Left
        nameText.BackgroundTransparency = 1
        nameText.Font = Enum.Font.GothamBold
        nameText.Parent = row
        
        local usernameText = Instance.new("TextLabel")
        usernameText.Size = UDim2.new(1, -40, 0, 9)
        usernameText.Position = UDim2.new(0, 24, 0, 12)
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

-- ============================================
-- 🔥 ประวัติการส่ง
-- ============================================
local function AddToHistory(receiverName, receiverId, itemName, count, category, status, note)
    local entry = {
        id = HttpService:GenerateGUID(false),
        timestamp = os.time(),
        timeStr = os.date("%H:%M"),
        dateStr = os.date("%d/%m/%Y"),
        receiverName = receiverName,
        receiverId = receiverId,
        itemName = itemName,
        count = count,
        category = category or "Unknown",
        status = status or "✅ สำเร็จ",
        note = note or "",
        senderName = player.DisplayName or player.Name,
        senderId = player.UserId
    }
    
    table.insert(sendHistory, 1, entry)
    
    if #sendHistory > MAX_HISTORY then
        table.remove(sendHistory)
    end
    
    UpdateHistoryUI()
    UpdateHistoryBadge()
end

local function UpdateHistoryUI()
    if not historyList then return end
    
    for _, child in ipairs(historyList:GetChildren()) do
        if child:IsA("Frame") then
            child:Destroy()
        end
    end
    
    if #sendHistory == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 40)
        emptyLabel.Text = "📭 ยังไม่มีประวัติการส่ง"
        emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        emptyLabel.TextSize = 12
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.Parent = historyList
        historyList.CanvasSize = UDim2.new(0, 0, 0, 45)
        return
    end
    
    local totalHeight = 0
    
    for _, entry in ipairs(sendHistory) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -4, 0, 54)
        row.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
        row.BackgroundTransparency = 0.2
        row.BorderSizePixel = 0
        row.Parent = historyList
        
        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 5)
        rowCorner.Parent = row
        
        -- ผู้ส่ง (เรา)
        local senderAvatar = Instance.new("ImageLabel")
        senderAvatar.Size = UDim2.new(0, 22, 0, 22)
        senderAvatar.Position = UDim2.new(0, 3, 0, 4)
        senderAvatar.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
        senderAvatar.BackgroundTransparency = 0.5
        senderAvatar.BorderSizePixel = 0
        senderAvatar.Parent = row
        
        local senderCorner = Instance.new("UICorner")
        senderCorner.CornerRadius = UDim.new(0, 11)
        senderCorner.Parent = senderAvatar
        
        task.spawn(function()
            senderAvatar.Image = GetCurrentPlayerThumb()
        end)
        
        local arrowLabel = Instance.new("TextLabel")
        arrowLabel.Size = UDim2.new(0, 16, 0, 16)
        arrowLabel.Position = UDim2.new(0, 28, 0, 7)
        arrowLabel.Text = "➜"
        arrowLabel.TextColor3 = Color3.fromRGB(100, 200, 100)
        arrowLabel.TextSize = 14
        arrowLabel.BackgroundTransparency = 1
        arrowLabel.Font = Enum.Font.GothamBold
        arrowLabel.Parent = row
        
        -- ผู้รับ
        local receiverAvatar = Instance.new("ImageLabel")
        receiverAvatar.Size = UDim2.new(0, 22, 0, 22)
        receiverAvatar.Position = UDim2.new(0, 48, 0, 4)
        receiverAvatar.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
        receiverAvatar.BackgroundTransparency = 0.5
        receiverAvatar.BorderSizePixel = 0
        receiverAvatar.Parent = row
        
        local receiverCorner = Instance.new("UICorner")
        receiverCorner.CornerRadius = UDim.new(0, 11)
        receiverCorner.Parent = receiverAvatar
        
        task.spawn(function()
            receiverAvatar.Image = GetPlayerThumbnail(entry.receiverId)
        end)
        
        -- ชื่อผู้รับ
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 120, 0, 14)
        nameLabel.Position = UDim2.new(0, 74, 0, 2)
        nameLabel.Text = entry.receiverName
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 11
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.BackgroundTransparency = 1
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = row
        
        -- รายละเอียด
        local detailLabel = Instance.new("TextLabel")
        detailLabel.Size = UDim2.new(1, -200, 0, 12)
        detailLabel.Position = UDim2.new(0, 74, 0, 17)
        detailLabel.Text = string.format("📦 %s x%d", entry.itemName, entry.count)
        detailLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
        detailLabel.TextSize = 9
        detailLabel.TextXAlignment = Enum.TextXAlignment.Left
        detailLabel.BackgroundTransparency = 1
        detailLabel.Font = Enum.Font.Gotham
        detailLabel.Parent = row
        
        -- หมวดหมู่
        local catLabel = Instance.new("TextLabel")
        catLabel.Size = UDim2.new(0, 80, 0, 10)
        catLabel.Position = UDim2.new(0, 74, 0, 29)
        catLabel.Text = entry.category
        catLabel.TextColor3 = Color3.fromRGB(150, 200, 150)
        catLabel.TextSize = 8
        catLabel.TextXAlignment = Enum.TextXAlignment.Left
        catLabel.BackgroundTransparency = 1
        catLabel.Font = Enum.Font.Gotham
        catLabel.Parent = row
        
        -- เวลา
        local timeLabel = Instance.new("TextLabel")
        timeLabel.Size = UDim2.new(0, 60, 0, 12)
        timeLabel.Position = UDim2.new(1, -135, 0, 2)
        timeLabel.Text = entry.timeStr
        timeLabel.TextColor3 = Color3.fromRGB(150, 150, 200)
        timeLabel.TextSize = 9
        timeLabel.TextXAlignment = Enum.TextXAlignment.Right
        timeLabel.BackgroundTransparency = 1
        timeLabel.Font = Enum.Font.Gotham
        timeLabel.Parent = row
        
        -- วันที่
        local dateLabel = Instance.new("TextLabel")
        dateLabel.Size = UDim2.new(0, 80, 0, 10)
        dateLabel.Position = UDim2.new(1, -135, 0, 15)
        dateLabel.Text = entry.dateStr
        dateLabel.TextColor3 = Color3.fromRGB(120, 120, 170)
        dateLabel.TextSize = 8
        dateLabel.TextXAlignment = Enum.TextXAlignment.Right
        dateLabel.BackgroundTransparency = 1
        dateLabel.Font = Enum.Font.Gotham
        dateLabel.Parent = row
        
        -- สถานะ
        local statusLabel2 = Instance.new("TextLabel")
        statusLabel2.Size = UDim2.new(0, 60, 0, 14)
        statusLabel2.Position = UDim2.new(1, -60, 0, 4)
        statusLabel2.Text = entry.status
        statusLabel2.TextColor3 = entry.status == "✅ สำเร็จ" and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 100, 100)
        statusLabel2.TextSize = 8
        statusLabel2.TextXAlignment = Enum.TextXAlignment.Right
        statusLabel2.BackgroundTransparency = 1
        statusLabel2.Font = Enum.Font.GothamBold
        statusLabel2.Parent = row
        
        -- หมายเหตุ
        if entry.note and entry.note ~= "" then
            local noteLabel = Instance.new("TextLabel")
            noteLabel.Size = UDim2.new(0, 100, 0, 10)
            noteLabel.Position = UDim2.new(0, 74, 0, 40)
            noteLabel.Text = "✏️ " .. entry.note
            noteLabel.TextColor3 = Color3.fromRGB(200, 180, 150)
            noteLabel.TextSize = 7
            noteLabel.TextXAlignment = Enum.TextXAlignment.Left
            noteLabel.BackgroundTransparency = 1
            noteLabel.Font = Enum.Font.Gotham
            noteLabel.Parent = row
        end
        
        totalHeight = totalHeight + 56
    end
    
    historyList.CanvasSize = UDim2.new(0, 0, 0, totalHeight + 10)
end

local function UpdateHistoryBadge()
    if historyBadge then
        if #sendHistory > 0 then
            historyBadge.Text = "📜 " .. #sendHistory
            historyBadge.TextColor3 = Color3.fromRGB(200, 200, 255)
        else
            historyBadge.Text = "📜"
            historyBadge.TextColor3 = Color3.fromRGB(150, 150, 180)
        end
    end
end

-- ============================================
-- 🔥 Send All Selected
-- ============================================
local function SendAllSelected()
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
            UpdateStatus(string.format("⚠️ ไม่มี %s!", item.DisplayName), Color3.fromRGB(255, 200, 100))
            failCount = failCount + 1
            if i < #SelectedItems then
                task.wait(0.15)
            end
        else
            if sendAmount > realCount then
                UpdateStatus(string.format("⚠️ %s มี %d ชิ้น", item.DisplayName, realCount), Color3.fromRGB(255, 200, 100))
                sendAmount = realCount
            end
            
            UpdateStatus(string.format("⏳ %d/%d: %s x%d", i, #SelectedItems, item.DisplayName, sendAmount), Color3.fromRGB(255, 200, 100))
            
            local ok = SendSingleMail(selectedPlayer.UserId, item.Category, item.ItemKey, sendAmount, note)
            if ok then
                successCount = successCount + 1
                AddToHistory(
                    selectedPlayer.DisplayName,
                    selectedPlayer.UserId,
                    item.DisplayName,
                    sendAmount,
                    item.Category,
                    "✅ สำเร็จ",
                    note
                )
            else
                failCount = failCount + 1
                AddToHistory(
                    selectedPlayer.DisplayName,
                    selectedPlayer.UserId,
                    item.DisplayName,
                    sendAmount,
                    item.Category,
                    "❌ ล้มเหลว",
                    note
                )
            end
            
            task.wait(0.15)
        end
    end
    
    if sendBtn then
        sendBtn.Text = "🚀 ส่ง"
        sendBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 70)
    end
    UpdateStatus(string.format("✅ สำเร็จ %d ล้มเหลว %d", successCount, failCount), Color3.fromRGB(150, 255, 150))
    
    SelectedItems = {}
    if selectedLabel then
        selectedLabel.Text = "✅ 0"
    end
    UpdateBatchInfo()
    BuildCategoryList()
end

-- ============================================
-- 🔥 Update Price Display
-- ============================================
local function UpdatePriceDisplay(item)
    if not priceDisplayFrame then return end
    
    if not item or not item.IsFruit then
        priceDisplayFrame.Visible = false
        return
    end
    
    priceDisplayFrame.Visible = true
    
    local fruitName = item.FruitData and item.FruitData.name or item.ItemKey
    local mutation = item.FruitData and item.FruitData.mutation or "Normal"
    local size = item.FruitData and item.FruitData.size or 1
    local fullName = item.DisplayName or item.ItemKey
    
    local price = GetFruitPrice(fruitName, size, mutation, 0)
    local priceInfo = GetFruitPriceInfo(fruitName)
    
    if fruitNameLabel then
        fruitNameLabel.Text = "🍎 " .. fruitName
    end
    
    if pricePerUnitLabel then
        pricePerUnitLabel.Text = "💰 " .. price .. " (ขนาด " .. size .. "x)"
    end
    
    if totalPriceLabel then
        totalPriceLabel.Text = "💎 รวม: " .. price
    end
    
    if countLabel then
        countLabel.Text = "📦 x1"
    end
    
    if sizeLabel then
        sizeLabel.Text = string.format("1x=%d | 5x=%d | 10x=%d", 
            priceInfo.normal, priceInfo.big, priceInfo.huge)
    end
end

-- ============================================
-- 🔥 Build Category List
-- ============================================
local function BuildCategoryList()
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
    
    local filteredItems = {}
    local searchLower = string.lower(itemSearchText or "")
    
    for _, item in ipairs(InventoryItems) do
        if searchLower == "" then
            table.insert(filteredItems, item)
        else
            local displayLower = string.lower(item.DisplayName or "")
            local categoryLower = string.lower(item.Category or "")
            if string.find(displayLower, searchLower, 1, true) or 
               string.find(categoryLower, searchLower, 1, true) then
                table.insert(filteredItems, item)
            end
        end
    end
    
    local grouped = {}
    for _, item in ipairs(filteredItems) do
        local cat = item.Category or "Unknown"
        if not grouped[cat] then
            grouped[cat] = {}
        end
        table.insert(grouped[cat], item)
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
        totalLabel.Text = "📊 " .. totalItems
    end
    
    local leftHeight = 0
    local rightHeight = 0
    
    if #sortedCategories == 0 then
        local emptyLabel = Instance.new("TextLabel")
        emptyLabel.Size = UDim2.new(1, 0, 0, 40)
        emptyLabel.Text = "🔍 ไม่พบไอเท็ม"
        emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
        emptyLabel.TextSize = 12
        emptyLabel.BackgroundTransparency = 1
        emptyLabel.Font = Enum.Font.Gotham
        emptyLabel.Parent = itemList
        itemList.CanvasSize = UDim2.new(0, 0, 0, 45)
        return
    end
    
    for _, catName in ipairs(sortedCategories) do
        local items = grouped[catName]
        if not items or #items == 0 then continue end
        
        local isExpanded = expandedCategories[catName] or false
        
        local catBtn = Instance.new("TextButton")
        catBtn.Size = UDim2.new(1, -2, 0, 24)
        
        local icon = CATEGORY_ICONS[catName] or "📦"
        local catNameSafe = tostring(catName) or "Unknown"
        local countSafe = tostring(#items) or "0"
        catBtn.Text = icon .. " " .. catNameSafe .. " (" .. countSafe .. ")"
        
        catBtn.TextColor3 = CATEGORY_COLORS[catName] or Color3.fromRGB(150, 255, 150)
        catBtn.TextSize = 9
        catBtn.TextXAlignment = Enum.TextXAlignment.Left
        catBtn.BackgroundColor3 = isExpanded and Color3.fromRGB(18, 55, 28) or Color3.fromRGB(10, 30, 16)
        catBtn.BackgroundTransparency = 0.3
        catBtn.BorderSizePixel = 0
        catBtn.Font = Enum.Font.Gotham
        catBtn.Parent = categoryList
        
        local catCorner = Instance.new("UICorner")
        catCorner.CornerRadius = UDim.new(0, 4)
        catCorner.Parent = catBtn
        
        catBtn.MouseEnter:Connect(function()
            TweenService:Create(catBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.1}):Play()
        end)
        catBtn.MouseLeave:Connect(function()
            TweenService:Create(catBtn, TweenInfo.new(0.1), {BackgroundTransparency = 0.3}):Play()
        end)
        
        leftHeight = leftHeight + 24 + 2
        
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
                row.Size = UDim2.new(1, -2, 0, 24)
                row.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
                row.BackgroundTransparency = 0.3
                row.BorderSizePixel = 0
                row.Parent = itemList
                
                local rowCorner = Instance.new("UICorner")
                rowCorner.CornerRadius = UDim.new(0, 4)
                rowCorner.Parent = row
                
                local checkBtn = Instance.new("TextButton")
                checkBtn.Size = UDim2.new(0, 18, 0, 18)
                checkBtn.Position = UDim2.new(0, 2, 0, 3)
                checkBtn.Text = "☐"
                checkBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                checkBtn.TextSize = 10
                checkBtn.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
                checkBtn.BackgroundTransparency = 0.3
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
                        row.BackgroundColor3 = Color3.fromRGB(18, 55, 28)
                        row.BackgroundTransparency = 0.2
                        break
                    end
                end
                
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(0, 100, 1, 0)
                nameLabel.Position = UDim2.new(0, 24, 0, 0)
                nameLabel.Text = tostring(item.DisplayName) or "Unknown"
                nameLabel.TextColor3 = Color3.fromRGB(220, 255, 220)
                nameLabel.TextSize = 10
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.BackgroundTransparency = 1
                nameLabel.Font = Enum.Font.Gotham
                nameLabel.Parent = row
                
                local amtLabel = Instance.new("TextLabel")
                amtLabel.Size = UDim2.new(0, 35, 1, 0)
                amtLabel.Position = UDim2.new(0, 128, 0, 0)
                amtLabel.Text = "x" .. tostring(item.Count or 0)
                amtLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
                amtLabel.TextSize = 9
                amtLabel.TextXAlignment = Enum.TextXAlignment.Left
                amtLabel.BackgroundTransparency = 1
                amtLabel.Font = Enum.Font.Gotham
                amtLabel.Parent = row
                
                if item.IsFruit then
                    local selectArea = Instance.new("TextButton")
                    selectArea.Size = UDim2.new(1, -50, 1, 0)
                    selectArea.BackgroundTransparency = 1
                    selectArea.BorderSizePixel = 0
                    selectArea.Text = ""
                    selectArea.Parent = row
                    
                    selectArea.MouseButton1Click:Connect(function()
                        selectedFruitInfo = item
                        UpdatePriceDisplay(item)
                    end)
                    selectArea.TouchTap:Connect(function()
                        selectArea.MouseButton1Click:Fire()
                    end)
                end
                
                local sendOneBtn = Instance.new("TextButton")
                sendOneBtn.Size = UDim2.new(0, 36, 0, 16)
                sendOneBtn.Position = UDim2.new(1, -40, 0, 4)
                sendOneBtn.Text = "ส่ง 1"
                sendOneBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                sendOneBtn.TextSize = 7
                sendOneBtn.BackgroundColor3 = Color3.fromRGB(35, 140, 60)
                sendOneBtn.BackgroundTransparency = 0.2
                sendOneBtn.BorderSizePixel = 0
                sendOneBtn.Font = Enum.Font.GothamBold
                sendOneBtn.Parent = row
                
                local sendOneCorner = Instance.new("UICorner")
                sendOneCorner.CornerRadius = UDim.new(0, 3)
                sendOneCorner.Parent = sendOneBtn
                
                sendOneBtn.MouseEnter:Connect(function()
                    TweenService:Create(sendOneBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.05}):Play()
                end)
                sendOneBtn.MouseLeave:Connect(function()
                    TweenService:Create(sendOneBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
                end)
                
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
                            AddToHistory(
                                selectedPlayer.DisplayName,
                                selectedPlayer.UserId,
                                item.DisplayName,
                                amt,
                                item.Category,
                                "✅ สำเร็จ",
                                note
                            )
                        else
                            UpdateStatus("❌ ส่งล้มเหลว!", Color3.fromRGB(255, 150, 150))
                            AddToHistory(
                                selectedPlayer.DisplayName,
                                selectedPlayer.UserId,
                                item.DisplayName,
                                amt,
                                item.Category,
                                "❌ ล้มเหลว",
                                note
                            )
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
                        row.BackgroundColor3 = Color3.fromRGB(18, 55, 28)
                        row.BackgroundTransparency = 0.2
                        table.insert(SelectedItems, item)
                    else
                        checkBtn.Text = "☐"
                        checkBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
                        row.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
                        row.BackgroundTransparency = 0.3
                        for i, selected in ipairs(SelectedItems) do
                            if selected == item then
                                table.remove(SelectedItems, i)
                                break
                            end
                        end
                    end
                    if selectedLabel then
                        selectedLabel.Text = "✅ " .. #SelectedItems
                    end
                    UpdateBatchInfo()
                end)
                checkBtn.TouchTap:Connect(function()
                    checkBtn.MouseButton1Click:Fire()
                end)
                
                rightHeight = rightHeight + 24 + 2
            end
        end
    end
    
    categoryList.CanvasSize = UDim2.new(0, 0, 0, leftHeight + 10)
    itemList.CanvasSize = UDim2.new(0, 0, 0, rightHeight + 30)
    
    if selectedLabel then
        selectedLabel.Text = "✅ " .. #SelectedItems
    end
    UpdateBatchInfo()
end

-- ============================================
-- 🔥 Switch Tab
-- ============================================
local function SwitchTab(tab)
    if tab == "mail" then
        mailContainer.Visible = true
        historyContainer.Visible = false
        tabMail.BackgroundColor3 = Color3.fromRGB(30, 100, 50)
        tabMail.BackgroundTransparency = 0.2
        tabMail.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabHistory.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
        tabHistory.BackgroundTransparency = 0.4
        tabHistory.TextColor3 = Color3.fromRGB(200, 200, 200)
        currentTab = "mail"
    else
        mailContainer.Visible = false
        historyContainer.Visible = true
        tabHistory.BackgroundColor3 = Color3.fromRGB(30, 100, 50)
        tabHistory.BackgroundTransparency = 0.2
        tabHistory.TextColor3 = Color3.fromRGB(255, 255, 255)
        tabMail.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
        tabMail.BackgroundTransparency = 0.4
        tabMail.TextColor3 = Color3.fromRGB(200, 200, 200)
        currentTab = "history"
        UpdateHistoryUI()
    end
end

-- ============================================
-- 🔥 สร้าง GUI
-- ============================================
local function CreateGUI()
    local oldGui = playerGui:FindFirstChild("AutoMailGUI")
    if oldGui then oldGui:Destroy() end
    
    screenGui = Instance.new("ScreenGui")
    screenGui.Name = "AutoMailGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = playerGui
    
    -- ============================================
    -- 🔥 Toggle Button (ลากได้ + เปิด/ปิด GUI)
    -- ============================================
    toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 50, 0, 50)
    toggleButton.Position = UDim2.new(0.85, -25, 0.1, 30)
    toggleButton.Text = "📭"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.TextSize = 24
    toggleButton.BackgroundColor3 = Color3.fromRGB(40, 180, 70)
    toggleButton.BackgroundTransparency = 0.2
    toggleButton.BorderSizePixel = 0
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.ZIndex = 999
    toggleButton.Parent = screenGui
    
    local toggleCorner = Instance.new("UICorner")
    toggleCorner.CornerRadius = UDim.new(0, 25)
    toggleCorner.Parent = toggleButton
    
    -- Shadow
    local toggleShadow = Instance.new("ImageLabel")
    toggleShadow.Size = UDim2.new(1.3, 0, 1.3, 0)
    toggleShadow.Position = UDim2.new(-0.15, 0, -0.15, 0)
    toggleShadow.Image = "rbxassetid://1316045230"
    toggleShadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
    toggleShadow.ImageTransparency = 0.7
    toggleShadow.BackgroundTransparency = 1
    toggleShadow.ZIndex = 998
    toggleShadow.Parent = toggleButton
    
    -- Glow ring
    local glowRing = Instance.new("Frame")
    glowRing.Size = UDim2.new(1.2, 0, 1.2, 0)
    glowRing.Position = UDim2.new(-0.1, 0, -0.1, 0)
    glowRing.BackgroundTransparency = 1
    glowRing.BorderSizePixel = 2
    glowRing.BorderColor3 = Color3.fromRGB(60, 200, 80)
    glowRing.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    glowRing.BorderMode = Enum.BorderMode.Outline
    glowRing.ZIndex = 997
    glowRing.Parent = toggleButton
    
    local glowRingCorner = Instance.new("UICorner")
    glowRingCorner.CornerRadius = UDim.new(0, 30)
    glowRingCorner.Parent = glowRing
    
    -- 🔥 Toggle Button Drag System
    toggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            isToggleDragging = true
            toggleDragStart = input.Position
            toggleStartPos = toggleButton.Position
        end
    end)
    
    toggleButton.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            if isToggleDragging then
                local delta = input.Position - toggleDragStart
                toggleButton.Position = UDim2.new(
                    toggleStartPos.X.Scale, toggleStartPos.X.Offset + delta.X,
                    toggleStartPos.Y.Scale, toggleStartPos.Y.Offset + delta.Y
                )
            end
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            isToggleDragging = false
        end
    end)
    
    toggleButton.MouseButton1Click:Connect(ToggleGUI)
    toggleButton.TouchTap:Connect(ToggleGUI)
    
    -- ============================================
    -- Main Frame (Center)
    -- ============================================
    local frameWidth = 680
    local frameHeight = 560
    
    mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, frameWidth, 0, frameHeight)
    mainFrame.Position = UDim2.new(0.5, -frameWidth/2, 0.5, -frameHeight/2)
    mainFrame.BackgroundColor3 = Color3.fromRGB(10, 30, 18)
    mainFrame.BackgroundTransparency = 0.03
    mainFrame.BorderSizePixel = 0
    mainFrame.ClipsDescendants = true
    mainFrame.Parent = screenGui
    mainFrame.Visible = true
    
    -- Main Gradient
    local mainGradient = Instance.new("UIGradient")
    mainGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(20, 60, 30)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(12, 40, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 25, 14))
    })
    mainGradient.Rotation = 135
    mainGradient.Parent = mainFrame
    
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
    titleBar.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
    titleBar.BackgroundTransparency = 0.2
    titleBar.BorderSizePixel = 0
    titleBar.Parent = mainFrame
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -160, 0, 18)
    titleLabel.Position = UDim2.new(0, 12, 0, 3)
    titleLabel.Text = "🌿 Auto Mail System"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextSize = 15
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = titleBar
    
    local subTitle = Instance.new("TextLabel")
    subTitle.Size = UDim2.new(1, -160, 0, 12)
    subTitle.Position = UDim2.new(0, 12, 0, 22)
    subTitle.Text = "✨ ส่งของ • รับเมล • Auto Claim"
    subTitle.TextColor3 = Color3.fromRGB(150, 255, 150)
    subTitle.TextSize = 9
    subTitle.TextXAlignment = Enum.TextXAlignment.Left
    subTitle.BackgroundTransparency = 1
    subTitle.Font = Enum.Font.Gotham
    subTitle.Parent = titleBar
    
    -- Mail Badge
    mailBadge = Instance.new("TextLabel")
    mailBadge.Size = UDim2.new(0, 45, 1, 0)
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
    closeBtn.Size = UDim2.new(0, 26, 0, 26)
    closeBtn.Position = UDim2.new(1, -34, 0, 5)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.BackgroundTransparency = 0.4
    closeBtn.BorderSizePixel = 0
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    closeBtn.MouseButton1Click:Connect(function()
        mainFrame.Visible = false
        if toggleButton then
            toggleButton.Text = "📬"
            toggleButton.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
        end
        isGUIVisible = false
    end)
    closeBtn.TouchTap:Connect(function()
        closeBtn.MouseButton1Click:Fire()
    end)
    
    -- Drag System (Main Frame)
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
    
    -- ============================================
    -- 🔥 Tabs
    -- ============================================
    local tabsFrame = Instance.new("Frame")
    tabsFrame.Size = UDim2.new(1, -12, 0, 28)
    tabsFrame.Position = UDim2.new(0, 6, 0, 40)
    tabsFrame.BackgroundTransparency = 1
    tabsFrame.Parent = mainFrame
    
    tabMail = Instance.new("TextButton")
    tabMail.Size = UDim2.new(0, 120, 1, 0)
    tabMail.Position = UDim2.new(0, 0, 0, 0)
    tabMail.Text = "📬 Mail"
    tabMail.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabMail.TextSize = 12
    tabMail.BackgroundColor3 = Color3.fromRGB(30, 100, 50)
    tabMail.BackgroundTransparency = 0.2
    tabMail.BorderSizePixel = 0
    tabMail.Font = Enum.Font.GothamBold
    tabMail.Parent = tabsFrame
    
    local tabCorner1 = Instance.new("UICorner")
    tabCorner1.CornerRadius = UDim.new(0, 6)
    tabCorner1.Parent = tabMail
    
    tabHistory = Instance.new("TextButton")
    tabHistory.Size = UDim2.new(0, 120, 1, 0)
    tabHistory.Position = UDim2.new(0, 124, 0, 0)
    tabHistory.Text = "📜 History"
    tabHistory.TextColor3 = Color3.fromRGB(200, 200, 200)
    tabHistory.TextSize = 12
    tabHistory.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
    tabHistory.BackgroundTransparency = 0.4
    tabHistory.BorderSizePixel = 0
    tabHistory.Font = Enum.Font.GothamBold
    tabHistory.Parent = tabsFrame
    
    local tabCorner2 = Instance.new("UICorner")
    tabCorner2.CornerRadius = UDim.new(0, 6)
    tabCorner2.Parent = tabHistory
    
    historyBadge = Instance.new("TextLabel")
    historyBadge.Size = UDim2.new(0, 30, 1, 0)
    historyBadge.Position = UDim2.new(1, -34, 0, 0)
    historyBadge.Text = "📜"
    historyBadge.TextColor3 = Color3.fromRGB(150, 150, 180)
    historyBadge.TextSize = 10
    historyBadge.BackgroundTransparency = 1
    historyBadge.Font = Enum.Font.GothamBold
    historyBadge.TextXAlignment = Enum.TextXAlignment.Right
    historyBadge.Parent = tabHistory
    
    -- ============================================
    -- Content Container
    -- ============================================
    local contentContainer = Instance.new("Frame")
    contentContainer.Size = UDim2.new(1, -12, 1, -80)
    contentContainer.Position = UDim2.new(0, 6, 0, 72)
    contentContainer.BackgroundTransparency = 1
    contentContainer.Parent = mainFrame
    
    -- ============================================
    -- 🔥 Mail Tab Content
    -- ============================================
    local mailContainer = Instance.new("Frame")
    mailContainer.Size = UDim2.new(1, 0, 1, 0)
    mailContainer.BackgroundTransparency = 1
    mailContainer.Parent = contentContainer
    
    -- Left Panel
    local leftPanel = Instance.new("Frame")
    leftPanel.Size = UDim2.new(0, 120, 1, 0)
    leftPanel.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
    leftPanel.BackgroundTransparency = 0.4
    leftPanel.BorderSizePixel = 0
    leftPanel.Parent = mailContainer
    
    local leftCorner = Instance.new("UICorner")
    leftCorner.CornerRadius = UDim.new(0, 6)
    leftCorner.Parent = leftPanel
    
    local leftHeader = Instance.new("Frame")
    leftHeader.Size = UDim2.new(1, 0, 0, 24)
    leftHeader.BackgroundColor3 = Color3.fromRGB(20, 55, 28)
    leftHeader.BackgroundTransparency = 0.2
    leftHeader.BorderSizePixel = 0
    leftHeader.Parent = leftPanel
    
    local leftHeaderCorner = Instance.new("UICorner")
    leftHeaderCorner.CornerRadius = UDim.new(0, 6)
    leftHeaderCorner.Parent = leftHeader
    
    local leftTitle = Instance.new("TextLabel")
    leftTitle.Size = UDim2.new(1, 0, 1, 0)
    leftTitle.Text = "📂 หมวดหมู่"
    leftTitle.TextColor3 = Color3.fromRGB(150, 255, 150)
    leftTitle.TextSize = 10
    leftTitle.BackgroundTransparency = 1
    leftTitle.Font = Enum.Font.GothamBold
    leftTitle.Parent = leftHeader
    
    categoryList = Instance.new("ScrollingFrame")
    categoryList.Size = UDim2.new(1, -4, 1, -30)
    categoryList.Position = UDim2.new(0, 2, 0, 28)
    categoryList.BackgroundTransparency = 1
    categoryList.CanvasSize = UDim2.new(0, 0, 0, 0)
    categoryList.ScrollBarThickness = 6
    categoryList.ScrollBarImageColor3 = Color3.fromRGB(60, 255, 80)
    categoryList.ScrollBarImageTransparency = 0.2
    categoryList.Parent = leftPanel
    
    local catListLayout = Instance.new("UIListLayout")
    catListLayout.Padding = UDim.new(0, 2)
    catListLayout.Parent = categoryList
    
    -- Right Panel
    local rightPanel = Instance.new("Frame")
    rightPanel.Size = UDim2.new(1, -132, 1, 0)
    rightPanel.Position = UDim2.new(0, 126, 0, 0)
    rightPanel.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
    rightPanel.BackgroundTransparency = 0.4
    rightPanel.BorderSizePixel = 0
    rightPanel.Parent = mailContainer
    
    local rightCorner = Instance.new("UICorner")
    rightCorner.CornerRadius = UDim.new(0, 6)
    rightCorner.Parent = rightPanel
    
    -- Recipient Section
    local recipientFrame = Instance.new("Frame")
    recipientFrame.Size = UDim2.new(1, -6, 0, 48)
    recipientFrame.Position = UDim2.new(0, 3, 0, 3)
    recipientFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    recipientFrame.BackgroundTransparency = 0.3
    recipientFrame.BorderSizePixel = 0
    recipientFrame.Parent = rightPanel
    
    local recCorner = Instance.new("UICorner")
    recCorner.CornerRadius = UDim.new(0, 5)
    recCorner.Parent = recipientFrame
    
    local recLabel = Instance.new("TextLabel")
    recLabel.Size = UDim2.new(0, 55, 0, 14)
    recLabel.Position = UDim2.new(0, 5, 0, 1)
    recLabel.Text = "👤 ผู้รับ"
    recLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    recLabel.TextSize = 10
    recLabel.BackgroundTransparency = 1
    recLabel.Font = Enum.Font.GothamBold
    recLabel.Parent = recipientFrame
    
    searchBox = Instance.new("TextBox")
    searchBox.Size = UDim2.new(1, -8, 0, 20)
    searchBox.Position = UDim2.new(0, 4, 0, 17)
    searchBox.Text = ""
    searchBox.PlaceholderText = "🔍 ค้นหาผู้เล่น..."
    searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    searchBox.PlaceholderColor3 = Color3.fromRGB(150, 200, 160)
    searchBox.TextSize = 10
    searchBox.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    searchBox.BackgroundTransparency = 0.3
    searchBox.BorderSizePixel = 0
    searchBox.ClearTextOnFocus = true
    searchBox.Font = Enum.Font.Gotham
    searchBox.Parent = recipientFrame
    
    local searchCorner = Instance.new("UICorner")
    searchCorner.CornerRadius = UDim.new(0, 4)
    searchCorner.Parent = searchBox
    
    -- Selected Player
    selectedDisplay = Instance.new("Frame")
    selectedDisplay.Size = UDim2.new(1, -6, 0, 26)
    selectedDisplay.Position = UDim2.new(0, 3, 0, 40)
    selectedDisplay.BackgroundColor3 = Color3.fromRGB(18, 55, 28)
    selectedDisplay.BackgroundTransparency = 0.2
    selectedDisplay.BorderSizePixel = 0
    selectedDisplay.Visible = false
    selectedDisplay.Parent = recipientFrame
    
    local selectedCorner = Instance.new("UICorner")
    selectedCorner.CornerRadius = UDim.new(0, 5)
    selectedCorner.Parent = selectedDisplay
    
    avatarImage = Instance.new("ImageLabel")
    avatarImage.Size = UDim2.new(0, 18, 0, 18)
    avatarImage.Position = UDim2.new(0, 4, 0, 4)
    avatarImage.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    avatarImage.BackgroundTransparency = 0.5
    avatarImage.BorderSizePixel = 0
    avatarImage.Parent = selectedDisplay
    
    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 9)
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
    selectedDisplayName.Position = UDim2.new(0, 28, 0, 14)
    selectedDisplayName.Text = ""
    selectedDisplayName.TextColor3 = Color3.fromRGB(150, 220, 170)
    selectedDisplayName.TextSize = 8
    selectedDisplayName.TextXAlignment = Enum.TextXAlignment.Left
    selectedDisplayName.BackgroundTransparency = 1
    selectedDisplayName.Font = Enum.Font.Gotham
    selectedDisplayName.Parent = selectedDisplay

    globalBadge = Instance.new("TextLabel")
    globalBadge.Size = UDim2.new(0, 40, 0, 12)
    globalBadge.Position = UDim2.new(1, -60, 0, 7)
    globalBadge.Text = "🌐 GLOBAL"
    globalBadge.TextColor3 = Color3.fromRGB(255, 220, 120)
    globalBadge.TextSize = 7
    globalBadge.BackgroundColor3 = Color3.fromRGB(60, 45, 10)
    globalBadge.BackgroundTransparency = 0.3
    globalBadge.BorderSizePixel = 0
    globalBadge.Font = Enum.Font.GothamBold
    globalBadge.Visible = false
    globalBadge.Parent = selectedDisplay

    local globalBadgeCorner = Instance.new("UICorner")
    globalBadgeCorner.CornerRadius = UDim.new(0, 3)
    globalBadgeCorner.Parent = globalBadge
    
    clearBtn = Instance.new("TextButton")
    clearBtn.Size = UDim2.new(0, 18, 0, 18)
    clearBtn.Position = UDim2.new(1, -22, 0, 4)
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
    resultsContainer.Size = UDim2.new(1, -6, 0, 0)
    resultsContainer.Position = UDim2.new(0, 3, 0, 40)
    resultsContainer.BackgroundTransparency = 1
    resultsContainer.ClipsDescendants = true
    resultsContainer.Parent = recipientFrame
    
    local resultsLayout = Instance.new("UIListLayout")
    resultsLayout.Padding = UDim.new(0, 2)
    resultsLayout.Parent = resultsContainer
    
    -- Controls
    local controlsFrame = Instance.new("Frame")
    controlsFrame.Size = UDim2.new(1, -6, 0, 26)
    controlsFrame.Position = UDim2.new(0, 3, 0, 70)
    controlsFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    controlsFrame.BackgroundTransparency = 0.3
    controlsFrame.BorderSizePixel = 0
    controlsFrame.Parent = rightPanel
    
    local controlsCorner = Instance.new("UICorner")
    controlsCorner.CornerRadius = UDim.new(0, 5)
    controlsCorner.Parent = controlsFrame
    
    local qtyLabel = Instance.new("TextLabel")
    qtyLabel.Size = UDim2.new(0, 20, 1, 0)
    qtyLabel.Position = UDim2.new(0, 4, 0, 0)
    qtyLabel.Text = "×"
    qtyLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    qtyLabel.TextSize = 12
    qtyLabel.BackgroundTransparency = 1
    qtyLabel.Font = Enum.Font.GothamBold
    qtyLabel.Parent = controlsFrame
    
    amountBox = Instance.new("TextBox")
    amountBox.Size = UDim2.new(0, 30, 0, 18)
    amountBox.Position = UDim2.new(0, 22, 0, 4)
    amountBox.Text = "1"
    amountBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    amountBox.TextSize = 10
    amountBox.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    amountBox.BackgroundTransparency = 0.3
    amountBox.BorderSizePixel = 0
    amountBox.Font = Enum.Font.Gotham
    amountBox.Parent = controlsFrame
    
    local amountCorner = Instance.new("UICorner")
    amountCorner.CornerRadius = UDim.new(0, 4)
    amountCorner.Parent = amountBox
    
    local quickAmounts = {"1", "5", "10", "100"}
    for i, val in ipairs(quickAmounts) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, val == "100" and 24 or 20, 0, 18)
        btn.Position = UDim2.new(0, 56 + (i-1) * (val == "100" and 28 or 24), 0, 4)
        btn.Text = val
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = val == "100" and 8 or 9
        btn.BackgroundColor3 = val == "100" and Color3.fromRGB(40, 160, 60) or Color3.fromRGB(18, 52, 28)
        btn.BackgroundTransparency = 0.3
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.Parent = controlsFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 3)
        btnCorner.Parent = btn
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
        end)
        
        btn.MouseButton1Click:Connect(function()
            amountBox.Text = val
        end)
        btn.TouchTap:Connect(function()
            amountBox.Text = val
        end)
    end
    
    noteBox = Instance.new("TextBox")
    noteBox.Size = UDim2.new(0, 80, 0, 18)
    noteBox.Position = UDim2.new(1, -86, 0, 4)
    noteBox.Text = ""
    noteBox.PlaceholderText = "✏️ ข้อความ..."
    noteBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    noteBox.PlaceholderColor3 = Color3.fromRGB(150, 200, 160)
    noteBox.TextSize = 9
    noteBox.BackgroundColor3 = Color3.fromRGB(15, 45, 22)
    noteBox.BackgroundTransparency = 0.3
    noteBox.BorderSizePixel = 0
    noteBox.Font = Enum.Font.Gotham
    noteBox.Parent = controlsFrame
    
    local noteCorner = Instance.new("UICorner")
    noteCorner.CornerRadius = UDim.new(0, 4)
    noteCorner.Parent = noteBox
    
    -- Price Display
    priceDisplayFrame = Instance.new("Frame")
    priceDisplayFrame.Size = UDim2.new(1, -6, 0, 48)
    priceDisplayFrame.Position = UDim2.new(0, 3, 0, 85)
    priceDisplayFrame.BackgroundColor3 = Color3.fromRGB(20, 55, 30)
    priceDisplayFrame.BackgroundTransparency = 0.2
    priceDisplayFrame.BorderSizePixel = 0
    priceDisplayFrame.Visible = false
    priceDisplayFrame.Parent = rightPanel
    
    local priceCorner = Instance.new("UICorner")
    priceCorner.CornerRadius = UDim.new(0, 5)
    priceCorner.Parent = priceDisplayFrame
    
    fruitNameLabel = Instance.new("TextLabel")
    fruitNameLabel.Size = UDim2.new(0, 100, 0, 18)
    fruitNameLabel.Position = UDim2.new(0, 6, 0, 1)
    fruitNameLabel.Text = "🍎 Carrot"
    fruitNameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
    fruitNameLabel.TextSize = 13
    fruitNameLabel.BackgroundTransparency = 1
    fruitNameLabel.Font = Enum.Font.GothamBold
    fruitNameLabel.TextXAlignment = Enum.TextXAlignment.Left
    fruitNameLabel.Parent = priceDisplayFrame
    
    pricePerUnitLabel = Instance.new("TextLabel")
    pricePerUnitLabel.Size = UDim2.new(0, 85, 0, 14)
    pricePerUnitLabel.Position = UDim2.new(0, 6, 0, 20)
    pricePerUnitLabel.Text = "💰 100 / ชิ้น"
    pricePerUnitLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
    pricePerUnitLabel.TextSize = 10
    pricePerUnitLabel.BackgroundTransparency = 1
    pricePerUnitLabel.Font = Enum.Font.Gotham
    pricePerUnitLabel.TextXAlignment = Enum.TextXAlignment.Left
    pricePerUnitLabel.Parent = priceDisplayFrame
    
    countLabel = Instance.new("TextLabel")
    countLabel.Size = UDim2.new(0, 60, 0, 14)
    countLabel.Position = UDim2.new(0, 95, 0, 20)
    countLabel.Text = "📦 x100"
    countLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    countLabel.TextSize = 10
    countLabel.BackgroundTransparency = 1
    countLabel.Font = Enum.Font.Gotham
    countLabel.TextXAlignment = Enum.TextXAlignment.Left
    countLabel.Parent = priceDisplayFrame
    
    totalPriceLabel = Instance.new("TextLabel")
    totalPriceLabel.Size = UDim2.new(1, -100, 0, 18)
    totalPriceLabel.Position = UDim2.new(0, 160, 0, 1)
    totalPriceLabel.Text = "💎 รวม: 10,000"
    totalPriceLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    totalPriceLabel.TextSize = 13
    totalPriceLabel.BackgroundTransparency = 1
    totalPriceLabel.Font = Enum.Font.GothamBold
    totalPriceLabel.TextXAlignment = Enum.TextXAlignment.Right
    totalPriceLabel.Parent = priceDisplayFrame
    
    sizeLabel = Instance.new("TextLabel")
    sizeLabel.Size = UDim2.new(1, -8, 0, 12)
    sizeLabel.Position = UDim2.new(0, 6, 0, 35)
    sizeLabel.Text = "1x=100 | 5x=500 | 10x=1,000"
    sizeLabel.TextColor3 = Color3.fromRGB(150, 200, 200)
    sizeLabel.TextSize = 8
    sizeLabel.BackgroundTransparency = 1
    sizeLabel.Font = Enum.Font.Gotham
    sizeLabel.TextXAlignment = Enum.TextXAlignment.Left
    sizeLabel.Parent = priceDisplayFrame
    
    -- Item Search
    local itemSearchFrame = Instance.new("Frame")
    itemSearchFrame.Size = UDim2.new(1, -6, 0, 22)
    itemSearchFrame.Position = UDim2.new(0, 3, 0, 137)
    itemSearchFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    itemSearchFrame.BackgroundTransparency = 0.3
    itemSearchFrame.BorderSizePixel = 0
    itemSearchFrame.Parent = rightPanel
    
    local itemSearchCorner = Instance.new("UICorner")
    itemSearchCorner.CornerRadius = UDim.new(0, 5)
    itemSearchCorner.Parent = itemSearchFrame
    
    local itemSearchLabel = Instance.new("TextLabel")
    itemSearchLabel.Size = UDim2.new(0, 20, 1, 0)
    itemSearchLabel.Position = UDim2.new(0, 4, 0, 0)
    itemSearchLabel.Text = "🔍"
    itemSearchLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    itemSearchLabel.TextSize = 11
    itemSearchLabel.BackgroundTransparency = 1
    itemSearchLabel.Font = Enum.Font.Gotham
    itemSearchLabel.Parent = itemSearchFrame
    
    itemSearchBox = Instance.new("TextBox")
    itemSearchBox.Size = UDim2.new(1, -30, 1, -2)
    itemSearchBox.Position = UDim2.new(0, 26, 0, 1)
    itemSearchBox.Text = ""
    itemSearchBox.PlaceholderText = "🔍 ค้นหาไอเท็ม..."
    itemSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    itemSearchBox.PlaceholderColor3 = Color3.fromRGB(150, 200, 160)
    itemSearchBox.TextSize = 9
    itemSearchBox.BackgroundTransparency = 1
    itemSearchBox.BorderSizePixel = 0
    itemSearchBox.ClearTextOnFocus = true
    itemSearchBox.Font = Enum.Font.Gotham
    itemSearchBox.Parent = itemSearchFrame
    
    clearSearchBtn = Instance.new("TextButton")
    clearSearchBtn.Size = UDim2.new(0, 18, 0, 16)
    clearSearchBtn.Position = UDim2.new(1, -20, 0, 3)
    clearSearchBtn.Text = "✕"
    clearSearchBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearSearchBtn.TextSize = 8
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
    
    -- Stats & Actions
    local statsFrame = Instance.new("Frame")
    statsFrame.Size = UDim2.new(1, -6, 0, 26)
    statsFrame.Position = UDim2.new(0, 3, 0, 163)
    statsFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    statsFrame.BackgroundTransparency = 0.3
    statsFrame.BorderSizePixel = 0
    statsFrame.Parent = rightPanel
    
    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 5)
    statsCorner.Parent = statsFrame
    
    totalLabel = Instance.new("TextLabel")
    totalLabel.Size = UDim2.new(0, 40, 1, 0)
    totalLabel.Position = UDim2.new(0, 4, 0, 0)
    totalLabel.Text = "📊 0"
    totalLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    totalLabel.TextSize = 9
    totalLabel.TextXAlignment = Enum.TextXAlignment.Left
    totalLabel.BackgroundTransparency = 1
    totalLabel.Font = Enum.Font.GothamBold
    totalLabel.Parent = statsFrame
    
    selectedLabel = Instance.new("TextLabel")
    selectedLabel.Size = UDim2.new(0, 35, 1, 0)
    selectedLabel.Position = UDim2.new(0, 48, 0, 0)
    selectedLabel.Text = "✅ 0"
    selectedLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    selectedLabel.TextSize = 9
    selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
    selectedLabel.BackgroundTransparency = 1
    selectedLabel.Font = Enum.Font.GothamBold
    selectedLabel.Parent = statsFrame
    
    batchInfoLabel = Instance.new("TextLabel")
    batchInfoLabel.Size = UDim2.new(0, 45, 1, 0)
    batchInfoLabel.Position = UDim2.new(0, 87, 0, 0)
    batchInfoLabel.Text = ""
    batchInfoLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    batchInfoLabel.TextSize = 8
    batchInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
    batchInfoLabel.BackgroundTransparency = 1
    batchInfoLabel.Font = Enum.Font.Gotham
    batchInfoLabel.Parent = statsFrame
    
    autoClaimBtn = Instance.new("TextButton")
    autoClaimBtn.Size = UDim2.new(0, 50, 0, 16)
    autoClaimBtn.Position = UDim2.new(1, -130, 0, 5)
    autoClaimBtn.Text = "▶️ OFF"
    autoClaimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoClaimBtn.TextSize = 8
    autoClaimBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
    autoClaimBtn.BackgroundTransparency = 0.3
    autoClaimBtn.BorderSizePixel = 0
    autoClaimBtn.Font = Enum.Font.GothamBold
    autoClaimBtn.Parent = statsFrame
    
    local autoClaimCorner = Instance.new("UICorner")
    autoClaimCorner.CornerRadius = UDim.new(0, 3)
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
        btn.Size = UDim2.new(0, 30, 0, 16)
        btn.Position = UDim2.new(1, -(8 + (3-i) * 34), 0, 5)
        btn.Text = text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.TextSize = 7
        btn.BackgroundColor3 = actionColors[i]
        btn.BackgroundTransparency = 0.3
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamBold
        btn.Parent = statsFrame
        
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 3)
        btnCorner.Parent = btn
        
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.2), {BackgroundTransparency = 0.3}):Play()
        end)
        
        if i == 1 then
            btn.MouseButton1Click:Connect(function()
                SelectedItems = {}
                for _, item in ipairs(InventoryItems) do
                    table.insert(SelectedItems, item)
                end
                if selectedLabel then
                    selectedLabel.Text = "✅ " .. #SelectedItems
                end
                UpdateBatchInfo()
                BuildCategoryList()
            end)
            btn.TouchTap:Connect(function() btn.MouseButton1Click:Fire() end)
        elseif i == 2 then
            btn.MouseButton1Click:Connect(function()
                SelectedItems = {}
                if selectedLabel then
                    selectedLabel.Text = "✅ 0"
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
    itemList.Size = UDim2.new(1, -6, 1, -200)
    itemList.Position = UDim2.new(0, 3, 0, 193)
    itemList.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
    itemList.BackgroundTransparency = 0.4
    itemList.BorderSizePixel = 0
    itemList.CanvasSize = UDim2.new(0, 0, 0, 0)
    itemList.ScrollBarThickness = 6
    itemList.ScrollBarImageColor3 = Color3.fromRGB(60, 255, 80)
    itemList.ScrollBarImageTransparency = 0.2
    itemList.Parent = rightPanel
    
    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 5)
    listCorner.Parent = itemList
    
    local itemLayout = Instance.new("UIListLayout")
    itemLayout.Padding = UDim.new(0, 2)
    itemLayout.Parent = itemList
    
    -- Bottom
    local bottomFrame = Instance.new("Frame")
    bottomFrame.Size = UDim2.new(1, -6, 0, 36)
    bottomFrame.Position = UDim2.new(0, 3, 1, -40)
    bottomFrame.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    bottomFrame.BackgroundTransparency = 0.3
    bottomFrame.BorderSizePixel = 0
    bottomFrame.Parent = rightPanel
    
    local bottomCorner = Instance.new("UICorner")
    bottomCorner.CornerRadius = UDim.new(0, 5)
    bottomCorner.Parent = bottomFrame
    
    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(0, 120, 1, 0)
    statusLabel.Position = UDim2.new(0, 6, 0, 0)
    statusLabel.Text = "✅ พร้อมใช้งาน"
    statusLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
    statusLabel.TextSize = 9
    statusLabel.BackgroundTransparency = 1
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = bottomFrame
    
    claimSingleBtn = Instance.new("TextButton")
    claimSingleBtn.Size = UDim2.new(0, 30, 0, 22)
    claimSingleBtn.Position = UDim2.new(1, -270, 0, 7)
    claimSingleBtn.Text = "📬 1"
    claimSingleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimSingleBtn.TextSize = 9
    claimSingleBtn.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
    claimSingleBtn.BackgroundTransparency = 0.2
    claimSingleBtn.BorderSizePixel = 0
    claimSingleBtn.Font = Enum.Font.GothamBold
    claimSingleBtn.Parent = bottomFrame
    
    local claimSingleCorner = Instance.new("UICorner")
    claimSingleCorner.CornerRadius = UDim.new(0, 4)
    claimSingleCorner.Parent = claimSingleBtn
    
    claimSingleBtn.MouseEnter:Connect(function()
        TweenService:Create(claimSingleBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.05}):Play()
    end)
    claimSingleBtn.MouseLeave:Connect(function()
        TweenService:Create(claimSingleBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
    end)
    
    claimSingleBtn.MouseButton1Click:Connect(function()
        ClaimSingleMail()
    end)
    claimSingleBtn.TouchTap:Connect(function()
        claimSingleBtn.MouseButton1Click:Fire()
    end)
    
    claimAllBtn = Instance.new("TextButton")
    claimAllBtn.Size = UDim2.new(0, 50, 0, 22)
    claimAllBtn.Position = UDim2.new(1, -215, 0, 7)
    claimAllBtn.Text = "📬 รับทั้งหมด"
    claimAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    claimAllBtn.TextSize = 9
    claimAllBtn.BackgroundColor3 = Color3.fromRGB(255, 170, 50)
    claimAllBtn.BackgroundTransparency = 0.2
    claimAllBtn.BorderSizePixel = 0
    claimAllBtn.Font = Enum.Font.GothamBold
    claimAllBtn.Parent = bottomFrame
    
    local claimAllCorner = Instance.new("UICorner")
    claimAllCorner.CornerRadius = UDim.new(0, 4)
    claimAllCorner.Parent = claimAllBtn
    
    claimAllBtn.MouseEnter:Connect(function()
        TweenService:Create(claimAllBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.05}):Play()
    end)
    claimAllBtn.MouseLeave:Connect(function()
        TweenService:Create(claimAllBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.2}):Play()
    end)
    
    claimAllBtn.MouseButton1Click:Connect(function()
        ClaimAllMail()
    end)
    claimAllBtn.TouchTap:Connect(function()
        claimAllBtn.MouseButton1Click:Fire()
    end)
    
    sendBtn = Instance.new("TextButton")
    sendBtn.Size = UDim2.new(0, 90, 0, 26)
    sendBtn.Position = UDim2.new(1, -98, 0, 5)
    sendBtn.Text = "🚀 ส่ง"
    sendBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    sendBtn.TextSize = 12
    sendBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 70)
    sendBtn.BackgroundTransparency = 0.1
    sendBtn.BorderSizePixel = 0
    sendBtn.Font = Enum.Font.GothamBold
    sendBtn.Parent = bottomFrame
    
    local sendCorner = Instance.new("UICorner")
    sendCorner.CornerRadius = UDim.new(0, 4)
    sendCorner.Parent = sendBtn
    
    local sendGradient = Instance.new("UIGradient")
    sendGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 200, 80)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 160, 60))
    })
    sendGradient.Rotation = 90
    sendGradient.Parent = sendBtn
    
    sendBtn.MouseEnter:Connect(function()
        TweenService:Create(sendBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.02}):Play()
    end)
    sendBtn.MouseLeave:Connect(function()
        TweenService:Create(sendBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.1}):Play()
    end)
    
    sendBtn.MouseButton1Click:Connect(SendAllSelected)
    sendBtn.TouchTap:Connect(function() sendBtn.MouseButton1Click:Fire() end)
    
    -- ============================================
    -- 🔥 History Tab Content
    -- ============================================
    historyContainer = Instance.new("Frame")
    historyContainer.Size = UDim2.new(1, 0, 1, 0)
    historyContainer.BackgroundTransparency = 1
    historyContainer.Visible = false
    historyContainer.Parent = contentContainer
    
    local historyHeader = Instance.new("Frame")
    historyHeader.Size = UDim2.new(1, 0, 0, 30)
    historyHeader.BackgroundColor3 = Color3.fromRGB(12, 38, 20)
    historyHeader.BackgroundTransparency = 0.3
    historyHeader.BorderSizePixel = 0
    historyHeader.Parent = historyContainer
    
    local historyHeaderCorner = Instance.new("UICorner")
    historyHeaderCorner.CornerRadius = UDim.new(0, 6)
    historyHeaderCorner.Parent = historyHeader
    
    local historyTitle = Instance.new("TextLabel")
    historyTitle.Size = UDim2.new(1, -80, 1, 0)
    historyTitle.Position = UDim2.new(0, 10, 0, 0)
    historyTitle.Text = "📜 ประวัติการส่ง"
    historyTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
    historyTitle.TextSize = 13
    historyTitle.TextXAlignment = Enum.TextXAlignment.Left
    historyTitle.BackgroundTransparency = 1
    historyTitle.Font = Enum.Font.GothamBold
    historyTitle.Parent = historyHeader
    
    local clearHistoryBtn = Instance.new("TextButton")
    clearHistoryBtn.Size = UDim2.new(0, 60, 0, 20)
    clearHistoryBtn.Position = UDim2.new(1, -70, 0, 5)
    clearHistoryBtn.Text = "🗑️ ล้าง"
    clearHistoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    clearHistoryBtn.TextSize = 9
    clearHistoryBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
    clearHistoryBtn.BackgroundTransparency = 0.3
    clearHistoryBtn.BorderSizePixel = 0
    clearHistoryBtn.Font = Enum.Font.GothamBold
    clearHistoryBtn.Parent = historyHeader
    
    local clearHistoryCorner = Instance.new("UICorner")
    clearHistoryCorner.CornerRadius = UDim.new(0, 4)
    clearHistoryCorner.Parent = clearHistoryBtn
    
    clearHistoryBtn.MouseButton1Click:Connect(function()
        sendHistory = {}
        UpdateHistoryUI()
        UpdateHistoryBadge()
        UpdateStatus("🗑️ ล้างประวัติแล้ว", Color3.fromRGB(200, 200, 200))
    end)
    clearHistoryBtn.TouchTap:Connect(function()
        clearHistoryBtn.MouseButton1Click:Fire()
    end)
    
    historyList = Instance.new("ScrollingFrame")
    historyList.Size = UDim2.new(1, -4, 1, -40)
    historyList.Position = UDim2.new(0, 2, 0, 35)
    historyList.BackgroundColor3 = Color3.fromRGB(10, 30, 16)
    historyList.BackgroundTransparency = 0.4
    historyList.BorderSizePixel = 0
    historyList.CanvasSize = UDim2.new(0, 0, 0, 0)
    historyList.ScrollBarThickness = 6
    historyList.ScrollBarImageColor3 = Color3.fromRGB(60, 255, 80)
    historyList.ScrollBarImageTransparency = 0.2
    historyList.Parent = historyContainer
    
    local historyListCorner = Instance.new("UICorner")
    historyListCorner.CornerRadius = UDim.new(0, 6)
    historyListCorner.Parent = historyList
    
    local historyLayout = Instance.new("UIListLayout")
    historyLayout.Padding = UDim.new(0, 4)
    historyLayout.Parent = historyList
    
    -- ============================================
    -- 🔥 Tab Switching
    -- ============================================
    tabMail.MouseButton1Click:Connect(function() SwitchTab("mail") end)
    tabMail.TouchTap:Connect(function() SwitchTab("mail") end)
    tabHistory.MouseButton1Click:Connect(function() SwitchTab("history") end)
    tabHistory.TouchTap:Connect(function() SwitchTab("history") end)
    
    -- ============================================
    -- 🔥 Search Events
    -- ============================================
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
    
    -- ============================================
    -- 🔥 เริ่มต้น
    -- ============================================
    
    UpdateStatus("🔄 โหลด...", Color3.fromRGB(255, 200, 100))
    task.wait(0.3)
    BuildCategoryList()
    UpdateMailCount()
    UpdateHistoryBadge()
    UpdateStatus("✅ พร้อมใช้งาน!", Color3.fromRGB(150, 255, 150))
    
    -- Auto refresh ทุก 30 วินาที
    task.spawn(function()
        while screenGui and screenGui.Parent do
            task.wait(30)
            UpdateMailCount()
        end
    end)
end

-- ============================================
-- 🔥 รัน GUI
-- ============================================
task.wait(1)
CreateGUI()
