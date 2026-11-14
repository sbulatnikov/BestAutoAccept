--------------------------------------------------------------------------------
-- BestAutoAccept / UI.lua
-- Кнопка, окно настроек, чёрный список, подсказки, уведомления.
--------------------------------------------------------------------------------
BAA.UI = {}
local UI = BAA.UI
local W, Child, Show, Enable, Fade, SetText, SetVariant, SetTex = BAA.W, BAA.Child, BAA.Show, BAA.Enable, BAA.Fade, BAA.SetText,
	BAA.SetVariant, BAA.SetTex
local S, WS = BAA.S, BAA.WS

local ui = {}
UI.ui = ui
UI.view = "main"            -- main | settings
local blocked = nil         -- сегмент, который нельзя снять: { key, left }
local editing = {}          -- [номер строки команды] = true, пока поле задержки в фокусе
local blDirty = true

local SEG_KEYS = { SegAll = "all", SegFriends = "friends", SegGuild = "guild" }
local VAR_OFF, VAR_ON, VAR_BLOCKED = 0, 1, 2

--------------------------------------------------------------------------------
-- Инициализация
--------------------------------------------------------------------------------
function UI.Init()
	ui.window = W( "BAAWindow" )
	ui.host = W( "BAAHost" )
	ui.button = W( "BAAButton" )
	ui.icon = W( "BAAIcon" )
	ui.ring = W( "BAARing" )
	ui.bar = W( "BAABar" )
	ui.barFill = W( "BAABarFill" )
	ui.header = W( "Header" )
	ui.mainPage = W( "MainPage" )
	ui.settingsPage = W( "SettingsPage" )
	ui.statusActive = W( "StatusActive" )
	ui.statusPause = W( "StatusPause" )
	ui.gear = W( "HdrGear" ); ui.gearIcon = W( "HdrGearIcon" )
	ui.pause = W( "HdrPause" ); ui.pauseIcon = W( "HdrPauseIcon" )
	ui.segs = { all = W( "SegAll" ), friends = W( "SegFriends" ), guild = W( "SegGuild" ) }
	ui.cmds = {}
	for i, c in ipairs( BAA.CMDS ) do
		local row = W( "CmdRow" .. i )
		local box = Child( row, "CdBox" )
		local r = { row = row, chip = Child( row, "CmdChip" ), name = Child( row, "CmdName" ), switch = Child( row, "CmdSwitch" ), box = box,
			minus = Child( box, "CdMinus" ), plus = Child( box, "CdPlus" ), edit = Child( box, "CdEdit" ), focus = Child( box, "CdFocus" ),
			unit = Child( box, "CdUnit" ) }
		SetText( Child( r.chip, "CmdCode" ), c.code )
		SetText( r.name, c.label )
		SetText( r.unit, "с" )
		ui.cmds[ i ] = r
	end
	ui.accs = {}
	for i, a in ipairs( BAA.ACCS ) do
		local row = W( "AccRow" .. i )
		local r = { row = row, icon = Child( row, "AccIcon" ), name = Child( row, "AccName" ), switch = Child( row, "AccSwitch" ) }
		SetText( r.name, a.label )
		ui.accs[ i ] = r
	end
	SetText( W( "WhoTitle" ), "На кого реагируем" )
	SetText( W( "CmdTitle" ), "Команды в личке" )
	SetText( W( "AccTitle" ), "Автопринятие" )
	SetText( W( "BlTitle" ), "Чёрный список" )
	SetText( W( "BlEmpty" ), "Список пуст" )
	SetText( W( "BlHint" ), "Ник персонажа" )
	ui.blEdit = W( "BlEdit" )
	ui.blHint = W( "BlHint" )
	ui.blErr = W( "BlInputErr" )
	ui.blList = W( "BlList" )
	ui.blRow = W( "BlRow" )
	ui.blEmpty = W( "BlEmpty" )
	ui.blCount = W( "BlCount" )
	ui.tip = W( "Tooltip" )
	ui.tipText = W( "TipText" )
	ui.tipBack = W( "TipBack" )
	ui.tipWarn = W( "TipBackWarn" )
	ui.toasts = {}
	for i = 1, 3 do
		local t = W( "Toast" .. i )
		ui.toasts[ i ] = { w = t, chip = Child( t, "ToastChip" ), icon = Child( t, "ToastIcon" ), text = Child( t, "ToastText" ) }
		ui.toasts[ i ].code = Child( ui.toasts[ i ].chip, "ToastCode" )
		ui.toasts[ i ].img = Child( ui.toasts[ i ].icon, "ToastIconImg" )
	end
	ui.follow = W( "FollowPrompt" )
	ui.followText = W( "FollowText" )
	Show( ui.window, false )
	Show( ui.blRow, false )
	Show( ui.tip, false )
