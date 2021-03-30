local enable = ui.new_checkbox("rage", "other", "Lua resolver")

local angles = { [0] = -58, [1] = 58, [2] = -48, [3] = 48, [4] = 0 } -- magic values
local last_angle = 0
local new_angle = 0

local function resolve(player)
    plist.set(player, "Correction active", false) -- disable default correction because i have a superiority complex
    plist.set(player, "Force body yaw", true) -- enable the forcing of the body yaw
    new_angle = angles[math.random(0, 4)]
    client.log("[resolver but good] missed player: " .. entity.get_player_name(player) .. ", at angle: " .. last_angle .. ", bruteforced to: " .. new_angle)
    plist.set(player, "Force body yaw value", new_angle) -- force yaw value to random
    last_angle = new_angle
end

client.set_event_callback("aim_miss", function(info)
    if not ui.get(enable) or info.reason ~= "?" then -- make sure we missed due to resolver :o
        return
    end
    resolve(info.target) -- resolve that noob
end)
