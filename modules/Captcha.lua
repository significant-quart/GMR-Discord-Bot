--[[ Variables ]]
local VerifyChannel

--[[ Database ]]
local DB = assert(SQL.open(Config.ModuleDir.."/Captcha.db"), "fatal: to open Captcha database!")
DB:exec("CREATE TABLE IF NOT EXISTS Words(Word TEXT);")
DB:exec("CREATE TABLE IF NOT EXISTS Users(UID TEXT PRIMARY KEY, Word TEXT, MID TEXT);")

local CreateUser = DB:prepare("INSERT OR REPLACE INTO Users(UID, Word, MID) VALUES(?, ?, ?)")
local GetUser = DB:prepare("SELECT * FROM Users WHERE UID = ?")
local GetWord = DB:prepare("SELECT * FROM Words ORDER BY RANDOM() LIMIT 1")
local RemoveWord = DB:prepare("DELETE FROM Words WHERE Word = ?")

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
                print("Deleting OUR message")
                local OurMessage = VerifyChannel:getMessage(User[3])
                
                if OurMessage then
                    OurMessage:delete()
                end
            end

            Word = User[2]
        else
            Word = GetWord:reset():step()[1]

            RemoveWord:reset():bind(Word):step()
            print("Removed word", Word)
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
            CreateUser:reset():bind(Member.user.id, Word, Message.id):step()
        else
            p(Message, Err)
        end
    end)
end)

BOT:on("messageCreate", function(Payload)
    pcall(function()
        if Payload.guild and Payload.guild.id == Config["GMRGID"] and Payload.author and not Payload.author.bot and Payload.channel and Payload.channel.id == Config["GMRVerifyCID"] then
            local User = GetUser:reset():bind(Payload.author.id):step()

            if User ~= nil and User[2] == Payload.content then
                Payload.member:addRole(Config["GMRVerifyRID"])

                if User[3] and #User[3] > 0 then
                    local OurMessage = VerifyChannel:getMessage(User[3])
                
                    if OurMessage then
                        OurMessage:delete()
                    end
                end
            end

            Payload:delete()
        end
    end)
end)