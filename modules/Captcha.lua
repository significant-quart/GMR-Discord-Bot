--[[ Init ]]
math.randomseed(os.time())

--[[ Variables ]]
local Words = assert(FileReader.readFileSync(ModuleDir.."/Captcha.txt"):split("\n"), "fatal: Failed to open Captcha database!")
local CurrentMessage = Words[math.random(1, #Words)]:gsub("%s", "")
local Ready = false

--[[ Functions ]]
local function HandleLastMessage()
    local VerifyChannel = BOT:getGuild(Config["GMRGID"]):getChannel(Config["GMRVerifyCID"])
    local LastMessage = VerifyChannel:getFirstMessage()

    local VerifyEmbed = SimpleEmbed(nil, "")
    VerifyEmbed["title"] = "Welcome to the GMR Official Discord!"
    VerifyEmbed["description"] = "To get verified please type the word highlighted below!\n``` ```\n\n**%s**\n\n``` ```\n"
    VerifyEmbed["footer"] = {
        ["text"] = "Make sure to type the word as shown; all lowercase, no spelling errors, no spaces.",
        ["icon_url"] = BOT.user.avatarURL
    }

    if LastMessage then
        CurrentMessage = Words[math.random(1, #Words)]:gsub("%s", "")
        VerifyEmbed["description"] = VerifyEmbed["description"]:format(CurrentMessage)

        LastMessage:setEmbed(VerifyEmbed)
    else
        VerifyEmbed["description"] = VerifyEmbed["description"]:format(CurrentMessage)

        VerifyChannel:send {
            embed = VerifyEmbed
        }
    end
end

local Clock = Discordia.Clock()
Clock:on("hour", HandleLastMessage)

--[[ Events ]]
BOT:on("ready", function()
    if not Ready then
        HandleLastMessage()

        Clock:start()

        Ready = true
    end
end)


BOT:on("messageCreate", function(Payload)
    pcall(function()
        if Payload.guild and Payload.guild.id == Config["GMRGID"] and Payload.author and not Payload.author.bot and Payload.channel and Payload.channel.id == Config["GMRVerifyCID"] then
            print(CurrentMessage, Payload.content)
            print(#CurrentMessage, #(Payload.content))
            if Payload.content == CurrentMessage then
                local Suc, Err = Payload.member:addRole(Config["GMRVerifyRID"])
                
                if Suc then
                    Payload:delete()

                    local Messages = Payload.channel:getMessages(100)
                    if Messages then
                        for k, Message in pairs(Messages) do
                            if Message.author.id == Payload.author.id and Message.author.id ~= BOT.user.id then
                                Message:delete()
                            end
                        end
                    end
                    
                    Log(3, F("Verified %s (%s)", Payload.member.user.name, Payload.member.user.id))
                else
                    Log(1, F("Failed to verify %s (%s)", Payload.member.user.name, Payload.member.user.id))
                end
            end
        end
    end)
end)