local module = {
	owner = "Bolodefchoco#0000" -- Do NOT change my nickname
}
local hardMode = 0 -- Change 0 to another number if you want it to be harder. More numbers, harder.

--[[ Translations ]]--
local translations = {
	en = {
		-- Init
		welcome = "[#cannonup-funcorp] Your aim is to be the survivor!\n<J>Submit maps in <S>https://atelier801.com/topic?f=6&t=859067\n\t<J>Report any issue to Bolodefchoco#0000.",

		-- Info
		nowinner = "No one won!",

		-- Simple words
		won = "won!"
	},
	br = {
		welcome = "[#cannonup-funcorp]. Seu objetivo é ser o sobrevivente!\n<J>Envie mapas em <S>https://atelier801.com/topic?f=6&t=859067\n\t<J>Reporte qualquer problema para Bolodefchoco#0000.",

		nowinner = "Ninguém ganhou!",

		won = "venceu!"
	},
}
local translation = translations[tfm.get.room.community] or translations.en

--[[ Maps ]]--
local maps = { 6001536, 6001536, 4591929, "#10" }
local mapHashes = { }
local mapsToAdd = { }

--[[ Settings ]]--
-- Status
local players = {
	room = { _count = 0 },
	alive = { _count = 0 },
	currentRound = { _count = 0 }
}
local soloGame = false
-- New Game
local cannon = {
	x = 0,
	y = 0,
	time = 2.5,
	quantity = 1,
	speed = 25,
	mul = 1,
}
local toSpawn = {}
local toDespawn = {}
local currentRound = 1
local announceWinner = true
local cannonID = {}

--[[ API ]]--
math.clamp = function(value, min, max)
	return value < min and min or value > max and max or value
end

string.nick = function(player, ignoreCheck)
	if not ignoreCheck and not player:find("#") then
		player = player .. "#0000"
	end

	return string.gsub(string.lower(player), "%a", string.upper, 1)
