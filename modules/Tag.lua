--[[ Database ]]
local DB = assert(SQL.open(ModuleDir.."/Tags.db"), "fatal: Failed to open Tags database!")
DB:exec("CREATE TABLE IF NOT EXISTS Tags(Tag TEXT PRIMARY KEY, Message TEXT, Owner TEXT, Uses NUMBER);")

local GetTagSTMT = DB:prepare("SELECT * FROM Tags WHERE Tag = ?")
local TagUsedSTMT = DB:prepare("UPDATE Tags SET Uses = Uses + 1 WHERE Tag = ?")
local AddTagSTMT = DB:prepare("INSERT INTO Tags(Tag, Message, Owner, Uses) VALUES(?, ?, ?, 0)")
local EditTagSTMT = DB:prepare("UPDATE Tags SET Message = ? WHERE Tag = ?")
local DeleteTagSTMT = DB:prepare("DELETE FROM Tags WHERE Tag = ?")

--[[ Variables ]]
local LengthLimit, NameLimit  = 200, 50

--[[ Functions ]]
local function GetTag(Args, Index)
    local SArgs = ReturnRestOfCommand(Args, (Index ~= nil and Index or 3))

    if SArgs:sub(1, 1) == [["]] then
        local Tag = SArgs:match([["(.-)"]])
        assert(Tag ~= nil and #Tag > 0, "you incorrectly formatted the tag name.")

        local TagEndArgIndex = assert(#Tag:split(" "), "failed to find the number of words in tag name")

        return { Tag, 3 + TagEndArgIndex }
    end

    return { Args[(Index ~= nil and 2 or 3)], 4 }
end

--[[ Commands ]]
local Tag = CommandManager.Command("tag", function(Args, Payload)
    assert(Args[2], "")

    print(ReturnRestOfCommand(Args, 2):gsub("%s<#[0-9]+>", ""))
    local TagName = ReturnRestOfCommand(Args, 2):gsub("%s<#[0-9]+>", "")

    local Tag = GetTagSTMT:reset():bind(TagName):step()

    assert(Tag ~= nil and #Tag > 0, F("tag ``%s`` does not exist.", TagName))

    if Payload.mentionedChannels and #Payload.mentionedChannels > 0 then
        for CID, _ in pairs(Payload.mentionedChannels) do
            local Channel = BOT:getChannel(CID)

            if Channel then
                Channel:send(Tag[2])
            end
        end
    else
        Payload:reply(Tag[2])
    end

    TagUsedSTMT:reset():bind(TagName):step()
end):SetCategory("Misc Commands"):SetDescription(F("Tag Manager", Prefix, Prefix))

Tag:AddSubCommand("add", function(Args, Payload)
    assert(Args[3], "")   

    local TagInfo = assert(GetTag(Args), "there was a problem finding the tag name.")
    local TagName, TagEndArgIndex = TagInfo[1], TagInfo[2]

    local Tag = GetTagSTMT:reset():bind(TagName):step()
    assert(Tag == nil or #Tag == 0, F("tag ``%s`` already exists.\nIf you are the owner of the tag use ``%stag edit`` to change it.", TagName, Prefix))
    assert(TagName:match("<[#@:]+.->") == nil, "you may not include channel, role or user mentions in your tag name.")
    assert(Args[TagEndArgIndex], "you need to provide a value for the tag.")

    local TagValue = ReturnRestOfCommand(Args, TagEndArgIndex)

    assert(#TagValue <= LengthLimit, F("your tag may not exeed %d characters.", LengthLimit))
    assert(#TagName <= NameLimit, F("your tag name may not exeed %d characters.", NameLimit))

    AddTagSTMT:reset():bind(TagName, TagValue, Payload.author.id):step()

    SimpleEmbed(Payload, F("Successfully added tag ``%s``.", TagName))
end):SetDescription("Create your own tag.")

Tag:AddSubCommand("remove", function(Args, Payload)
    assert(Args[3], "") 

    local TagInfo = assert(GetTag(Args), "there was an issue formatting the tag name")
    local TagName = TagInfo[1]

    local Tag = GetTagSTMT:reset():bind(TagName):step()

    assert(Tag ~= nil and #Tag > 0, F("tag ``%s`` does not exist.", TagName))

    assert(Tag[3] == Payload.author.id or Payload.guild.owner and Payload.author.id == Payload.guild.owner.id, "you do not have permission to remove this tag as it does not belong to you.")

    DeleteTagSTMT:reset():bind(TagName):step()

    SimpleEmbed(Payload, F("Successfully removed tag ``%s``.", TagName))
end):SetDescription("Remove a tag that belongs to you.")

Tag:AddSubCommand("edit", function(Args, Payload)
    assert(Args[3], "")   

    local TagInfo = assert(GetTag(Args), "there was an issue formatting the tag name")
    local TagName = TagInfo[1]

    local Tag = GetTagSTMT:reset():bind(TagName):step()

    assert(Tag ~= nil and #Tag > 0, F("tag ``%s`` does not exist.", TagName))

    assert(Tag[3] == Payload.author.id or Payload.guild.owner and Payload.author.id == Payload.guild.owner.id, "you do not have permission to remove this tag as it does not belong to you.")

    local TagValue = ReturnRestOfCommand(Args, TagEndArgIndex)
    assert(#TagValue <= LengthLimit, F("your tag may not exeed %d characters.", LengthLimit))
    assert(#TagName <= NameLimit, F("your tag name may not exeed %d characters.", NameLimit))

    EditTagSTMT:reset():bind(TagValue, TagName):step()

    SimpleEmbed(Payload, F("Successfully edited tag ``%s``.", TagName))
end):SetDescription("Edit a tag that belongs to you.")