--[[ 
    Super Basic Commander Maker Thingy.
]]

local Class = require("discordia").class
local Command = Class("Command")

local Commands = {}
local SubCommands = {}
local CommandAlias = {}

--[[ Initialise a new command. ]]
function Command:__init(Name, Handle, SubCommand)
    self._Name = Name
    self._Handle = Handle
    self._IsSubCommand = (SubCommand ~= nil and true or false)
    if SubCommand ~= nil then
        assert(Commands[SubCommand] ~= nil, "Tried to make a sub-command whose parent command doesn't exist.")

        if not SubCommands[SubCommand] then
            SubCommands[SubCommand] = {}
        end

        SubCommands[SubCommand][Name] = self
    else
        Commands[Name] = self
    end

    return self
end

--[[ Command Setters ]]
function Command:SetDescription(Description)
    self._Description = Description

    return self
end

function Command:SetLongDescription(LongDescription)
    self._LongDescription = LongDescription

    return self
end

function Command:SetCategory(Category)
    assert(Category:match("[^%w%s]") == nil, "Invalid category, "..Category.." contains invalid characters. Alphanumeric only.")

    self._Category = Category

    return self
end

function Command:AddSubCommand(Name, Handle)
    return Command(Name, Handle, self._Name)
end

function Command:AddAlias(Name)
    assert(self._IsSubCommand == false, "You cannot add an alias to a sub command.")

    CommandAlias[Name] = self._Name

    return self
end

--[[ Command Getters ]]
function Command:GetName()
    return self._Name
end

function Command:GetDescription()
    return self._Description
end

function Command:GetLongDescription()
    return self._LongDescription
end

function Command:GetCategory()
    return self._Category
end

function Command:GetSubCommands()
    return SubCommands[self._Name]
end

function Command:GetSubCommand(Name)
    return (SubCommands[self._Name] ~= nil and SubCommands[self._Name][Name] or nil)
end

function Command:Exec(...)
    return self._Handle(...)
end

function Exists(Name)
    return (Commands[Name] ~= nil)
end

function GetCommand(Name)
    return Commands[Name]
end

function GetAllCommands()
    return Commands
end

function GetSubCommand(ParentName, Name)
    return SubCommands[ParentName][Name]
end

function GetAllSubCommands(ParentName)
    return SubCommands[ParentName]
end

function GetAliasCommand(Alias)
    return Commands[CommandAlias[Alias]]
end

return {
    Command = Command,
    GetCommand = GetCommand,
    GetAllCommands = GetAllCommands,
    GetSubCommand = GetSubCommand,
    GetAllSubCommands = GetAllSubCommands,
    GetAliasCommand = GetAliasCommand,
    Exists = Exists
}