end

--------------------------------------------------------------------------------
-- Отрисовка
--------------------------------------------------------------------------------
local function Plural( n )
	local m10, m100 = n % 10, n % 100
	if m10 == 1 and m100 ~= 11 then return n .. " персонаж" end
	if m10 >= 2 and m10 <= 4 and ( m100 < 12 or m100 > 14 ) then return n .. " персонажа" end
	return n .. " персонажей"
end

-- Число и «с» стоят по центру поля задержки (строка ввода сама выравнивает текст только влево)
local CD_BOX, CD_SIDE, CD_DIGIT, CD_GAP, CD_UNIT = 101, 26, 9, 4, 8
local function PlaceCd( row, digits )
	if row.digits == digits or not row.edit or not row.unit then return end
	row.digits = digits
	local numW = digits * CD_DIGIT
	local x = CD_SIDE + math.floor( ( CD_BOX - 2 * CD_SIDE - ( numW + CD_GAP + CD_UNIT ) ) / 2 + 0.5 )
	local pe = row.edit:GetPlacementPlain()
	pe.posX = x
	row.edit:SetPlacementPlain( pe )
	local pu = row.unit:GetPlacementPlain()
	pu.posX = x + numW + CD_GAP
	row.unit:SetPlacementPlain( pu )
end

local function RenderButton()
	local n, total = BAA.Cfg.CountOn()
	local v, icon
	if BAA.cfg.paused then v, icon = 3, "MAIN_PAUSE"
	elseif n == total then v, icon = 0, "MAIN_ON"
	elseif n == 0 then v, icon = 2, "MAIN_OFF"
	else v, icon = 1, "MAIN_PART" end
	SetVariant( ui.button, v )
	SetTex( ui.icon, icon )
	Show( ui.bar, v == 1 )
	if v == 1 and ui.barFill then
		local pl = ui.barFill:GetPlacementPlain()
		local w = math.max( 2, math.floor( 16 * n / total + 0.5 ) )
		if pl.sizeX ~= w then pl.sizeX = w ui.barFill:SetPlacementPlain( pl ) end
	end
	Show( ui.ring, ui.window and ui.window:IsVisible() )
end

