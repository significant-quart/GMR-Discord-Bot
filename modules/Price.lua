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

    return "0."..("0"):rep(ZeroOffset - 3)..RoundedNum
end

--[[ Commands ]]
CommandManager.Command("price", function(Args, Payload)
    assert(GMRPriceEmbed ~= nil, F("sorry but there is no price information available at the moment, please allow up to %d seconds.", UpdateInterval))

    Payload:reply {
        embed = GMRPriceEmbed
    }
end):SetCategory("GMR Commands"):SetDescription("Current price, 24h change and more about GMR.")

--[[ Price Updates ]]
Interval(UpdateInterval * 1000, function()
    local GMRData = {
        ["Symbol"] = "GMR"
    }

    GMRPriceEmbed = {
        ["title"] = "GMR Coin Price Data",
        ["url"] = "https://gmr.finance/",
        ["description"] = [[
            Buy/Sell GMR: [Coinsbit](https://coinsbit.io/trade_classic/GMR_mUSDT) | [Biki](https://www.biki.com/en_US/trade/GMR_USDT) 

            Charts: [Bogged Finance](https://charts.bogged.finance/?token=0x0523215DCafbF4E4aA92117d13C6985a3BeF27D7) | [poocoin](https://poocoin.app/tokens/0x0523215dcafbf4e4aa92117d13c6985a3bef27d7)
        ]],
        ["color"] = Config.EmbedColour,
        ["thumbnail"] = {
            ["url"] = "https://cdn.discordapp.com/attachments/843952944922492999/843982060795854888/GMR.png"
        },
        ["fields"] = {},
        ["footer"] = {
            ["text"] = "Token Address: 0x0523215DCafbF4E4aA92117d13C6985a3BeF27D7"
        }
    }

    local SucCG, CoinGecko = pcall(APIGet, "https://api.coingecko.com/api/v3/simple/price?ids=gmr-finance&vs_currencies=usd&include_market_cap=true&include_24hr_vol=true&include_24hr_change=true&include_last_updated_at=true")

    if SucCG == true and CoinGecko["gmr-finance"] then
        local CoinGecko = CoinGecko["gmr-finance"]

        GMRData["CoinGecko"] = {
            ["Price"] = GetCoinGeckoPrice(tostring(CoinGecko["usd"])),
            ["24hVol"] = math.round(CoinGecko["usd_24h_vol"], 2),
            ["24hChange"] = math.round(CoinGecko["usd_24h_change"], 2)
        }
    end

    local SucPS, PancakeSwap = pcall(APIGet, "https://api.pancakeswap.info/api/v2/tokens/0x0523215dcafbf4e4aa92117d13c6985a3bef27d7")
    
    if SucPS == true then
        GMRData["PancakeSwap"] = {
            ["Price"] = GetPancakeSwapPrice(PancakeSwap["data"]["price"]),
        }
    end

    local SucBQ, BitQuery = pcall(APIGet, "https://graphql.bitquery.io", {
        { "Content-Type", "application/json" },
        { "Content-Length", 600 },
        { "X-API-KEY", "BQY5WwW4iwp2fUEL8DVFrgXt3NEzWqZz" }
    }, [[{"query":"{\n  ethereum(network: bsc) {\n    dexTrades(\n      baseCurrency: {is: \"0x0523215DCafbF4E4aA92117d13C6985a3BeF27D7\"}\n      quoteCurrency: {is: \"0x55d398326f99059ff775485246999027b3197955\"}\n      options: {desc: [\"block.height\", \"transaction.index\"], limit: 1}\n    ) {\n      block {\n        height\n        timestamp {\n          time(format: \"%Y-%m-%d %H:%M:%S\")\n        }\n      }\n      transaction {\n        index\n      }\n      baseCurrency {\n        symbol\n      }\n      quoteCurrency {\n        symbol\n      }\n      quotePrice\n    }\n  }\n}","variables":"{}"}]])

    if SucBQ == true then
        GMRData["BitQuery"] = {
            ["Price"] = GetCoinGeckoPrice(tostring(BitQuery["data"]["ethereum"]["dexTrades"][1]["quotePrice"]))
        }
    end

    if not GMRData["CoinGecko"] and not GMRData["PancakeSwap"] and not GMRData["BitQuery"] then
        p(#GMRData)
        GMRPriceEmbed = nil

        return
    end

    table.insert(GMRPriceEmbed["fields"], {
        ["name"] = "Price ($) <:coingecko:843985310379016223>",
        ["value"] = (GMRData["CoinGecko"] ~= nil and GMRData["CoinGecko"]["Price"] or "N/A"),
        ["inline"] = true
    })

    table.insert(GMRPriceEmbed["fields"], {
        ["name"] = "Price ($) <:pancakeswap:843985675816665099>",
        ["value"] = (GMRData["PancakeSwap"] ~= nil and GMRData["PancakeSwap"]["Price"] or "N/A"),
        ["inline"] = true
    })

    table.insert(GMRPriceEmbed["fields"], {
        ["name"] = "Price ($) <:bitquery:858844249419022336>",
        ["value"] = (GMRData["BitQuery"] ~= nil and GMRData["BitQuery"]["Price"] or "N/A"),
        ["inline"] = true
    })

    table.insert(GMRPriceEmbed["fields"], {
        ["name"] = "24h Change ($) <:coingecko:843985310379016223>",
        ["value"] = (GMRData["CoinGecko"] ~= nil and GMRData["CoinGecko"]["24hChange"] and F("%s%% %s", GMRData["CoinGecko"]["24hChange"], (GMRData["CoinGecko"]["24hChange"] > 0 and ":chart_with_upwards_trend:" or ":chart_with_downwards_trend:")) or "N/A"),
        ["inline"] = false
    })

    table.insert(GMRPriceEmbed["fields"], {
        ["name"] = "24h Volume ($) <:coingecko:843985310379016223>",
        ["value"] = (GMRData["CoinGecko"] ~= nil and GMRData["CoinGecko"]["24hVol"] and F("$%s", CommaNumber(GMRData["CoinGecko"]["24hVol"])) or "N/A"),
        ["inline"] = false
    })
end, true)