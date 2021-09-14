--[[ Variables ]]
local Permissions = FileReader.readFileSync(ModuleDir.."/Permissions.json")
if not Permissions then 
    Log(2, "Couldn't find Permissions.json, creating a new one... (Remember to add permissions to commands)") 

    Permissions = {
        ["Commands"] = {},
        ["Categories"] = {}
    }
else
    Permissions = assert(JSON.decode(Permissions), "fatal: Failed to parse Permissions.json.")
end

--[[ External Function ]]
_G.HasPermission = function(Member, Command, Category, Payload)
    if Member == nil then return false end
    if Payload.member:hasPermission(nil, 0x00000008) then return true end
    if Permissions["Commands"][Command] == nil and Permissions["Categories"][Command] == nil then return false end
    
    if Category and Permissions["Categories"][Category] then
        if Permissions["Categories"][Category]["Roles"]["everyone"] and Permissions["Categories"][Category]["Roles"]["everyone"] == true then 
            return true 
        end

        if  Permissions["Categories"][Category]["Users"][Member.id] and Permissions["Categories"][Category]["Users"][Member.id] == true then
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

function AuditPermission(Command, Type, Allow, MRoles, MUsers, OtherRoles)
    print("Adding permission for "..Command..": type = "..Type..": allow = "..tostring(Allow)..": other = "..(OtherRoles or "none"))

    if Permissions[Type][Command] == nil then
        Permissions[Type][Command] = {
            ["Users"] = {},
            ["Roles"] = {}
        }
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
end) 

--[[ Sub-Commands ]]
PermissionsCommand:AddSubCommand("add", function(Args, Payload)
    assert(CommandManager.Exists(Args[3]), "that command doesn't exist.")
    assert(#(Payload.mentionedRoles) > 0 or #(Payload.mentionedUsers) > 0 or Payload.mentionsEveryone == true, "you need to provide role(s) and/or user(s) to add to the ``"..Args[3].."`` command permissions.")

    AuditPermission(Args[3], "Commands", true, Payload.mentionedRoles, Payload.mentionedUsers, (Payload.mentionsEveryone == true and "everyone" or nil))

    SimpleEmbed(Payload, Payload.author.mentionString.." updated role(s) and/or user(s) permissions for command:\n \n``"..Args[3].."``")
end)

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
    assert(#(Payload.mentionedRoles) > 0 or #(Payload.mentionedUsers) > 0 or Payload.mentionsEveryone == true, "you need to provide role(s) and/or user(s) to add to the ``"..CommandCategory.."`` command category permissions.")

    AuditPermission(CommandCategory, "Categories", true, Payload.mentionedRoles, Payload.mentionedUsers, (Payload.mentionsEveryone == true and "everyone" or nil))

    SimpleEmbed(Payload, Payload.author.mentionString.." updated role(s) and/or user(s) permissions for category:\n \n``"..CommandCategory.."``")
end)

PermissionsCommand:AddSubCommand("remove", function(Args, Payload)
    assert(CommandManager.Exists(Args[3]), "that command doesn't exist.")
    assert(#(Payload.mentionedRoles) > 0 or #(Payload.mentionedUsers) > 0 or Payload.mentionsEveryone == true, "you need to provide role(s) and/or user(s) to remove from the ``"..Args[3].."`` command permissions.")
    
    AuditPermission(Args[3], "Commands", false, Payload.mentionedRoles, Payload.mentionedUsers, (Payload.mentionsEveryone == true and "everyone" or nil))

    SimpleEmbed(Payload, Payload.author.mentionString.." updated role(s) and/or user(s) permissions for command:\n \n``"..Args[3].."``")
end)

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
    assert(#(Payload.mentionedRoles) > 0 or #(Payload.mentionedUsers) > 0 or Payload.mentionsEveryone == true, "you need to provide role(s) and/or user(s) to remove from the ``"..CommandCategory.."`` command category permissions.")

    AuditPermission(CommandCategory, "Categories", false, Payload.mentionedRoles, Payload.mentionedUsers, (Payload.mentionsEveryone == true and "everyone" or nil))

    SimpleEmbed(Payload, Payload.author.mentionString.." updated role(s) and/or user(s) permissions for category:\n \n``"..CommandCategory.."``")
end)

--[[ Commands ]]
CommandManager.Command("view", function(Args, Payload)
    local Commands = CommandManager.GetAllCommands()
    local PermissionData = {}
    assert(Commands ~= nil, "there was a problem fetching all available commands.")

    for _, Command in pairs(Commands) do
        local Category = Command:GetCategory()
        local Name = Command:GetName()

        if Category and Name then
            local RoleStr = ""

            if Permissions["Categories"][Category] and Permissions["Categories"][Category]["Roles"] then
                for Role, _ in pairs(Permissions["Categories"][Category]["Roles"]) do
                    RoleStr = F("%s %s", RoleStr, (Role ~= "everyone" and "<@&"..Role..">" or Role))
                end
            end

            if Permissions["Commands"][Name] and Permissions["Commands"][Name]["Roles"] then
                for Role, _ in pairs(Permissions["Commands"][Name]["Roles"]) do
                    RoleStr = F("%s %s", RoleStr, (Role ~= "everyone" and "<@&"..Role..">" or Role))
                end
            end

            if not PermissionData[Category] then
                PermissionData[Category] = {}
            end

            table.insert(PermissionData[Category], {
                ["Name"] = Name,
                ["Permissions"] = (#RoleStr > 0 and RoleStr or "Only the server owner can use this command.")
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
end)

--[[ File Saving ]]
Interval(DefaultInterval * 1000, function()
    local EncodedPermissions = assert(JSON.encode(Permissions, { indent = Config.PrettyJSON }), "Failed to encode Permissions!")

    FileReader.writeFileSync(ModuleDir.."/Permissions.json", EncodedPermissions)
end)