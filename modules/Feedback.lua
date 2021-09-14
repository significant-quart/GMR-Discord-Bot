--[[ Vatiables ]]
local Ready = false
local WaitTime = 30 -- 30 Seconds

local FeedBackOpen = true

local FeedbackC

local SentResponses = {}
local AwaitingResponse = {}

--[[ Events ]]
BOT:on("ready", function()
    if not Ready then 
        Ready = true

        FeedbackC = BOT:getChannel(Config["GMRFeedbackCID"])
    end
end)

BOT:on("messageCreate", function(Payload)
    if Payload.author.bot or Payload.guild ~= nil or AwaitingResponse[Payload.author.id] then return end

    if SentResponses[Payload.author.id] then
        if (os.time() - SentResponses[Payload.author.id]) >= 10 then
            SentResponses[Payload.author.id] = nil
        else
            return SimpleEmbed(Payload, "Sorry however you may only submit feedback once per 24 hours.")
        end
    end

    if FeedbackC == nil or FeedBackOpen == false then 
        return SimpleEmbed(Payload, "Sorry however the GMR.finance Discord is not receiving any feedback at the moment.")
    end

    AwaitingResponse[Payload.author.id] = true

    SimpleEmbed(Payload, F("Are you sure you want to send the feedback above to the staff of the GMR.finance discord server?\n\nPlease answer: ``yes`` or ``no`` (You have %d seconds to do so.)\n\nNote: All feedback is sent anonymously and those who see it will not know you sent it!", WaitTime))

    local Success, FeedbackPayload = BOT:waitFor("messageCreate", WaitTime * 1000, function(FeedbackPayload)
        if FeedbackPayload.channel == Payload.channel then
            local Answer = FeedbackPayload.content:lower()

            if Answer == "yes" or Answer == "no" then
                AwaitingResponse[FeedbackPayload.author.id] = false

                return true
            end
        end

        return false
    end)

    if Success then
        if FeedbackPayload.content:lower() == "yes" then
            SentResponses[Payload.author.id] = os.time()

            local Embed = {
                ["title"] = "Feedback from "..Payload.author.tag,
                ["color"] = Config["EmbedColour"],
                ["description"] = Payload.cleanContent,
                ["fields"] = {}
            }

            if Payload.attachment then
                table.insert(Embed["fields"], {
                    ["name"] = "Attachemnt",
                    ["value"] = F("[%s](%s)", Payload.attachment.filename, Payload.attachment.url)
                })
            end

            local Success, Err = FeedbackC:send {
                embed = Embed
            }

            if Success and not Err then
                return SimpleEmbed(Payload, "Feedback sent!\n\nThanks for making the GMR.finance project better!")
            end

            SimpleEmbed(Payload, "there was a problem sending the feedback, please try again.")
        end
    end
end)

--[[ Commands ]]
local FeedbackCommand = CommandManager.Command("feedback", function(Args, Payload)
end)

FeedbackCommand:AddSubCommand("open", function(Args, Payload)
    assert(FeedBackOpen == false, "Feedback is already open.")

    FeedBackOpen = true

    return SimpleEmbed(Payload, "Feedback is now open.")
end)

FeedbackCommand:AddSubCommand("close", function(Args, Payload)
    assert(FeedBackOpen == true, "Feedback is already closed.")

    FeedBackOpen = false

    return SimpleEmbed(Payload, "Feedback is now closed.")
end)

FeedbackCommand:AddSubCommand("status", function(Args, Payload)
    return SimpleEmbed(Payload, F("Feedback is currently %s.", FeedBackOpen == true and "open" or "closed"))
end)