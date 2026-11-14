--------------------------------------------------------------------------------
-- BestAutoAccept / Config.lua
-- Настройки — глобальные, одни на всех персонажей.
-- Файл: Mods/Configs/BestAutoAccept/user.cfg, блок global -> ... -> data:
--   baa = { ... }    — настройки аддона
--   DnD:...          — положения кнопки и окна (LibDnD)
-- Секция пишется целиком, поэтому перед записью читаем её заново.
--------------------------------------------------------------------------------
BAA.Cfg = {}
local Cfg = BAA.Cfg

BAA.CMDS = {
	{ k = "invite", code = "++", label = "Пригласить в группу", cd = 0,
		tip = "Игрок пишет вам в личку «++» — вы приглашаете его в свою группу или отряд" },
	{ k = "leader", code = "!!", label = "Передать лидерство", cd = 0,
		tip = "«!!» в личке — вы передаёте игроку лидерство. Сработает, если вы лидер и он в вашем формировании" },
	{ k = "ready", code = "??", label = "Проверка готовности", cd = 0,
		tip = "«??» в личке — вы запускаете проверку готовности. Нужны права лидера или помощника" },
	{ k = "trade", code = "##", label = "Начать обмен", cd = 0,
		tip = "«##» в личке — вы предлагаете игроку обмен. Игрок должен быть рядом" },
	{ k = "follow", code = ">>", label = "Следовать за игроком", cd = 0,
		tip = "«>>» в личке — ваш персонаж начинает следовать за игроком" },
}

BAA.ACCS = {
	{ k = "group", icon = "GROUP", label = "Приглашение в группу/отряд",
		tip = "Сразу принимать приглашение в группу или отряд" },
	{ k = "activity", icon = "ACTIVITY", label = "Приглашение в активность",
		tip = "Сразу принимать приглашение в активность" },
	{ k = "trade", icon = "TRADE", label = "Предложение обмена",
		tip = "Когда игрок предлагает обмен, аддон сразу отправляет ему встречное предложение обмена" },
	{ k = "vehicle", icon = "VEHICLE", label = "Транспорт",
		tip = "Сразу садиться в транспорт игрока или к нему на мотоцикл" },
	{ k = "carry", icon = "CARRY", label = "На ручки!",
		tip = "Сразу соглашаться, когда игрок предлагает взять вас на руки" },
	{ k = "res", icon = "RES", label = "Воскрешение",
		tip = "Сразу принимать воскрешение от игрока" },
}

BAA.CMD_BY_CODE = {}
for _, c in ipairs( BAA.CMDS ) do BAA.CMD_BY_CODE[ c.code ] = c end

local function Defaults()
	local d = {
		version = 1,
		react = { all = false, friends = true, guild = true, memF = true, memG = true },
		cmds = {},
		acc = {},
		bl = {},
		paused = false,
	}
	for _, c in ipairs( BAA.CMDS ) do d.cmds[ c.k ] = { on = true, cd = c.cd } end
	for _, a in ipairs( BAA.ACCS ) do d.acc[ a.k ] = true end
	return d
end

local function Merge( dst, src )
	for k, v in pairs( src ) do
		if dst[ k ] == nil then
			dst[ k ] = BAA.Copy( v )
		elseif type( v ) == "table" and type( dst[ k ] ) == "table" and k ~= "bl" then
			Merge( dst[ k ], v )
		end
	end
end

function BAA.Copy( t )
	if type( t ) ~= "table" then return t end
	local r = {}
	for k, v in pairs( t ) do r[ k ] = BAA.Copy( v ) end
	return r
end

local function ReadSection()
	local g = userMods.GetGlobalConfigSection( common.GetAddonName() )
	-- Ожидаем: при первом запуске секции настроек нет (nil) — начинаем с пустой
	return type( g ) == "table" and g or {}
end

function Cfg.Load()
	local g = ReadSection()
	local c = type( g.baa ) == "table" and g.baa or {}
	Merge( c, Defaults() )
	-- починка: «на кого реагируем» не может быть пустым
	if not c.react.all and not c.react.friends and not c.react.guild then c.react.friends = true end
	for _, cmd in ipairs( BAA.CMDS ) do
		local s = c.cmds[ cmd.k ]
		s.cd = math.max( 0, math.min( BAA.CD_MAX, math.floor( tonumber( s.cd ) or cmd.cd ) ) )
	end
	BAA.cfg = c
	BAA.DEBUG = ( g.debug == true ) --@debug
	Cfg.RebuildBlacklist()
end

function Cfg.Save()
	local g = ReadSection()
	g.baa = BAA.cfg
	g.debug = BAA.DEBUG and true or false --@debug
	userMods.SetGlobalConfigSection( common.GetAddonName(), g )
end

--------------------------------------------------------------------------------
-- Чёрный список
--------------------------------------------------------------------------------
local blSet = {}

function Cfg.RebuildBlacklist()
	blSet = {}
	for _, n in ipairs( BAA.cfg.bl ) do blSet[ BAA.Lower( n ) ] = true end
end

function Cfg.IsBlacklisted( name )
	return blSet[ BAA.Lower( name or "" ) ] and true or false
end

-- nil, если добавлено; иначе текст ошибки
function Cfg.BlacklistAdd( name )
	name = BAA.Trim( name )
	local n = BAA.CharLen( name )
	if n < BAA.NICK_MIN or n > BAA.NICK_MAX then return "Ник — от 3 до 14 символов" end
	if Cfg.IsBlacklisted( name ) then return "Этот персонаж уже в списке" end
	table.insert( BAA.cfg.bl, 1, name )
	Cfg.RebuildBlacklist()
	Cfg.Save()
	return nil
end

function Cfg.BlacklistRemove( index )
	if BAA.cfg.bl[ index ] then
		table.remove( BAA.cfg.bl, index )
		Cfg.RebuildBlacklist()
		Cfg.Save()
	end
end

-- Сколько пунктов включено (5 команд + 6 автопринятий)
function Cfg.CountOn()
	local n, total = 0, 0
	for _, c in ipairs( BAA.CMDS ) do total = total + 1 if BAA.cfg.cmds[ c.k ].on then n = n + 1 end end
	for _, a in ipairs( BAA.ACCS ) do total = total + 1 if BAA.cfg.acc[ a.k ] then n = n + 1 end end
	return n, total
end
