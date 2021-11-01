--[[ Variables ]]
local StillAnswering = {}
local TimeToAnswer = 15 -- 15 Seconds

local Categories = {
    ["General Knowledge"] = "9",
    ["Books"] = "10",
    ["Film"] = "11",
    ["Music"] = "12",
    ["Musicals & Theatres"] = "13",
    ["Television"] = "14",
    ["Video Games"] = "15",
    ["Board Games"] = "16",
    ["Science & Nature"] = "17",
    ["Computers"] = "18",
    ["Mathematics"] = "19",
    ["Mythology"] = "20",
    ["Sports"] = "21",
    ["Geography"] = "22",
    ["History"] = "23",
    ["Politics"] = "24",
    ["Art"] = "25",
    ["Celebrities"] = "26",
    ["Animals"] = "27",
    ["Vehicles"] = "28",
    ["Comics"] = "29",
    ["Gadgets"] = "30",
    ["Japanese Anime & Manga"] = "31",
    ["Cartoon & Animations"] = "32"
}

local CategoriesIndexMap = {
    "General Knowledge",
    "Books",
    "Film",
    "Music",
    "Musicals & Theatres",
    "Television",
    "Video Games",
    "Board Games",
    "Science & Nature",
    "Computers",
    "Mathematics",
    "Mythology",
    "Sports",
    "Geography",
    "History",
    "Politics",
    "Art",
    "Celebrities",
    "Animals",
    "Vehicles",
    "Comics",
    "Gadgets",
    "Japanese Anime & Manga",
    "Cartoon & Animations"
}

local IndexToAnswer = {
    "a",
    "b",
    "c",
    "d"
}

local AnswerToIndex = {
    ["a"] = 1,
    ["b"] = 2,
    ["c"] = 3,
    ["d"] = 4
}

