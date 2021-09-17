--[[ External Librarys ]]
local JSON = require("json")
local Routine = require("timer")
local HTTP = require("coro-http")
local Query = require("querystring")
local Spawn = require("coro-spawn")
local FileReader = require("fs")
local PP = require("pretty-print")
local SQL = require("sqlite3")

--[[ Config ]]
local Config = assert(JSON.decode(FileReader.readFileSync("Base.json")), "Failed to read or parse Base.json!")

if Config._DEBUG == true then
	Config["GMRGID"] = "843951362907439135"
	Config["GMRUID"] = "843951774834360371"
	Config["GMRVerifyRID"] = "883084646433300501"
	Config["GMRVerifyCID"] = "883087815326466048"
	Config["GMRFeedbackCID"] = "885270081670643772"
	Config["CoingeckEID"] = "coingecko:843985310379016223"
	Config["BitqueryEID"] = "bitquery:858844249419022336"
	Config["ApeswapEID"] = "apeswap:887821326138634261"
	Config["GMREID"] = "gmr:887332510269313084"
 	Config["PancakeEID"] = "pancakeswap:843985675816665099"
	Config["FeedbackDelay"] = 10
	Config["CoCAPIKey"] = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzUxMiIsImtpZCI6IjI4YTMxOGY3LTAwMDAtYTFlYi03ZmExLTJjNzQzM2M2Y2NhNSJ9.eyJpc3MiOiJzdXBlcmNlbGwiLCJhdWQiOiJzdXBlcmNlbGw6Z2FtZWFwaSIsImp0aSI6IjQ1YmM1ZDQ0LWVmN2MtNDNhZi1hZmE1LTMzMGQ1YTI4NjNkMSIsImlhdCI6MTYzMDE3MjI1Mywic3ViIjoiZGV2ZWxvcGVyLzBiOTMxMTg0LWQwODctODgwMi1mMWFlLTYzMTczZmI1Y2YwMSIsInNjb3BlcyI6WyJjbGFzaCJdLCJsaW1pdHMiOlt7InRpZXIiOiJkZXZlbG9wZXIvc2lsdmVyIiwidHlwZSI6InRocm90dGxpbmcifSx7ImNpZHJzIjpbIjkyLjcuMTY4LjQxIl0sInR5cGUiOiJjbGllbnQifV19.j3xHD8iOXuKrwGn-NlXj4mwzf6XZ7-Mm63ycL55qDU27OCN7MJTrCRm33zHPRreeOtl0P03pfJo5UeP85GLV8Q"
else
	Config["GMRGID"] = "835927915325161523"
	Config["GMRUID"] = "887775198944821279"
    Config["GMRVerifyRID"] = "840619660244287489"
    Config["GMRVerifyCID"] = "840634281336242198"
	Config["GMRFeedbackCID"] = "887788240814342245"
	Config["CoingeckEID"] = "coingecko:887798321903710268"
	Config["BitqueryEID"] = "BitQuery:887798309174018068"
	Config["ApeswapEID"] = "apeswap:887821797012156486"
	Config["GMREID"] = "GMR:840895605017935872"
	Config["PancakeEID"] = "pancakeswap:887798337707855932"
	Config["FeedbackDelay"] = 86400
	Config["CoCAPIKey"] = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzUxMiIsImtpZCI6IjI4YTMxOGY3LTAwMDAtYTFlYi03ZmExLTJjNzQzM2M2Y2NhNSJ9.eyJpc3MiOiJzdXBlcmNlbGwiLCJhdWQiOiJzdXBlcmNlbGw6Z2FtZWFwaSIsImp0aSI6ImY3MTlkMDBmLTZmMzEtNGEyYy1hYWQwLWRlMjU1YWZlMWVkMyIsImlhdCI6MTYyNDkxNTUyMywic3ViIjoiZGV2ZWxvcGVyLzBiOTMxMTg0LWQwODctODgwMi1mMWFlLTYzMTczZmI1Y2YwMSIsInNjb3BlcyI6WyJjbGFzaCJdLCJsaW1pdHMiOlt7InRpZXIiOiJkZXZlbG9wZXIvc2lsdmVyIiwidHlwZSI6InRocm90dGxpbmcifSx7ImNpZHJzIjpbIjE1OS42NS4yMS45NyJdLCJ0eXBlIjoiY2xpZW50In1dfQ.2MRdMkmVJdlwML3IQXnj53t5aED2BLCzvRzg2flIb4vTziij_SgGf4NMYyTDrKInjqjh_VRCqtlf1khs2MvXlQ"
