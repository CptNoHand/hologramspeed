-- Events
RegisterNetEvent('HologramSpeed:SetTheme')

-- Constants
local ResourceName       = GetCurrentResourceName()
local HologramURI        = string.format("nui://%s/ui/hologram.html", ResourceName)
local OffsetTable        = {
	[0] = vec3(2.5, -0.8, 0.99), -- compact
	[1] = vec3(2.5, -0.8, 0.99), -- sedan
	[2] = vec3(2.5, -0.8, 0.99), -- SUV
	[3] = vec3(2.5, -0.8, 0.99), -- Coupe
	[4] = vec3(2.5, -0.8, 0.99), -- Muscle
	[5] = vec3(2.5, -0.8, 0.99), -- Sports Classic
	[6] = vec3(2.5, -0.8, 0.99), -- Sports
	[7] = vec3(2.5, -0.8, 0.99), -- Super
	[8] = vec3(1.8, -0.8, 0.99), -- Motorcycle
	[9] = vec3(2.5, -0.8, 0.99), -- off-road
	[10] = vec3(2.5, -0.8, 0.99), -- Industrial
	[11] = vec3(2.5, -0.8, 0.99), -- Utility
	[12] = vec3(2.5, -0.8, 0.99), -- Vans
	[13] = vec3(1.8, -0.8, 0.99), -- Bicycles
	[14] = vec3(2.5, -0.8, 0.99), -- Boats
	[15] = vec3(2.5, -0.8, 0.99), -- Helicopters
	[16] = vec3(2.5, -0.8, 0.99), -- Planes
	[17] = vec3(2.5, -0.8, 0.99), -- Service
	[18] = vec3(2.5, -0.8, 0.99), -- Emergency
	[19] = vec3(2.5, -0.8, 0.99), -- Military
	[20] = vec3(2.5, -0.8, 0.99), -- Commercial
	[21] = vec3(2.5, -0.8, 0.99) -- Trains
}
local AttachmentRotation = vec3(0, 0, -15)
local HologramModel      = `hologram_box_model`
local UpdateFrequency    = 100 -- If less than average frame time, there will be an update every tick regardless of the actual number specified.
local SettingKey         = string.format("%s:profile", GetCurrentServerEndpoint()) -- The key to store the current theme setting in. As themes are per server, this key is also.
local DBG                = false -- Enables debug information, not very useful unless you know what you are doing!

-- Variables
local duiObject      = false -- The DUI object, used for messaging and is destroyed when the resource is stopped
local duiIsReady     = false -- Set by a callback triggered by DUI once the javascript has fully loaded
local hologramObject = 0 -- The current DUI anchor. 0 when one does not exist
local usingMetric, shouldUseMetric = ShouldUseMetricMeasurements() -- Used to track the status of the metric measurement setting
local textureReplacementMade = false -- Due to some weirdness with the experimental replace texture native, we need to make the replacement after the anchor has been spawned in-game

-- Preferences
local displayEnabled = true
local currentTheme   = GetConvar("hsp_defaultTheme", "default")

local function DebugPrint(...)
	if DBG then
		print(...)
	end
end

local function EnsureDuiMessage(data)
	if duiObject and duiIsReady then
		SendDuiMessage(duiObject, json.encode(data))
		return true
	end

	return false
end

local function SendChatMessage(message)
	TriggerEvent('chat:addMessage', {args = {message}})
end

-- Register a callback for when the DUI JS has loaded completely
RegisterNUICallback("duiIsReady", function(_, cb)
	duiIsReady = true
    cb({ok = true})
end)

local function ToggleDisplay()
	displayEnabled = not displayEnabled
	SendChatMessage("Holographic speedometer " .. (displayEnabled and "^2enabled^r" or "^1disabled^r") .. ".")
end

local function SetTheme(newTheme)
	if newTheme ~= currentTheme then
		EnsureDuiMessage {theme = newTheme}
		SendChatMessage(newTheme == "default" and "Holographic speedometer theme ^5reset^r." or ("Holographic speedometer theme set to ^5" .. newTheme .. "^r."))
		currentTheme = newTheme
	end
end

local function UpdateEntityAttach()
	local playerPed, currentVehicle
	playerPed = PlayerPedId()
	if IsPedInAnyVehicle(playerPed) then
		currentVehicle = GetVehiclePedIsIn(playerPed, false)
		-- Attach the hologram to the vehicle
		AttachEntityToEntity(hologramObject, currentVehicle, GetEntityBoneIndexByName(currentVehicle, "chassis"), GetAttachmentOffset(currentVehicle), FlipRotation(currentVehicle), false, false, false, false, false, true)
		DebugPrint(string.format("DUI anchor %s attached to %s", hologramObject, currentVehicle))
	end
end

local function CheckRange(x, y, z, minVal, maxVal)
	if x == nil or y == nil or z == nil or minVal == nil or maxVal == nil then
		return false
	else
		return not (x < minVal or x > maxVal or y < minVal or y > maxVal or z < minVal or z > maxVal)
	end