end
string.split = function(value, pattern, f)
	local out = {}
	for v in string.gmatch(value, pattern) do
		out[#out + 1] = (not f and v or f(v))
	end
	return out
end

table.copy = function(list)
	local out = {}
	for k, v in next, list do
		out[k] = (type(v) == "table" and table.copy(v) or v)
	end
	return out
end
table.merge = function(this, src)
	for k, v in next, src do
		if this[k] then
			if type(v) == "table" then
				this[k] = table.turnTable(this[k])
				table.merge(this[k], v)
			else
				this[k] = this[k] or v
			end
		else
			this[k] = v
		end
	end
end
table.random = function(t, q)
	return t[math.random(q or #t)]
end
table.shuffle = function(t)
	local len = #t
	for i = len, 1, -1 do
		local rand = math.random(i)
		t[i], t[rand] = t[rand], t[i]
	end
	return t
end
table.turnTable = function(x)
	return (type(x)=="table" and x or {x})
end
local insert = function(where, playerName)
	if not where[playerName] then
		where._count = where._count + 1
		where[where._count] = playerName
		where[playerName] = where._count
	end
end
local remove = function(where, playerName)
	if where[playerName] then
		where._count = where._count - 1
		table.remove(where, where[playerName])
		for i = where[playerName], where._count do
			where[where[i]] = where[where[i]] - 1
		end
		where[playerName] = nil
	end
end

local timer
do
	timer = {
		_timers = {
			_count = 0
		}
	}

	timer.start = function(callback, ms, times, ...)
		local t = timer._timers
		t._count = t._count + 1

		t[t._count] = {
			id = t._count,
			callback = callback,
			args = { ... },
			defaultMilliseconds = ms,
			milliseconds = ms,
			times = times
		}
		t[t._count].args[#t[t._count].args + 1] = t[t._count]

		return t._count
	end

	timer.delete = function(id)
		timer._timers[id] = nil
	end

	timer.loop = function()
		local t
		for i = 1, timer._timers._count do
			t = timer._timers[i]
			if t then
				t.milliseconds = t.milliseconds - 500
				if t.milliseconds <= 0 then
					t.milliseconds = t.defaultMilliseconds
					t.times = t.times - 1

					t.callback(table.unpack(t.args))

					if t.times == 0 then
						timer.delete(i)
					end
				end
			end
		end
	end
end

local xml = {}
xml.parseParameters = function(currentXml)
	currentXml = string.match(currentXml, "<P (.-)/>") or ""
	local out = {}
	for tag, _, value in string.gmatch(currentXml, "([%-%w]+)=([\"'])(.-)%2") do
		out[tag] = value
	end
	return out, currentXml
end
xml.attribFunc = function(currentXml, funcs)
	local attributes, properties = xml.parseParameters(currentXml)
	for k,v in next, funcs do
		if attributes[v.attribute] then
			v.func(attributes[v.attribute])
		end
	end
	return properties
end
xml.getCoordinates = function(s)
	if string.find(s, ";") then
		local x, y
		local axis, value = string.match(s, "(%a);(%-?%d+)")
		value = tonumber(value)
		if value then
			if axis == "x" then
				x = value
			elseif axis == "y" then
				y = value
			end
		end
		return x or 0, y or 0
	else
		local pos = {}
		for x, y in string.gmatch(s, "(%-?%d+) ?, ?(%-?%d+)") do
			pos[#pos + 1] = { x = x, y = y }
		end
		return pos
	end
end

--[[ System ]]--
-- Translations
for k, v in next, translations do
	if k ~= "en" then
		table.merge(v, translations.en, true)
	end
end

-- Cannon
local getCannon
do
	local currentMonth = tonumber(os.date("%m"))
	local cannons = { 17, 17, 17, 1706 }
	if currentMonth == 1 or currentMonth == 12 then
		cannons[#cannons + 1] = 1703 -- Christmas decoration
		cannons[#cannons + 1] = 1703
		cannons[#cannons + 1] = 1705 -- Apple
	elseif currentMonth == 2 then
		cannons[#cannons + 1] = 1701 -- Glass
		cannons[#cannons + 1] = 1705
		cannons[#cannons + 1] = 1706 -- Watermelon
		cannons[#cannons + 1] = 1706
	elseif currentMonth > 2 and currentMonth < 10 then
		if currentMonth == 5 then
			cannons[#cannons + 1] = 1704 -- Shaman
			cannons[#cannons + 1] = 1704
			cannons[#cannons + 1] = 1704
			cannons[#cannons + 1] = 1709 -- Light
		elseif currentMonth > 5 and currentMonth < 9 then
			cannons[#cannons + 1] = 1705
			cannons[#cannons + 1] = 1705
			cannons[#cannons + 1] = 1710 -- Nut
		elseif currentMonth == 9 then
			cannons[#cannons + 1] = 1711 -- Flower
		end
		cannons[#cannons + 1] = 1706
		cannons[#cannons + 1] = 1706
	elseif currentMonth == 10 then
		cannons[#cannons + 1] = 1701
		cannons[#cannons + 1] = 1702 -- Lollipop
		cannons[#cannons + 1] = 1702
		cannons[#cannons + 1] = 1702
		cannons[#cannons + 1] = 1707 -- Purple
		cannons[#cannons + 1] = 1708 -- Spike
	end

	getCannon = function()
		if #cannonID > 0 then
			return table.random(cannonID)
		end
		return table.random(cannons)
	end
end

-- Shoot
local newCannon = function()
	if players.alive._count > 0 then
		local player
		repeat
			player = tfm.get.room.playerList[table.random(players.alive, players.alive._count)]
		until not player or not player.isDead
		if not player then return end

		local coordinates = {
			{ player.x, math.random() * 700 },
			{ player.y, math.random() * 300 },
			{ false, false }
		}

		local id
		if type(cannon.x) == "table" then
			id = math.random(#cannon.x)
			coordinates[1][2] = cannon.x[id]
			coordinates[3][1] = true
		else
			if cannon.x ~= 0 then
				coordinates[1][2] = cannon.x
				coordinates[3][1] = true
			end
		end

		if type(cannon.y) == "table" then
			coordinates[2][2] = cannon.y[id]
			coordinates[3][2] = true
		else
			if cannon.y ~= 0 then
				coordinates[2][2] = cannon.y
				coordinates[3][2] = true
			end
		end

		if not coordinates[3][2] and coordinates[2][2] > coordinates[2][1] then
			coordinates[2][2] = coordinates[2][1] - math.random(100) - 35
		end
		if not coordinates[3][1] and math.abs(coordinates[1][2] - coordinates[1][1]) > 350 then
			coordinates[1][2] = coordinates[1][1] + math.random(-100,100)
		end

		local ang = math.deg(math.atan2(coordinates[2][2] - coordinates[2][1],coordinates[1][2] - coordinates[1][1]))
		tfm.exec.addShamanObject(0, coordinates[1][2] - (coordinates[3][1] and 0 or 10), coordinates[2][2] - (coordinates[3][2] and 0 or 10), ang + 90)

		toSpawn[#toSpawn + 1] = { os.time() + 150, getCannon(), coordinates[1][2], coordinates[2][2], ang - 90, cannon.speed }
	end
end

--[[ Events ]]--
-- NewPlayer
eventNewPlayer = function(n)
	insert(players.room, n)

	tfm.exec.lowerSyncDelay(n)

	tfm.exec.chatMessage("<J>" .. translation.welcome, n)
end

-- NewGame
local xmlFunctions = {
	[1] = {
		attribute = "cn",
		func = function(value)
			local coord, axY = xml.getCoordinates(value)
			if type(coord) == "table" then
				cannon.x = {}
				cannon.y = {}

				for k, v in next, coord do
					cannon.x[#cannon.x + 1] = v.x
					cannon.y[#cannon.y + 1] = v.y
				end
			else
				if axY == 0 then
					cannon.x = coord
				else
					cannon.y = axY
				end
			end
		end
	},
	[2] = {
		attribute = "cheese",
		func = function()
			for n in next, tfm.get.room.playerList do
				tfm.exec.giveCheese(n)
			end
		end
	},
	[3] = {
		attribute = "meep",
		func = function()
			for n in next, tfm.get.room.playerList do
				tfm.exec.giveMeep(n)
			end
		end
	},
	[4] = {
		attribute = "quantity",
		func = function(value)
			value = tonumber(value) or 1
			cannon.mul = math.clamp(value, 1, 3)
		end
	},
	[5] = {
		attribute = "bh",
		func = function()
			bhAttribute = true
		end
	},
	[6] = {
		attribute = "mgoc",
		func = function(value)
			mgocAttribute = tonumber(value)
		end
	},
	[7] = {
		attribute = "style",
		func = function(cannons)
			cannons = string.split(cannons, "[^,]+", function(id)
				id = tonumber(id)
				if id then
					if id == 0 then
						return 17
					else
						if id > 0 and id < 12 then
							return 1700 + id
						end
					end
				end
				return nil
			end)

			if #cannons > 0 then
				cannonID = cannons
			end
		end
	},
	[8] = {
		attribute = "time",
		func = function(value)
			value = tonumber(value)
			if value then
				tfm.exec.setGameTime(math.clamp(value * 60, 60, 180))
			end
		end
	},
	[9] = {
		attribute = "size",
		func = function(value)
			value = tonumber(value)
			if value then
				for n in next, tfm.get.room.playerList do
					tfm.exec.changePlayerSize(n, value)
				end
			end
		end
	}
}

local currentTime, leftTime, loadingNextMap = 0, 125, 0
eventNewGame = function()
	loadingNextMap = 0
	currentTime, leftTime = 0, 125

	currentRound = currentRound + 1
	if currentRound > #maps then
		currentRound = 1
		maps = table.shuffle(maps)
	end

	players.alive = table.copy(players.room)
	players.currentRound = table.copy(players.room)

	toSpawn, toDespawn = {}, {}
	announceWinner = true
	cannonID = {}

	cannon = {
		x = 0,
		y = 0,
		time = 2.5,
		speed = 20,
		mul = 1
	}

	tfm.exec.setGameTime(125)

	for n in next, tfm.get.room.playerList do
		tfm.exec.changePlayerSize(n, 1) -- it doesn't reset by i
	end

	local bhAttribute, mgocAttribute = false, false

	xml.attribFunc(((tfm.get.room.xmlMapInfo or {}).xml or ""), xmlFunctions)

	cannon.quantity = math.ceil(math.max(1, (players.currentRound._count - (players.currentRound._count % 15)) / 10) * cannon.mul + hardMode)
end

-- Loop
eventLoop = function()
	timer.loop()
	if loadingNextMap > 0 then
		loadingNextMap = loadingNextMap - .5
		if loadingNextMap <= 0 then
			tfm.exec.newGame(maps[currentRound])
			loadingNextMap = 3
		end
		return
	end

	currentTime, leftTime = currentTime + .5, leftTime - .5

	soloGame = players.currentRound._count == 1

	if currentTime <= 3 then return end

	if (leftTime < 3 or (not soloGame and players.alive._count < 2) or players.alive._count == 0) then
		if not soloGame and announceWinner then
			announceWinner = false
			if players.alive._count > 0 then
				local p
				for i = 1, players.alive._count do
					p = players.alive[i]
					tfm.exec.respawnPlayer(p)
					tfm.exec.setPlayerScore(p, 5, true)
					tfm.exec.giveCheese(p)
				end
				tfm.exec.chatMessage("<J>" .. table.concat(players.alive, "<G>, <J>") .. " <J>" .. translation.won)
			else
				tfm.exec.chatMessage("<J>" .. translation.nowinner)
			end
		end
		loadingNextMap = 3
	else
		if currentTime % cannon.time == 0 then
			for i = 1, cannon.quantity do
				newCannon()
			end
		end

		for k, v in next, table.copy(toSpawn) do
			if os.time() > v[1] then
				toDespawn[#toDespawn + 1] = { tfm.exec.addShamanObject(table.unpack(v, 2)), os.time() + 5000 }
				toSpawn[k] = nil
			end
		end

		for k, v in next, table.copy(toDespawn) do
			if os.time() > v[2] then
				tfm.exec.removeObject(v[1])
				toDespawn[k] = nil
			end
		end

		if currentTime % 20 == 0 then
			cannon.quantity = math.ceil(math.max(1, (players.currentRound._count - (players.currentRound._count % 15)) / 10) * cannon.mul + hardMode)
			cannon.speed = cannon.speed + 20
			cannon.time = math.max(.5, cannon.time - .5)
		end
	end
end

-- ChatCommand
eventChatCommand = function(n, c)
	if n == module.owner and string.sub(c, 1, 6) == "speak " then
		tfm.exec.chatMessage("<VP><B>[#cannonup] " .. string.sub(c, 7) .. "</B>")
	end
end

-- PlayerLeft
eventPlayerLeft = function(player)
	remove(players.alive, player)
	remove(players.room, player)
	remove(players.currentRound, player)
end

-- PlayerDied
eventPlayerDied = function(player)
	remove(players.alive, player)
end

-- FileLoaded
eventFileLoaded = function(id, data)
	local counter = 0
	maps, mapHashes = { }, { }
	string.gsub(data, "[^@]+", function(code)
		counter = counter + 1

		code = tonumber(code) or code
		maps[counter] = code
		mapHashes[code] = true
	end)
	maps = table.shuffle(maps)
end

eventFileLoaded(nil, "7358555@7512510@7353955@7358539@3666224@7495335@7514637@7358551@7515791@7491728@7360966@7495663@7353967@6001536@7433899@7515782@7685104@7516553@7333323@4981031@#10@2579234@7359784@7566929@4591929@7516383@7505012@7516175@7354007@7491744@7514167@7512816@7512825@7433562@7435497@7518822@7219601@7516548@7516567@7355500@7518823@7516923@5887525@7523204@7444451@7277212@5045246@7687703@7684164@7687968")

maps = table.shuffle(maps)

tfm.exec.disableAutoShaman()
tfm.exec.disableAutoScore()
tfm.exec.disableAutoNewGame()
tfm.exec.disableAutoTimeLeft()
tfm.exec.disablePhysicalConsumables()

tfm.exec.setRoomMaxPlayers(25)
tfm.exec.setGameTime(5, false) -- Prevention

system.disableChatCommandDisplay(nil, true)

for playerName in next, tfm.get.room.playerList do
	eventNewPlayer(playerName)
end
tfm.exec.newGame(maps[currentRound])
