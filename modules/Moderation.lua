--[[ Variables ]]
local DeletionC, MassDeletionC

--[[ Functions ]]
local function FindResponsible(ActionType, Message)
    local Responsible
    local AuditLogs = Message.guild:getAuditLogs({["type"] = ActionType})

    if AuditLogs then
        for _, AuditLog in pairs(AuditLogs) do
            if AuditLog.targetId == Message.author.id then
                local AuditTime = AuditLog:getDate():toSeconds()

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

        if Responsible then
            Responsible["Member"] = Message.guild:getMember(Responsible["UID"])
        end

        return Responsible
    end

    return nil
end

local function HandleDeletion(Message)
    if DeletionC and MassDeletionC and Message.guild.id == Config["GMRGID"] and Message.content and not Message.author.bot then
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
                ["value"] = F("This message was deleted by %s", Deleter and Deleter["Member"] and Deleter["Member"].mentionString or F("%s or %s", Message.author.mentionString, BOT.user.mentionString))
            })

            DeletionC:send {
                embed = Embed
            }
        end
    end
end

--[[ Events ]]
BOT:on("ready", function()
    if not DeletionC then
        DeletionC = BOT:getChannel(Config["DeletionCID"])
    end

    if not MassDeletionC then
        MassDeletionC = BOT:getChannel(Config["MassDeletionCID"])
    end
end)

BOT:on("messageDelete", HandleDeletion)