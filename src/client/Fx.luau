--[[
	Fx — звуки и частицы клиента. Сторонних звуков нет: встроенные rbxasset:// и синтез —
	мелодия лифта и звонки играются «пингом» с разной высотой (PlaybackSpeed = 2^(n/12)).
	Мелодия идёт по кадрам (update), без task.delay.
]]

local Workspace = game:GetService("Workspace")
local SoundService = game:GetService("SoundService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Make = require(Shared.Make)

local Fx = {}

local sounds: { [string]: Sound } = {}
local folder: Folder? = nil
local music = { on = false, t = 0, i = 1 }
local queue: { { at: number, note: number, vol: number } } = {}
local clock = 0
local cleanup: { { part: BasePart, at: number } } = {}
local emotesUpdate: (number) -> ()

function Fx.build()
	local f = Make("Folder", { Name = "LiftSounds", Parent = SoundService })
	folder = f
	for name, s in Config.Sounds do
		sounds[name] = Make(
			"Sound",
			{ Name = name, SoundId = s.Id, Volume = s.Volume, PlaybackSpeed = s.Speed, Parent = f }
		)
	end
	-- отдельные «голоса» для нот, чтобы звучали поверх друг друга
	for i = 1, 4 do
		sounds["Note" .. i] =
			Make("Sound", { Name = "Note" .. i, SoundId = Config.Sounds.Ping.Id, Volume = 0.3, Parent = f })
	end
end

function Fx.play(name: string, speed: number?)
	local s = sounds[name]
	if s then
		if speed then
			s.PlaybackSpeed = speed
		end
		s:Play()
	end
end

local voice = 0
local function note(n: number, vol: number)
	voice = voice % 4 + 1
	local s = sounds["Note" .. voice]
	if s then
		s.PlaybackSpeed = 2 ^ (n / 12)
		s.Volume = vol
		s:Play()
	end
end

-- Сыграть ноты (полутоны) по очереди
function Fx.notes(list: { number }, gap: number?, vol: number?)
	for i, n in list do
		table.insert(queue, { at = clock + (i - 1) * (gap or 0.22), note = n, vol = vol or 0.35 })
	end
end

function Fx.music(on: boolean)
	if music.on ~= on then
		music.on = on
		music.t, music.i = 0, 1
	end
end

function Fx.update(dt: number)
	clock += dt
	for i = #queue, 1, -1 do
		local q = queue[i]
		if clock >= q.at then
			note(q.note, q.vol)
			table.remove(queue, i)
		end
	end
	if music.on then
		music.t += dt
		if music.t >= Config.Music.Tempo then
			music.t -= Config.Music.Tempo
			note(Config.Music.Notes[music.i] - 5, Config.Music.Volume)
			music.i = music.i % #Config.Music.Notes + 1
		end
	end
	Fx.sweep()
	emotesUpdate(dt)
end

-- Взрыв частиц в точке мира (конфетти, сердечки, звёзды)
function Fx.burst(pos: Vector3, colors: { { number } }, n: number)
	if n <= 0 then
		return
	end
	local fx = Workspace:FindFirstChild("LiftFx") or Make("Folder", { Name = "LiftFx", Parent = Workspace })
	local p = Make("Part", {
		Name = "Burst",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(pos),
		Parent = fx,
	})
	local keys = {}
	for i, c in colors do
		table.insert(
			keys,
			ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), Color3.fromRGB(c[1], c[2], c[3]))
		)
	end
	if #keys == 1 then
		table.insert(keys, ColorSequenceKeypoint.new(1, keys[1].Value))
	end
	local e = Make("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(keys),
		Lifetime = NumberRange.new(0.8, 1.6),
		Speed = NumberRange.new(10, 22),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -30, 0),
		Size = NumberSequence.new(0.6),
		Rate = 0,
		Parent = p,
	})
	e:Emit(n)
	-- убрать через 3 с (по кадрам)
	table.insert(cleanup, { part = p, at = clock + 3 })
end

-- Реакция над головой: всплывает 2 с и исчезает
local emotes: { { part: BasePart, t: number } } = {}
function Fx.trackEmote(part: BasePart)
	table.insert(emotes, { part = part, t = 0 })
end

function emotesUpdate(dt: number)
	for i = #emotes, 1, -1 do
		local e = emotes[i]
		e.t += dt
		e.part.CFrame = e.part.CFrame + Vector3.new(0, dt * 2, 0)
		if e.t > 2 then
			e.part:Destroy()
			table.remove(emotes, i)
		end
	end
end

function Fx.sweep()
	for i = #cleanup, 1, -1 do
		local c = cleanup[i]
		if clock >= c.at then
			c.part:Destroy()
			table.remove(cleanup, i)
		end
	end
end

_ = folder

return Fx
