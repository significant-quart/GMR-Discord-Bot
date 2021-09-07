--[[ Commands ]]
CommandManager.Command("coin", function(Args, Payload)
    math.randomseed(os.time())
    local RInt = math.random(1, 2)

    SimpleEmbed(Payload, (RInt == 1 and "Heads" or "Tails"))
end):SetCategory("Misc Commands"):SetDescription("Flip a coin.")