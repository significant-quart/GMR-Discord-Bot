--[[ Database ]]
local DB = assert(SQL.open(Config.ModuleDir.."/Reminder.db"), [[failed to open Reminder database - "remind" command will not work!]])
DB:exec("CREATE TABLE IF NOT EXISTS Reminder(ID INTEGER PRIMARY KEY AUTOINCREMENT, Start INTEGER, Duration INTEGER, Message TEXT, CID TEXT, Owner TEXT);")

local AddReminderSTMT = DB:prepare("INSERT INTO Reminder(Start, Duration, Message, CID, Owner) VALUES(?, ?, ?, ?, ?)")
local DeleteReminderSTMT = DB:prepare("DELETE FROM Reminder WHERE Start = ? AND Duration = ?")
local DeleteReminderByIDSTMT = DB:prepare("DELETE FROM Reminder WHERE ID = ?")

--[[ Variables ]]
local MaxReminderLength = 500

--[[ Functions ]]
function SetReminder(Data, Insert)
    Data.Start = tonumber(Data.Start)

    Routine.setTimeout((Data.Duration - os.time()) * 1000, coroutine.wrap(function()
        local Channel, Err = BOT:getChannel(Data.CID)

        if Channel and not Err then
            Channel:send {
                embed = SimpleEmbed(nil, F("<@%s> your reminder from <t:%d:F>\n \n%s", Data.Owner, Data.Start, Data.Message))
            }
        end

        DeleteReminderSTMT:reset():bind(Data.Start, Data.Duration):step()
    end))

    if Insert then
        AddReminderSTMT:reset():bind(Data.Start, Data.Duration, Data.Message, Data.CID, Data.Owner):step()
    end
end

--[[ Init ]]
local Reminders = DB:exec("SELECT * FROM Reminder")
if Reminders ~= nil then 
    for i = 1, #Reminders.ID do
        Reminders.ID[i], Reminders.Duration[i] = tonumber(Reminders.ID[i]), tonumber(Reminders.Duration[i])

        if Reminders.Duration[i] <= os.time() then
            Log(4, "A reminder has been deleted as the bot was offline.")

            DeleteReminderByIDSTMT:reset():bind(Reminders.ID[i]):step()
        else
            Log(4, "Restarting reminder as bot was offline.")

            SetReminder({
                ["Duration"] = tonumber(Reminders.Duration[i]),
                ["CID"] = Reminders.CID[i],
                ["Owner"] = Reminders.Owner[i],
                ["Start"] = Reminders.Start[i],
                ["Message"] = Reminders.Message[i]
            }, false)
        end
    end
end

--[[ Command ]]
CommandManager.Command("remind", function(Args, Payload)
    assert(Args[2] ~= nil, "")

    local CommandS = ReturnRestOfCommand(Args, 2, " ", #Args).." "
    local Days = CommandS:match("(%d+)d ")
    local Hours = CommandS:match("(%d+)h ")
    local Minutes = CommandS:match("(%d+)m ")
    local ArgIgnore = 0
    
    if Days then 
        Days = tonumber(Days)
        assert(Days > 0 and Days <= 365, "you specified too many or too few days.")
        ArgIgnore = ArgIgnore + 1
    end

    if Hours then
        Hours = tonumber(Hours)
        assert(Hours > 0 and Hours <= 24, "you specified too many or too few hours.")
        ArgIgnore = ArgIgnore + 1
    end

    if Minutes then
        Minutes = tonumber(Minutes)
        assert(Minutes > 0 and Minutes <= 60, "you specified too many or too few Minutes.")
        ArgIgnore = ArgIgnore + 1
    end

    assert(ArgIgnore ~= 0, "please provide a valid time for your reminder.")

    local ReminderText = ReturnRestOfCommand(Args, 2 + ArgIgnore)

    assert(#ReminderText > 0, "you haven't included a reminder.")
    assert(#ReminderText <= MaxReminderLength, "your reminder is too long, musn't be greater than %d characters.", MaxReminderLength)

    local RemindTime = os.time() + (Minutes ~= nil and (Minutes * 60) or 0) + (Hours ~= nil and (Hours * 60 * 60) or 0) + (Days ~= nil and (Days * 24 * 60 * 60) or 0)
    
    SetReminder({
        ["Duration"] = RemindTime,
        ["CID"] = Payload.channel.id,
        ["Owner"] = Payload.author.id,
        ["Start"] = os.time(),
        ["Message"] = ReminderText
    }, true)

    SimpleEmbed(Payload, F("Your reminder has been successfully set for <t:%d:F>", RemindTime))
end):SetCategory("Misc Commands"):SetDescription("Set a reminder for later."):SetLongDescription(F([[
    An example reminder is as follows:

    ``%sremind 5m 10h Buy some GMR token!``

    The above will message you in the channel you created the reminder exactly 10 hours and 5 minutes from the moment the reminder was created with the message "Buy some GMR token!".

    As of now, reminder durations can be set using ``m``, ``h`` and ``d`` to specify the minute, hour and day duration of a reminder.
]], Prefix))