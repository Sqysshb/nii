-- Sqays Hub – Trials Only (Hard/Medium/Easy) – Safe Header
if _G.TrialHubLoaded then return end
_G.TrialHubLoaded = true

local WS = game:GetService("Workspace")
local RS = game:GetService("ReplicatedStorage")
local TS = game:GetService("TweenService")
local LP = game:GetService("Players").LocalPlayer

-- ===== TRIAL VERİLERİ =====
local Trials = {
    Hard = {
        coord = Vector3.new(907.9375, 11.014291763305664, 13443.76953125),
        room = "HardTrialRoom",
        path = {"__GAME_CONTENT","Trials_HardTrialRoom","__TrialHardRoom","TouchPart","BillboardGui","Timer1"}
    },
    Medium = {
        coord = Vector3.new(879.1256103515625, 11.030077934265137, 13414.4521484375),
        room = "MediumTrialRoom",
        path = {"__GAME_CONTENT","Trials_MediumTrialRoom","__TrialMediumRoom","TouchPart","BillboardGui","Timer1"}
    },
    Easy = {
        coord = Vector3.new(848.3804931640625, 11.014291763305664, 13442.626953125),
        room = "EasyTrialRoom",
        path = {"__GAME_CONTENT","Trials_EasyTrialRoom","__TrialEasyRoom","TouchPart","BillboardGui","Timer1"}
    }
}

-- ===== STATE =====
local Trial = {}
for diff in pairs(Trials) do
    Trial[diff] = {
        autoJoin = false,
        autoLeave = false,
        walk = false,
        wave = 1,
        leaveWave = 5,
        prev = -1,
        captured = nil,
        autoReturn = false,
        teleported = false,
        lastLog = 0,
        listening = false
    }
end

-- ===== TELEPORT (konum kontrolü yok) =====
local function teleport(pos)
    local c = LP.Character; if not c then return false end
    local h = c:FindFirstChild("HumanoidRootPart"); if not h then return false end
    h.CFrame = CFrame.new(pos)
    pcall(function() h.AssemblyLinearVelocity = Vector3.new() end)
    return true
end

-- ===== LABEL VE SAYAÇ =====
local function getLabel(diff)
    local o = WS
    for _, n in ipairs(Trials[diff].path) do if o then o = o:FindFirstChild(n) end end
    return o and o:IsA("TextLabel") and o or nil
end

local function parseTime(text)
    local m = tonumber(text:match("(%d+)m")) or 0
    local s = tonumber(text:match("(%d+)s")) or 0
    return m*60 + s
end

-- ===== MOB BULMA =====
local function findMob(diff)
    local room = WS:FindFirstChild("__GAME_CONTENT") and WS.__GAME_CONTENT:FindFirstChild("Trials") and WS.__GAME_CONTENT.Trials:FindFirstChild(Trials[diff].room)
    if not room then return nil end
    local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    local best, bestD = nil, math.huge
    for _, v in ipairs(room:GetDescendants()) do
        if v:IsA("Humanoid") and v.Health > 0 and v.Parent ~= LP.Character then
            local r = v.Parent:FindFirstChild("HumanoidRootPart") or v.Parent.PrimaryPart
            if r and r:IsA("BasePart") then
                local d = (hrp.Position - r.Position).Magnitude
                if d < bestD then bestD = d; best = r end
            end
        end
    end
    return best
end

-- ===== AUTO JOIN SAYAÇ =====
task.spawn(function()
    while not _G.TrialHubStop do
        for diff, st in pairs(Trial) do
            if st.autoJoin then
                local lbl = getLabel(diff)
                if lbl then
                    if not st.listening then
                        print("[AUTO JOIN "..diff.."] Countdown listening started.")
                        st.listening = true
                    end
                    local sec = parseTime(lbl.Text)
                    if os.time() - st.lastLog >= 60 then
                        if sec > 0 then print("[AUTO JOIN "..diff.."] "..sec.." seconds until trial opens.")
                        else print("[AUTO JOIN "..diff.."] Countdown finished, teleporting...") end
                        st.lastLog = os.time()
                    end
                    if sec == 0 and not st.teleported then
                        if teleport(Trials[diff].coord) then
                            print("[AUTO JOIN "..diff.."] Teleport successful!"); st.teleported = true
                        else print("[AUTO JOIN "..diff.."] Teleport failed!") end
                    end
                    if sec > 0 then st.teleported = false end
                else
                    if os.time() - st.lastLog >= 30 then
                        warn("[AUTO JOIN "..diff.."] Countdown label not found!"); st.lastLog = os.time()
                    end
                end
            else st.listening = false end
        end
        task.wait(5)
    end
end)

