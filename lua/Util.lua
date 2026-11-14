--------------------------------------------------------------------------------
-- BestAutoAccept / Util.lua
-- Общие помощники: строки, кэш виджетов. Файл в Windows-1251.
--------------------------------------------------------------------------------
Global( "BAA", {} )

BAA.VERSION = "0.9.4"
BAA.tick = 0               -- секунды с запуска (EVENT_SECOND_TIMER)
BAA.NICK_MIN = 3
BAA.NICK_MAX = 14
BAA.CD_MAX = 30             -- задержка реакции: приглашения в игре живут не дольше 30 с
BAA.TOAST_TIME = 5

--------------------------------------------------------------------------------
-- Строки
--------------------------------------------------------------------------------
function BAA.WS( s )
	return userMods.ToWString( s or "" )
end

-- Обычная строка из string или WString; для остального — пустая строка
function BAA.S( v )
	if type( v ) == "string" then return v end
	-- Ожидаем: на входе может быть не строка (nil, число, другой объект API) — тогда пустая строка
	if v ~= nil and apitype( v ) == "WString" then return userMods.FromWString( v ) end
	return ""
end

function BAA.Trim( s )
	return ( string.gsub( s or "", "^%s*(.-)%s*$", "%1" ) )
end

-- Строка в UTF-8 с многобайтными символами?
local function IsUtf8( s )
	local i, len, multi = 1, #s, false
	while i <= len do
		local c = string.byte( s, i )
		local k = ( c < 0x80 and 1 ) or ( c >= 0xC2 and c <= 0xDF and 2 ) or ( c >= 0xE0 and c <= 0xEF and 3 ) or ( c >= 0xF0 and c <= 0xF4 and 4 ) or 0
		if k == 0 or i + k - 1 > len then return false end
		for j = i + 1, i + k - 1 do
			local b = string.byte( s, j )
			if b < 0x80 or b > 0xBF then return false end
		end
		if k > 1 then multi = true end
		i = i + k
	end
	return multi
end

-- Нижний регистр для латиницы и кириллицы (UTF-8 или Windows-1251)
function BAA.Lower( s )
	s = s or ""
	if IsUtf8( s ) then
		s = string.gsub( s, "\208([\144-\175])", function( c )
			local b = string.byte( c )
			if b <= 0x9F then return "\208" .. string.char( b + 0x20 ) end -- А..П -> а..п
			return "\209" .. string.char( b - 0x20 )                          -- Р..Я -> р..я
		end )
		s = string.gsub( s, "\208\129", "\209\145" ) -- Ё -> ё
		return ( string.gsub( s, "%u", string.lower ) )
	end
	return ( string.gsub( s, ".", function( c )
		local b = string.byte( c )
		if ( b >= 65 and b <= 90 ) or ( b >= 0xC0 and b <= 0xDF ) then return string.char( b + 32 ) end
		if b == 0xA8 then return string.char( 0xB8 ) end
		return c
	end ) )
end

-- Длина в символах (UTF-8 или однобайтная кодировка)
function BAA.CharLen( s )
	s = s or ""
	if not IsUtf8( s ) then return #s end
	local n = 0
	for _ in string.gmatch( s, "[^\128-\191]" ) do n = n + 1 end
	return n
end

function BAA.F( fmt, ... )
	return string.format( fmt, ... )
end

--@debug
--------------------------------------------------------------------------------
-- Отладочная сборка: запись в Personal\\Logs\\mods.txt (в обычной сборке этого блока нет)
--------------------------------------------------------------------------------
BAA.DEBUG = false

function BAA.Chat( text )
	userMods.SendSelfChatMessage( BAA.WS( "[BAA] " .. tostring( text ) ), "message" )
end

local function Join( ... )
	local parts = {}
	for i = 1, select( "#", ... ) do
		local v = ( select( i, ... ) )
		local s = BAA.S( v )
		if s == "" and type( v ) ~= "string" then s = tostring( v ) end
		parts[ #parts + 1 ] = s
	end
	return table.concat( parts, " " )
end

function BAA.File( text )
	common.LogInfo( "common", BAA.WS( "[BAA] " .. tostring( text ) ) )
end

function BAA.Log( ... )
	if BAA.DEBUG then BAA.File( Join( ... ) ) end
end
--@end

--------------------------------------------------------------------------------
-- Персонаж
--------------------------------------------------------------------------------
function BAA.MyName()
	-- Ожидаем: до входа в мир аватара нет — тогда пустое имя
	if avatar.IsExist() then return BAA.S( object.GetName( avatar.GetId() ) ) end
	return ""
end

--------------------------------------------------------------------------------
-- Виджеты (как в RPL: кэш и пропуск повторных вызовов с тем же значением)
--------------------------------------------------------------------------------
local widgetCache = {}

function BAA.W( name )
	local w = widgetCache[ name ]
	if w == nil then
		w = mainForm:GetChildChecked( name, true ) or false
		widgetCache[ name ] = w
	end
	return w or nil
end

function BAA.Child( parent, name )
	if not parent then return nil end
	return parent:GetChildChecked( name, false )
end

local memo = setmetatable( {}, { __mode = "k" } )
local function M( w )
	local m = memo[ w ]
	if not m then m = {} memo[ w ] = m end
	return m
end

function BAA.Show( w, on )
	if not w then return end
	on = on and true or false
	local m = M( w )
	if m.show ~= on then m.show = on w:Show( on ) end
end

function BAA.Enable( w, on )
	if not w then return end
	on = on and true or false
	local m = M( w )
	if m.enable ~= on then m.enable = on w:Enable( on ) end
end

function BAA.Fade( w, a )
	if not w then return end
	local m = M( w )
	if m.fade ~= a then m.fade = a w:SetFade( a ) end
end

function BAA.SetText( w, s )
	if not w then return end
	s = s or ""
	local m = M( w )
	if m.text ~= s then m.text = s w:SetVal( "value", BAA.WS( s ) ) end
end

function BAA.SetVariant( w, v )
	if not w then return end
	local m = M( w )
	if m.variant ~= v then m.variant = v w:SetVariant( v ) end
end

local iconGroup = nil
function BAA.Tex( key )
	if iconGroup == nil then
		iconGroup = common.GetAddonRelatedTextureGroup( "Icons", true ) or false
	end
	if iconGroup and iconGroup:HasTexture( key ) then return iconGroup:GetTexture( key ) end
	return nil
end

function BAA.SetTex( w, key )
	if not w or not key then return end
	local m = M( w )
	if m.tex == key then return end
	local t = BAA.Tex( key )
	if t then m.tex = key w:SetBackgroundTexture( t ) end
end
