local Drownable = Class(function(self, inst)
    self.inst = inst

	self.enabled = nil

    --V2C: weregoose hacks will set this to false on load.
    --     Please refactor this block to use POST LOAD timing instead.
	self.inst:DoTaskInTime(0, function() if self.enabled == nil then self.enabled = true end end) -- delaying the enable until after the character is finished being set up so that the idle state doesnt sink the player while loading

--	self.customtuningsfn = nil
--	self.ontakedrowningdamage = nil
end)

function Drownable:SetOnTakeDrowningDamageFn(fn)
	self.ontakedrowningdamage = fn
end

function Drownable:SetCustomTuningsFn(fn)
	self.customtuningsfn = fn
end

function Drownable:IsInDrownableMapBounds(x, y, z)
    -- NOTES(JBK): This is here primarily for mods that have players go out of bounds if they want to override it for this component only.
    -- The old check was to see if it was an invalid tile but this is too overbearing for in world applications for caves.
    -- Instead we will check if the player is outside of the playable map because if they escape we should not care what the player does there.
    return TheWorld.Map:IsInMapBounds(x, y, z)
end

function Drownable:IsSafeFromFalling()
    if self.inst:GetCurrentPlatform() then
        return true
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    if not self:IsInDrownableMapBounds(x, y, z) then
        return true -- Do not handle out of map bounds.
    end

    if TheWorld.Map:IsVisualGroundAtPoint(x, y, z) then -- Expensive check last.
        return true
    end

    return false
end

function Drownable:IsOverVoid()
    if self:IsSafeFromFalling() then
        return false
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    return TheWorld.Map:IsInvalidTileAtPoint(x, y, z)
end

function Drownable:IsOverWater()
    if self:IsSafeFromFalling() then
        return false
    end

    local x, y, z = self.inst.Transform:GetWorldPosition()
    return TheWorld.Map:IsOceanTileAtPoint(x, y, z)
end

function Drownable:ShouldX_InternalCheck()
    if not self.enabled then
        return false
    end
    if self.inst.components.health and self.inst.components.health:IsInvincible() then -- Godmode check.
        return false
    end

    return true
end

function Drownable:ShouldDrown()
    if not self:ShouldX_InternalCheck() then
        return false
    end

    return self:IsOverWater()
end

function Drownable:ShouldFallInVoid()
    if not self:ShouldX_InternalCheck() then
        return false
    end

    return self:IsOverVoid()
end

function Drownable:GetFallingReason()
    if self:ShouldDrown() then
        return FALLINGREASON.OCEAN
    elseif self:ShouldFallInVoid() then
        return FALLINGREASON.VOID
    end
end

local function NoHoles(pt)
    return not TheWorld.Map:IsPointNearHole(pt)
end

local function NoPlayersOrHoles(pt)
    return not (IsAnyPlayerInRange(pt.x, 0, pt.z, 2) or TheWorld.Map:IsPointNearHole(pt))
end

function Drownable:Teleport()
    local target_x, target_y, target_z = self.dest_x, self.dest_y, self.dest_z
    local radius = 2 + math.random() * 3

    local pt = Vector3(target_x, target_y, target_z)
    local angle = math.random() * TWOPI
    local offset =
        FindWalkableOffset(pt, angle, radius, 8, true, false, NoPlayersOrHoles) or
        FindWalkableOffset(pt, angle, radius * 1.5, 6, true, false, NoPlayersOrHoles) or
        FindWalkableOffset(pt, angle, radius, 8, true, false, NoHoles) or
        FindWalkableOffset(pt, angle, radius * 1.5, 6, true, false, NoHoles)
    if offset ~= nil then
        target_x = target_x + offset.x
        target_z = target_z + offset.z
    end

    if self.inst.Physics ~= nil then
        self.inst.Physics:Teleport(target_x, target_y, target_z)
    elseif self.inst.Transform ~= nil then
        self.inst.Transform:SetPosition(target_x, target_y, target_z)
    end
end

