--[[ Variables ]]
local VerifyChannel
local Responses = {}
local SuccessMessageDelete = 10

--[[ Database ]]
local DB = assert(SQL.open(Config.ModuleDir.."/Captcha.db"), "fatal: to open Captcha database!")
DB:exec("CREATE TABLE IF NOT EXISTS Words(Word TEXT);")
DB:exec("CREATE TABLE IF NOT EXISTS Users(UID TEXT PRIMARY KEY, Word TEXT, MID TEXT);")

local CreateUser = DB:prepare("INSERT OR REPLACE INTO Users(UID, Word, MID) VALUES(?, ?, ?)")
local GetUser = DB:prepare("SELECT * FROM Users WHERE UID = ?")
local GetWord = DB:prepare("SELECT * FROM Words ORDER BY RANDOM() LIMIT 1")
local RemoveWord = DB:prepare("DELETE FROM Words WHERE Word = ?")
local GetUserMessage = DB:prepare("SELECT MID FROM Users WHERE UID = ?")

local Message = [[
Welcome to the GMR.finance Discord server %s!

**To get verified please type the message that is highlighted below in this channel!**

``%s``
]]

local Ready = false


local function AddWords()
    local Words = assert(JSON.decode(FileReader.readFileSync(ModuleDir.."/Captcha.json")), "fatal: Failed to read or parse Captcha.json!")
    local WordsIpair = {}

    for k, Word in pairs(Words) do
        table.insert(WordsIpair, Word)
    end

    local Stmt = [[INSERT INTO Words(Word) VALUES]]

    for i, Word in pairs(WordsIpair) do
        Stmt = Stmt.."\n"..F([[("%s")%s]], Word, (i < #WordsIpair and "," or ""))
    end

    DB:exec(Stmt)
end

local function RemoveWords()
    local badwords = ([[]]):split("\n")

    for _, word in pairs(badwords) do
        RemoveWord:reset():bind(word):step()
    end
end

--[[ Events ]]
BOT:on("ready", function()
    if Ready == true then return end

    VerifyChannel = assert(BOT:getChannel(Config["GMRVerifyCID"]), "fatal: Failure fetching GMR verification channel!")
end)

BOT:on("memberJoin", function(Member)
    pcall(function()
        local User = GetUser:reset():bind(Member.user.id):step()
        local Word

        if User then
            if User[3] ~= nil and #User[3] > 0 then
                local OurMessage = VerifyChannel:getMessage(User[3])
                
                if OurMessage then
                    OurMessage:delete()
                end
            end

            Word = User[2]
        else
            Word = GetWord:reset():step()[1]

            RemoveWord:reset():bind(Word):step()
        end

        local Arrow = string.rep("=", 23 - math.ceil(#Word/4))

        Embed = {
            ["description"] = F([[Welcome to the GMR.finance Discord server %s!

            **To get verified please type the message that is highlighted below in this channel!**]], Member.user.mentionString),
            ["color"] = Config.EmbedColour,
            ["fields"] = {
                {
                    ["name"] = "** **",
                    ["value"] = Arrow..">",
                    ["inline"] = true
                },
                {
                    ["name"] = "** **",
                    ["value"] = F("``%s``", Word),
                    ["inline"] = true
                },
                {
                    ["name"] = "** **",
                    ["value"] = "<"..Arrow,
                    ["inline"] = true
                }
            }
        }

        local Message, Err = VerifyChannel:send {
            embed = Embed
        }

        if Err == nil and Message.id then
            Log(3, F("Creating/Updating user %s (%s)", Member.user.name, Member.user.id))

            CreateUser:reset():bind(Member.user.id, Word, Message.id):step()
        end
    end)
end)

BOT:on("memberLeave", function(Member)
    local MID = GetUserMessage:reset():bind(Member.user.id):step()

    if MID ~= nil and MID[1] and #MID[1] > 0 then
        local OurMessage = VerifyChannel:getMessage(MID[1])
                
        if OurMessage then
            OurMessage:delete()
        end
    end
end )

BOT:on("messageCreate", function(Payload)
    pcall(function()
        if Payload.guild and Payload.guild.id == Config["GMRGID"] and Payload.author and not Payload.author.bot and Payload.channel and Payload.channel.id == Config["GMRVerifyCID"] then
            local User = GetUser:reset():bind(Payload.author.id):step()

            if User ~= nil then
                if Responses[Payload.author.id] then
                    Responses[Payload.author.id]:delete()

                    Responses[Payload.author.id] = nil
                end

                if User[2] == Payload.content then
                    Payload.member:addRole(Config["GMRVerifyRID"])
                    
                    Log(3, F("Verified %s (%s)", Payload.member.user.name, Payload.member.user.id))

                    if User[3] and #User[3] > 0 then
                        local OurMessage = VerifyChannel:getMessage(User[3])
                    
                        if OurMessage then
                            OurMessage:delete()
                        end
                    end

                    local Embed = SimpleEmbed(nil, F("%s **verification successful!\n\nWelcome to the GMR.finance Discord!**", Payload.author.mentionString))
                    Embed["thumbnail"] = {
                        ["url"] = "https://cdn.discordapp.com/attachments/859171545418432533/887359235774623794/header-logo.png"
                    }

                    local SuccessMessage, Err = VerifyChannel:send {
                        embed = Embed
                    }

                    Routine.setTimeout(SuccessMessageDelete * 1000, coroutine.wrap(function()
                        if SuccessMessage and not Err then
                            SuccessMessage:delete()

                            SuccessMessage, Err = nil, nil
                        end
                    end))
                else
                    local LastMessage, Err = SimpleEmbed(Payload, F("%s the word you typed is not correct, if you can't see your word click [__``here!``__](https://discord.com/channels/%s/%s/%s).", Payload.author.mentionString, Payload.guild.id, Payload.channel.id, User[3]))

                    if LastMessage and not Err then
                        Responses[Payload.author.id] = LastMessage
                    end
                end
            end

            Payload:delete()
        end
    end)
end)