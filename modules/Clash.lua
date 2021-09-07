--[[ Variables ]]
local ClashCache = assert(JSON.decode(FileReader.readFileSync(F("%s/ClashPlayers.json", Config.ModuleDir))), "failed to load Clash of Clans player cache.")
local ClashEmoji = assert(JSON.decode(FileReader.readFileSync("./vendor/CoC/ClashEmojis.json")), "failed to load Clash of Clans emojis.")
local Headers = { 
	{ "Accept", "application/json" }, 
	{ "authorization", F("Bearer %s", Config["CoCAPIKey"]) } 
}

--[[ Functions ]]
local function VerifyProcess(Payload, Level)
	if Level == 1 then
		ClashCache[Payload.author.id] = {
			["Completion"] = 1
		}

		SimpleEmbed(Payload.author, "**Please provide you Clash of Clans tag.**\n \nYou can find your tag by following these steps:\n1. Launch the game and click the blue button in the top left.\n2. Below your name there should be a # followed by numbers and letters. I.e. #1234abcde.\n3. Send your tag in this chat.\n \nNote: if you provide an incorrect tag you can resart by typing ``"..Prefix.."unlink`` in the GMR.finance server.")
	elseif Level == 2 then
		local Tag = Payload.content

		if Tag:sub(1, 1) == "#" then
			Tag = Tag:sub(2, #Tag)
		end

		if Tag:match("%W") then return SimpleEmbed(Payload.author, "The tag you provided is not valid, numbers and letters only.") end

		ClashCache[Payload.author.id]["Tag"] = Tag
		ClashCache[Payload.author.id]["Completion"] = 2

		SimpleEmbed(Payload.author, "**Please provide your API token.**\n \nYou can find your API token by following these steps:\n1. Go to settings (Cogs above shop button).\n2. Click More Settings.\n3. Scroll Down to API Token and press show.\n4. Send your token in this chat.\n \n**Do not share this token with anyone, this is how we know you own the account you are trying to link!**")
	elseif Level == 3 then
		local Token = Payload.content

		if Token:match("%W") then return SimpleEmbed(Payload.author, "The token you provided is not valid, numbers and letters only.") end

		local Res, Body = HTTP.request("POST", F("https://api.clashofclans.com/v1/players/%%23%s/verifytoken", ClashCache[Payload.author.id]["Tag"]), Headers, JSON.encode({
			["token"] = Token
		}))

		if Res.code ~= 200 then return SimpleEmbed(Payload.author, "Token verification un-successful!\n \nPlease try again.") end

		Body = JSON.decode(Body)

		if Body.status ~= "ok" then return SimpleEmbed(Payload.author, "The token you provided is not valid.") end
		
		SimpleEmbed(Payload.author, "Token verification successful!\n \nYour Clash of Clans account is now linked.")
		
		ClashCache[Payload.author.id]["Token"] = Token
		ClashCache[Payload.author.id]["Completion"] = 3
	end
end

--[[ Command ]]
local Clash = CommandManager.Command("coc", function(Args, Payload)
    assert(Args[2], "you didn't provide any arguments.")
end):SetCategory("Fun Commands"):SetDescription("Show off your Clash of Clans stats!")

--[[ Sub-Commands ]]
Clash:AddSubCommand("link", function(Args, Payload)
    assert(ClashCache[Payload.author.id] == nil, "you have already began or finished the linking process.")

	SimpleEmbed(Payload, Payload.author.mentionString.." please check your Discord DMs from "..BOT.user.mentionString..".")
	VerifyProcess(Payload, 1)
end):SetDescription("Link Clash of Clans account to Discord.")

Clash:AddSubCommand("unlink", function(Args, Payload)
    assert(ClashCache[Payload.author.id] ~= nil, "you haven't linked your Clash of Clans account to Discord.")

	ClashCache[Payload.author.id] = nil
	SimpleEmbed(Payload, Payload.author.mentionString.." your Clash of Clans account has been successfully unlinked.")
end):SetDescription("Unlink your Clash of Clans account from Discord.")

Clash:AddSubCommand("stats", function(Args, Payload)
    assert(ClashCache[Payload.author.id] ~= nil, "you haven't linked your Clash of Clans account to Discord.\n \nYou can do so by typing, ``"..Prefix.."coc link``.")

    local Res, Info = HTTP.request("GET", "https://api.clashofclans.com/v1/players/%23"..ClashCache[Payload.author.id]["Tag"], Headers)
    assert(Res.code == 200, "there was a problem getting your Clash of Clans information.")

    Info = JSON.decode(Info)

    local UserEmbed = {
        ["description"] = F("Level: %d", Info.expLevel),
        ["color"] = Config.EmbedColour,
        ["thumbnail"] = {
            ["url"] = ClashEmoji[F("TH%d%s", Info.townHallLevel, (Info.townHallWeaponLevel ~= nil and tostring(Info.townHallWeaponLevel) or ""))].URL
        },
        ["author"] = {
            ["name"] = F("%s%s", Info.name, Info.tag),
            ["icon_url"] = F("%s", (Info.clan ~= nil and Info.clan.badgeUrls and Info.clan.badgeUrls.medium or ""))
        },
        ["fields"] = {
            {
                ["name"] = F("Trophies <:%s:%s>", ClashEmoji["Trophy"].Name,  ClashEmoji["Trophy"].EID),
                ["value"] = F("```Current Trophies : %d\nBest Trophies    : %d```", Info.trophies, Info.bestTrophies),
                ["inline"] = true
            },
            {
                ["name"] = "Wins",
                ["value"] = F("```Attack Wins  : %d\nDefence Wins : %d```", Info.attackWins, Info.defenseWins),
                ["inline"] = true
            },
            {
                ["name"] = F("Builder Base: Level %d", Info.builderHallLevel),
                ["value"] = F("```Versus Wins    : %d\n\nVersus Trophies : %d\nBest Trophies   : %d```", Info.versusBattleWins, Info.versusTrophies, Info.bestVersusTrophies),
                ["inline"] = false
            }
        },
        ["footer"] = {
            ["text"] = "Informatiom may not be completely correct or up to date!"
        }
    }

    if Info.clan then
        table.insert(UserEmbed.fields, {
            ["name"] = F("Clan: %s%s", Info.clan.name, Info.clan.tag),
            ["value"] = F("```Level              : %s\n \nDonations          : %d\nDonations Received : %d```", Info.clan.clanLevel, Info.donations, Info.donationsReceived),
            ["inline"] = false
        })
    end

    for _, Hero in pairs(Info["heroes"]) do
        local HeroEName, HeroEID

        if Hero.name == "Battle Machine" then
            local Index

            if Hero.level < 10 then
                Index = 1
            elseif Hero.level < 20 then
                Index = 2
            elseif Hero.level < 26 then
                Index = 3
            else
                if Index < 30 then
                    Index = 4
                else
                    Index = 5
                end
            end

            HeroEName, HeroEID = ClashEmoji[Hero.name]["Levels"][Index].EName, ClashEmoji[Hero.name]["Levels"][Index].EID
        else
            HeroEName, HeroEID = ClashEmoji[Hero.name].EName, ClashEmoji[Hero.name].EID
        end
        table.insert(UserEmbed.fields, {
            ["name"] = F("%s <:%s:%s>", Hero.name, HeroEName, HeroEID),
            ["value"] = F("```Level: %d/%d```", Hero.level, Hero.maxLevel),
            ["inline"] = true
        })
    end

    if Info.league and Info.league.iconUrls and Info.league.iconUrls.small then
        UserEmbed["image"] = {
            ["url"] = Info.league.iconUrls.small
        }
    end
 
    Payload:reply {
        embed = UserEmbed
    }
end):SetDescription("Information about your Clash of Clans account. Ensure your account is linked!")

--[[ Events ]]
BOT:on("messageCreate", function(Payload)
	if Payload.guild ~= nil or Payload.author.bot == true or #Payload.content == 0 then return end

	if ClashCache[Payload.author.id] ~= nil then
		local User = ClashCache[Payload.author.id]

		if User["Completion"] == 3 then return end

		VerifyProcess(Payload, User["Completion"] + 1)
	end
end)

--[[ Interval ]]
coroutine.wrap(function()
	Routine.setInterval(1000, function()
		local Suc, Encoded = pcall(JSON.encode, ClashCache)

		if not Suc then return end

		FileReader.writeFileSync(F("%s/ClashPlayers.json", Config.ModuleDir), Encoded)
	end)
end)()