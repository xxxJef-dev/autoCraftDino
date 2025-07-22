local WEBHOOK_URL = getgenv().DinoWebhook or nil
local EggType = getgenv().EggType or "Dinosaur Egg"

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local Backpack = LocalPlayer:WaitForChild("Backpack")
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local CraftingService = ReplicatedStorage.GameEvents.CraftingGlobalObjectService

local lastWebhook = 0
local WEBHOOK_DELAY = 1

local function notify(t, tx, d)
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = t, Text = tx, Duration = d or 1.5 })
    end)
end

local function parseNumFromName(name)
    local m = name:match("[xX]%s*(%d+)")
    if m then return tonumber(m) end
    local m2 = name:match("(%d+)%s*$")
    if m2 then return tonumber(m2) end
    return nil
end

local function getStack(tool)
    local a = tool:GetAttribute("Stack") or tool:GetAttribute("Count") or tool:GetAttribute("Quantity") or tool:GetAttribute("Amount")
    if typeof(a) == "number" and a > 0 then return a end
    return parseNumFromName(tostring(tool.Name)) or 1
end

local function totalEggs()
    local total = 0
    for _, inst in ipairs(Character:GetChildren()) do
        if inst:IsA("Tool") and inst.Name:lower():find(EggType:lower()) then
            total += getStack(inst)
        end
    end
    for _, inst in ipairs(Backpack:GetChildren()) do
        if inst:IsA("Tool") and inst.Name:lower():find(EggType:lower()) then
            total += getStack(inst)
        end
    end
    return total
end

local function sendWebhook(qty)
    if not WEBHOOK_URL then return end
    local now = tick()
    local waitLeft = WEBHOOK_DELAY - (now - lastWebhook)
    if waitLeft > 0 then task.wait(waitLeft) end
    lastWebhook = tick()
    local data = {
        embeds = {
            {
                title = "🎉 Egg Crafted",
                color = 65280,
                fields = {
                    { name = "Egg", value = EggType, inline = false },
                    { name = "Quantity", value = tostring(qty or 0), inline = false }
                },
                footer = { text = "Made with ❤️ by Nagi | " .. os.date("!%X UTC") }
            }
        }
    }
    local body = HttpService:JSONEncode(data)
    pcall(function()
        if syn and syn.request then
            syn.request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif http_request then
            http_request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        elseif request then
            request({ Url = WEBHOOK_URL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = body })
        else
            HttpService:PostAsync(WEBHOOK_URL, body, Enum.HttpContentType.ApplicationJson)
        end
    end)
end

local function findTool(attr, val)
    for _, inst in ipairs(Character:GetChildren()) do
        if inst:IsA("Tool") and inst:GetAttribute(attr) == val then return inst end
    end
    for _, inst in ipairs(Backpack:GetChildren()) do
        if inst:IsA("Tool") and inst:GetAttribute(attr) == val then return inst end
    end
end

local function unequipAll()
    for _, t in ipairs(Character:GetChildren()) do
        if t:IsA("Tool") then t.Parent = Backpack end
    end
end

task.spawn(function()
    local DinoEvent = workspace:FindFirstChild("DinoEvent") or ReplicatedStorage.Modules:WaitForChild("UpdateService"):WaitForChild("DinoEvent")
    if DinoEvent and DinoEvent:IsDescendantOf(ReplicatedStorage) then DinoEvent.Parent = workspace end
    local DinoTable = workspace:WaitForChild("DinoEvent"):WaitForChild("DinoCraftingTable")

    local firstIngredient = EggType == "Primal Egg" and findTool("h", "Dinosaur Egg") or findTool("h", "Common Egg")
    local blossomTool = findTool("f", "Bone Blossom")
    if not firstIngredient or not blossomTool then
        notify("Stop", "No materials.")
        return
    end

    notify("Crafting", "Auto Start")
    local pre = totalEggs()

    CraftingService:FireServer("SetRecipe", DinoTable, "DinoEventWorkbench", EggType)
    task.wait(0.08)

    unequipAll()
    firstIngredient.Parent = Character
    task.wait(0.08)
    local u1 = firstIngredient:GetAttribute("c")
    if u1 then
        CraftingService:FireServer("InputItem", DinoTable, "DinoEventWorkbench", 1, {
            ItemType = "PetEgg",
            ItemData = { UUID = u1 }
        })
    end
    firstIngredient.Parent = Backpack

    unequipAll()
    blossomTool.Parent = Character
    task.wait(0.08)
    local u2 = blossomTool:GetAttribute("c")
    if u2 then
        CraftingService:FireServer("InputItem", DinoTable, "DinoEventWorkbench", 2, {
            ItemType = "Holdable",
            ItemData = { UUID = u2 }
        })
    end
    blossomTool.Parent = Backpack

    task.wait(0.12)
    CraftingService:FireServer("Craft", DinoTable, "DinoEventWorkbench")

    local start = tick()
    local new = totalEggs()
    while new == pre and tick() < start + 0.3 do
        task.wait(0.05)
        new = totalEggs()
    end

    -- notify in parallel so teleport doesn't wait
    task.spawn(function()
        notify("Done", "Egg: " .. new)
    end)

    sendWebhook(new)
    TeleportService:Teleport(game.PlaceId, Players.LocalPlayer)
end)