end

local function GetSideToggle()
	local camHead = GetGameplayCamRelativeHeading()

	if camHead <= -10 and camHead > -40 then
	    return "right"
	elseif camHead <= -40 then
	    return "farright"
	elseif camHead > -10 and camHead <= 40 then
	    return "left"
	elseif camHead > 40 then
	    return "farleft"
	else
	    print("holo:GetSideToggle: Unknown Heading Math - "..camHead)
	    return "left"
	end
end

local function FlipRotation(veh)
	local flop = GetSideToggle()

	if flop == "left" then
		return AttachmentRotation
	elseif flop == "right" then
		local posz = math.abs(AttachmentRotation.z)
		return vec3(AttachmentRotation.x, AttachmentRotation.y, posz)
	elseif flop == "farleft" then
		return vec3(AttachmentRotation.x, AttachmentRotation.y, AttachmentRotation.z+75) --100
	else
		local posz = math.abs(AttachmentRotation.z)
		return vec3(AttachmentRotation.x, AttachmentRotation.y, posz-75) --100
	end
end

local function GetAttachmentOffset(veh)
	local vehOff = OffsetTable[GetVehicleClass(veh)]
	local lOrR = GetSideToggle()
	--print(lOrR)

	if lOrR == "left" then
		return vehOff
	elseif lOrR == "farleft"  then
		return vec3(vehOff.x-0.5, vehOff.y+1.3, vehOff.z)
	elseif lOrR == "right" then
		local negx = (-vehOff.x)
		return vec3(negx+1.2, vehOff.y+0.3, vehOff.z)
	else
		local negx = (-vehOff.x)
		return vec3(negx+1.2, vehOff.y+0.2, vehOff.z)
	end
end

-- Command Handler

local function CommandHandler(args)

	local msgErr = "^1The the acceptable range for ^0%s ^1is ^0%f^1 ~ ^0%f^1, reset to default setting.^r"
	local msgSuc = "^2Speedometer ^0%s ^2changed to ^0%f, %f, %f^r"

	if args[1] == "theme" then
		if #args >= 2 then
			TriggerServerEvent('HologramSpeed:CheckTheme', args[2])
		else
			SendChatMessage("^1Invalid theme! ^0Usage: /hsp theme <name>^r")
		end
	else
		SendChatMessage("^1Usage: ^0/hsp <theme> [args...]^r")
	end
end

-- Network events

AddEventHandler('HologramSpeed:SetTheme', function(theme)
	SetTheme(theme)
end)

-- Register command

RegisterCommand("hsp", function(_, args)
	if #args == 0 then
		ToggleDisplay()
	else
		CommandHandler(args)
	end
end, false)

TriggerEvent('chat:addSuggestion', '/hsp', 'Toggle the holographic speedometer', {
    { name = "command",  help = "Allow command: theme" },
})

