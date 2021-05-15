local ragebot, key = ui.reference('RAGE', 'Aimbot', 'Enabled')
local auto_fire = ui.reference('RAGE', 'Aimbot', 'Automatic fire')
local onshot, onshot_key = ui.reference('AA', 'Other', 'On shot anti-aim')
 
local fl_enabled = ui.reference('AA', 'Fake lag', 'Enabled')
local aa_enabled = ui.reference('AA', 'Anti-aimbot angles', 'Enabled')
local body_yaw = ui.reference('AA', 'Anti-aimbot angles', 'Body yaw')
local lby = ui.reference('AA', 'Anti-aimbot angles', 'Lower body yaw target')
local hit_chance = ui.reference('RAGE', 'Aimbot', 'Minimum hit chance')
local fake_duck = ui.reference('RAGE', 'Other', 'Duck peek assist')
 
local dtap, dtap_key = ui.reference('RAGE', 'Other', 'Double tap')
local dtap_mode = ui.reference('RAGE', 'Other', 'Double tap mode')
 
local command_holdaim = ui.reference('MISC', 'Settings', 'sv_maxusrcmdprocessticks_holdaim')
local ticks_to_process = ui.reference('MISC', 'Settings', 'sv_maxusrcmdprocessticks')
 
local clock = cvar.cl_clock_correction
 
-- MENU
local modes = { '-', 'Offensive', 'Dynamic' }
local hold_aim_modes = { 'Off', 'Force', 'Disable' }
 
local master_switch = ui.new_checkbox('AA', 'Other', 'Tickbase controller')
 
local label = ui.new_label('AA', 'Other', 'TBC Logging')
local mode = ui.new_combobox('AA', 'Other', '\n doubletap_mode', modes)
local acb_hold_aim = ui.new_combobox('AA', 'Other', 'User cmd hold aim', hold_aim_modes)
local disable_clocks = ui.new_checkbox('AA', 'Other', 'Disable clock correction')
 
-- CONTROLLERS
local ffi_cache = { }
local ui_get, ui_set = ui.get, ui.set
 