local function RenderBlacklist()
	local bl = BAA.cfg.bl
	SetText( ui.blCount, #bl > 0 and Plural( #bl ) or "" )
	Show( ui.blEmpty, #bl == 0 )
	if not blDirty or not ui.blList or not ui.blRow then return end
	blDirty = false
	ui.blList:RemoveItems()
	for _, row in ipairs( ui.blRows or {} ) do row:DestroyWidget() end
	ui.blRows = {}
	local desc = ui.blRow:GetWidgetDesc()
	for i, name in ipairs( bl ) do
		local row = mainForm:CreateChildByDesc( desc )
		row:SetName( "BlRow" .. i )
		Child( row, "BlRowName" ):SetVal( "value", WS( name ) )
		row:Show( true )
		ui.blList:PushBack( row )
		ui.blRows[ #ui.blRows + 1 ] = row
	end
end

function UI.Render()
	if not ui.window then return end
	local cfg = BAA.cfg
	RenderButton()
	if not ui.window:IsVisible() then return end
	local paused = cfg.paused
	Show( ui.statusActive, not paused )
	Show( ui.statusPause, paused )
	local settings = UI.view == "settings"
	Show( ui.mainPage, not settings )
	Show( ui.settingsPage, settings )
	SetVariant( ui.gear, settings and 1 or 0 )
	SetTex( ui.gearIcon, settings and "GEAR_ON" or "GEAR" )
	SetVariant( ui.pause, paused and 1 or 0 )
	SetTex( ui.pauseIcon, paused and "PLAY" or "PAUSE" )
	Fade( ui.mainPage, paused and 0.45 or 1 )

	-- на кого реагируем
	local r = cfg.react
	for key, w in pairs( ui.segs ) do
		local disabled = key ~= "all" and r.all
		Enable( w, not disabled )
		if blocked and blocked.key == key then SetVariant( w, VAR_BLOCKED )
		else SetVariant( w, r[ key ] and VAR_ON or VAR_OFF ) end
	end

	-- команды
	for i, c in ipairs( BAA.CMDS ) do
		local st, row = cfg.cmds[ c.k ], ui.cmds[ i ]
		SetVariant( row.switch, st.on and 1 or 0 )
		Fade( row.chip, st.on and 1 or 0.4 )
		Fade( row.name, st.on and 1 or 0.55 )
		Fade( row.box, st.on and 1 or 0.38 )
		Enable( row.minus, st.on )
		Enable( row.plus, st.on )
		Enable( row.edit, st.on )
		Show( row.focus, editing[ i ] and true or false )
		if not editing[ i ] and row.edit then
			local s = tostring( st.cd )
			if row.shown ~= s then row.shown = s row.edit:SetText( WS( s ) ) end
			PlaceCd( row, #s )
		elseif editing[ i ] then
			PlaceCd( row, 2 )
		end
	end

	-- автопринятие
	for i, a in ipairs( BAA.ACCS ) do
		local on, row = cfg.acc[ a.k ], ui.accs[ i ]
		SetVariant( row.switch, on and 1 or 0 )
		SetTex( row.icon, "ACC_" .. a.icon .. ( on and "_ON" or "_OFF" ) )
		Fade( row.name, on and 1 or 0.55 )
	end

	if settings then RenderBlacklist() end
end

function UI.Changed()
	BAA.Cfg.Save()
	UI.Render()
end

function UI.ShowWindow( on )
	Show( ui.window, on )
	if not on then UI.HideTip() end
	UI.Render()
end

function UI.ToggleWindow()
	UI.ShowWindow( not ui.window:IsVisible() )
end

--------------------------------------------------------------------------------
-- Подсказки
--------------------------------------------------------------------------------
local tipLeft = 0
local TIP_W = 300

local function SegTip( key )
	local r = BAA.cfg.react
	if blocked and blocked.key == key then return "Нельзя снять последний вариант. Чтобы реагировать на всех, включите «Все»", true end
	if key == "all" then return "Реагировать на любого игрока" end
	if r.all then return "Выключите «Все», чтобы выбрать только друзей или согильдейцев" end
	if key == "friends" then return "Реагировать на игроков из списка друзей" end
	return "Реагировать на членов вашей гильдии"
end

local function RowIndex( w, prefix )
	local p = w
	for _ = 1, 3 do
		if not p then return nil end
		local n = tonumber( string.match( p:GetName() or "", "^" .. prefix .. "(%d+)$" ) or "" )
		if n then return n end
		p = p:GetParent()
	end
	return nil
end

local function TipFor( w )
	local name = w:GetName()
	local cfg = BAA.cfg
	if SEG_KEYS[ name ] then return SegTip( SEG_KEYS[ name ] ) end
	if name == "WhoTitle" then return "Команды и автопринятие срабатывают только для выбранных игроков. Чёрный список действует всегда" end
	if name == "CmdTitle" then return "Игрок пишет вам в личку короткую команду — аддон выполняет её" end
	if name == "AccTitle" then return "Что принимать сразу, без окна с вопросом" end
	if name == "CdHead" then return "Задержка в секундах: команда выполняется через N секунд после сообщения. 0 — сразу" end
	if name == "BlTitle" then return "На этих персонажей аддон не реагирует: ни на команды в личке, ни на приглашения. Действует поверх «На кого реагируем»" end
	if name == "StatusChip" then return cfg.paused and "Пауза — ничего не срабатывает" or "Аддон работает по настройкам" end
	if name == "HdrGear" then
		return UI.view == "settings" and "Вернуться к основным настройкам" or "Настройки: чёрный список. Все настройки аддона общие для всех персонажей"
	end
	if name == "HdrPause" then
		return cfg.paused and "Снять паузу — всё снова работает по настройкам" or "Пауза: временно отключить все команды и автопринятие. Настройки не меняются"
	end
	if name == "HdrClose" then return "Закрыть окно" end
	if name == "CmdName" or name == "CmdChip" then
		local i = RowIndex( w, "CmdRow" )
		return i and BAA.CMDS[ i ] and BAA.CMDS[ i ].tip
	end
	if name == "CdBox" then
		local i = RowIndex( w, "CmdRow" )
		local st = i and cfg.cmds[ BAA.CMDS[ i ].k ]
		if not st then return nil end
		if not st.on then return "Команда выключена — включите её, чтобы задать задержку" end
		if st.cd == 0 then return "Без задержки: команда выполняется сразу" end
		return "Команда выполняется через " .. st.cd .. " с после сообщения. Колесо мыши или -/+ меняют на 5 с"
	end
	if name == "AccName" or name == "AccIcon" then
		local i = RowIndex( w, "AccRow" )
		return i and BAA.ACCS[ i ] and BAA.ACCS[ i ].tip
	end
	return nil
end

function UI.ShowTip( anchor, text, warn, seconds )
	if not ui.tip or not anchor or not text then return end
	local rect = anchor:GetRealRect()
	-- Ожидаем: у скрытого виджета может не быть размеров — подсказку не показываем
	if type( rect ) ~= "table" then return end
	local lines = math.max( 1, math.ceil( BAA.CharLen( text ) / 36 ) )
	local h = lines * 18 + 14
	local pl = ui.tip:GetPlacementPlain()
	pl.alignX = WIDGET_ALIGN_LOW_ABS
	pl.alignY = WIDGET_ALIGN_LOW_ABS
	pl.posX = math.floor( rect.x1 )
	pl.posY = math.floor( rect.y2 + 6 )
	pl.sizeX = TIP_W
	pl.sizeY = h
	ui.tip:SetPlacementPlain( pl )
	SetText( ui.tipText, text )
	Show( ui.tipBack, not warn )
	Show( ui.tipWarn, warn and true or false )
	Show( ui.tip, true )
	tipLeft = seconds or 6
end

function UI.HideTip()
	Show( ui.tip, false )
	tipLeft = 0
end

function UI.OnPointing( params )
	local w = params and params.widget
	if not w then return end
	if params.active == false then UI.HideTip() return end
	local text, warn = TipFor( w )
	if text then UI.ShowTip( w, text, warn ) else UI.HideTip() end
end

--------------------------------------------------------------------------------
-- Уведомления
--------------------------------------------------------------------------------
local toastData = {}   -- новые сверху: { code | icon, text, left }

local function RenderToasts()
	for i = 1, 3 do
		local t, d = ui.toasts[ i ], toastData[ i ]
		if d then
			Show( t.chip, d.code ~= nil )
			Show( t.icon, d.code == nil )
			if d.code then SetText( t.code, d.code ) else SetTex( t.img, "ACC_" .. ( d.icon or "GROUP" ) .. "_TOAST" ) end
			SetText( t.text, d.text )
			Show( t.w, true )
		else
			Show( t.w, false )
		end
	end
end

function UI.Toast( d )
	d.left = BAA.TOAST_TIME
	table.insert( toastData, 1, d )
	while #toastData > 3 do table.remove( toastData ) end
	RenderToasts()
end

local followId, followLeft = nil, 0

function UI.FollowPrompt( name, id )
	followId = id
	followLeft = 15
	SetText( ui.followText, "Следовать за " .. name .. "?" )
	Show( ui.follow, true )
end

function UI.OnFollow()
	Show( ui.follow, false )
	local id = followId
	followId = nil
	if not id then return end
	-- Ожидаем: пока игрок думал, тот мог уйти из видимости
	if not object.IsExist( id ) then return UI.Toast( { code = ">>", text = "Игрок уже не рядом" } ) end
	avatar.SelectTarget( id )  -- по клику SelectTarget разрешён
	avatar.SetFollowTarget( true )
	UI.Toast( { code = ">>", text = "Следую за " .. S( object.GetName( id ) ) } )
end

--------------------------------------------------------------------------------
-- Таймер
--------------------------------------------------------------------------------
function UI.OnSecond()
	local changed = false
	for i = #toastData, 1, -1 do
		local d = toastData[ i ]
		d.left = d.left - 1
		if d.left <= 0 then table.remove( toastData, i ) changed = true end
	end
	if changed then RenderToasts() end
	if followLeft > 0 then
		followLeft = followLeft - 1
		if followLeft <= 0 then Show( ui.follow, false ) followId = nil end
	end
	if tipLeft > 0 then
		tipLeft = tipLeft - 1
		if tipLeft <= 0 then UI.HideTip() end
	end
	if blocked then
		blocked.left = blocked.left - 1
		if blocked.left <= 0 then blocked = nil UI.Render() end
	end
end

--------------------------------------------------------------------------------
-- Реакции
--------------------------------------------------------------------------------
function UI.OnSeg( params )
	local key = SEG_KEYS[ params.sender or "" ] or ( params.widget and SEG_KEYS[ params.widget:GetName() ] )
	if not key then return end
	local r = BAA.cfg.react
	if key == "all" then
		if r.all then
			local f, g = r.memF, r.memG
			if not f and not g then f = true end
			r.all, r.friends, r.guild = false, f, g
		else
			r.memF, r.memG = r.friends, r.guild
			r.all, r.friends, r.guild = true, false, false
		end
	else
		if r.all then return end
		local other = key == "friends" and "guild" or "friends"
		if r[ key ] and not r[ other ] then
			blocked = { key = key, left = 3 }
			UI.Render()
			UI.ShowTip( ui.segs[ key ], SegTip( key ), true, 3 )
			return
		end
		r[ key ] = not r[ key ]
	end
	blocked = nil
	UI.Changed()
end

local function CmdIndex( params )
	return params.widget and RowIndex( params.widget, "CmdRow" )
end

function UI.OnCmdSwitch( params )
	local i = CmdIndex( params )
	local c = i and BAA.CMDS[ i ]
	if not c then return end
	local st = BAA.cfg.cmds[ c.k ]
	st.on = not st.on
	UI.Changed()
end

local function SetCd( i, v )
	local c = BAA.CMDS[ i ]
	if not c then return end
	local st = BAA.cfg.cmds[ c.k ]
	if not st.on then return end
	v = math.max( 0, math.min( BAA.CD_MAX, math.floor( v ) ) )
	if st.cd ~= v then
		st.cd = v
		ui.cmds[ i ].shown = nil
		UI.Changed()
	end
end

local function Step( i, dir )
	local c = BAA.CMDS[ i ]
	if not c then return end
	local cd = BAA.cfg.cmds[ c.k ].cd
	if dir > 0 then SetCd( i, math.floor( cd / 5 ) * 5 + 5 )
	else SetCd( i, cd - 5 < 0 and 0 or math.ceil( cd / 5 ) * 5 - 5 ) end
end

function UI.OnCdMinus( params ) local i = CmdIndex( params ) if i then Step( i, -1 ) end end
function UI.OnCdPlus( params ) local i = CmdIndex( params ) if i then Step( i, 1 ) end end
function UI.OnCdUp( params ) local i = CmdIndex( params ) if i then Step( i, 1 ) end end
function UI.OnCdDown( params ) local i = CmdIndex( params ) if i then Step( i, -1 ) end end

-- Значение проверяется после ввода: Enter или потеря фокуса; Esc возвращает прежнее
local function Commit( i )
	local row = ui.cmds[ i ]
	if not row then return end
	editing[ i ] = nil
	local v = tonumber( BAA.Trim( S( row.edit:GetText() ) ) )
	row.shown = nil
	if v then SetCd( i, v ) end
	UI.Render()
end

function UI.OnCdFocus( params )
	local i = CmdIndex( params )
	if not i then return end
	if params.active then
		editing[ i ] = true
		UI.Render()
	elseif editing[ i ] then
		Commit( i )
	end
end

function UI.OnCdEnter( params )
	local i = CmdIndex( params )
	if not i then return end
	Commit( i )
	params.widget:SetFocus( false )
end

function UI.OnCdEsc( params )
	local i = CmdIndex( params )
	if not i then return end
	editing[ i ] = nil
	ui.cmds[ i ].shown = nil
	params.widget:SetFocus( false )
	UI.Render()
end

function UI.OnAccSwitch( params )
	local i = params.widget and RowIndex( params.widget, "AccRow" )
	local a = i and BAA.ACCS[ i ]
	if not a then return end
	BAA.cfg.acc[ a.k ] = not BAA.cfg.acc[ a.k ]
	UI.Changed()
end

function UI.OnGear()
	UI.view = UI.view == "settings" and "main" or "settings"
	if UI.view == "settings" then blDirty = true end
	UI.HideTip()
	UI.Render()
end

function UI.OnPause()
	BAA.cfg.paused = not BAA.cfg.paused
	UI.Changed()
end

-- Чёрный список
local function BlText() return BAA.Trim( S( ui.blEdit:GetText() ) ) end

local function BlUpdateHint()
	Show( ui.blHint, BlText() == "" )
end

function UI.OnBlChanged()
	Show( ui.blErr, false )
	BlUpdateHint()
end

function UI.OnBlAdd()
	local text = BlText()
	if text == "" then return end
	local err = BAA.Cfg.BlacklistAdd( text )
	if err then
		Show( ui.blErr, true )
		UI.ShowTip( W( "BlInput" ), err, true, 3 )
		return
	end
	Show( ui.blErr, false )
	ui.blEdit:SetText( WS( "" ) )
	BlUpdateHint()
	UI.HideTip()
	blDirty = true
	UI.Render()
end

function UI.OnBlEsc()
	ui.blEdit:SetText( WS( "" ) )
	Show( ui.blErr, false )
	BlUpdateHint()
	ui.blEdit:SetFocus( false )
end

function UI.OnBlRemove( params )
	local row = params.widget and params.widget:GetParent()
	local i = row and tonumber( string.match( row:GetName() or "", "^BlRow(%d+)$" ) or "" )
	if not i then return end
	BAA.Cfg.BlacklistRemove( i )
	blDirty = true
	UI.Render()
end
