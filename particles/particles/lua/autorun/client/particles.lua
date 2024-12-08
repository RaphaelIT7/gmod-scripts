jit.on()
jit.flush()

particles = 0
particles_pos_x = {}
particles_pos_y = {}
particles_mass = {}
particles_acc_x = {}
particles_acc_y = {}
particles_vel_x = {}
particles_vel_y = {}
particles_size = {}
particles_fixed = {}

local function AddBody(pos, mass, acc, vel, size, fixed, override)
	acc = acc or {0, 0}
	mass = mass or 100
	vel = vel or {0, 0}
	size = size or 1
	fixed = fixed or false

	particles = particles + 1
	particles_pos_x[particles] = pos[1]
	particles_pos_y[particles] = pos[2]
	particles_mass[particles] = mass
	particles_acc_x[particles] = acc[1]
	particles_acc_y[particles] = acc[2]
	particles_vel_x[particles] = vel[1]
	particles_vel_y[particles] = vel[2]
	particles_size[particles] = size
	particles_fixed[particles] = fixed
end

local MAXS = 500
local MINS = -MAXS
for k=1, 3000 do
	AddBody({ math.random(MINS, MAXS), math.random(MINS, MAXS) }, 10, nil, {0, 0})
end

local function UpdateBody(bodyID, dt)
	if particles_fixed[bodyID] then return end

	local velx = particles_vel_x[bodyID] * dt
	local vely = particles_vel_y[bodyID] * dt

	particles_pos_x[bodyID] = particles_pos_x[bodyID] + velx
	particles_pos_y[bodyID] = particles_pos_y[bodyID] + vely

	particles_vel_x[bodyID] = particles_vel_x[bodyID] + (particles_acc_x[bodyID] * dt)
	particles_vel_y[bodyID] = particles_vel_y[bodyID] + (particles_acc_y[bodyID] * dt)
	particles_acc_x[bodyID] = 0
	particles_acc_y[bodyID] = 0
end

local Scale = MAXS / 500
local DT = 0.02
local MIN = 0.0001
local MIN_SQR = MIN * MIN
local allow_collision = false
local Zoom = 1
local Next_Zoom = Zoom
function Update(bodyCount)
	local jbody, ibody, m1, p1x, p1y, m2, dx, dy, mag_sq, inv_mag, tmp_x, tmp_y
    for bodyID=1, bodyCount do
        m1 = particles_mass[bodyID]
        p1x, p1y = particles_pos_x[bodyID], particles_pos_y[bodyID]
        
        for bodyID2=bodyID+1, bodyCount do
            m2 = particles_mass[bodyID2]

			dx, dy = particles_pos_x[bodyID2] - p1x, particles_pos_y[bodyID2] - p1y
        	mag_sq = dx * dx + dy * dy

			if mag_sq > MIN_SQR then
			    inv_mag = 2 / mag_sq -- Use "1 / math.sqrt(mag_sq)" if you want them to have a different pattern. If you use it lower DT to 0.002

			    tmp_x = dx * inv_mag
			    tmp_y = dy * inv_mag

			    particles_acc_x[bodyID] = particles_acc_x[bodyID] + m2 * tmp_x
			    particles_acc_y[bodyID] = particles_acc_y[bodyID] + m2 * tmp_y

			    particles_acc_x[bodyID2] = particles_acc_x[bodyID2] - m1 * tmp_x
			    particles_acc_y[bodyID2] = particles_acc_y[bodyID2] - m1 * tmp_y
			end
        end
    end

    local furthest = MAXS
    local collision = false
    local positions = {}
    local collided = {}
    for bodyID=1, bodyCount do
        UpdateBody(bodyID, DT)

        if math.abs(particles_pos_x[bodyID]) > furthest then
        	furthest = math.abs(particles_pos_x[bodyID])
        end

        if math.abs(particles_pos_y[bodyID]) > furthest then
        	furthest = math.abs(particles_pos_y[bodyID])
        end
    end

    if furthest > (Next_Zoom * MAXS) then
    	Next_Zoom = math.min(furthest / MAXS, 10)
    end

    if furthest < (Next_Zoom * MAXS) then
    	while (furthest < (Next_Zoom * MAXS)) do
    		Next_Zoom = Next_Zoom - 0.0001
    	end
    end
end

local OldParticles = {}
hook.Add("HUDPaint", "example", function()
	Update(particles)

	local XOffset = ScrW() / 2
	local YOffset = ScrH() / 2

	Zoom = Lerp(0.05, Zoom, Next_Zoom * Scale)

	surface.SetDrawColor(0, 0, 0, 255)
	surface.DrawRect(0, 0, ScrW(), ScrH())
	surface.SetDrawColor(255, 255, 255, 255)

		for bodyID=1, particles do
			if !OldParticles[bodyID] then
				OldParticles[bodyID] = {0, 0}
			end
			local old = OldParticles[bodyID]

			if old[1] == 0 or old[2] == 0 then
				surface.DrawRect((particles_pos_x[bodyID] / Zoom) + XOffset, (particles_pos_y[bodyID] / Zoom) + YOffset, particles_size[bodyID], particles_size[bodyID])
			else
				surface.DrawLine((old[1] / Zoom) + XOffset, (old[2] / Zoom) + YOffset, (particles_pos_x[bodyID] / Zoom) + XOffset, (particles_pos_y[bodyID] / Zoom) + YOffset)
			end
			OldParticles[bodyID][1] = particles_pos_x[bodyID]
			OldParticles[bodyID][2] = particles_pos_y[bodyID]
		end
end)