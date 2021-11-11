--[[ Database ]]
local DB = assert(SQL.open(ModuleDir.."/Competition.db"), "fatal: Failed to open Competition database!")
DB:exec("PRAGMA foreign_keys = ON;")

DB:exec("CREATE TABLE IF NOT EXISTS Competitions(ID INTEGER PRIMARY KEY AUTOINCREMENT, Name TEXT NOT NULL, Start TEXT NOT NULL, End TEXT, Participants INTEGER NOT NULL, StatMID TEXT NOT NULL);")
DB:exec("CREATE TABLE IF NOT EXISTS Submissions(Content TEXT NOT NULL, OwnerID TEXT NOT NULL, ID INTEGER NOT NULL, FOREIGN KEY (ID) REFERENCES Competitions (ID));")

local CreateCompSTMT = DB:prepare("INSERT INTO Competitions(Name, Start, End, Participants, StatMID) VALUES(?, ?, ?, 0, ?)")

--[[ Variables ]]
local CompetitionCID = Config["CompetitionCID"]
local CompetitionStatsCID = Config["CompetitionStatsCID"]

local LatestCompetitionID = assert(tonumber(DB:rowexec("SELECT count(1) FROM Competitions")), "fatal: Failed to get latest competition ID!")

local Ready = false

--[[ Functions ]]
local function IsCompetitionOngoing()
    local OnGoing = false

    local Competitions = DB:exec("SELECT * FROM Competitions;")
    if Competitions then
        for i = 1, #Competitions["End"] do
            Competitions["End"][i] = tonumber(Competitions["End"][i])
            OnGoing = (Competitions["End"][i] == 0 or Competitions["End"][i] < os.time())

            if Competitions["End"][i] ~= 0 and Competitions["End"][i] < os.time() then
                local CompetitionStatChannel = BOT:getChannel(CompetitionStatsCID)

                if CompetitionStatChannel then
                    local StatMessage = CompetitionStatChannel:getMessage(Competitions["StatMID"][i])

                    if StatMessage then
                        local Stats = SimpleEmbed(nil, F("Start: <t:%d:F>\nEnd: <t:%d:F>\nParticipants: %d", tonumber(Competitions["Start"][i]), Competitions["End"][i], tonumber(Competitions["Participants"][i])))
                        Stats["title"] = F("[CLOSED] #%d | %s", tonumber(Competitions["ID"][i]), Competitions["Name"][i])
                        
                        StatMessage:setEmbed(Stats)
                    end
                end
            end
        end
    end

    return OnGoing
end

--[[ Events ]]
BOT:on("ready", function()
    if Ready == true then return end
    Ready = true

    IsCompetitionOngoing()
end)

--[[ Commands ]]
CommandManager.Command("copen", function(Args, Payload)
    assert(#Args > 2, "")
    assert(IsCompetitionOngoing() == false, "there is already an ongoing competition!")

    local SArgs = ReturnRestOfCommand(Args, 2)
    local Name = assert(SArgs:match([[([^"]+)]]), "you need to provide the competition name.")
    local Start = os.time()
    local End = tonumber(Args[#Args]:match("%d+"))
    if End ~= nil then
        assert(End > Start, "competition end time must be later than now.")
    end

    local CompetitionStatChannel = assert(BOT:getChannel(CompetitionStatsCID), "failed to fetch competition statistics channel.")

    local Stats = SimpleEmbed(nil, F("Start: <t:%d:F>\nEnd: %s\nParticipants: 0", Start, (End ~= nil and F("<t:%d:F>" ,End) or "TBA")))
    Stats["title"] = F("#%d | %s", LatestCompetitionID + 1, Name)

    local StatMessage = assert(CompetitionStatChannel:send {
        embed = Stats
    })

    print(Type, Name, End)
    local Res = CreateCompSTMT:reset():bind(Name, tostring(Start), tostring(End or 0), StatMessage.id):step()
    p(Res)
    --"there was a error creating the competition")
    LatestCompetitionID = LatestCompetitionID + 1
end)