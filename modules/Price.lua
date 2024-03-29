--[[ Variables ]]
local GMRPriceEmbed
local ChainID, GMRContract = 56, "0xadca52302e0a6c2d5d68edcdb4ac75deb5466884"

local LastMessage

local Ready = false

--[[ Events ]]
BOT:on("ready", function()
    if Ready == true then return end

    Ready = true

    local PriceChannel, Err = BOT:getChannel(Config["PriceMCID"])
    if PriceChannel and not Err then
        local LatestMessage = PriceChannel:getLastMessage()

        if LatestMessage then
            LastMessage = LatestMessage
        end
    end
end)

--[[ Functions ]]
local function APIGet(URL, Headers, Body)
    local Res, Body = HTTP.request((Body ~= nil and "POST" or "GET"), URL, Headers, Body)

    assert(Res.code == 200, "")

    local Body = assert(JSON.decode(Body))
    
    return Body
end

local function GetSuperScript(N)
    local SuperScripts = {
        [0] = "⁰",
        [1] = "¹",
        [2] = "²",
        [3] = "³",
        [4] = "⁴",
        [5] = "⁵",
        [6] = "⁶",
        [7] = "⁷",
        [8] = "⁸",
        [9] = "⁹",
    }
    
    local N = tostring(N)
    local SuperN = ""

    for i = 1, #N, 1 do
        SuperN = SuperN..SuperScripts[tonumber(N:sub(i, i))]
    end

    return SuperN
end

local function GetPriceFromSF(Price, Sign)
    print(Price)
    if Price:sub(2, 2) == "e" then
        Price = Price:gsub("e", ".0e")
    end

    local Exponent = tonumber(Price:match("[+-]%d+"))
    local Characteristic = Price:match("%d%.%d+"):gsub("%.", "")
    local Characteristic = Characteristic:sub(1, #Characteristic > 3 and 3 or #Characteristic)

    local Zeros

    if Exponent > 0 then
        Zeros = ""
    else
        Zeros = "0."
        Exponent = Exponent + 1
    end

    Zeros = Zeros..string.rep("0", math.abs(Exponent))
    
    return (Sign and "$" or "")..(Exponent > 0 and Characteristic..Zeros or Zeros..Characteristic)
end

--[[ Commands ]]
CommandManager.Command("price", function(Args, Payload)
    assert(GMRPriceEmbed ~= nil, F("sorry however there is no price information available at the moment, please allow up to %d seconds.", Config["DefaultInterval"]))

    Payload:reply {
        embed = GMRPriceEmbed
    }
end):SetCategory("GMR Commands"):SetDescription("Current price, 24h change and more about GMR.")

--[[ Price Updates ]]
Interval(Config["DefaultInterval"] * 1000, function()
    local ThisGMRPriceEmbed = {
        ["title"] = "GMR Coin Price Data",
        ["url"] = "https://gmr.finance/",
        ["description"] = F([[

            [Buy GMR on <:%s>](https://app.apeswap.finance/swap?outputCurrency=0xadca52302e0a6c2d5d68edcdb4ac75deb5466884) | [Buy GMR on <:%s>](https://pancakeswap.finance/swap?outputCurrency=0xadca52302e0a6c2d5d68edcdb4ac75deb5466884)

            Charts: [DEXTools](https://www.dextools.io/app/bsc/pair-explorer/0xadca52302e0a6c2d5d68edcdb4ac75deb5466884) | [poocoin](https://poocoin.app/tokens/0xadca52302e0a6c2d5d68edcdb4ac75deb5466884)
        ]], Config["ApeswapEID"], Config["PancakeEID"]),
        ["color"] = Config.EmbedColour,
        ["thumbnail"] = {
            ["url"] = "https://cdn.discordapp.com/attachments/859171545418432533/887359235774623794/header-logo.png"
        },
        ["fields"] = {},
        ["footer"] = {
            ["text"] = "All token data is courtesy of dex.guru",
            ["icon_url"] = "https://cdn.discordapp.com/attachments/859171545418432533/889964116578545694/dexguru.png"
        }
    }

    local Success, Data = pcall(APIGet, F("https://api.dev.dex.guru/v1/chain/%d/tokens/%s/market", ChainID, GMRContract), {
        { "api-key", Config["API"]["DEXGuru"] }
    })

    if Success then
        table.insert(ThisGMRPriceEmbed["fields"], {
            ["name"] = F("Price"),
            ["value"] = (Data["price_usd"] ~= nil and tostring(math.round(Data["price_usd"], 5)) or "Unavailable"),
            ["inline"] = true
        })

        table.insert(ThisGMRPriceEmbed["fields"], {
            ["name"] = F("Liquidity"),
            ["value"] = (Data["liquidity_usd"] and F("$%s", CommaNumber(math.round(Data["liquidity_usd"], 0)) or "Unvailable")),
            ["inline"] = true
        })

        table.insert(ThisGMRPriceEmbed["fields"], {
            ["name"] = F("24h Volume"),
            ["value"] = (Data["volume_24h_usd"] and F("$%s", CommaNumber(math.round(Data["volume_24h_usd"], 0)) or "Unvailable")),
            ["inline"] = true
        })

        table.insert(ThisGMRPriceEmbed["fields"], {
            ["name"] = F("24h Change"),
            ["value"] = (Data["price_24h_delta"] ~= nil and F("%s%% %s", tostring(math.round(Data["price_24h_delta"] * 100, 2)), (Data["price_24h_delta"] > 0 and ":chart_with_upwards_trend:" or Data["price_24h_delta"] < 0 and ":chart_with_downwards_trend:" or "")) or "Unavailable"),
            ["inline"] = true
        })

        table.insert(ThisGMRPriceEmbed["fields"], {
            ["name"] = F("24h Change"),
            ["value"] = (Data["liquidity_24h_delta"] ~= nil and F("%s%% %s", tostring(math.round(Data["liquidity_24h_delta"] * 100, 2)), (Data["liquidity_24h_delta"] > 0 and ":chart_with_upwards_trend:" or Data["liquidity_24h_delta"] < 0 and ":chart_with_downwards_trend:" or "")) or "Unavailable"),
            ["inline"] = true
        })

        table.insert(ThisGMRPriceEmbed["fields"], {
            ["name"] = F("24h Change"),
            ["value"] = (Data["volume_24h_delta"] ~= nil and F("%s%% %s", tostring(math.round(Data["volume_24h_delta"] * 100, 2)), (Data["volume_24h_delta"] > 0 and ":chart_with_upwards_trend:" or Data["volume_24h_delta"] < 0 and ":chart_with_downwards_trend:" or "")) or "Unavailable"),
            ["inline"] = true
        })
    
        GMRPriceEmbed = ThisGMRPriceEmbed

        local PriceChannel, Err = BOT:getChannel(Config["PriceCID"])
        if PriceChannel and not Err then
            PriceChannel:setName(F("💲 %s", (Data["price_usd"] ~= nil and tostring(math.round(Data["price_usd"], 5)) or "Unavailable")))
        end

        local PriceChannel, Err = BOT:getChannel(Config["PriceMCID"])

        if PriceChannel and not Err then
            if LastMessage then
                LastMessage:update {
                    embed = GMRPriceEmbed
                }
            else
                LastMessage = PriceChannel:send {
                    embed = GMRPriceEmbed
                }
            end
        end
    else
        GMRPriceEmbed = nil
    end
end, true)