function Drownable:GetWashingAshoreTeleportSpot(excludeclosest)
    local ex, ey, ez = self.inst.Transform:GetWorldPosition()
    local x, y, z = FindRandomPointOnShoreFromOcean(ex, ey, ez, excludeclosest)
    if x == nil then
        x, y, z = ex, ey, ez
    end

    local radius = 2 + math.random() * 3
    local angle = math.random() * TWOPI
    local pt = Vector3(x, y, z)
    local offset =
        FindWalkableOffset(pt, angle, radius, 8, true, false, NoPlayersOrHoles) or
        FindWalkableOffset(pt, angle, radius * 1.5, 6, true, false, NoPlayersOrHoles) or
        FindWalkableOffset(pt, angle, radius, 8, true, false, NoHoles) or
        FindWalkableOffset(pt, angle, radius * 1.5, 6, true, false, NoHoles)
    if offset ~= nil then
        x = x + offset.x
        z = z + offset.z
    end

    return x, y, z
end

local function _oncameraarrive(inst)
    inst:SnapCamera()
    inst:ScreenFade(true, 2)
end

local function _onarrive(inst)
	if inst.sg.statemem.teleportarrivestate ~= nil then
		inst.sg:GoToState(inst.sg.statemem.teleportarrivestate)
	end

    inst:PushEvent("on_washed_ashore")
end

function Drownable:WashAshore()
	self:Teleport()

	if self.inst:HasTag("player") then
	    self.inst:ScreenFade(false)
		self.inst:DoTaskInTime(3, _oncameraarrive)
	end
    self.inst:DoTaskInTime(4, _onarrive)
end

function Drownable:ShouldDropItems()
	if self.inst:HasTag("stronggrip") then
		return false
	end

	return self.shoulddropitemsfn == nil and true or self.shoulddropitemsfn(self.inst)
end

function Drownable:OnFallInOcean(shore_x, shore_y, shore_z)
	self.src_x, self.src_y, self.src_z = self.inst.Transform:GetWorldPosition()

	if shore_x == nil then
		shore_x, shore_y, shore_z = FindRandomPointOnShoreFromOcean(self.src_x, self.src_y, self.src_z)
	end

	self.dest_x, self.dest_y, self.dest_z = shore_x, shore_y, shore_z

	if self.inst.components.sleeper ~= nil then
		self.inst.components.sleeper:WakeUp()
	end

	local inv = self.inst.components.inventory
	if inv ~= nil then
		local active_item = inv:GetActiveItem()
		if active_item ~= nil and not active_item:HasTag("irreplaceable") and not active_item.components.inventoryitem.keepondrown then
			Launch(inv:DropActiveItem(), self.inst, 3)
		end

		if self:ShouldDropItems() then
			local handitem = inv:GetEquippedItem(EQUIPSLOTS.HANDS)
			if handitem ~= nil and not handitem:HasTag("irreplaceable") and not handitem.components.inventoryitem.keepondrown then
				Launch(inv:DropItem(handitem), self.inst, 3)
			end
		end
	end
end

local function _onarrive_void(inst)
	if inst.sg.statemem.teleportarrivestate ~= nil then
		inst.sg:GoToState(inst.sg.statemem.teleportarrivestate)
	end

    inst:PushEvent("on_void_arrive")
end

function Drownable:VoidArrive()
	self:Teleport()

	if self.inst:HasTag("player") then
	    self.inst:ScreenFade(false)
		self.inst:DoTaskInTime(3, _oncameraarrive)
	end
    self.inst:DoTaskInTime(4, _onarrive_void)
end

function Drownable:OnFallInVoid(teleport_x, teleport_y, teleport_z)
	self.src_x, self.src_y, self.src_z = self.inst.Transform:GetWorldPosition()

	if teleport_x == nil then
		teleport_x, teleport_y, teleport_z = FindRandomPointOnShoreFromOcean(self.src_x, self.src_y, self.src_z)
	end

	self.dest_x, self.dest_y, self.dest_z = teleport_x, teleport_y, teleport_z

	if self.inst.components.sleeper ~= nil then
		self.inst.components.sleeper:WakeUp()
	end

    -- FIXME(JBK): Penalties for falling in the void.
