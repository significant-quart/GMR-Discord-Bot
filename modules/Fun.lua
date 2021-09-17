--[[ Commands ]]
CommandManager.Command("coin", function(Args, Payload)
    math.randomseed(os.time())
    local RInt = math.random(1, 2)

    SimpleEmbed(Payload, (RInt == 1 and "Heads" or "Tails"))
end):SetCategory("Misc Commands"):SetDescription("Flip a coin.")

CommandManager.Command("whois", function(Args, Payload)
    local Member = Payload.member

    if Payload.mentionedUsers and Payload.mentionedUsers.first then
        Member = Payload.guild:getMember(Payload.mentionedUsers.first)
    elseif Args[2] and tonumber(Args[2]) ~= nil then
        Member = Payload.guild:getMember(Args[2])
    end

    assert(Member ~= nil and Member, "sorry however there was an issue fetching information.")

    assert(Member.name and Member.user.discriminator and Member.id and Member.status and Member.joinedAt and Member.roles, "there was an issue fetching required information.")

    local AllRoleNames = {}

    Member.roles:forEach(function(Role)
        table.insert(AllRoleNames, Role.mentionString)
    end)

    local Status = "Not available."
    if Member.status then
        Status = Member.status:sub(1, 1):upper()..Member.status:sub(2, #Member.status)
    end

    Payload:reply {
        embed = {
            ["color"] = Config.EmbedColour,
            ["thumbnail"] = {
                ["url"] = Member.user:getAvatarURL()
            },
            ["fields"] = {
                {
                    ["name"] = "Name",
                    ["value"] = F("%s\n(``%s``)", Member.name, Member.id),
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
                    ["value"] = table.concat(AllRoleNames, ", ")
                }
            }
        }
    }
end):SetCategory("Misc Commands"):SetDescription("Get info about a user on discord."):SetLongDescription(F([[
    An example usage can be found below:

    *%swhois*

    The above will provide information about you.

    *%swhois <@%s>*

    Supports mentions.
    
    *%swhois 843951774834360371*

    Supports Discord User IDs.
]], Prefix, Prefix, Config["GMRUID"], Prefix))