--[[ Variables ]]
local Permissions = FileReader.readFileSync(ModuleDir.."/Permissions.json")
if not Permissions then 
    Log(2, "Couldn't find Permissions.json, creating a new one... (Remember to add permissions to commands)") 

    Permissions = {
        ["Commands"] = {},
        ["Categories"] = {},
    }
else
    Permissions = assert(JSON.decode(Permissions), "fatal: Failed to parse Permissions.json.")
end

local AllChannels = "#everything"

--[[ External Function ]]
_G.HasPermission = function(Member, Command, Category, Channel)
    if Member == nil then return false end
    if Member:hasPermission(nil, 0x00000008) then return true end
    if Permissions["Commands"][Command] == nil and Permissions["Categories"][Category] == nil then return false end

    local FoundChannel, Channels, i = false, {}, 0

    if Command and Permissions["Commands"][Command] and Permissions["Commands"][Command]["Channels"] then
        for CID, Allow in pairs(Permissions["Commands"][Command]["Channels"]) do
            if Allow == true then
                i = i + 1

                if CID == AllChannels then
                    table.insert(Channels, CID)
                else
                    table.insert(Channels, F("<#%s>", CID))
                end
            end
        end

        FoundChannel = (Permissions["Commands"][Command]["Channels"][Channel.id] or Permissions["Commands"][Command]["Channels"][AllChannels] or false)
    end

    if Category and Permissions["Categories"][Category] and Permissions["Categories"][Category]["Channels"] and not FoundChannel then
        for CID, Allow in pairs(Permissions["Categories"][Category]["Channels"]) do
            if Allow == true then
                i = i + 1

                if CID == AllChannels then
                    table.insert(Channels, CID)
                else
                    table.insert(Channels, F("<#%s>", CID))
                end 
            end
        end

        FoundChannel = (Permissions["Categories"][Category]["Channels"][Channel.id] or Permissions["Categories"][Category]["Channels"][AllChannels] or false)
    end

    if FoundChannel == false then 
        return false, F("this command is not available in this channel.\n\nAvailable Channels:\n%s", (i > 0 and table.concat(Channels, ",\n") or "This command is not available in any channel!"))
    end

    if Category and Permissions["Categories"][Category] then
        if Permissions["Categories"][Category]["Roles"]["everyone"] and Permissions["Categories"][Category]["Roles"]["everyone"] == true then 
            return true 
        end

        if Permissions["Categories"][Category]["Users"][Member.id] and Permissions["Categories"][Category]["Users"][Member.id] == true then
            return true
        end
    end

    if Command and Permissions["Commands"][Command] then
        if Permissions["Commands"][Command]["Roles"]["everyone"] and Permissions["Commands"][Command]["Roles"]["everyone"] == true then 
            return true 
        end

        if Permissions["Commands"][Command]["Users"][Member.id] and Permissions["Commands"][Command]["Users"][Member.id] == true then 
            return true
        end
    end

    for Role in Member.roles:iter() do
        if Category and Permissions["Categories"][Category] and Permissions["Categories"][Category]["Roles"] then
            if Permissions["Categories"][Category]["Roles"][Role.id] and Permissions["Categories"][Category]["Roles"][Role.id] == true then
                return true
            end    
        end

        if Command and Permissions["Commands"][Command] and Permissions["Commands"][Command]["Roles"] then
            if Permissions["Commands"][Command]["Roles"][Role.id] and Permissions["Commands"][Command]["Roles"][Role.id] == true then
                return true
            end
        end
    end

    return false
end

function AuditPermission(Command, Type, Allow, MRoles, MUsers, MChannels, AllChannels, OtherRoles)
    if Permissions[Type][Command] == nil then
        Permissions[Type][Command] = {
            ["Users"] = {},
            ["Roles"] = {},
            ["Channels"] = {}
        }
    else        
        if Permissions[Type][Command]["Channels"] == nil then
            Permissions[Type][Command]["Channels"] = {}
        end
    end 

    if #MRoles > 0 then
        for RID, _ in pairs(MRoles) do
            Permissions[Type][Command]["Roles"][RID] = Allow
        end  
    end

    if #MUsers > 0 then 
        for UID, _ in pairs(MUsers) do
            Permissions[Type][Command]["Users"][UID] = Allow
        end 
    end
    
    if #MChannels > 0 then 
        for CID, _ in pairs(MChannels) do
            Permissions[Type][Command]["Channels"][CID] = Allow
        end 
    end

    if AllChannels then
        Permissions[Type][Command]["Channels"]["#everything"] = Allow
    end

    if OtherRoles then
        Permissions[Type][Command]["Roles"][OtherRoles] = Allow
    end
