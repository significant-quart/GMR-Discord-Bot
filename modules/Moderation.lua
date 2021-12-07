--[[ Init ]]
local ModerationData = FileReader.readFileSync(ModuleDir.."/Moderation.json")
if not ModerationData then 
    Log(2, "Couldn't find Moderation.json, creating a new one...") 

    ModerationData = {
        ["SuspiciousNames"] = {
            "gmr",
            "brandon",
            "craig",
            "scott",
            "wannabree",
            "frank🎙",
            "admin",
            "dev",
            "support",
            "help",
            "desk",
            "metamask",
            "trustwallet",
            "center"
        },
        ["SuspiciousUsers"] = {}
    }
else
    ModerationData = assert(JSON.decode(ModerationData), "fatal: Failed to parse SusNames.json.")
end

--[[ Variables ]]
local GMRG

local DeletionC, MassDeletionC

local SuspiciousNamesC

--[[ Functions ]]
local function FindResponsible(ActionType, Message)
    local Responsible
    local AuditLogs = Message.guild:getAuditLogs({["type"] = ActionType})
    local MessageTime

    if ActionType == 72 then
        MessageTime = Discordia.Date().fromISO(Message.timestamp):toSeconds()
    end

    if AuditLogs then
        for _, AuditLog in pairs(AuditLogs) do
            local AuditTime = AuditLog:getDate():toSeconds()
            local Delta = (MessageTime ~= nil and (AuditTime - MessageTime) or 0)

            if AuditLog.targetId == Message.author.id then
                if (Delta == 0 or Delta > 0 or AuditLog["options"] and AuditLog["options"]["count"] and tonumber(AuditLog["options"]["count"]) > 1) then
                    if not Responsible then
                        Responsible = {
                            ["TimeStamp"] = AuditTime,
                            ["UID"] = AuditLog.userId
                        }
                    else
                        Responsible = (AuditTime < Responsible["TimeStamp"] and {
                            ["TimeStamp"] = AuditTime,
                            ["UID"] = AuditLog.userId
                        } or Responsible)
                    end
                end
            end
        end

        if Responsible then
            Responsible["Member"] = Message.guild:getMember(Responsible["UID"])
        end

        return Responsible
    end

    return nil
end

local function HandleDeletion(Message)
    if DeletionC and MassDeletionC and Message.guild.id == Config["GMRGID"] and Message.content and not Message.author.bot and Message.channel.id ~= Config["GMRVerifyCID"] then
        local Suc, Member = pcall(function()
            return Message.guild.members:get(Message.author.id)
        end)

        local Embed = SimpleEmbed(nil, F("Message sent by %s deleted in <#%s>\n\n", (Member and F("<@%s>", Message.author.id) or F("%s (``%s``)", Message.author.name, Message.author.id)), Message.channel.id)..Message.content)
        Embed["author"] = {
            ["name"] = Message.author.name,
            ["icon_url"] = Message.author.avatarURL
        }
        Embed["fields"] = {
            {
                ["name"] = "TTS",
                ["value"] = (Message.tts and "Yes" or "No"),
                ["inline"] = true
            },
            {
                ["name"] = "Pinned",
                ["value"] = (Message.pinned and "Yes" or "No"),
                ["inline"] = true
            }
        }

        table.insert(Embed["fields"], {
            ["name"] = "Attachment",
            ["value"] = (Message.attachment and F("\n[%s](%s)", "View Here", Message.attachment.url) or "None"),
            ["inline"] = true
        })

        if not Member then
            local CurrentBan = FindResponsible(22, Message)

            table.insert(Embed["fields"], {
                ["name"] = "** **",
                ["value"] = (CurrentBan and CurrentBan["Member"] and F("This user was banned by %s", CurrentBan["Member"].mentionString) or "")
            })

            MassDeletionC:send {
                embed = Embed
            }
        else
            local Deleter = FindResponsible(72, Message)

            table.insert(Embed["fields"], {
                ["name"] = "** **",
                ["value"] = F("This message was deleted by %s", Deleter and Deleter["Member"] and Deleter["Member"].mentionString or F("%s or <@&%s>", Message.author.mentionString, "885228925981196320"))
            })

            DeletionC:send {
                embed = Embed
            }
        end
    end
end

local function SaveModerationData()
    FileReader.writeFileSync(ModuleDir.."/Moderation.json", JSON.encode(ModerationData))
end