end

--[[ Discord Utils ]]
local Discordia = require("discordia")
local BOT = Discordia.Client {
	cacheAllMembers = true,
	syncGuilds = true,
	dateTime = "%F @ %T",
	logLevel = (Config._DEBUG == true and 4 or 3)
}
Discordia.extensions()

--[[ Logger ]]
local Logger = Discordia.Logger((Config._DEBUG == false and 3 or 4), "%F @ %T", "GMR.log")
local Log = function(Level, ...) Logger:log(Level, ...) end

--[[ Command Handler ]]
local CommandManager = require("CM")

--[[ Functions ]]
local function SimpleEmbed(Channel, Description)
	local Embed = {
		["description"] = Description,
		["color"] = Config.EmbedColour
	}

	if Channel then
		local Channel = (Channel.channel or Channel)

		return Channel:send {
			embed = Embed
		}
	end 

	return Embed
end

local function TableIndexExist(t, Indexes)
	local CurrentPoint = t

	for _, Index in ipairs(Indexes) do
		if CurrentPoint[Index] then
			CurrentPoint = CurrentPoint[Index]
		else
			return false
		end
	end

	return true
end

local function ReturnRestOfCommand(AllArgs, StartIndex, Seperator, EndIndex)
    return table.concat(AllArgs, (Seperator ~= nil and type(Seperator) == "string" and Seperator or " "), StartIndex, EndIndex)
end

local function Interval(Ms, Func)
	return Routine.setInterval(Ms, function()
		coroutine.wrap(function()
			local Suc, Err = pcall(Func)

			if not Suc and Config._DEBUG == true then
				Log(1, Err or "")
			end
		end)()
	end)	
end

local function CommaNumber(N)
    local _, _, Minus, NInt, Decimal = tostring(N):find('([-]?)(%d+)([.]?%d*)')

    NInt = NInt:reverse():gsub("(%d%d%d)", "%1,")
    
    return Minus..NInt:reverse():gsub("^,", "")..Decimal 
end

--[[ Module Func ]]
local function LoadModule(Module)
	local FilePath = Config.ModuleDir.."/"..Module..".lua"
	local Code = assert(FileReader.readFileSync(FilePath))

	Config[Module] = {}
	local Env = setmetatable({
		require = require,

		Discordia = Discordia,
		BOT = BOT,

		JSON = JSON,
		Routine = Routine,
		HTTP = HTTP,
		Spawn = Spawn,
		FileReader = FileReader,
		PP = PP,
		Query = Query,
		SQL = SQL,

		Config = Config,
		Module = Module,

		InitConfig = InitConfig,

		CommandManager = CommandManager,

		Log = Log, 
		Logger = Logger,
		Round = math.round,
		F = string.format,
		SimpleEmbed = SimpleEmbed,
		ReturnRestOfCommand = ReturnRestOfCommand,
		Interval = Interval,
		CommaNumber = CommaNumber,
		TableIndexExist = TableIndexExist,

		ModuleDir = Config.ModuleDir,
		Prefix = Config.Prefix,
		DefaultInterval = Config.DefaultInterval,
	}, {__index = _G})

	local Func = assert(loadstring(Code, "@"..Module, "t", Env))

	return Func()
end

--[[ Init ]]
do
	local Token = assert(FileReader.readFileSync("./token.txt"):split("\n")[1], "Could not find bot token. Please create a file called token.txt in the directory of your bot and put your bot token inside of it.")

	assert(FileReader.existsSync(Config.ModuleDir), "Could not find module directory, are you sure it is valid?")

	for File, Type in FileReader.scandirSync(Config.ModuleDir) do
		if Type == "file" then
			local FileName = File:match("(.*)%.lua")
			if FileName then
				local Suc, Err = pcall(LoadModule, FileName)

				if Suc == true then
					Log(3, "Module loaded: "..FileName)
				else
					Log(1, "Failed to load module "..FileName.." ["..Err.."]")

					if Err:lower():find("fatal") then
						_G = nil

						process:exit(1)
					end
				end
			end
		end
	end

	BOT:run("Bot "..Token)
end