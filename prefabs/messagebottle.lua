local messagebottletreasures = require("messagebottletreasures")

local assets =
{
	Asset("ANIM", "anim/bottle.zip"),
	Asset("INV_IMAGE", "messagebottle"),
	Asset("ANIM", "anim/swap_bottle.zip"),
}

local assets_gelblob =
{
	Asset("ANIM", "anim/bottle.zip"),
	Asset("ANIM", "anim/swap_gelblobbottle.zip"),
}

local messagebottletreasures_prefabs = messagebottletreasures.GetPrefabs()

local prefabs =
{
	"messagebottleempty",
	"messagebottle_throwable",
}
ConcatArrays(prefabs, messagebottletreasures_prefabs)

local prefabs_empty =
{
	"gelblob_bottle",
}

local prefabs_gelblob =
{
	"gelblob_small_fx",
}

local function playidleanim(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	if TheWorld.Map:IsOceanAtPoint(x, y, z, false) then
		inst.AnimState:PlayAnimation("idle_water")
	else
		inst.AnimState:PlayAnimation("idle")
	end
end

local function ondropped(inst)
	inst.AnimState:PlayAnimation("idle")
end

local function getrevealtargetpos(inst, doer)
	if TheWorld.components.messagebottlemanager == nil then
		return false, "MESSAGEBOTTLEMANAGER_NOT_FOUND"
	end

	local pos, reason = TheWorld.components.messagebottlemanager:UseMessageBottle(inst, doer)
	return pos, reason
end

local function turn_empty(inst, targetpos)
	local inventory = inst.components.inventoryitem:GetContainer() -- Also returns inventory component

	local empty_bottle = SpawnPrefab("messagebottleempty")
	empty_bottle.Transform:SetPosition(inst.Transform:GetWorldPosition())

	inst:Remove()

	if inventory ~= nil then
		inventory:GiveItem(empty_bottle)
	end
end

local function onplayerfinishedreadingnote(player)
	if player.AnimState:IsCurrentAnimation("build_pst") then
		if player.components.talker ~= nil then
            local str
            if player:HasTag("mime") then
                str = ""
            else
                str = STRINGS.MESSAGEBOTTLE_NOTES[math.random(#STRINGS.MESSAGEBOTTLE_NOTES)]
            end
			player.components.talker:Say(str)
		end
	end

	player:RemoveEventCallback("animover", onplayerfinishedreadingnote)
end

local function ShouldForceMapReveal(inst)
	local hermit = TheWorld.components.messagebottlemanager ~= nil and TheWorld.components.messagebottlemanager:GetHermitCrab() or nil

	if hermit == nil or not hermit.pearlgiven then
		return false -- The Pearl doesn't exist yet.
	end

	if TheSim:FindFirstEntityWithTag("hermitpearl") then
		return false -- The Pearl or Cracked Pearl exist.
	end

	local crabking = TheSim:FindFirstEntityWithTag("crabking")

	if crabking ~= nil and crabking.gemcount ~= nil then
		return crabking.gemcount.pearl <= 0 -- Checking if crabking has the Pearl.
	end

	return true -- The Cracked Pearl has been given to Hermit.
end

local function prereveal(inst, doer)
	if ShouldForceMapReveal(inst, doer) then
		return true
	end

	local bottle_contains_note = false

	if TheWorld.components.messagebottlemanager ~= nil then
		if (TheWorld.components.messagebottlemanager:GetPlayerHasUsedABottle(doer) or TheWorld.components.messagebottlemanager:GetPlayerHasFoundHermit(doer))
			and math.random() < TUNING.MESSAGEBOTTLE_NOTE_CHANCE then

			bottle_contains_note = true
		end

		TheWorld.components.messagebottlemanager:SetPlayerHasUsedABottle(doer)
	end

	if bottle_contains_note then
		doer:ListenForEvent("animover", onplayerfinishedreadingnote)
		turn_empty(inst)
		return false
	else
		return true
	end
end

local function commonmakebottle(common_postinit, master_postinit)
	local inst = CreateEntity()

    inst.entity:AddTransform()
	inst.entity:AddNetwork()

    inst.entity:AddAnimState()
    inst.AnimState:SetBank("bottle")
    inst.AnimState:SetBuild("bottle")
	inst.AnimState:PlayAnimation("idle")

	MakeInventoryPhysics(inst)
	MakeInventoryFloatable(inst, "small", 0.05, 1)

	--waterproofer (from waterproofer component) added to pristine state for optimization
	inst:AddTag("waterproofer")

	--mapspotrevealer (from mapspotrevealer component) added to pristine state for optimization
	inst:AddTag("mapspotrevealer")

	if common_postinit then
		common_postinit(inst)
	end

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst.scrapbook_removedeps = messagebottletreasures_prefabs

    inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("waterproofer")
	inst.components.waterproofer:SetEffectiveness(0)

	inst:AddComponent("mapspotrevealer")
	inst.components.mapspotrevealer:SetGetTargetFn(getrevealtargetpos)
	inst.components.mapspotrevealer:SetPreRevealFn(prereveal)

	inst:ListenForEvent("on_landed", playidleanim)
	inst:ListenForEvent("on_reveal_map_spot_pst", turn_empty)

	inst:ListenForEvent("ondropped", ondropped)

	if master_postinit then
		master_postinit(inst)
	end

	return inst
end

local function messagebottlefn()
	return commonmakebottle()
end

local function playidleanim_empty(inst)
	local x, y, z = inst.Transform:GetWorldPosition()
	if TheWorld.Map:IsOceanAtPoint(x, y, z, false) then
		inst.AnimState:PlayAnimation("idle_empty_water")
	else
		inst.AnimState:PlayAnimation("idle_empty")
	end
end

local function ondropped_empty(inst)
	inst.AnimState:PlayAnimation("idle_empty")
end

--------------------------------------------------------------------------

local function OnBottle(inst, target, doer)
	if target.prefab == "gelblob_small_fx" then
		local targetpos = target:GetPosition()
		local x, y, z = inst.Transform:GetWorldPosition()
		inst.components.stackable:Get():Remove()
		target:Remove()

		local bottledinst = SpawnPrefab("gelblob_bottle")
		if doer and doer.components.inventory then
			doer.components.inventory:GiveItem(bottledinst, nil, targetpos)
		else
			bottledinst.Transform:SetPosition(x, y, z)
		end
		return true
	end
	return false
end

--------------------------------------------------------------------------

local function emptybottlefn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("bottle")
    inst.AnimState:SetBuild("bottle")
	inst.AnimState:PlayAnimation("idle_empty")

	--waterproofer (from waterproofer component) added to pristine state for optimization
	inst:AddTag("waterproofer")

	MakeInventoryPhysics(inst)
	MakeInventoryFloatable(inst, "small", 0.05, 1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
	end

    inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

	inst:AddComponent("bottler")
	inst.components.bottler:SetOnBottleFn(OnBottle)

    inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_MEDITEM

	inst:AddComponent("waterproofer")
	inst.components.waterproofer:SetEffectiveness(0)

	inst:ListenForEvent("on_landed", playidleanim_empty)

	inst:ListenForEvent("ondropped_empty", ondropped)

	return inst
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_object", "swap_bottle", "swap_bottle")
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
end

local function OnHit(inst, attacker, target)
    local x, y, z = inst.Transform:GetWorldPosition()
    if not TheWorld.Map:IsVisualGroundAtPoint(x,y,z) and not TheWorld.Map:GetPlatformAtPoint(x,z) then
    	SpawnPrefab("splash_green_small").Transform:SetPosition(x,y,z)
		inst.components.inventoryitem.canbepickedup = false

    	inst.AnimState:PlayAnimation("bob")
		inst:ListenForEvent("animover", function(inst) inst:Remove() end)
    else
		SpawnPrefab("messagebottle_break_fx").Transform:SetPosition(x,y,z)
		inst:Remove()
    end
end

local function onthrown(inst)
    inst:AddTag("NOCLICK")
    inst.persists = false

    inst.AnimState:PlayAnimation("spin_loop", true)

    inst.Physics:SetMass(1)
    inst.Physics:SetFriction(0)
    inst.Physics:SetDamping(0)
    inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:SetCollisionMask(
		COLLISION.WORLD,
		COLLISION.OBSTACLES,
		COLLISION.ITEMS
	)
    inst.Physics:SetCapsule(.2, .2)
end

local function throwing_common_postinit(inst)
	--projectile (from complexprojectile component) added to pristine state for optimization
	inst:AddTag("projectile")
	inst:AddTag("complexprojectile")
end

local function throwing_master_postinit(inst)
    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst.components.inventoryitem:ChangeImageName("messagebottle")

    inst:AddComponent("complexprojectile")
    inst.components.complexprojectile:SetHorizontalSpeed(15)
    inst.components.complexprojectile:SetGravity(-35)
    inst.components.complexprojectile:SetLaunchOffset(Vector3(.25, 1, 0))
    inst.components.complexprojectile:SetOnLaunch(onthrown)
    inst.components.complexprojectile:SetOnHit(OnHit)
    inst.components.complexprojectile.water_targetable = true
    inst.useonimpassible = true
end

local function throwingbottlefn(inst)
	return commonmakebottle(throwing_common_postinit, throwing_master_postinit)
end

local function bobbottlefn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("bottle")
    inst.AnimState:SetBuild("bottle")
	inst.AnimState:PlayAnimation("bob")

	--MakeInventoryPhysics(inst)
	MakeInventoryFloatable(inst, "small", 0.05, 1)


    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

	inst:AddComponent("inventoryitem")
	inst.canbepickedup = false
	inst:ListenForEvent("animover", function(inst) inst:Remove() end)

	return inst
end

-----------------------------------------------------------------------------------------

local function GelBlobBottle_OnEquip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_object", "swap_gelblobbottle", "swap_bottle")
	owner.AnimState:Show("ARM_carry")
	owner.AnimState:Hide("ARM_normal")
end

local function GelBlobBottle_OnUnequip(inst, owner)
	owner.AnimState:Hide("ARM_carry")
	owner.AnimState:Show("ARM_normal")
end

local function GelBlobBottle_OnHit(inst, attacker, target)
	local x, y, z = inst.Transform:GetWorldPosition()
	if not TheWorld.Map:IsVisualGroundAtPoint(x,y,z) and not TheWorld.Map:GetPlatformAtPoint(x,z) then
		SpawnPrefab("splash_green_small").Transform:SetPosition(x,y,z)
		inst.components.inventoryitem.canbepickedup = false

		inst.AnimState:PlayAnimation("bob_gelblob")
		inst:ListenForEvent("animover", inst.Remove)
	else
		SpawnPrefab("messagebottle_break_fx").Transform:SetPosition(x, y, z)
		inst:Remove()
		local blob = SpawnPrefab("gelblob_small_fx")
		blob.Transform:SetPosition(x, 0, z)
		blob:SetLifespan(TUNING.TOTAL_DAY_TIME)
		blob:ReleaseFromBottle()
	end
end

local function GelBlobBottle_OnThrown(inst)
	inst:AddTag("NOCLICK")
	inst.persists = false

	inst.AnimState:PlayAnimation("spin_gelblob_loop", true)

	inst.Physics:SetMass(1)
	inst.Physics:SetFriction(0)
	inst.Physics:SetDamping(0)
	inst.Physics:SetCollisionGroup(COLLISION.CHARACTERS)
	inst.Physics:SetCollisionMask(
		COLLISION.WORLD,
		COLLISION.OBSTACLES,
		COLLISION.ITEMS
	)
	inst.Physics:SetCapsule(.2, .2)
end

local function GelBlobBottle_OnStartFloating(inst)
	inst.AnimState:PlayAnimation("idle_gelblob_water")
end

local function GelBlobBottle_OnStopFloating(inst)
	inst.AnimState:PlayAnimation("idle_gelblob")
end

local function gelblobbottlefn()
	local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    inst.AnimState:SetBank("bottle")
    inst.AnimState:SetBuild("bottle")
	inst.AnimState:PlayAnimation("idle_gelblob")

	--waterproofer (from waterproofer component) added to pristine state for optimization
	inst:AddTag("waterproofer")

	--projectile (from complexprojectile component) added to pristine state for optimization
	inst:AddTag("projectile")
	inst:AddTag("complexprojectile")

	MakeInventoryPhysics(inst)
	MakeInventoryFloatable(inst, "small", 0.05, 1)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
	end

    inst:AddComponent("inspectable")
	inst:AddComponent("inventoryitem")

    inst:AddComponent("stackable")
	inst.components.stackable.maxsize = TUNING.STACK_SIZE_LARGEITEM

	inst:AddComponent("waterproofer")
	inst.components.waterproofer:SetEffectiveness(0)

	inst:AddComponent("equippable")
	inst.components.equippable:SetOnEquip(GelBlobBottle_OnEquip)
	inst.components.equippable:SetOnUnequip(GelBlobBottle_OnUnequip)
	inst.components.equippable.equipstack = true

	inst:AddComponent("complexprojectile")
	inst.components.complexprojectile:SetHorizontalSpeed(15)
	inst.components.complexprojectile:SetGravity(-35)
	inst.components.complexprojectile:SetLaunchOffset(Vector3(.25, 1, 0))
	inst.components.complexprojectile:SetOnLaunch(GelBlobBottle_OnThrown)
	inst.components.complexprojectile:SetOnHit(GelBlobBottle_OnHit)

    inst:ListenForEvent("floater_startfloating", GelBlobBottle_OnStartFloating)
    inst:ListenForEvent("floater_stopfloating",  GelBlobBottle_OnStopFloating )

	return inst
end

return
	Prefab("messagebottle", messagebottlefn, assets, prefabs),
	Prefab("messagebottleempty", emptybottlefn, assets, prefabs_empty),
	Prefab("messagebottle_throwable", throwingbottlefn, assets),
	Prefab("gelblob_bottle", gelblobbottlefn, assets_gelblob, prefabs_gelblob)