end

local function is_enabled_flotation_item(item)
	return item.components.flotationdevice ~= nil and item.components.flotationdevice:IsEnabled()
		and (not item.components.equippable or item.components.equippable:IsEquipped())
end

function Drownable:TakeDrowningDamage()
	local tunings = (self.customtuningsfn ~= nil and self.customtuningsfn(self.inst))
					or TUNING.DROWNING_DAMAGE[string.upper(self.inst.prefab)]
					or TUNING.DROWNING_DAMAGE[self.inst:HasTag("player") and "DEFAULT" or "CREATURE"]

	local penalty_scale = 1.0
	if self.src_x then
		local tile = TheWorld.Map:GetTileAtPoint(self.src_x, self.src_y, self.src_z)
		penalty_scale = (TileGroupManager:IsShallowOceanTile(tile) and TUNING.DROWNING_SHALLOW_SCALE) or 1.0
	end

	if self.inst.components.moisture ~= nil and tunings.WETNESS ~= nil then
		self.inst.components.moisture:DoDelta(penalty_scale * tunings.WETNESS, true)
	end

	if self.inst.components.inventory ~= nil then
		-- For whatever reason, inventory:FindItem doesn't search equip slots, but inventory:FindItems does.
		local flotationitems = self.inst.components.inventory:FindItems(is_enabled_flotation_item)
		if #flotationitems > 0 then
			flotationitems[1].components.flotationdevice:OnPreventDrowningDamage(Vector3(self.src_x, self.src_y, self.src_z))
			return
		end
	end

	if self.inst.components.hunger ~= nil and tunings.HUNGER ~= nil then
		local delta = penalty_scale * -math.min(tunings.HUNGER, self.inst.components.hunger.current - 30)
		if delta < 0 then
			self.inst.components.hunger:DoDelta(delta)
		end
	end

	if self.inst.components.health ~= nil then
		if tunings.HEALTH_PENALTY ~= nil then
			-- Health penalties don't get scaled because they're very particularly restricted in terms of character application,
			-- and need to be of a particular size to even be visible in-game.
			self.inst.components.health:DeltaPenalty(tunings.HEALTH_PENALTY)
		end

		if tunings.HEALTH ~= nil then
			local delta = penalty_scale * -math.min(tunings.HEALTH, self.inst.components.health.currenthealth - 30)
			if delta < 0 then
				self.inst.components.health:DoDelta(delta, false, "drowning", true, nil, true)
			end
		end
	end

	if self.inst.components.sanity ~= nil and tunings.SANITY ~= nil then
		local delta = penalty_scale * -math.min(tunings.SANITY, self.inst.components.sanity.current - 30)
		if delta < 0 then
			self.inst.components.sanity:DoDelta(delta)
		end
	end

	if self.ontakedrowningdamage ~= nil then
		self.ontakedrowningdamage(self.inst, tunings)
	end
end

function Drownable:DropInventory()
	if not self:ShouldDropItems() then
		return
	end

	local inv = self.inst.components.inventory
	if inv ~= nil then
		local to_drop = {}
		for k, v in pairs(inv.itemslots) do
			if not v:HasTag("irreplaceable") and not v.components.inventoryitem.keepondrown then
				table.insert(to_drop, k)
			end
		end
		shuffleArray(to_drop)

		local x, y, z = self.inst.Transform:GetWorldPosition()
		local tile = TheWorld.Map:GetTileAtPoint(x, y, z)
		local inventory_partition = (TileGroupManager:IsShallowOceanTile(tile) and math.floor(#to_drop / TUNING.DROWNING_ITEMDROP_SHALLOWS))
			or math.floor(#to_drop / TUNING.DROWNING_ITEMDROP_NORMAL)
		if inventory_partition > 0 then
			for i = 1, inventory_partition do
				Launch(inv:DropItem(inv.itemslots[ to_drop[i] ], true), self.inst, 2)
			end
		end
	end
end


return Drownable