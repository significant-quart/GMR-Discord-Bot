--[[ Events ]]
BOT:on("messageCreate", function(Payload)
	if Payload.author.bot or Payload.guild == nil then return end

	local Content = Payload.content
	local Args = Content:split(" ")

	if Args[1] then
		if Args[1]:sub(1, #Prefix) == Prefix then
			local CommandArg = Args[1]:sub((#Prefix + 1), #Args[1])
			
			local Command = CommandManager.GetCommand(CommandArg)
			if not Command then
				Command = CommandManager.GetAliasCommand(CommandArg)
			end

			if Command then
				local CommandName = Command:GetName()
				local CommandCategory = Command:GetCategory()

				if not HasPermission(Payload.member, CommandName, CommandCategory, Payload) then 
					Log(2, "A user just entered a command they are not allowed to enter.")

					return SimpleEmbed(Payload, Payload.author.mentionString.." **you do not have permission to use that command.**")
				end

				Log(3, "Command "..CommandName.." entered by "..Payload.author.tag)

				local CommandSuc, Err = pcall(function()
					if Args[2] then
						local CommandSub = Command:GetSubCommand(Args[2])
						if CommandSub then
							return CommandSub:Exec(Args, Payload)
						end
					end

					Command:Exec(Args, Payload)
				end)

				if not CommandSuc and Err ~= nil then
					local _, Err2 = Err:match(":(%d+):(.+)")
					
					if Err2 ~= nil and #Err2 > 1 then
						Log(2, Err)
						SimpleEmbed(Payload, Payload.author.mentionString.." "..Err2)
					end
				end
			end
		end
	end
end)

BOT:on("ready", function()
	BOT:setGame({
		["name"] = Prefix.."help | DM to Give Feedback!",
		["type"] = 3
	})
end)