end

function GetCommandCategory(Args, Index)
    local SArgs = table.concat(Args, " ", Index)

    return SArgs:match([["(.-)"]]) or Args[Index]
end

--[[ Command ]]
local PermissionsCommand = CommandManager.Command("permissions", function(Args, Payload)
end):SetCategory("Moderation Commands"):SetDescription("Permission commands!"):SetLongDescription(F([[
    An example usage can be found below:

    *%spermissions add price <@&%s>*

    The above will enable the role <@&%s> to use the ``%sprice`` command.

    *%spermissions addc "Fun Commands " <@&%s>*

    The above will enable the role <@&%s> to use all commands in the ``Fun Commands`` category.

    **Notes:
    > These exact same principles apply when using ``remove`` or ``removec`` however the role(s)/user(s)/channel(s) will not be able to use the commands in question.

    > When using the ``addc`` or ``removec`` commands, double quotes must be used for specifying the command category!

    > You can specify as many roles, users or channels when using the above commands.
    
    > To enable a command for all channels use #everything when auditing a permission.**

    To see which users and roles can use which commands in which channels type the following:

    ``%spermissions view``
]], Prefix, Config["GMRVerifyRID"], Config["GMRVerifyRID"], Prefix, Prefix, Config["GMRVerifyRID"], Config["GMRVerifyRID"], Prefix, Prefix))