--[[ Functions ]]
local function ShuffleAnswers(Answers)
    for i = 1, 4, 1 do
        RInt = math.random(1, #Answers)
        local This, New = Answers[i], Answers[RInt]

        Answers[i] = New
        Answers[RInt] = This
    end

    return Answers
end

local function DecodeBody(Body)
    Body.results[1].category = Query.urldecode(Body.results[1].category)
    Body.results[1].question = Query.urldecode(Body.results[1].question)
    Body.results[1].correct_answer = Query.urldecode(Body.results[1].correct_answer)
    
    for i = 1, #Body.results[1].incorrect_answers, 1 do
        Body.results[1].incorrect_answers[i] = Query.urldecode(Body.results[1].incorrect_answers[i])
    end 

    return Body
end

--[[ Commands ]]
CommandManager.Command("coin", function(Args, Payload)
    Args = nil
    
    math.randomseed(os.time())
    local RInt = math.random(1, 2)

    SimpleEmbed(Payload, (RInt == 1 and "Heads" or "Tails"))
end):SetCategory("Misc Commands"):SetDescription("Flip a coin.")

CommandManager.Command("whois", function(Args, Payload)
    local Member = Payload.member

    if Payload.mentionedUsers and Payload.mentionedUsers.first then
        Member = Payload.guild:getMember(Payload.mentionedUsers.first)
    elseif Args[2] and tonumber(Args[2]) ~= nil then
        Member = Payload.guild:getMember(Args[2])
    end

    assert(Member ~= nil and Member, "sorry however there was an issue fetching information.")

    assert(Member.name and Member.user.discriminator and Member.id and Member.status and Member.joinedAt and Member.roles, "there was an issue fetching required information.")

    local AllRoleNames = {}

    Member.roles:forEach(function(Role)
        table.insert(AllRoleNames, Role.mentionString)
    end)

    local Status = "Not available."
    if Member.status then
        Status = Member.status:sub(1, 1):upper()..Member.status:sub(2, #Member.status)
    end

    Payload:reply {
        embed = {
            ["color"] = Config.EmbedColour,
            ["thumbnail"] = {
                ["url"] = Member.user:getAvatarURL()
            },
            ["fields"] = {
                {
                    ["name"] = "Name",
                    ["value"] = F("%s\n(``%s``)", Member.name, Member.id),
                    ["inline"] = true
                },
                {
                    ["name"] = "Discriminator",
                    ["value"] = Member.user.discriminator,
                    ["inline"] = true
                },
                {
                    ["name"] = "Status",
                    ["value"] = Status,
                    ["inline"] = true
                },
                {
                    ["name"] = "Joined Discord",
                    ["value"] = (Member.joinedAt and F("<t:%d:F>", Discordia.Date().fromSnowflake(Member.id):toSeconds()) or "Not available"),
                    ["inline"] = true
                },
                {
                    ["name"] = "Joined GMR Discord",
                    ["value"] = (Member.joinedAt and F("<t:%d:F>", Discordia.Date().fromISO(Member.joinedAt):toSeconds()) or "Not available"),
                    ["inline"] = true
                },
                {
                    ["name"] = "Boosting Since",
                    ["value"] = (Member.premiumSince and F("<t:%d:F>", Discordia.Date().fromISO(Member.premiumSince):toSeconds()) or "Not boosting."),
                    ["inline"] = true
                },
                {
                    ["name"] = "Roles",
                    ["value"] = table.concat(AllRoleNames, ", ")
                }
            }
        }
    }
end):SetCategory("Misc Commands"):SetDescription("Get info about a user on discord."):SetLongDescription(F([[
    An example usage can be found below:

    *%swhois*

    The above will provide information about you.

    *%swhois <@%s>*

    Supports mentions.
    
    *%swhois 843951774834360371*

    Supports Discord User IDs.
]], Prefix, Prefix, Config["GMRUID"], Prefix))

local TriviaCommand = CommandManager.Command("trivia", function(Args, Payload)
    assert(not StillAnswering[Payload.author.id], "you are still answering a previous question.")

    local TriviaArgs = "&type=multiple&encode=url3986"

    if Args[2] ~= nil then
        Args[2] = tonumber(Args[2])
        assert(Args[2] ~= nil and CategoriesIndexMap[Args[2]] ~= nil, F("that is an invalid category, use ``%strivia categories`` to list them all.", Prefix)) 

        TriviaArgs = TriviaArgs.."&category="..Categories[CategoriesIndexMap[Args[2]]]
    end

    local Res, Body = HTTP.request("GET", "https://opentdb.com/api.php?amount=1"..TriviaArgs)
    Body = JSON.decode(Body)

    assert(Res.code == 200 and Body.response_code == 0, "there was a problem finding a question, please try again.")

    Body = DecodeBody(Body)

    local QA = F("**%s**\n \n", Body.results[1].question)

    table.insert(Body.results[1].incorrect_answers, Body.results[1].correct_answer)

    local Answers = ShuffleAnswers(Body.results[1].incorrect_answers)

    local TriviaEmbed = {
        ["description"] = F("%s's trivia question!\n \n%s", Payload.author.mentionString, QA),
        ["fields"] = {
            {
                ["name"] = "Difficulty",
                ["value"] = F("``%s``", Body.results[1].difficulty),
                ["inline"] = true
            },
            {
                ["name"] = "Category",
                ["value"] = F("``%s``", Body.results[1].category),
                ["inline"] = true
            }
        },
        ["color"] = Config.EmbedColour
    }

    for i = 1, 4 do
        TriviaEmbed.description = TriviaEmbed.description..F("%s) %s\n", IndexToAnswer[i], Answers[i])
    end

    Payload:reply {
        embed = TriviaEmbed
    }

    StillAnswering[Payload.author.id] = true

    local Suc, Payload2 = BOT:waitFor("messageCreate", (TimeToAnswer * 1000), function(Payload2)
        if Payload.author == Payload2.author and #Payload2.content == 1 and AnswerToIndex[Payload2.content] ~= nil then
            return Payload2
        end
    end)

    StillAnswering[Payload.author.id] = false

    assert(Suc == true, "you took too long to answer.")

    assert(Answers[AnswerToIndex[Payload2.content]] == Body.results[1].correct_answer, "that is not the correct answer!\n \nCorrect Answer: ``"..Body.results[1].correct_answer.."``")

    SimpleEmbed(Payload2, F("%s correct, the answer was indeed ``%s``!", Payload2.author.mentionString, Body.results[1].correct_answer))
end):SetCategory("Misc Commands"):SetDescription("Multiple choice trivia with 24 categories.")

TriviaCommand:AddSubCommand("categories", function(Args, Payload)
    Args = nil

    local CategoryString = ""
    for i = 1, #CategoriesIndexMap, 1 do
        CategoryString = CategoryString..F("\n``%s%s``: %s", (i < 10 and "0" or ""), i, CategoriesIndexMap[i])
    end
    
    SimpleEmbed(Payload, F("%s\n \nSimply do ``%strivia [Category Number]`` to get a question from a specific category.", CategoryString, Prefix))
end)