local invoke_cache = function(b,c,d)local e=function(f,g,h)local i={[0]='always on',[1]='on hotkey',[2]='toggle',[3]='off hotkey'}local j=tostring(f)local k=ui.get(f)local l=type(k)local m,n=ui.get(f)local o=n~=nil and n or(l=='boolean'and tostring(k)or k)ffi_cache[j]=ffi_cache[j]or o;if g then ui.set(f,n~=nil and i[h]or h)else if ffi_cache[j]~=nil then local p=ffi_cache[j]if l=='boolean'then if p=='true'then p=true end;if p=='false'then p=false end end;ui.set(f,n~=nil and i[p]or p)ffi_cache[j]=nil end end end;if type(b)=='table'then for q,r in pairs(b)do e(q,r[1],r[2])end else e(b,c,d)end end
local notes_pos = function(b)local c=function(d,e)local f={}for g in pairs(d)do table.insert(f,g)end;table.sort(f,e)local h=0;local i=function()h=h+1;if f[h]==nil then return nil else return f[h],d[f[h]]end end;return i end;local j={get=function(k)local l,m=0,{}for n,o in c(_notes_rtop)do if o==true then l=l+1;m[#m+1]={n,l}end end;for p=1,#m do if m[p][1]==b then return k(m[p][2]-1)end end end,set_state=function(q)_notes_rtop[b]=q;table.sort(_notes_rtop)end,unset=function()client.unset_event_callback('shutdown',callback)end}client.set_event_callback('shutdown',function()if _notes_rtop[b]~=nil then _notes_rtop[b]=nil end end)if _notes_rtop==nil then _notes_rtop={}end;return j end
 
local note = notes_pos 'b_tbcontroller'
 
local prev_command = { }
 
local did_shift_before = false
local cmd_scmd_data = nil
local cmd_surpass, cmd_number = 0, 0
local cmd_data_overlap = 0
local cmd_data_time = 0
 
local get_script_state = function(type, sw_active)
    local region_check = ''
    local script_active = ui_get(master_switch)
    local duck_active = ui_get(fake_duck)
 
    -- region script safety
    local ids = { pcall(ui.reference, 'RAGE', 'Other', 'Increase doubletap speed') }
 
    if ids[1] and ui_get(ids[2]) then
        region_check = '> double tap is controlled by other script'
        script_active = false
    end
 
    local double_tap = ui_get(dtap) and ui_get(dtap_key)
    local onshot_aa = ui_get(onshot) and ui_get(onshot_key)
 
    if script_active and not duck_active and not onshot_aa and double_tap then
        local prc = ui_get(ticks_to_process)
        local ovp = cmd_data_overlap
 
        if prc > 17 and ovp <= 5 then
            cmd_data_overlap = ovp + 1
            cmd_data_time = globals.realtime() + 0.1
        end
 
        if cmd_data_time ~= 0 and globals.realtime() > cmd_data_time then
            if prc <= 17 then
                cmd_data_overlap = 0
                cmd_data_time = 0
            end
        end
 
        if ovp > 5 then
            region_check = string.format('> usrcmdticks[%d] is unsafe (>17)', prc)
            script_active = false
        end
    end
    -- end_region
 
    if sw_active and not script_active then
        return false, region_check
    end
 
    local types = {
        ['DT'] = double_tap and not duck_active,
        ['OS'] = onshot_aa and not duck_active,
 
        ['SC'] = script_active,
        ['@'] = not duck_active and (double_tap or onshot_aa)
    }
 
    return types[type], region_check
end
 
local can_exploit = function(me, ticks_to_shift)
    local wpn = entity.get_player_weapon(me)
 
    local tickbase = entity.get_prop(me, 'm_nTickBase')
    local curtime = globals.tickinterval() * (tickbase-ticks_to_shift)
 
    if curtime < entity.get_prop(me, 'm_flNextAttack') then
        return false
    end
 
    if curtime < entity.get_prop(wpn, 'm_flNextPrimaryAttack') then
        return false
    end
 
    return true
end
 
local function g_command(e)
    local next_shift_amount = 0
 
    local me = entity.get_local_player()
    local wpn = entity.get_player_weapon(me)
 
    local can_shift_shot = can_exploit(me, 13)
    local can_shot = can_exploit(me, math.abs(-1 - next_shift_amount))
 
    if can_shift_shot or not can_shot and did_shift_before then
        next_shift_amount = 13
    else
        next_shift_amount = 0
    end
 
    did_shift_before = next_shift_amount ~= 0
 
    ::begin_command::
 
    if cmd_scmd_data ~= nil then
        ui_set(dtap, cmd_scmd_data)
        cmd_scmd_data = nil
    end
 
    local script_active = get_script_state('SC', 1)
    local onshot_aa = get_script_state('OS', 1)
    local doubletap = get_script_state('DT', 1)
 
    local active_dt = not onshot_aa and doubletap
 
    -- Revolver tickbase correction
    local cmd_difference = math.abs(e.command_number - cmd_number)
    local wpn_id = entity.get_prop(wpn, 'm_iItemDefinitionIndex')
    local m_item = wpn_id ~= nil and bit.band(wpn_id, 0xFFFF) or 0
 
    if m_item == 64 and (not get_script_state('@', 1) or cmd_difference > 1) then
        cmd_surpass = 0
        if cmd_difference > 1 then
            cmd_surpass = 1
        end
    end
 
    -- Begin corrections
    local mode = ui_get(mode)
    local hold_aim = ui_get(acb_hold_aim)
    local can_clock = (script_active and ui_get(disable_clocks) and active_dt) and 0 or 1
 
    local in_move = e.forwardmove == 0 and e.sidemove == 0
    local skip_command = cmd_surpass < next_shift_amount and cmd_surpass > 0
 
    if hold_aim == hold_aim_modes[2] or get_script_state('OS', 1) then
        ui.set(command_holdaim, true)  
    elseif hold_aim == hold_aim_modes[3] and active_dt and not ui.get(fake_duck) then
        ui.set(command_holdaim, false)
    end
   
    if active_dt then
        if mode == modes[3] then
            ui_set(dtap_mode, in_move and 'Defensive' or 'Offensive')
        else
            ui_set(dtap_mode, mode == modes[2] and 'Offensive' or 'Defensive')
        end
    end
 
    -- Fakelag manipulations
    if active_dt and ui_get(dtap_mode) == 'Offensive' and not can_shift_shot then
        cmd_scmd_data = ui_get(dtap)
    end
 
    if cmd_scmd_data ~= nil then
        ui_set(dtap, false)
    end
 
    invoke_cache({
        [key] = { skip_command, 'On hotkey' },
        [lby] = { get_script_state('@', 1), 'Eye yaw' },
       
        [ticks_to_process] = { active_dt, 17 },

    })
   
    clock:set_int(can_clock and 0 or 1)
 
    cmd_surpass = cmd_surpass + 1
    cmd_number = e.command_number
 
    prev_command = {
        dtap = active_dt,
        can_shift_shot = can_shift_shot,
        can_shot = can_shot,
        tick_clocked = can_clock
    }
end
 
local function g_command_run(e)
    if cmd_scmd_data ~= nil then
        ui_set(dtap, cmd_scmd_data)
        cmd_scmd_data = nil
    end
end
 
local function g_shutdown()
    clock:set_int(1)
   
    if cmd_scmd_data ~= nil then
        ui_set(dtap, cmd_scmd_data)
        cmd_scmd_data = nil
    end
 
    invoke_cache({
        [lby] = { false },
        [auto_fire] = { false },
        [hit_chance] = { false },
 
        [key] = { false },
        [dtap] = { false },
        [dtap_key] = { false },
        [dtap_mode] = { false },

        [ticks_to_process] = { false },
    })
end
 
local function g_paint_handler()
    note.set_state(false)
 
    local form = prev_command
    local me = entity.get_local_player()
   
    if not entity.is_alive(me) then
        g_shutdown()
        return
    end
 
    note.set_state(form.dtap)
    note.get(function(id)
        local r, g, b, a = 89, 119, 239, 255
 
        -- if get_script_state('QM', 1) then r, g, b, a = 255, 167, 38, 255 end
 
        if not form.can_shift_shot then
            r, g, b, a = 150, 150, 150, 150
        end
 
        local text = string.format('YagoCord | hold aim: %s | clocks: %s', ui_get(command_holdaim), form.tick_clocked)
        local h, w = 17, renderer.measure_text(nil, text) + 8
        local x, y = client.screen_size(), 10 + (25*id)
 
        x = x - w - 10
 
        renderer.rectangle(x-3, y, 2, h, r, g, b, a)
 
        renderer.rectangle(x-1, y, w+1, h, 17, 17, 17, 255)
        renderer.text(x+4, y + 2, 255, 255, 255, 255, '', 0, text)
    end)
end
 
local function g_ui_handler()
    local active, region = ui_get(master_switch)
    local qmode = ui_get(mode)
 
    ui.set_visible(mode, active)
    ui.set_visible(disable_clocks, active)
end
 
client.set_event_callback('paint_ui', function()
    local _, region = get_script_state('SC')
    local visible = ui_get(master_switch) and region ~= ''
 
    ui.set_visible(label, visible)
    ui.set(label, region)
end)
 
client.set_event_callback('setup_command', g_command)
client.set_event_callback('run_command', g_command_run)
 
client.set_event_callback('paint', g_paint_handler)
client.set_event_callback('shutdown', g_shutdown)
 
ui.set_callback(master_switch, g_ui_handler)
ui.set_callback(mode, g_ui_handler)
 
ui.set_visible(label, false)
 
g_ui_handler()	





local ui_legit_hotkey = ui.new_hotkey("LUA", "B", "LegitAA")
local ui_Forward_hotkey = ui.new_hotkey("LUA", "B", "ForwardAA")



local ui_get, ui_set, ui_ref = ui.get, ui.set, ui.reference
local ui_left_hotkey = ui.new_hotkey("LUA", "B", "Left")
local ui_right_hotkey = ui.new_hotkey("LUA", "B", "Right")
local ui_backwards_hotkey = ui.new_hotkey("LUA", "B", "Back")
local ui_freestanding_hotkey = ui.new_hotkey("LUA", "B", "Freestanding")
local ui_indicator_combobox = ui.new_combobox("LUA", "B", "Anti-aim indicator", "Off", "Single", "Full")
local ui_indicator_color_picker = ui.new_color_picker("LUA", "B", "Arrow color", "150", "200", "60", "255")

local client_log = client.log
local client_draw_text = client.draw_text
local client_screensize = client.screen_size
local client_set_event_callback = client.set_event_callback

local yaw = { ui.reference("aa", "anti-aimbot angles", "yaw") }
local yaw_base_reference = ui_ref("AA", "Anti-aimbot angles", "Yaw base")
local freestanding_reference = ui_ref("AA", "Anti-aimbot angles", "Freestanding")
	
local isLeft, isRight, isBack, isFreestanding = false

local function get_antiaim_dir()
	if ui_get(ui_freestanding_hotkey) then
		isFreestanding = true
		isLeft, isRight, isBack = false
	elseif ui_get(ui_left_hotkey) then
		isLeft = true
		isFreestanding, isRight, isBack = false
	elseif ui_get(ui_right_hotkey) then
		isRight = true
		isFreestanding, isLeft, isBack = false
	elseif ui_get(ui_backwards_hotkey) then
		isBack = true
		isFreestanding, isLeft, isRight = false
	end	
	end

local function setLeft()

	ui.set(yaw[2], -90)
	ui_set(yaw_base_reference, "Local view")
	ui_set(freestanding_reference, "")
end

local function setRight()

	ui.set(yaw[2], 90)
	ui_set(yaw_base_reference, "Local view")
	ui_set(freestanding_reference, "")
end
	
local function setBack()

	ui.set(yaw[2], 0)
	ui_set(yaw_base_reference, "At targets")
	ui_set(freestanding_reference, "")
end

local function setFreestanding()
	ui_set(yaw_val_reference, 0)
	ui_set(yaw_base_reference, "At targets")
	ui_set(freestanding_reference, "Default", "Edge")
end

local function on_paint(c)
	local scrsize_x, scrsize_y = client_screensize()
	local center_x, center_y = scrsize_x / 2, scrsize_y / 2
	
	local indicator = ui_get(ui_indicator_combobox)
	local indicator_r, indicator_g, indicator_b, indicator_a = ui_get(ui_indicator_color_picker)

	get_antiaim_dir()

	if isFreestanding then
		setFreestanding()
		if indicator == "Single" then
		elseif indicator == "Full" then
			client_draw_text(c, center_x, center_y + 45, 255, 255, 255, 200, "c+", 0, "⮋")
			client_draw_text(c, center_x + 45, center_y, 255, 255, 255, 200, "c+", 0, "⮊")
			client_draw_text(c, center_x - 45, center_y, 255, 255, 255, 200, "c+", 0, "⮈")
		end
	elseif isLeft then
		setLeft()
		if indicator == "Single" then
			client_draw_text(c, center_x - 45, center_y, indicator_r, indicator_g, indicator_b, indicator_a, "c+", 0, "⮈")
		elseif indicator == "Full" then
			client_draw_text(c, center_x - 45, center_y, indicator_r, indicator_g, indicator_b, indicator_a, "c+", 0, "⮈")
			client_draw_text(c, center_x, center_y + 45, 255, 255, 255, 200, "c+", 0, "⮋")
			client_draw_text(c, center_x + 45, center_y, 255, 255, 255, 200, "c+", 0, "⮊")
		end
	elseif isRight then
		setRight()
		if indicator == "Single" then
			client_draw_text(c, center_x + 45, center_y, indicator_r, indicator_g, indicator_b, indicator_a, "c+", 0, "⮊")
		elseif indicator == "Full" then
			client_draw_text(c, center_x + 45, center_y, indicator_r, indicator_g, indicator_b, indicator_a, "c+", 0, "⮊")
			client_draw_text(c, center_x, center_y + 45, 255, 255, 255, 200, "c+", 0, "⮋")
			client_draw_text(c, center_x - 45, center_y, 255, 255, 255, 200, "c+", 0, "⮈")
		end
	elseif isBack then
		setBack()
		if indicator == "Single" then
			client_draw_text(c, center_x, center_y + 45, indicator_r, indicator_g, indicator_b, indicator_a, "c+", 0, "⮋")
		elseif indicator == "Full" then
			client_draw_text(c, center_x, center_y + 45, indicator_r, indicator_g, indicator_b, indicator_a, "c+", 0, "⮋")
			client_draw_text(c, center_x + 45, center_y, 255, 255, 255, 200, "c+", 0, "⮊")
			client_draw_text(c, center_x - 45, center_y, 255, 255, 255, 200, "c+", 0, "⮈")
		end
	end 
end

local err = client_set_event_callback('paint', on_paint)

if err then
	client_log('set_event_callback failed: ', err)
end
--region gs_api
--region Client
local client = {
	latency = client.latency,
	log = client.log,
	userid_to_entindex = client.userid_to_entindex,
	set_event_callback = client.set_event_callback,
	screen_size = client.screen_size,
	eye_position = client.eye_position,
	color_log = client.color_log,
	delay_call = client.delay_call,
	visible = client.visible,
	exec = client.exec,
	trace_line = client.trace_line,
	draw_hitboxes = client.draw_hitboxes,
	camera_angles = client.camera_angles,
	draw_debug_text = client.draw_debug_text,
	random_int = client.random_int,
	random_float = client.random_float,
	trace_bullet = client.trace_bullet,
	scale_damage = client.scale_damage,
	timestamp = client.timestamp,
	set_clantag = client.set_clantag,
	system_time = client.system_time,
	reload_active_scripts = client.reload_active_scripts
}
--endregion

--region Entity
local entity = {
	get_local_player = entity.get_local_player,
	is_enemy = entity.is_enemy,
	hitbox_position = entity.hitbox_position,
	get_player_name = entity.get_player_name,
	get_steam64 = entity.get_steam64,
	get_bounding_box = entity.get_bounding_box,
	get_all = entity.get_all,
	set_prop = entity.set_prop,
	is_alive = entity.is_alive,
	get_player_weapon = entity.get_player_weapon,
	get_prop = entity.get_prop,
	get_players = entity.get_players,
	get_classname = entity.get_classname,
	get_game_rules = entity.get_game_rules,
	get_player_resource = entity.get_prop,
	is_dormant = entity.is_dormant,
}
--endregion

--region Globals
local globals = {
	realtime = globals.realtime,
	absoluteframetime = globals.absoluteframetime,
	tickcount = globals.tickcount,
	curtime = globals.curtime,
	mapname = globals.mapname,
	tickinterval = globals.tickinterval,
	framecount = globals.framecount,
	frametime = globals.frametime,
	maxplayers = globals.maxplayers,
	lastoutgoingcommand = globals.lastoutgoingcommand,
}
--endregion

--region Ui
local ui = {
	new_slider = ui.new_slider,
	new_combobox = ui.new_combobox,
	reference = ui.reference,
	set_visible = ui.set_visible,
	is_menu_open = ui.is_menu_open,
	new_color_picker = ui.new_color_picker,
	set_callback = ui.set_callback,
	set = ui.set,
	new_checkbox = ui.new_checkbox,
	new_hotkey = ui.new_hotkey,
	new_button = ui.new_button,
	new_multiselect = ui.new_multiselect,
	get = ui.get,
	new_textbox = ui.new_textbox,
	mouse_position = ui.mouse_position
}
--endregion

--region Renderer
local renderer = {
	text = renderer.text,
	measure_text = renderer.measure_text,
	rectangle = renderer.rectangle,
	line = renderer.line,
	gradient = renderer.gradient,
	circle = renderer.circle,
	circle_outline = renderer.circle_outline,
	triangle = renderer.triangle,
	world_to_screen = renderer.world_to_screen,
	indicator = renderer.indicator,
	texture = renderer.texture,
	load_svg = renderer.load_svg
}
--endregion
--endregion

--region ui_references
local uiref_pitch = ui.reference("aa", "anti-aimbot angles", "Pitch")
local uiref_yaw, uiref_yaw_slider = ui.reference("aa", "anti-aimbot angles", "Yaw")
local uiref_fake_yaw, uiref_fake_yaw_slider = ui.reference("aa", "anti-aimbot angles", "Body Yaw")
local uiref_lby_target = ui.reference("aa", "anti-aimbot angles", "Lower body yaw target")
local uiref_fake_limit = ui.reference("aa", "anti-aimbot angles", "Fake yaw limit")
--endregion

--region globals 
local manual_aa_direction = 0
local info_antiaim_status
local fakewalk_enabled
local nospread_mode_desync_selected
local player_is_alive
local spamtime = 0
local antiresolve
local delay_time = 0
local inverse_time = 0
local anti_resolve_timer = 0

local screen_width, screen_height = client.screen_size()
local screen_center_x, screen_center_y = screen_width / 2, screen_height / 2

local manual_aa_arrow_offsets = {
	left = screen_center_x - 80,
	right = screen_center_x + 80,
}

local manual_aa_arrow_fake_color = {
	r = 0,
	g = 85,
	b = 101,
	a = 100
}
--endregion

--region helpers
local function contains(table, val)
	for i = 1, #table do
		if table[i] == val then
			return true
		end
	end

	return false
end

local function while_timings()
	info_antiaim_status = "Unknown"

	local function fl_onground(ent)
		local flags = entity.get_prop(ent, "m_fFlags")
		local flags_on_ground = bit.band(flags, 1)

		if flags_on_ground == 1 then
			return true
		end

		return false
	end

	local function fl_induck(ent)
		local flags = entity.get_prop(ent, "m_fFlags")
		local flags_induck = bit.band(flags, 2)

		if flags_induck == 2 then
			return true
		end

		return false
	end

	local vel_x, vel_y = entity.get_prop(entity.get_local_player(), "m_vecVelocity")
	local vel_real = math.floor(math.min(10000, math.sqrt(vel_x * vel_x + vel_y * vel_y) + 0.5))

	if fl_onground(entity.get_local_player()) and not fl_induck(entity.get_local_player()) and not fakewalk_enabled then
		info_antiaim_status = "Standing"
	end

	if fl_onground(entity.get_local_player()) and not fl_induck(entity.get_local_player()) and vel_real > 1.0 then
		info_antiaim_status = "Running"
	end

	if fl_onground(entity.get_local_player()) == false then
		info_antiaim_status = "Jumping"
	end

	if fl_onground(entity.get_local_player()) and fl_induck(entity.get_local_player()) then
		info_antiaim_status = "Crouching"
	end
end
--endregion

--region ui
	local yaw_reference, yaw_val_reference = ui_ref("AA", "Anti-aimbot angles", "Yaw")
	local jit = { ui.reference("aa", "anti-aimbot angles", "Yaw jitter","Center") }
local enable_PerSync_aa = ui.new_checkbox("LUA", "B", "PerSync v2.0 BETA")
local side_key = ui.new_hotkey("LUA", "B", "PerSync Inverter ")
local indicatorbox = ui.new_combobox("LUA", "B", "Indicator Type", "Bottom", "Crosshair")
local colorpick = ui.new_color_picker("LUA", "B", "Indicator Color")
local aamodedesync = ui.new_combobox("LUA", "B", "Desync", "Off", "Manual", "Triple Hitbox", "Step", "Crooked")
local crooked_mode = ui.new_combobox("LUA", "B", "Mode", "Static", "Manual", "Random")
local pre_crooked_yaw = ui.new_slider("LUA", "B", "[pre]Crooked angle", -180, 180)
local crooked_yaw = ui.new_slider("LUA", "B", "Crooked angle", -180, 180)
local stepangle1 = ui.new_slider("LUA", "B", "Step angle", 0, 60)
local stepangle2 = ui.new_slider("LUA", "B", "Step angle 2", -60, 0)
local nospreaddesnyc = ui.new_combobox("LUA", "B", "Anti-Aims", "Off", "Verse", "Crooked", "Half back")
local manual_mode = ui.new_multiselect("LUA", "B", "Bullet Evasion", "Fake", "Real")
local fake_speed = ui.new_combobox("LUA", "B", "Fake evasion speed", "Default", "Fast", "Experimental")
local evade_mode = ui.new_combobox("LUA", "B", "Real evasion mode", "Off", "Lean", "Static", "Far")
local resolver_exploit_mode = ui.new_combobox("LUA", "B", "Exploit mode", "Off", "Mega", "Chronicle", "Aimware", "PerechTeam", "Universal", "Break Bruteforce", "Custom")
local custommode = ui.new_combobox("LUA", "B", "Mode", "Jitter", "Static") 
local customangle1 = ui.new_slider("LUA", "B", "Lean angle", 0, 60) 
local customangle2 = ui.new_slider("LUA", "B", "Lean angle 2", 0, 60) 
local universalmode = ui.new_combobox("LUA", "B", "Mode", "Phaze", "LBY")
local brutemode = ui.new_combobox("LUA", "B", "Break Mode", "Slow", "Fast", "Jitter")
local aimwaresploit = ui.new_multiselect("LUA", "B", "Mode", "Jump", "Shooting")
local skeetsploit = ui.new_combobox("LUA", "B", "Mode", "PerSync", "PerSyncV2")
local espamspeed = ui.new_combobox("LUA", "B", "Extend desync speed", "Slow", "Fast", "Exploit Pitch")
local espamkey = ui.new_hotkey("LUA", "B", "Extend desync", true)

local function handle_ui()
	local main_state = ui.get(enable_PerSync_aa)
	ui.set_visible(aamodedesync, main_state)
	ui.set_visible(nospreaddesnyc, main_state)
	ui.set_visible(resolver_exploit_mode, main_state)
	ui.set_visible(indicatorbox, main_state)
	ui.set_visible(colorpick, main_state)
	ui.set_visible(side_key, main_state)
	ui.set_visible(espamkey, main_state)
	ui.set_visible(espamspeed, main_state)

	if (ui.get(aamodedesync) == "Manual") then
		ui.set_visible(manual_mode, main_state)
		if contains(ui.get(manual_mode), "Real") then
			ui.set_visible(evade_mode, main_state)
		else
			ui.set_visible(evade_mode, false)
		end
		if contains(ui.get(manual_mode), "Fake") then
			ui.set_visible(fake_speed, main_state)
		else
			ui.set_visible(fake_speed, false)
		end
	elseif (ui.get(aamodedesync) ~= "Manual") then
		ui.set_visible(manual_mode, false)
		ui.set_visible(evade_mode, false)
		ui.set_visible(fake_speed, false)
	end

	if (ui.get(aamodedesync) == "Crooked") then
		ui.set_visible(crooked_mode, main_state)
		if ui.get(crooked_mode) == "Static" then
			ui.set_visible(pre_crooked_yaw, main_state)
			ui.set_visible(crooked_yaw, main_state)
		else
			ui.set_visible(pre_crooked_yaw, false)
			ui.set_visible(crooked_yaw, false)
		end
	elseif (ui.get(aamodedesync) ~= "Crooked") then
		ui.set_visible(crooked_yaw, false)
		ui.set_visible(pre_crooked_yaw, false)
		ui.set_visible(crooked_mode, false)
	end
	if (ui.get(enable_PerSync_aa)) then
		-- ui.set_visible(uiref_fix_leg_movement, false)
	end

	if (ui.get(resolver_exploit_mode) == "PerechTeam") then
		ui.set_visible(skeetsploit, main_state)
	else
		ui.set_visible(skeetsploit, false)
	end

	if (ui.get(resolver_exploit_mode) == "Aimware") then
		ui.set_visible(aimwaresploit, main_state)
	else
		ui.set_visible(aimwaresploit, false)
	end

	if (ui.get(resolver_exploit_mode) == "Universal") then
		ui.set_visible(universalmode, main_state)
	else
		ui.set_visible(universalmode, false)
	end

	if (ui.get(resolver_exploit_mode) == "Break Bruteforce") then
		ui.set_visible(brutemode, main_state)
	else
		ui.set_visible(brutemode, false)
	end

	if (ui.get(resolver_exploit_mode) == "Custom") then
		ui.set_visible(custommode, main_state)
		if ui.get(custommode) == "Jitter" then
			ui.set_visible(customangle1, main_state)
			ui.set_visible(customangle2, main_state)
		elseif ui.get(custommode) == "Static" then
			ui.set_visible(customangle1, main_state)
			ui.set_visible(customangle2, false)
		end
	else
		ui.set_visible(custommode, false)
		ui.set_visible(customangle1, false)
		ui.set_visible(customangle2, false)
	end

	if (ui.get(aamodedesync) == "Step") then
		ui.set_visible(stepangle1, main_state)
		ui.set_visible(stepangle2, main_state)
	else
		ui.set_visible(stepangle1, false)
		ui.set_visible(stepangle2, false)
	end
end
--endregion

--ui callbacks
ui.set_callback(enable_PerSync_aa, handle_ui)
ui.set_callback(aamodedesync, handle_ui)
ui.set_callback(crooked_mode, handle_ui)
ui.set_callback(pre_crooked_yaw, handle_ui)
ui.set_callback(crooked_yaw, handle_ui)
ui.set_callback(stepangle1, handle_ui)
ui.set_callback(stepangle2, handle_ui)
ui.set_callback(nospreaddesnyc, handle_ui)
ui.set_callback(manual_mode, handle_ui)
ui.set_callback(fake_speed, handle_ui)
ui.set_callback(evade_mode, handle_ui)
ui.set_callback(resolver_exploit_mode, handle_ui)
ui.set_callback(custommode, handle_ui)
ui.set_callback(customangle1, handle_ui)
ui.set_callback(customangle2, handle_ui)
ui.set_callback(universalmode, handle_ui)
ui.set_callback(brutemode, handle_ui)
ui.set_callback(aimwaresploit, handle_ui)
ui.set_callback(indicatorbox, handle_ui)
ui.set_callback(colorpick, handle_ui)
ui.set_callback(skeetsploit, handle_ui)
ui.set_callback(side_key, handle_ui)
ui.set_callback(espamkey, handle_ui)
ui.set_callback(espamspeed, handle_ui)

--call handleUI once on load
handle_ui()

--region manual_aa_arrows
local function arrows()
	if not ui.get(enable_PerSync_aa) then return end
	local r, g, b = ui.get(colorpick)
	player_is_alive = entity.is_alive(entity.get_local_player())

	if (player_is_alive) then
		if (manual_aa_direction == 1) then
			if ui.get(indicatorbox) == "Crosshair" then
				renderer.text(
					manual_aa_arrow_offsets.left,
					screen_center_y,
					manual_aa_arrow_fake_color.r,
					manual_aa_arrow_fake_color.g,
					manual_aa_arrow_fake_color.b,
					manual_aa_arrow_fake_color.a,
					"c+",
					0,
					"⮜"
				) -- Fake

				renderer.text(
					manual_aa_arrow_offsets.right,
					screen_center_y,
					r,
					g,
					b,
					255,
					"c+",
					0,
					"⮞"
				) -- Real
			end

			if ui.get(indicatorbox) == "Bottom" then
				renderer.indicator(0, 0, 255, 255, "⮞")
			end
		else

			if ui.get(indicatorbox) == "Crosshair" then
				renderer.text(
					manual_aa_arrow_offsets.left,
					screen_center_y,
					r,
					g,
					b,
					255,
					"c+",
					0,
					"⮜"
				) -- Real

				renderer.text(
					manual_aa_arrow_offsets.right,
					screen_center_y,
					manual_aa_arrow_fake_color.r,
					manual_aa_arrow_fake_color.g,
					manual_aa_arrow_fake_color.b,
					manual_aa_arrow_fake_color.a,
					"c+",
					0,
					"⮞"
				) -- Fake
			end
			
			if ui.get(indicatorbox) == "Bottom" then
				renderer.indicator(0, 0, 255, 255, "⮜")
			end
		end

		if (ui.get(resolver_exploit_mode) == "Universal") then
			if ui.get(universalmode) == "LBY" then
				if player_is_alive == true then
					if ui.get(uiref_fake_limit) > 2 and info_antiaim_status == "Standing" or info_antiaim_status == "Crouching" then
						renderer.indicator(104, 208, 102, 255, "LBY")
					else
						renderer.indicator(255, 0, 0, 255, "LBY")
					end
				end
			end
		end
	end
end
--endregion

--region antiaim
local function spread_aa()
	if not ui.get(enable_PerSync_aa) then return end

	local vel_x, vel_y = entity.get_prop(entity.get_local_player(), "m_vecVelocity")
	local vel_real = math.floor(math.min(10000, math.sqrt(vel_x * vel_x + vel_y * vel_y) + 0.5))

	if ui.get(side_key) == true then
		manual_aa_direction = 1
	else
		manual_aa_direction = 0
	end

	if globals.realtime() >= spamtime and ui.get(espamkey) == true then
		if ui.get(espamspeed) == "Slow" then
			client.delay_call(0.1, client.exec, "+use")
			client.delay_call(0.2, client.exec, "-use")
			spamtime = globals.realtime() + 0.2
		end
		if ui.get(espamspeed) == "Fast" then
			client.delay_call(0.01, client.exec, "+use")
			client.delay_call(0.02, client.exec, "-use")
			spamtime = globals.realtime() + 0.02
		end
		if ui.get(espamspeed) == "Exploit Pitch" then
			client.delay_call(0.005, client.exec, "-use")
			client.delay_call(0.01, client.exec, "+use")
			spamtime = globals.realtime() + 0.01
		end
	end

	if globals.realtime() >= delay_time and manual_aa_direction == 0 and ui.get(aamodedesync) == "Manual" then
		if (antiresolve) then
			if ui.get(evade_mode) == "Lean" then
				ui.set(uiref_fake_yaw_slider, 90)
				ui.set(uiref_yaw_slider, 30)
				antiresolve = false
				delay_time = globals.realtime() + 1
			elseif ui.get(evade_mode) == "Static" then
				ui.set(uiref_fake_yaw_slider, -90)
				ui.set(uiref_yaw_slider, -12)
				antiresolve = false
				delay_time = globals.realtime() + 1
			elseif ui.get(evade_mode) == "Far" then
				ui.set(uiref_fake_yaw_slider, -90)
				ui.set(uiref_yaw_slider, 45)
				antiresolve = false
				delay_time = globals.realtime() + .5
			end
		else
			ui.set(uiref_yaw, "180")
			ui.set(uiref_fake_yaw, "Static")
			ui.set(uiref_yaw_slider, 0)
			ui.set(uiref_fake_yaw_slider, 90)
			delay_time = globals.realtime() + 0.5
		end

	elseif globals.realtime() >= delay_time and manual_aa_direction == 1 and ui.get(aamodedesync) == "Manual" then
		if (antiresolve) then
			if ui.get(evade_mode) == "Lean" then
				ui.set(uiref_fake_yaw_slider, -90)
				ui.set(uiref_yaw_slider, -30)
				antiresolve = false
				delay_time = globals.realtime() + 1
			elseif ui.get(evade_mode) == "Static" then
				ui.set(uiref_fake_yaw_slider, 90)
				ui.set(uiref_yaw_slider, 12)
				antiresolve = false
				delay_time = globals.realtime() + 1
			elseif ui.get(evade_mode) == "Far" then
				ui.set(uiref_fake_yaw_slider, 90)
				ui.set(uiref_yaw_slider, -45)
				antiresolve = false
				delay_time = globals.realtime() + .5
			end
		else
			ui.set(uiref_yaw, "180")
			ui.set(uiref_fake_yaw, "Static")
			ui.set(uiref_yaw_slider, -15)
			ui.set(uiref_fake_yaw_slider, -90)

			delay_time = globals.realtime() + 0.5
		end
	end

	if globals.realtime() >= inverse_time and contains(ui.get(manual_mode), "Fake") then
		if ui.get(aamodedesync) == "Manual" then
			if ui.get(fake_speed) == "Default" then
				client.delay_call(0.5, ui.set, uiref_lby_target, "Opposite")
				client.delay_call(1, ui.set, uiref_lby_target, "Eye yaw")
				inverse_time = globals.realtime() + 1
			end
			if ui.get(fake_speed) == "Fast" then
				client.delay_call(0.37, ui.set, uiref_lby_target, "Opposite")
				client.delay_call(0.57, ui.set, uiref_lby_target, "Eye yaw")
				inverse_time = globals.realtime() + 0.5
			end
			if ui.get(fake_speed) == "Experimental" then
				client.delay_call(0.1, ui.set, uiref_lby_target, "Opposite")
				client.delay_call(0.2, ui.set, uiref_lby_target, "Eye yaw")
				inverse_time = globals.realtime() + 0.2
			end
		end
	end

	if globals.realtime() >= delay_time and manual_aa_direction == 0 and ui.get(aamodedesync) == "Triple Hitbox" then
		ui.set(uiref_yaw, "180")
		ui.set(uiref_fake_yaw, "Static")
		ui.set(uiref_fake_yaw_slider, 90)

		client.delay_call(0.05, ui.set, uiref_yaw_slider, 150)
		client.delay_call(0.1, ui.set, uiref_yaw_slider, -150)

		delay_time = globals.realtime() + 0.1
	end

	if globals.realtime() >= delay_time and manual_aa_direction == 1 and ui.get(aamodedesync) == "Triple Hitbox" then
		ui.set(uiref_yaw, "180")
		ui.set(uiref_fake_yaw, "Static")
		ui.set(uiref_fake_yaw_slider, 90)

		client.delay_call(0.05, ui.set, uiref_yaw_slider, 30)
		client.delay_call(0.01, ui.set, uiref_yaw_slider, -30)

		delay_time = globals.realtime() + 0.1
	end

	if globals.realtime() >= delay_time and ui.get(aamodedesync) == "Crooked" then
		if ui.get(crooked_mode) == "Static" then
			if vel_real <= 70 then
				ui.set(uiref_yaw_slider, ui.get(crooked_yaw))
				if ui.get(crooked_yaw) > 0 then
					ui.set(uiref_fake_yaw_slider, -90)
				else
					ui.set(uiref_fake_yaw_slider, 90)
				end
			else
				ui.set(uiref_yaw_slider, ui.get(pre_crooked_yaw))
				if ui.get(pre_crooked_yaw) > 0 then
					ui.set(uiref_fake_yaw_slider, -90)
				else
					ui.set(uiref_fake_yaw_slider, 90)
				end
			end
		end

		if ui.get(crooked_mode) == "Manual" then
			if vel_real <= 70 then
				if manual_aa_direction == 0 then
					ui.set(uiref_yaw_slider, client.random_int(0, 30))
					ui.set(uiref_fake_yaw_slider, -90)
				elseif manual_aa_direction == 1 then
					ui.set(uiref_yaw_slider, client.random_int(-30, 0))
					ui.set(uiref_fake_yaw_slider, 90)
				end
			else
				if manual_aa_direction == 0 then
					ui.set(uiref_yaw_slider, -30)
					ui.set(uiref_fake_yaw_slider, 90)
				elseif manual_aa_direction == 1 then
					ui.set(uiref_yaw_slider, 30)
					ui.set(uiref_fake_yaw_slider, -90)
				end
			end
		end

		delay_time = globals.realtime() + 0.1
	end
end

local function anti_resolver()
	if not ui.get(enable_PerSync_aa) then return end


	  if ui.get(ui_Forward_hotkey) then
        ui.set(ui.reference("AA", "Anti-aimbot angles", "Pitch"), "Minimal")
        ui.set(ui.reference("AA", "Anti-aimbot angles", "Yaw base"), "Local view")
        ui.set(uiref_yaw_slider, 180)
		ui_set(yaw_val_reference, 90)
		ui.set(jit[2], 180)
		ui.set(ui.reference("AA", "Anti-aimbot angles", "Yaw jitter"),"center", "180")
        ui.set(ui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"), true)
else
        ui.set(ui.reference("AA", "Anti-aimbot angles", "Pitch"), "Down")
		ui.set(ui.reference("AA", "Anti-aimbot angles", "Yaw base"), "At targets")
		ui.set(jit[2], 0)

		ui.set(ui.reference("AA", "Anti-aimbot angles", "Yaw jitter"), "Off")
      end
	          if ui.get(ui_legit_hotkey) then
        ui.set(ui.reference("AA", "Anti-aimbot angles", "Pitch"), "Off")
        ui.set(ui.reference("AA", "Anti-aimbot angles", "Yaw base"), "At targets")
        ui.set(uiref_yaw_slider, 180)
        ui.set(ui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"), true)
else
        ui.set(ui.reference("AA", "Anti-aimbot angles", "Pitch"), "Down")
end

        

	if ui.get(resolver_exploit_mode) == "Off" then
		ui.set(uiref_fake_limit, 47)
	end

	if ui.get(resolver_exploit_mode) == "Chronicle" then
		if globals.realtime() >= anti_resolve_timer then
			client.delay_call(0.1, ui.set, uiref_fake_limit, 30)
			client.delay_call(0.2, ui.set, uiref_fake_limit, 32)
			client.delay_call(0.3, ui.set, uiref_fake_limit, 34)
			client.delay_call(0.4, ui.set, uiref_fake_limit, 36)
			client.delay_call(0.5, ui.set, uiref_fake_limit, 38)
			client.delay_call(0.6, ui.set, uiref_fake_limit, 40)

			client.delay_call(0.7, ui.set, uiref_fake_limit, 39)
			client.delay_call(0.8, ui.set, uiref_fake_limit, 37)
			client.delay_call(0.9, ui.set, uiref_fake_limit, 35)
			client.delay_call(1.0, ui.set, uiref_fake_limit, 33)
			client.delay_call(1.1, ui.set, uiref_fake_limit, 31)
			client.delay_call(1.2, ui.set, uiref_fake_limit, 29)

			anti_resolve_timer = globals.realtime() + 1.2
		end
	end

	if ui.get(resolver_exploit_mode) == "Mega" then
		if globals.realtime() >= anti_resolve_timer then
			client.delay_call(0.1, ui.set, uiref_fake_limit, 25)
			client.delay_call(0.2, ui.set, uiref_fake_limit, 35)
			client.delay_call(0.4, ui.set, uiref_fake_limit, 55)

			anti_resolve_timer = globals.realtime() + 0.4
		end
	end

	if ui.get(resolver_exploit_mode) == "Aimware" then
		if globals.realtime() >= anti_resolve_timer then
			client.delay_call(0.1, ui.set, uiref_fake_limit, 47)
			client.delay_call(0.2, ui.set, uiref_fake_limit, 37)

			anti_resolve_timer = globals.realtime() + 0.2
		end
	end

	if ui.get(resolver_exploit_mode) == "PerechTeam" then
		if ui.get(skeetsploit) == "PerSyncV2" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.2, ui.set, uiref_fake_limit, 45)
				client.delay_call(0.4, ui.set, uiref_fake_limit, 55) 
				client.delay_call(0.6, ui.set, uiref_fake_limit, 60)
				client.delay_call(0.8, ui.set, uiref_fake_limit, 55)
				client.delay_call(1, ui.set, uiref_fake_limit, 45)

				anti_resolve_timer = globals.realtime() + 0.7
			end
		end

		if ui.get(skeetsploit) == "PerSync" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.5, ui.set, uiref_fake_limit, 2)
                                client.delay_call(0.65, ui.set, uiref_fake_limit, 6)
                                client.delay_call(0.8, ui.set, uiref_fake_limit, 10)
				client.delay_call(0.95, ui.set, uiref_fake_limit, 12)
				client.delay_call(1.1, ui.set, uiref_fake_limit, 10)
                                client.delay_call(1.25, ui.set, uiref_fake_limit, 6)
                                client.delay_call(1.4, ui.set, uiref_fake_limit, 2)
				anti_resolve_timer = globals.realtime() + 1
			end
		end
	elseif ui.get(resolver_exploit_mode) == "Universal" then
		if ui.get(universalmode) == "Phaze" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.1, ui.set, uiref_fake_limit, 34)
				client.delay_call(0.2, ui.set, uiref_fake_limit, 38)
				client.delay_call(0.3, ui.set, uiref_fake_limit, 42)
				client.delay_call(0.4, ui.set, uiref_fake_limit, 46)

				anti_resolve_timer = globals.realtime() + 0.4
			end
		end

		if ui.get(universalmode) == "LBY" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.1, ui.set, uiref_fake_limit, 58)
				client.delay_call(1.1, ui.set, uiref_fake_limit, 1)

				anti_resolve_timer = globals.realtime() + 1.1
			end
		end
	elseif ui.get(resolver_exploit_mode) == "Break Bruteforce" then
		if ui.get(brutemode) == "Slow" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.1, ui.set, uiref_fake_limit, 47)
				client.delay_call(1.1, ui.set, uiref_fake_limit, 2)

				anti_resolve_timer = globals.realtime() + 1.1
			end
		end

		if ui.get(brutemode) == "Fast" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.1, ui.set, uiref_fake_limit, 47)
				client.delay_call(0.5, ui.set, uiref_fake_limit, 2)

				anti_resolve_timer = globals.realtime() + 0.5
			end
		end

		if ui.get(brutemode) == "Jitter" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.1, ui.set, uiref_fake_limit, 47)
				client.delay_call(0.2, ui.set, uiref_fake_limit, 2)

				anti_resolve_timer = globals.realtime() + 0.2
			end
		end
	elseif ui.get(resolver_exploit_mode) == "Custom" then
		if ui.get(custommode) == "Jitter" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.1, ui.set, uiref_fake_limit, ui.get(customangle1))
				client.delay_call(0.2, ui.set, uiref_fake_limit, ui.get(customangle2))

				anti_resolve_timer = globals.realtime() + 0.2
			end
		end

		if ui.get(custommode) == "Static" then
			if globals.realtime() >= anti_resolve_timer then
				client.delay_call(0.1, ui.set, uiref_fake_limit, ui.get(customangle1))

				anti_resolve_timer = globals.realtime() + 0.1
			end
		end
	end