--[[ Sub-Commands ]]
PermissionsCommand:AddSubCommand("add", function(Args, Payload)
    assert(CommandManager.Exists(Args[3]), "that command doesn't exist.")
    assert(#(Payload.mentionedRoles) > 0 or #(Payload.mentionedUsers) > 0 or #(Payload.mentionedChannels) > 0 or Payload.content:find(AllChannels) or Payload.mentionsEveryone == true, "you need to provide role(s) and/or user(s) to add to the ``"..Args[3].."`` command permissions.")

    AuditPermission(Args[3], "Commands", true, Payload.mentionedRoles, Payload.mentionedUsers, Payload.mentionedChannels, Payload.content:find(AllChannels), (Payload.mentionsEveryone == true and "everyone" or nil))

    SimpleEmbed(Payload, Payload.author.mentionString.." updated permissions for command:\n \n``"..Args[3].."``")
end):SetDescription("Allow roles, users or channels to use a particular command.")

PermissionsCommand:AddSubCommand("addc", function(Args, Payload)
    local Exists = false 
    local CommandCategory = GetCommandCategory(Args, 3)

    for _, Command in pairs(CommandManager.GetAllCommands()) do
        local Category = Command:GetCategory()

        if Category and Category == CommandCategory then
            Exists = true

            break
        end
    end

    assert(Exists == true, "that command category doesn't exist.")
    assert(#(Payload.mentionedRoles) > 0 or #(Payload.mentionedUsers) > 0 or #(Payload.mentionedChannels) > 0 or Payload.content:find(AllChannels) or Payload.mentionsEveryone == true, "you need to provide role(s) and/or user(s) to add to the ``"..CommandCategory.."`` command category permissions.")

    AuditPermission(CommandCategory, "Categories", true, Payload.mentionedRoles, Payload.mentionedUsers, Payload.mentionedChannels, Payload.content:find(AllChannels), (Payload.mentionsEveryone == true and "everyone" or nil))

    SimpleEmbed(Payload, Payload.author.mentionString.." updated permissions for category:\n \n``"..CommandCategory.."``")
end):SetDescription("Allow roles, users or channels to use a particular command **category**.")

PermissionsCommand:AddSubCommand("remove", function(Args, Payload)
    assert(CommandManager.Exists(Args[3]), "that command doesn't exist.")
    assert(#(Payload.mentionedRoles) > 0 or #(Payload.mentionedUsers) > 0 or #(Payload.mentionedChannels) > 0 or Payload.content:find(AllChannels) or Payload.mentionsEveryone == true, "you need to provide role(s) and/or user(s) to remove from the ``"..Args[3].."`` command permissions.")
    
    AuditPermission(Args[3], "Commands", false, Payload.mentionedRoles, Payload.mentionedUsers, Payload.mentionedChannels, Payload.content:find(AllChannels), (Payload.mentionsEveryone == true and "everyone" or nil))

    SimpleEmbed(Payload, Payload.author.mentionString.." updated permissions for command:\n \n``"..Args[3].."``")
end):SetDescription("Disallow roles, users or channels to use a particular command.")

PermissionsCommand:AddSubCommand("removec", function(Args, Payload)
    local Exists = false 
    local CommandCategory = GetCommandCategory(Args, 3)

    for _, Command in pairs(CommandManager.GetAllCommands()) do
        if Command:GetCategory() == CommandCategory then
            Exists = true

            break
        end
    end

    assert(Exists == true, "that command category doesn't exist.")
    assert(#(Payload.mentionedRoles) > 0 or #(Payload.mentionedUsers) > 0 or #(Payload.mentionedChannels) > 0 or Payload.content:find(AllChannels) or Payload.mentionsEveryone == true, "you need to provide role(s) and/or user(s) to remove from the ``"..CommandCategory.."`` command category permissions.")

    AuditPermission(CommandCategory, "Categories", false, Payload.mentionedRoles, Payload.mentionedUsers, Payload.mentionedChannels, Payload.content:find(AllChannels), (Payload.mentionsEveryone == true and "everyone" or nil))

    SimpleEmbed(Payload, Payload.author.mentionString.." updated permissions for category:\n \n``"..CommandCategory.."``")
end):SetDescription("Disallow roles, users or channels to use a particular command **category**.")

--[[ Commands ]]
PermissionsCommand:AddSubCommand("view", function(Args, Payload)
    local Commands = CommandManager.GetAllCommands()
    local PermissionData = {}
    assert(Commands ~= nil, "there was a problem fetching all available commands.")

    for _, Command in pairs(Commands) do
        local Category = Command:GetCategory()
        local Name = Command:GetName()

        if Category and Name then
            local RoleStr = ""

            if Permissions["Categories"][Category] then
                if Permissions["Categories"][Category]["Roles"] then
                    for RID, Allow in pairs(Permissions["Categories"][Category]["Roles"]) do
                        RoleStr = F("%s %s %s", RoleStr, (RID ~= "everyone" and F("<@&%s>", RID) or RID), (Allow == true and ":green_circle:" or ":red_circle:"))
                    end
                end

                if Permissions["Categories"][Category]["Channels"] then
                    for CID, Allow in pairs(Permissions["Categories"][Category]["Channels"]) do
                        RoleStr = F("%s %s %s", RoleStr, (CID ~= AllChannels and F("<#%s>", CID) or "**All Channels**"), (Allow == true and ":green_circle:" or ":red_circle:"))
                    end
                end

            end

            if Permissions["Commands"][Name] then
                if Permissions["Commands"][Name]["Roles"] then
                    for RID, Allow in pairs(Permissions["Commands"][Name]["Roles"]) do
                        RoleStr = F("%s %s %s", RoleStr, (RID ~= "everyone" and F("<@&%s>", RID) or RID), (Allow == true and ":green_circle:" or ":red_circle:"))
                    end
                end

                if Permissions["Commands"][Name]["Channels"] then
                    for CID, Allow in pairs(Permissions["Commands"][Name]["Channels"]) do
                        RoleStr = F("%s %s %s", RoleStr, (CID ~= AllChannels and F("<#%s>", CID) or "**All Channels**"), (Allow == true and ":green_circle:" or ":red_circle:"))
                    end
                end
            end

            if not PermissionData[Category] then
                PermissionData[Category] = {}
            end

            table.insert(PermissionData[Category], {
                ["Name"] = Name,
                ["Permissions"] = (#RoleStr > 0 and RoleStr or "Only users with administrator permission can use this command.")
            })
        end
    end

    local PermissionEmbed = SimpleEmbed(nil, "Here are the permissions for all available commands:")
    PermissionEmbed["fields"] = {}

    for Category, Data in pairs(PermissionData) do
        local Field = {
            ["name"] = Category,
            ["value"] = ""
        }

        for i = 1, #Data do
            local CommandData = Data[i]

            Field["value"] = F("%s``%s%s`` - %s\n", Field["value"], Prefix, CommandData["Name"], CommandData["Permissions"])
        end

        table.insert(PermissionEmbed["fields"], Field)
    end

    Payload:reply{
        embed = PermissionEmbed
    }
end):SetDescription("View the commands particular roles can use.")

--[[ File Saving ]]
Interval(DefaultInterval * 1000, function()
    local EncodedPermissions = assert(JSON.encode(Permissions, { indent = Config.PrettyJSON }), "Failed to encode Permissions!")

    FileReader.writeFileSync(ModuleDir.."/Permissions.json", EncodedPermissions)
end)