RegisterKeyMapping("hsp", "Toggle Holographic Speedometer", "keyboard", "grave") -- default: `

-- Hologram Creation
function createHologram(HologramModel,currentVehicle)
	-- Create the hologram objec
	hologramObject = CreateVehicle(HologramModel, GetEntityCoords(currentVehicle), 0.0, false, true)
	SetVehicleIsConsideredByPlayer(hologramObject, false)
	SetVehicleEngineOn(hologramObject, true, true)
	SetEntityCollision(hologramObject, false, false)
	DebugPrint("DUI anchor created "..tostring(hologramObject))
	return hologramObject
end

function attachHologramToVehicle(hologramObject,currentVehicle)
	-- Attach the hologram to the vehicle
	AttachEntityToEntity(hologramObject, currentVehicle, GetEntityBoneIndexByName(currentVehicle, "chassis"), GetAttachmentOffset(currentVehicle), FlipRotation(currentVehicle), false, false, false, false, false, true)
	DebugPrint(string.format("DUI anchor %s attached to %s", hologramObject, currentVehicle))
end

-- Initialise the DUI. We only need to do this once.
local function InitialiseDui()
	DebugPrint("Initialising...")

	duiObject = CreateDui(HologramURI, 512, 512)

	DebugPrint("\tDUI created")

	repeat Wait(0) until duiIsReady

	DebugPrint("\tDUI available")

	EnsureDuiMessage {
		useMetric = usingMetric,
		display = false,
		theme = currentTheme
	}

	DebugPrint("\tDUI initialised")

	local txdHandle  = CreateRuntimeTxd("HologramDUI")
	local duiHandle  = GetDuiHandle(duiObject)
	local duiTexture = CreateRuntimeTextureFromDuiHandle(txdHandle, "DUI", duiHandle)
	DebugPrint("\tRuntime texture created")

	DebugPrint("Done!")
end

-- Main Loop
CreateThread(function()
	-- Sanity checks
	if string.lower(ResourceName) ~= ResourceName then
		return
	end

	if not IsModelInCdimage(HologramModel) or not IsModelAVehicle(HologramModel) then
		SendChatMessage("^1Could not find `hologram_box_model` in the game... ^rHave you installed the resource correctly?")
		return
	end

	InitialiseDui()

	-- This thread watches for changes to the user's preferred measurement system
	CreateThread(function()
		while true do
			Wait(1000)

			shouldUseMetric = ShouldUseMetricMeasurements()

			if usingMetric ~= shouldUseMetric and EnsureDuiMessage {useMetric = shouldUseMetric} then
				usingMetric = shouldUseMetric
			end
		end
	end)

	local playerPed, currentVehicle, vehicleSpeed

	while true do
		playerPed = PlayerPedId()

		if IsPedInAnyVehicle(playerPed) then
			currentVehicle = GetVehiclePedIsIn(playerPed, false)

			-- When the player is in the drivers seat of their current vehicle...
			if GetPedInVehicleSeat(currentVehicle, -1) == playerPed then
				-- Ensure the display is off before we start
				EnsureDuiMessage {display = false}

				-- Load the hologram model
				RequestModel(HologramModel)
				repeat Wait(0) until HasModelLoaded(HologramModel)

				-- Create the hologram object
				hologramObject=createHologram(HologramModel,currentVehicle)

				-- Odd hacky fix for people who's textures won't replace properly
				if not textureReplacementMade then
					AddReplaceTexture("hologram_box_model", "p_hologram_box", "HologramDUI", "DUI")
					DebugPrint("Texture replacement made")
					textureReplacementMade = true
				end

				SetModelAsNoLongerNeeded(HologramModel)

				-- If the ped's current vehicle still exists and they are still driving it...
				if DoesEntityExist(currentVehicle) and GetPedInVehicleSeat(currentVehicle, -1) == playerPed then
					-- Attach the hologram to the vehicle
					attachHologramToVehicle(hologramObject,currentVehicle)

					-- Wait until the engine is on before enabling the hologram proper
					repeat
						Wait(0)
						if GetVehiclePedIsIn(playerPed, false)~=currentVehicle then
							currentVehicle=GetVehiclePedIsIn(playerPed, false)
							hologramObject=createHologram(HologramModel,currentVehicle)
							attachHologramToVehicle(hologramObject,currentVehicle)
						end
					until IsVehicleEngineOn(currentVehicle)

					local flipCount = 0

					-- Until the player is no longer driving this vehicle, update the UI
					repeat
						vehicleSpeed = GetEntitySpeed(currentVehicle)

						EnsureDuiMessage {
							display  = displayEnabled and IsVehicleEngineOn(currentVehicle),
							rpm      = GetVehicleCurrentRpm(currentVehicle),
							gear     = GetVehicleCurrentGear(currentVehicle),
							abs      = (GetVehicleWheelSpeed(currentVehicle, 0) == 0.0) and (vehicleSpeed > 0.0),
							hBrake   = GetVehicleHandbrake(currentVehicle),
							rawSpeed = vehicleSpeed,
						}

						flipCount = flipCount + 1
						if flipCount >= 4 then
							flipCount = 0
							AttachEntityToEntity(hologramObject, currentVehicle, GetEntityBoneIndexByName(currentVehicle, "chassis"), GetAttachmentOffset(currentVehicle), FlipRotation(currentVehicle), false, false, false, false, false, true)
						end

						-- Wait for the next frame or half a second if we aren't displaying
						Wait(displayEnabled and UpdateFrequency or 500)
					until GetPedInVehicleSeat(currentVehicle, -1) ~= PlayerPedId()
				end
			end
		end

		-- At this point, the player is no longer driving a vehicle or was never driving a vehicle this cycle

		-- If there is a hologram object currently created...
		if hologramObject ~= 0 and DoesEntityExist(hologramObject) then
			-- Delete the hologram object
			DeleteVehicle(hologramObject)
			DebugPrint("DUI anchor deleted "..tostring(hologramObject))
		else
			-- Instead of setting this in the above block, clearing the handle here ensures that the entity must not exist before it's handle is lost.
			hologramObject = 0
		end

		-- We don't need to check every single frame for the player being in a vehicle so we check every second
		Wait(1000)
	end
end)

-- Resource cleanup
AddEventHandler("onResourceStop", function(resource)
	if resource == ResourceName then
		DebugPrint("Cleaning up...")

		displayEnabled = false
		DebugPrint("\tDisplay disabled")

		if DoesEntityExist(hologramObject) then
			DeleteVehicle(hologramObject)
			DebugPrint("\tDUI anchor deleted "..tostring(hologramObject))
		end

		RemoveReplaceTexture("hologram_box_model", "p_hologram_box")
		DebugPrint("\tReplace texture removed")

		if duiObject then
			DebugPrint("\tDUI browser destroyed")
			DestroyDui(duiObject)
			duiObject = false
		end
	end
end)
