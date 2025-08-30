-- Generation Scanner & Server Hopper Script
-- Auto-loads on server hop and scans for high-generation animals

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

-- Configuration
local PLACE_ID = 109983668079237
local MIN_GENERATION_THRESHOLD = 10000000 -- 10M/s minimum threshold

-- Global variables
local player = Players.LocalPlayer
local isScanning = false
local allFoundAnimals = {} -- Store all high-gen animals found

-- Simple auto-execute setup
local function setupAutoExec()
    -- Queue this script to run again when we teleport
    if queue_on_teleport then
        queue_on_teleport([[
            wait(3)
            
            print("Auto-executed after server hop!")
        ]])
    end
end

-- Utility Functions
local function debugPrint(message)
    print("[DEBUG] " .. tostring(message))
end

local function parseGeneration(generationText)
    if not generationText then return 0 end
    
    -- Clean the text and extract number
    local cleanText = string.gsub(tostring(generationText), "[$,/s ]", "")
    local number = tonumber(string.match(cleanText, "%d+%.?%d*"))
    
    if not number then return 0 end
    
    -- Convert based on suffix
    if string.find(tostring(generationText), "B") or string.find(tostring(generationText), "b") then
        return number * 1000000000
    elseif string.find(tostring(generationText), "M") or string.find(tostring(generationText), "m") then
        return number * 1000000
    elseif string.find(tostring(generationText), "K") or string.find(tostring(generationText), "k") then
        return number * 1000
    else
        return number
    end
end

local function getTextFromObject(obj)
    if not obj then return nil end
    
    -- Try different property names
    local properties = {"Text", "Value", "text", "value"}
    
    for _, prop in pairs(properties) do
        local success, value = pcall(function()
            return obj[prop]
        end)
        if success and value then
            return tostring(value)
        end
    end
    
    -- Try to get string representation
    local success, value = pcall(function()
        return tostring(obj)
    end)
    
    return success and value or nil
end

local function processHighGenAnimal(jobId, generation, displayName, plotName, podiumNumber)
    local parsedGen = parseGeneration(generation)
    
    -- Only process if generation meets threshold
    if parsedGen >= MIN_GENERATION_THRESHOLD then
        local animalInfo = {
            jobId = tostring(jobId),
            generation = tostring(generation),
            displayName = tostring(displayName),
            plotName = tostring(plotName),
            podiumNumber = tostring(podiumNumber),
            timestamp = os.time(),
            parsedValue = parsedGen
        }
        
        -- Save data for tracking
        table.insert(allFoundAnimals, animalInfo)
        
        -- Create API-ready JSON
        local apiData = {
            generation = animalInfo.generation,
            displayName = animalInfo.displayName,
            jobId = animalInfo.jobId,
            plotName = animalInfo.plotName,
            timestamp = animalInfo.timestamp
        }
        
        local jsonString = HttpService:JSONEncode(apiData)
        
        -- Print formatted output
        print("\n" .. string.rep("=", 70))
        print("🔥 HIGH GENERATION FOUND! (≥10M/s)")
        print("📊 Generation: " .. animalInfo.generation)
        print("🏷️ Name: " .. animalInfo.displayName) 
        print("🆔 Job ID: " .. animalInfo.jobId)
        print("📍 Plot: " .. animalInfo.plotName)
        print("🐾 Podium: #" .. animalInfo.podiumNumber)
        print("💰 Parsed Value: $" .. string.format("%.2f", parsedGen/1000000) .. "M/s")
        print("📋 API JSON: " .. jsonString)
        print(string.rep("=", 70))
        
        -- Copy to clipboard
        local clipboardSuccess = pcall(function()
            setclipboard(jsonString)
        end)
        
        if clipboardSuccess then
            print("📎 JSON data copied to clipboard!")
        else
            print("⚠️ Failed to copy to clipboard (setclipboard not available)")
        end
        
        return true
    else
        debugPrint("Generation below threshold (" .. string.format("%.2f", parsedGen/1000000) .. "M/s < 10M/s)")
        return false
    end
