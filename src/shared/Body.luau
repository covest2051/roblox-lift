--[[
	Body — кинематика тела бота и тестов, как у персонажа Roblox:
	ходьба 16, прыжок 50 (высота зависит от гравитации этажа), полное управление в воздухе,
	опора только сверху (стены — края этажа inst.bounds), батуты (bounce), лёд (ice:
	скорость догоняет желаемую медленно), зеркальное управление (inst.mirror).
	Люди в игре двигаются физикой Roblox — сервер только читает их позиции.
]]

local Shared = script.Parent
local Config = require(Shared.Config)
local Kit = require(Shared.FloorKit)

local Body = {}

local B = Config.Body

function Body.init(p, x: number, y: number, z: number)
	p.x, p.y, p.z = x, y, z
	p.vx, p.vy, p.vz = 0, 0, 0
	p.grounded, p.on = true, nil
	return p
end

--[[
	Шаг тела. it = { mx, mz (направление, длина ≤ 1), jump (прыгать, если на опоре) }.
	Возвращает опору, от которой отскочил (батут), или nil.
]]
function Body.step(p, it, dt: number, inst)
	local mx, mz = it.mx or 0, it.mz or 0
	if inst.mirror then
		mx, mz = -mx, mz
	end
	local sp = B.Walk * (inst.speedMul or 1)
	if inst.freeze and inst.t < inst.freeze then
		sp = 0 -- «на старт»: первые секунды стоим
	end
	local wx, wz = mx * sp, mz * sp
	local on = p.on
	if p.grounded and on and on.ice then
		local k = math.min(1, B.IceGrip * dt)
		p.vx += (wx - p.vx) * k
		p.vz += (wz - p.vz) * k
	elseif not p.grounded and p.slide then
		-- в воздухе после льда: инерция плюс управление
		p.vx += (wx - p.vx) * math.min(1, 3 * dt)
		p.vz += (wz - p.vz) * math.min(1, 3 * dt)
	else
		p.vx, p.vz = wx, wz
	end
	if it.jump and p.grounded and sp > 0 then
		p.vy = B.Jump
		p.grounded = false
		p.slide = on ~= nil and on.ice == true
	end
	local g = inst.gravity or B.Gravity
	local py = p.y
	p.x += p.vx * dt
	p.z += p.vz * dt
	local b = inst.bounds
	if b then
		if p.x < b[1] then
			p.x, p.vx = b[1], 0
		elseif p.x > b[2] then
			p.x, p.vx = b[2], 0
		end
		if p.z < b[3] then
			p.z, p.vz = b[3], 0
		elseif p.z > b[4] then
			p.z, p.vz = b[4], 0
		end
	end
	-- точно для постоянной гравитации (иначе при шаге 0.1 с прыжок ниже на треть)
	p.y += p.vy * dt - 0.5 * g * dt * dt
	p.vy -= g * dt
	local top, s = Kit.groundAt(inst, p.x, p.z, math.max(py, p.y) + B.StepUp)
	if top and p.y <= top and p.vy <= 0 then
		p.y = top
		if s.bounce then
			p.vy = s.bounce
			p.lastBounce = s
			p.grounded, p.on = false, nil
			p.slide = false
			return s
		end
		p.vy = 0
		p.grounded, p.on = true, s
		p.slide = false
	else
		p.grounded, p.on = false, nil
	end
	return nil
end

-- Время в воздухе и дальность прыжка при гравитации g (для голов ботов)
function Body.jumpReach(g: number): (number, number)
	local air = 2 * B.Jump / g
	return air, air * B.Walk
end

return Body