local function HandleMemberName(Member)
    if not Member.user or not Member.user.username or ModerationData["SuspiciousUsers"][Member.user.username] ~= nil then return end
    if Member.highestRole.id ~= Config["GMRVerifyRID"] and Member.highestRole ~= Member.guild.defaultRole then return end

    local Username = Member.user.username:lower()

    for i, Pattern in ipairs(ModerationData["SuspiciousNames"]) do
        if Username:match(Pattern:lower()) then
            local AllRoleNames = {}

            if Member.roles then
                Member.roles:forEach(function(Role)
                    table.insert(AllRoleNames, Role.mentionString)
                end) 
            end
        
            local Status = "Not available."
            if Member.status then
                Status = Member.status:sub(1, 1):upper()..Member.status:sub(2, #Member.status)
            end
        
            local Suc, Err = SuspiciousNamesC:send {
                embed = {
                    ["color"] = Config.EmbedColour,
                    ["thumbnail"] = {
                        ["url"] = Member.user:getAvatarURL()
                    },
                    ["title"] = "User Found with Suspicious Username!",
                    ["fields"] = {
                        {
                            ["name"] = "Name",
                            ["value"] = F("%s\n(``%s``)", Member.user.mentionString, Member.id),
                            ["inline"] = true
                        },
                        {
                            ["name"] = "Discriminator",
                            ["value"] = Member.user.discriminator,
                            ["inline"] = true
                        },
                        {
                            ["name"] = "Status",
                            ["value"] = Status,
                            ["inline"] = true
                        },
                        {
                            ["name"] = "Joined Discord",
                            ["value"] = (Member.joinedAt and F("<t:%d:F>", Discordia.Date().fromSnowflake(Member.id):toSeconds()) or "Not available"),
                            ["inline"] = true
                        },
                        {
                            ["name"] = "Joined GMR Discord",
                            ["value"] = (Member.joinedAt and F("<t:%d:F>", Discordia.Date().fromISO(Member.joinedAt):toSeconds()) or "Not available"),
                            ["inline"] = true
                        },
                        {
                            ["name"] = "Boosting Since",
                            ["value"] = (Member.premiumSince and F("<t:%d:F>", Discordia.Date().fromISO(Member.premiumSince):toSeconds()) or "Not boosting."),
                            ["inline"] = true
                        },
                        {
                            ["name"] = "Roles",
                            ["value"] = (#AllRoleNames > 0 and table.concat(AllRoleNames, ", ") or "No Roles")
                        }
                    }
                }
            }

            if Suc then
                ModerationData["SuspiciousUsers"][Member.user.username] = true

                SaveModerationData()
            end

            return
        end
    end
end

--[[ Commands ]]
local ManageKeyword = CommandManager.Command("keyword", function() end)

ManageKeyword:AddSubCommand("add", function(Args, Payload)
    assert(Args[2] ~= nil, "")

    table.insert(ModerationData["SuspiciousNames"], ReturnRestOfCommand(Args, 3))

    SaveModerationData()

    assert(1 == 2, "added keyword(s) successfully.")
end)

ManageKeyword:AddSubCommand("remove", function(Args, Payload)
    assert(Args[2] ~= nil, "")

    local Content = ReturnRestOfCommand(Args, 3)

    for i, Word in ipairs(ModerationData["SuspiciousNames"]) do
        if Word == Content then
            ModerationData["SuspiciousNames"][i] = nil

            SaveModerationData()
            assert(1 == 2, "removed keyword(s) successfully.")

            return
        end
    end

    assert(1 == 2, "those keyword(s) do not exist.")
end)

--[[ Events ]]
BOT:on("ready", function()
    if not GMRG then
        GMRG = BOT:getGuild(Config["GMRGID"])
    end

    if not DeletionC then
        DeletionC = BOT:getChannel(Config["DeletionCID"])
    end

    if not MassDeletionC then
        MassDeletionC = BOT:getChannel(Config["MassDeletionCID"])
    end

    if not SuspiciousNamesC then
        SuspiciousNamesC = BOT:getChannel(Config["SuspiciousNamesCID"])
    end
end)

BOT:on("messageDelete", HandleDeletion)

BOT:on("memberJoin", HandleMemberName)

--[[ Interval ]]
Interval((Config["DefaultInterval"] * 4) * 1000, function()
    print("...", GMRG, GMRG.members)
    if not GMRG or not GMRG.members then return end

    for _, Member in pairs(GMRG.members) do
        pcall(HandleMemberName, Member)
    end
end)