end

local function findPlotsInWorkspace()
    local plots = {}
    local workspace = game.Workspace
    local plotsFolder = workspace:FindFirstChild("Plots")
    
    if not plotsFolder then
        debugPrint("ERROR: Plots folder not found in workspace!")
        -- Try alternative locations
        for _, child in pairs(workspace:GetChildren()) do
            if string.lower(child.Name):find("plot") then
                debugPrint("Found potential plots folder: " .. child.Name)
                plotsFolder = child
                break
            end
        end
    end
    
    if not plotsFolder then
        debugPrint("No plots folder found anywhere!")
        return plots
    end
    
    debugPrint("Found Plots folder: " .. plotsFolder.Name)
    
    for _, child in pairs(plotsFolder:GetChildren()) do
        local name = child.Name
        -- Check if name matches UUID pattern OR just add all children
        if string.match(name, "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") or child:IsA("Model") then
            table.insert(plots, child)
            debugPrint("Found plot: " .. name)
        end
    end
    
    debugPrint("Total plots found: " .. #plots)
    return plots
end

local function scanSinglePodium(plot, podiumNumber)
    local success, animalData = pcall(function()
        local plotName = plot.Name
        
        -- Try to find AnimalPodiums folder
        local animalPodiums = plot:FindFirstChild("AnimalPodiums")
        if not animalPodiums then
            -- Try alternative names
            for _, child in pairs(plot:GetChildren()) do
                if string.lower(child.Name):find("podium") or string.lower(child.Name):find("animal") then
                    animalPodiums = child
                    break
                end
            end
        end
        
        if not animalPodiums then
            return nil
        end
        
        local podium = animalPodiums:FindFirstChild(tostring(podiumNumber))
        if not podium then
            return nil
        end
        
        -- Navigate through the object hierarchy
        local pathsToTry = {
            {"Base", "Spawn", "Attachment", "AnimalOverhead"},
            {"Spawn", "Attachment", "AnimalOverhead"},
            {"Attachment", "AnimalOverhead"},
            {"AnimalOverhead"}
        }
        
        local animalOverhead = nil
        
        for _, path in pairs(pathsToTry) do
            local current = podium
            local pathSuccess = true
            
            for _, step in pairs(path) do
                current = current:FindFirstChild(step)
                if not current then
                    pathSuccess = false
                    break
                end
            end
            
            if pathSuccess then
                animalOverhead = current
                break
            end
        end
        
        if not animalOverhead then
            return nil
        end
        
        local generation = animalOverhead:FindFirstChild("Generation")
        local displayName = animalOverhead:FindFirstChild("DisplayName")
        
        if not generation or not displayName then
            return nil
        end
        
        local generationValue = getTextFromObject(generation)
        local displayNameValue = getTextFromObject(displayName)
        
        if not generationValue or not displayNameValue then
            return nil
        end
        
        local parsedGen = parseGeneration(generationValue)
        
        return {
            generation = generationValue,
            displayName = displayNameValue,
            plotName = plotName,
            podiumNumber = podiumNumber,
            parsedValue = parsedGen
        }
    end)
    
    if success and animalData then
        debugPrint("Found animal on plot " .. plot.Name .. " podium " .. podiumNumber .. ": " .. animalData.displayName .. " (" .. animalData.generation .. ")")
        return animalData
    end
    
    return nil
end

local function scanAllPlots()
    if isScanning then 
        debugPrint("Scan already in progress, skipping...")
        return false 
    end
    
    isScanning = true
    debugPrint("Starting comprehensive plot scan...")
    
    local plots = findPlotsInWorkspace()
    if #plots == 0 then
        debugPrint("No plots found to scan!")
        isScanning = false
        return false
    end
    
    local highestGeneration = 0
    local highestAnimalData = nil
    local totalAnimalsFound = 0
    
    -- Scan each plot
    for plotIndex, plot in pairs(plots) do
        debugPrint("Scanning plot " .. plotIndex .. "/" .. #plots .. ": " .. plot.Name)
        
        -- Scan podiums 1-23
        for podiumNumber = 1, 23 do
            local animalData = scanSinglePodium(plot, podiumNumber)
            
            if animalData then
                totalAnimalsFound = totalAnimalsFound + 1
                
                -- Track highest generation
                if animalData.parsedValue > highestGeneration then
                    highestGeneration = animalData.parsedValue
                    highestAnimalData = animalData
                end
                
                -- Process immediately if it meets threshold
                if animalData.parsedValue >= MIN_GENERATION_THRESHOLD then
                    debugPrint("High-gen animal found immediately!")
                    local jobId = game.JobId or "unknown"
                    processHighGenAnimal(
                        jobId,
                        animalData.generation,
                        animalData.displayName,
                        animalData.plotName,
                        animalData.podiumNumber
                    )
                end
            end
            
            task.wait(0.01) -- Small delay to prevent lag
        end
        
        task.wait(0.1) -- Delay between plots
    end
    
    isScanning = false
    
    debugPrint("Scan completed!")
    debugPrint("Total animals found: " .. totalAnimalsFound)
    
    if highestAnimalData then
        debugPrint("Highest generation this scan: " .. highestAnimalData.generation .. " (" .. string.format("%.2f", highestAnimalData.parsedValue/1000000) .. "M/s)")
    else
        debugPrint("No animals found in any plots")
    end
    
    -- Return true if we found any high-gen animals
    return highestGeneration >= MIN_GENERATION_THRESHOLD
end

-- Server hop function
local function serverHop()
    debugPrint("Server hopping...")
    TeleportService:Teleport(PLACE_ID, player)
end

-- Helper functions for manual use
local function printAllFoundAnimals()
    print("\n" .. string.rep("=", 60))
    print("📋 ALL HIGH GENERATION ANIMALS FOUND:")
    print(string.rep("=", 60))
    
    if #allFoundAnimals == 0 then
        print("No high-gen animals found yet.")
        return
    end
    
    for i, animal in pairs(allFoundAnimals) do
        print(string.format("#%d - %s | %s | %s", 
            i, 
            animal.generation, 
            animal.displayName, 
            animal.jobId
        ))
    end
    print(string.rep("=", 60) .. "\n")
end

local function getLastFound()
    if #allFoundAnimals > 0 then
        local last = allFoundAnimals[#allFoundAnimals]
        local data = HttpService:JSONEncode(last)
        
        local clipboardSuccess = pcall(function()
            setclipboard(data)
        end)
        
        if clipboardSuccess then
            print("📎 Last found animal copied to clipboard: " .. last.displayName)
        else
            print("⚠️ Clipboard not available")
            print("Last found: " .. data)
        end
        
        return last
    else
        print("No animals found yet.")
        return nil
    end
end

-- Make functions globally accessible
_G.printAnimals = printAllFoundAnimals
_G.getLastFound = getLastFound
_G.getAllAnimals = function() return allFoundAnimals end
_G.serverHop = serverHop
_G.scanNow = function() 
    task.spawn(function()
        scanAllPlots() 
    end)
end

-- Main execution
local function mainLoop()
    debugPrint("Generation Scanner Started!")
    debugPrint("Threshold: 10M/s or higher")
    
    -- Setup simple auto-exec
    setupAutoExec()
    
    debugPrint("Available commands:")
    debugPrint("   _G.printAnimals() - Show all found animals")
    debugPrint("   _G.getLastFound() - Copy last found to clipboard") 
    debugPrint("   _G.serverHop() - Manually hop servers")
    debugPrint("   _G.scanNow() - Force immediate scan")
    
    -- Do one scan then hop
    task.spawn(function()
        scanAllPlots()
        wait(10) -- Wait 10 seconds then hop regardless
        serverHop()
    end)
end

-- Start the script
mainLoop()
