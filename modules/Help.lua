--[[ Command ]]
CommandManager.Command("help", function(Args, Payload)
	if Args[2] then
		local Command = CommandManager.GetCommand(Args[2])
		assert(Command ~= nil, "that command does not exist.")
		
		local Description = Command:GetLongDescription()
		assert(Description ~= nil, "there is no additional information available for that command.")

		return SimpleEmbed(Payload, F("Additional information for command ``%s%s``:\n \n%s", Prefix, Args[2], Description))
	end

	local Commands = {}

	for Name, Command in pairs(CommandManager.GetAllCommands()) do
		local Category = Command:GetCategory()

		if Category then
			local Description = Command:GetDescription()

			local Data = {
				["Name"] = F("``%s%s`` %s", Prefix, Name, (Description ~= nil and "*"..Description.."*" or "")),
				["Category"] = Category
			}

			local SubCommands = CommandManager.GetAllSubCommands(Name)
			if SubCommands then
				Data["SubCommands"] = {}

				for _, SubCommand in pairs(SubCommands) do
					local SubCommandDescription = SubCommand:GetDescription()

					table.insert(Data["SubCommands"], F("\t``↳ %s`` %s", SubCommand:GetName(), (SubCommandDescription ~= nil and "*"..SubCommandDescription.."*" or "")))
				end
			end 

			table.insert(Commands, Data)
		end
	end

	table.sort(Commands, function(A, B)
		return A["Category"] < B["Category"]
	end)

	local HelpEmbed = {
		["title"] = "Here are all the available coomands:",
		["color"] = Config.EmbedColour,
		["description"] = "",
		["footer"] = {
			["text"] = F("For more information about how to use a command type %shelp [command name]", Prefix)
		}
	}

	local CurrentCategory

	for _, Data in pairs(Commands) do
		if not CurrentCategory or CurrentCategory ~= Data.Category then
			HelpEmbed.description = HelpEmbed.description.."\n\n"..Data.Category

			CurrentCategory = Data.Category
		end
	
		HelpEmbed.description = HelpEmbed.description.."\n"..Data.Name..(Data.SubCommands ~= nil and "\n"..table.concat(Data.SubCommands, "\n") or "")
	end

	Payload:reply {
		embed = HelpEmbed
	}
end)