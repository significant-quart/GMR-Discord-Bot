--[[ Variables ]]
local UpdateInterval = 30
local GMRPriceEmbed

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

local function GetCoinGeckoPrice(Price)
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
    
    return "$"..(Exponent > 0 and Characteristic..Zeros or Zeros..Characteristic)
end

local function GetPancakeSwapPrice(Price)
    local ZeroOffset = #Price:match("%.0+") + 2
    local RoundedNum = Price:sub(ZeroOffset, (#Price - ZeroOffset > 2 and ZeroOffset + 2 or #Price))

    return "$0."..("0"):rep(ZeroOffset - 3)..RoundedNum
end

--[[ Commands ]]
CommandManager.Command("price", function(Args, Payload)
    assert(GMRPriceEmbed ~= nil, F("sorry however there is no price information available at the moment, please allow up to %d seconds.", UpdateInterval))

    Payload:reply {
        embed = GMRPriceEmbed
    }
end):SetCategory("GMR Commands"):SetDescription("Current price, 24h change and more about GMR.")

--[[ Price Updates ]]
Interval(UpdateInterval * 1000, function()
    local GMRData = {}

    local ThisGMRPriceEmbed = {
        ["title"] = "GMR Coin Price Data",
        ["url"] = "https://gmr.finance/",
        ["description"] = F([[

            [Buy/Sell <:%s>](https://app.apeswap.finance/swap?outputCurrency=0x0523215dcafbf4e4aa92117d13c6985a3bef27d7)

            Charts: [DEXTools](https://www.dextools.io/app/bsc/pair-explorer/0x007ace5397b56e19a9436fba289d7fed71c49328) | [poocoin](https://poocoin.app/tokens/0x0523215dcafbf4e4aa92117d13c6985a3bef27d7)
        ]], Config["GMREID"]),
        ["color"] = Config.EmbedColour,
        ["thumbnail"] = {
            ["url"] = "https://cdn.discordapp.com/attachments/859171545418432533/887359235774623794/header-logo.png"
        },
        ["fields"] = {}
    }

    local SucCG, CoinGecko = pcall(APIGet, "https://api.coingecko.com/api/v3/simple/price?ids=gmr-finance&vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&include_24hr_change=true&include_last_updated_at=true")

    if SucCG == true and TableIndexExist(CoinGecko, { "gmr-finance" })  then
        local CoinGeckoData = CoinGecko["gmr-finance"]

        GMRData["CoinGecko"] = {
            ["Price"] = GetCoinGeckoPrice(tostring(CoinGeckoData["usd"])),
            ["24hVol"] = math.round(CoinGeckoData["usd_24h_vol"], 2),
            ["24hChange"] = math.round(CoinGeckoData["usd_24h_change"], 2)
        }
    end

    local SucPS, PancakeSwap = pcall(APIGet, "https://api.pancakeswap.info/api/v2/tokens/0x0523215dcafbf4e4aa92117d13c6985a3bef27d7")
    
    if SucPS == true and TableIndexExist(PancakeSwap, { "data", "price" }) then
        GMRData["PancakeSwap"] = {
            ["Price"] = GetPancakeSwapPrice(PancakeSwap["data"]["price"]),
        }
    end

    local SucBQ, BitQuery = pcall(APIGet, "https://graphql.bitquery.io", {
        { "Content-Type", "application/json" },
        { "Content-Length", 600 },
        { "X-API-KEY", "BQY5WwW4iwp2fUEL8DVFrgXt3NEzWqZz" }
    }, [[{"query":"{\n  ethereum(network: bsc) {\n    dexTrades(\n      baseCurrency: {is: \"0x0523215DCafbF4E4aA92117d13C6985a3BeF27D7\"}\n      quoteCurrency: {is: \"0x55d398326f99059ff775485246999027b3197955\"}\n      options: {desc: [\"block.height\", \"transaction.index\"], limit: 1}\n    ) {\n      block {\n        height\n        timestamp {\n          time(format: \"%Y-%m-%d %H:%M:%S\")\n        }\n      }\n      transaction {\n        index\n      }\n      baseCurrency {\n        symbol\n      }\n      quoteCurrency {\n        symbol\n      }\n      quotePrice\n    }\n  }\n}","variables":"{}"}]])

    if SucBQ == true and TableIndexExist(BitQuery, {
        "data",
        "ethereum",
        "dexTrades",
        1,
        "quotePrice"
    }) then
        GMRData["BitQuery"] = {
            ["Price"] = GetCoinGeckoPrice(tostring(BitQuery["data"]["ethereum"]["dexTrades"][1]["quotePrice"]))
        }
    end

    if not GMRData["CoinGecko"] and not GMRData["PancakeSwap"] and not GMRData["BitQuery"] then
        ThisGMRPriceEmbed = nil

        return
    end

    table.insert(ThisGMRPriceEmbed["fields"], {
        ["name"] = F("Price <:%s>", Config["CoingeckEID"]),
        ["value"] = (GMRData["CoinGecko"] ~= nil and GMRData["CoinGecko"]["Price"] or "N/A"),
        ["inline"] = true
    })

    table.insert(ThisGMRPriceEmbed["fields"], {
        ["name"] = F("Price <:%s>", Config["PancakeEID"]),
        ["value"] = (GMRData["PancakeSwap"] ~= nil and GMRData["PancakeSwap"]["Price"] or "N/A"),
        ["inline"] = true
    })

    table.insert(ThisGMRPriceEmbed["fields"], {
        ["name"] = F("Price <:%s>", Config["BitqueryEID"]),
        ["value"] = (GMRData["BitQuery"] ~= nil and GMRData["BitQuery"]["Price"] or "N/A"),
        ["inline"] = true
    })

    table.insert(ThisGMRPriceEmbed["fields"], {
        ["name"] = F("24h Change <:%s>", Config["CoingeckEID"]),
        ["value"] = (GMRData["CoinGecko"] ~= nil and GMRData["CoinGecko"]["24hChange"] and F("%s%% %s", GMRData["CoinGecko"]["24hChange"], (GMRData["CoinGecko"]["24hChange"] > 0 and ":chart_with_upwards_trend:" or ":chart_with_downwards_trend:")) or "N/A"),
        ["inline"] = false
    })

    table.insert(ThisGMRPriceEmbed["fields"], {
        ["name"] = F("24h Volume <:%s>", Config["CoingeckEID"]),
        ["value"] = (GMRData["CoinGecko"] ~= nil and GMRData["CoinGecko"]["24hVol"] and F("$%s", CommaNumber(GMRData["CoinGecko"]["24hVol"])) or "N/A"),
        ["inline"] = false
    })

    GMRPriceEmbed = ThisGMRPriceEmbed
end, true)