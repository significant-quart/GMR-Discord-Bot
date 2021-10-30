--[[ Variables ]]
local DeletionC, MassDeletionC

--[[ Functions ]]
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
            local CurrentBan
 
            for _, AuditLog in pairs(Message.guild:getAuditLogs({["type"] = 22})) do
                if AuditLog.targetId == Message.author.id then
                    local BanTime = AuditLog:getDate():toSeconds()

                    if not CurrentBan then
                        CurrentBan = {
                            ["TimeStamp"] = BanTime,
                            ["UID"] = AuditLog.userId
                        }
                    else
                        CurrentBan = (BanTime < CurrentBan["TimeStamp"] and {
                            ["TimeStamp"] = BanTime,
                            ["UID"] = AuditLog.userId
                        } or CurrentBan)
                    end
                end
            end

            if CurrentBan then
                CurrentBan["Banner"] = Message.guild:getMember(CurrentBan.UID)
            end

            table.insert(Embed["fields"], {
                ["name"] = "** **",
                ["value"] = (CurrentBan["Banner"] and F("This user was banned by %s", CurrentBan["Banner"].mentionString) or "")
            })

            MassDeletionC:send {
                embed = Embed
            }
        else
            DeletionC:send {
                embed = Embed
            }
        end

        Suc, Member, Embed = nil, nil, nil
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