-- ===== GRIND + WAVE + AUTO LEAVE =====
for diff, data in pairs(Trials) do
    local st = Trial[diff]
    task.spawn(function()
        while not _G.TrialHubStop do
            if st.walk then
                local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then task.wait(0.3); continue end
                local room = WS:FindFirstChild("__GAME_CONTENT") and WS.__GAME_CONTENT:FindFirstChild("Trials") and WS.__GAME_CONTENT.Trials:FindFirstChild(data.room)
                if not room then task.wait(0.3); continue end
                local target = findMob(diff)
                local alive = 0
                for _, v in ipairs(room:GetDescendants()) do
                    if v:IsA("Humanoid") and v.Health > 0 and v.Parent ~= LP.Character then alive = alive + 1 end
                end
                if target and (hrp.Position - target.Position).Magnitude > 5 then
                    local tw = TS:Create(hrp, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {CFrame = CFrame.new(target.Position)})
                    tw:Play(); tw.Completed:Wait()
                end
                if st.prev > 0 and alive == 0 then
                    st.wave = st.wave + 1
                    print("["..diff.." WAVE] Wave "..st.wave)
                    if st.autoLeave and st.leaveWave > 0 and st.wave >= st.leaveWave then
                        print("[AUTO LEAVE] Leaving "..diff.." trial at wave "..st.wave)
                        pcall(function() RS:WaitForChild("__Net"):WaitForChild("MainRemote"):FireServer("LeaveTrial") end)
                        if st.autoReturn and st.captured then teleport(st.captured) end
                        st.walk = false
                        pcall(function() Rayfield.Flags["trialWalk_"..diff] = false end)
                    end
                end
                st.prev = alive
            end
            task.wait(0.3)
        end
    end)
end

-- ===== RAYFIELD UI =====
local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()
local win = Rayfield:CreateWindow({
    Name = "Sqays Hub – Trials",
    LoadingTitle = "Sqays Hub – Trials",
    ConfigurationSaving = { Enabled = false }
})

local TrialTabs = {}
for _, diff in ipairs({"Hard","Medium","Easy"}) do
    TrialTabs[diff] = win:CreateTab("⚡ "..diff)
end

for _, diff in ipairs({"Hard","Medium","Easy"}) do
    local tab = TrialTabs[diff]
    local st = Trial[diff]

    tab:CreateSection("Auto Join")
    tab:CreateToggle({ Name = "Auto Join (Countdown)", Flag = "autoJoin_"..diff, Callback = function(v) st.autoJoin = v end })

    tab:CreateSection("Grind")
    tab:CreateToggle({ Name = "Trial Walk", Flag = "trialWalk_"..diff, Callback = function(v) st.walk = v; if v then st.wave = 1; st.prev = -1 end end })

    tab:CreateSection("Auto Leave")
    tab:CreateToggle({ Name = "Auto Leave", Flag = "autoLeave_"..diff, Callback = function(v) st.autoLeave = v end })
    tab:CreateSlider({ Name = "Leave after wave", Range = {1,40}, Increment = 1, CurrentValue = 5, Flag = "leaveWave_"..diff, Callback = function(v) st.leaveWave = v end })

    tab:CreateSection("Capture & Return")
    tab:CreateButton({ Name = "Capture Point", Callback = function()
        local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp then st.captured = hrp.Position; Rayfield:Notify({Title="Captured", Content="Position saved!", Duration=3}) end
    end})
    tab:CreateToggle({ Name = "Auto Old Position", Flag = "autoReturn_"..diff, Callback = function(v) st.autoReturn = v end })
end

print("[Sqays Hub – Trials] Ready. Auto Join, Auto Leave, Capture & Return active.")