end

local function nospread_aa()
	if not ui.get(enable_PerSync_aa) then return end
	nospread_mode_desync_selected = ui.get(nospreaddesnyc)

	if globals.realtime() >= delay_time and nospread_mode_desync_selected == "Verse" then
		ui.set(uiref_yaw, "180")
		ui.set(uiref_fake_yaw, "Static")

		client.delay_call(0.01, ui.set, uiref_yaw_slider, client.random_int(-58, 0))
		client.delay_call(0.015, ui.set, uiref_fake_yaw_slider, ui.get(uiref_yaw_slider))
		client.delay_call(0.02, ui.set, uiref_yaw_slider, client.random_int(0, 58))

		delay_time = globals.realtime() + 0.02
	end

	if globals.realtime() >= delay_time and nospread_mode_desync_selected == "Half back" then
		ui.set(uiref_yaw, "180")
		ui.set(uiref_fake_yaw, "Static")
		ui.set(uiref_fake_yaw_slider, 0)

		client.delay_call(0.01, ui.set, uiref_yaw_slider, 90)
		client.delay_call(0.02, ui.set, uiref_yaw_slider, -90)
		client.delay_call(0.03, ui.set, uiref_yaw_slider, 30)
		client.delay_call(0.04, ui.set, uiref_yaw_slider, -30)
		client.delay_call(0.05, ui.set, uiref_yaw_slider, 12)

		delay_time = globals.realtime() + 0.05
	end
end

local function on_shot(e)
	if not ui.get(enable_PerSync_aa) then return end
	if (client.userid_to_entindex(e.userid) == entity.get_local_player() and contains(ui.get(manual_mode), "Real") and ui.get(evade_mode) ~= "Off") then
		antiresolve = true
	end

	if (client.userid_to_entindex(e.userid) == entity.get_local_player()) then
		if ui.get(resolver_exploit_mode) == "Aimware" then
			if contains(ui.get(aimwaresploit), "Shooting") then
				client.delay_call(0.1, ui.set, uiref_pitch, "Off")
				client.delay_call(.5, ui.set, uiref_pitch, "Down")
			end
		end
	end
end

local function stepaa(e)
	if not ui.get(enable_PerSync_aa) then return end
	if (client.userid_to_entindex(e.userid) == entity.get_local_player() and ui.get(aamodedesync) == "Step") then
		if ui.get(uiref_yaw_slider) < 0 then
			ui.set(uiref_yaw_slider, ui.get(stepangle1))
			ui.set(uiref_fake_yaw_slider, -90)
		elseif ui.get(uiref_yaw_slider) > 0 then
			ui.set(uiref_yaw_slider, ui.get(stepangle2))
			ui.set(uiref_fake_yaw_slider, 90)
		end
	end
end

local function jumpaa(e)
	if not ui.get(enable_PerSync_aa) then return end
	if (client.userid_to_entindex(e.userid) == entity.get_local_player()) then
		if ui.get(resolver_exploit_mode) == "Aimware" then
			if contains(ui.get(aimwaresploit), "Jump") then
				client.delay_call(0.1, ui.set, uiref_pitch, "Off")
				client.delay_call(.5, ui.set, uiref_pitch, "Down")
			end
		end
	end

	if (client.userid_to_entindex(e.userid) == entity.get_local_player() and ui.get(nospreaddesnyc) == "Crooked") then
		ui.set(uiref_yaw_slider, client.random_int(-180, 180))
	end
end
--endregion

--region hooks
client.set_event_callback('run_command', spread_aa)
client.set_event_callback('run_command', nospread_aa)
client.set_event_callback("run_command", anti_resolver)
client.set_event_callback('run_command', while_timings)
client.set_event_callback('paint', arrows)
client.set_event_callback('weapon_fire', on_shot)
client.set_event_callback("player_footstep", stepaa)
client.set_event_callback("player_jump", jumpaa)
