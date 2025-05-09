local assets =
{
    Asset("ANIM", "anim/gelblob_storage.zip"),
}

local prefabs =
{
    "collapse_small",
    "messagebottleempty",
}

---------------------------------------------------------------------------------------------------------------

-- TODO(DiogoW/V2C): Do we want to accept all of this??
local ACCEPTABLE_FOODTYPES =
{
    "GENERIC",
    "MEAT",
    "VEGGIE",
    "SEEDS",
    "BERRY",
    "RAW",
    "GOODIES",
    "MONSTER",
}

local FOOD_ONEOF_TAGS = {}

for i, type in ipairs(ACCEPTABLE_FOODTYPES) do
    table.insert(FOOD_ONEOF_TAGS, "edible_"..type)
end

---------------------------------------------------------------------------------------------------------------

local function OnHammered(inst)
    inst.components.lootdropper:DropLoot()

    -- TODO(DiogoW): A more fitting fx?
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("rock")

    if inst.components.inventoryitemholder ~= nil then
        inst.components.inventoryitemholder:TakeItem()
    end

    inst:Remove()
end

local function OnHit(inst)
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("idle")
end

local function OnBuiltFn(inst)
    inst.AnimState:PlayAnimation("place")
    inst.AnimState:PushAnimation("idle")

    inst.SoundEmitter:PlaySound("rifts4/gelblob_storage/place")
end

---------------------------------------------------------------------------------------------------------------

local function OnFoodGiven(inst, item, giver)
    local stacked = item == nil or not item:IsValid()

    if not POPULATING then
        inst.AnimState:PlayAnimation("give")

        if stacked then
            inst.AnimState:SetFrame(6)
        end

        inst.AnimState:PushAnimation("idle")

        inst.SoundEmitter:PlaySound("rifts4/gelblob_storage/store")
    end

    if stacked then
        return
    end

    if item.components.perishable ~= nil then
        item.components.perishable:StopPerishing()
    end

	item:AddTag("NOCLICK")
	item:ReturnToScene()

    item.components.inventoryitem.canbepickedup = false

    inst.takeitem:set(item)

	if item.Follower == nil then
		item.entity:AddFollower()
	end
	item.Follower:FollowSymbol(inst.GUID, "swap_object", 0, 0, 0, true)
end

local function OnFoodTaken(inst, item, taker, wholestack)
    inst.SoundEmitter:PlaySound("rifts4/gelblob_storage/store")

    if not wholestack then
        inst.AnimState:PlayAnimation("give")
        inst.AnimState:PushAnimation("idle")
        inst.AnimState:SetFrame(6)

        return
    end

    inst.AnimState:PlayAnimation("take")
    inst.AnimState:PushAnimation("idle")

    inst.takeitem:set(nil)

    if item == nil or not item:IsValid() then
        return
    end

    if item.components.perishable ~= nil then
        item.components.perishable:StartPerishing()
    end

    item.components.inventoryitem.canbepickedup = true

	item:RemoveTag("NOCLICK")
	item.Follower:StopFollowing()
end

---------------------------------------------------------------------------------------------------------------

local function GetStatus(inst)
    return inst.components.inventoryitemholder:IsHolding() and "FULL" or nil
end

---------------------------------------------------------------------------------------------------------------

local function StorageFn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()

    inst.MiniMapEntity:SetIcon("gelblob_storage.png")

    MakeObstaclePhysics(inst, .5)

    inst:SetPhysicsRadiusOverride(.8) -- For better looking interactions...
    inst:SetDeploySmartRadius(DEPLOYSPACING_RADIUS[DEPLOYSPACING.DEFAULT] / 2) -- Match kit item.

    inst.AnimState:SetBank("gelblob_storage")
    inst.AnimState:SetBuild("gelblob_storage")
    inst.AnimState:PlayAnimation("idle", true)

    inst.AnimState:SetLightOverride(.1)
    inst.AnimState:SetSymbolLightOverride("red", 1)

    inst:AddTag("structure")

    inst.takeitem = net_entity(inst.GUID, "gelblob_storage.takeitem") -- For action string.

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.OnBuiltFn = OnBuiltFn
    inst:ListenForEvent("onbuilt", inst.OnBuiltFn)

    inst:AddComponent("lootdropper")

    inst:AddComponent("inspectable")
    inst.components.inspectable.getstatus = GetStatus

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(4)
    inst.components.workable:SetOnFinishCallback(OnHammered)
    inst.components.workable:SetOnWorkCallback(OnHit)

    inst:AddComponent("inventoryitemholder")
    inst.components.inventoryitemholder:SetAllowedTags(FOOD_ONEOF_TAGS)
    inst.components.inventoryitemholder:SetAcceptStacks(true)
    inst.components.inventoryitemholder:SetOnItemGivenFn(OnFoodGiven)
    inst.components.inventoryitemholder:SetOnItemTakenFn(OnFoodTaken)

    MakeHauntableWork(inst)

    return inst
end

--------------------------------------------------------------------------------------------------------------------------

return
    Prefab("gelblob_storage", StorageFn, assets, prefabs),
    MakePlacer("gelblob_storage_kit_placer", "gelblob_storage", "gelblob_storage", "placer"),
    MakeDeployableKitItem(
        "gelblob_storage_kit", -- name
        "gelblob_storage",     -- prefab_to_deploy
        "gelblob_storage",     -- bank
        "gelblob_storage",     -- build
        "kit",                 -- anim
        assets,                -- assets
        {                      -- floatable_data
            size = "med",
            y_offset = 0.1,
            scale = {1, .75, 1},
        },
        nil,                   -- tags
        nil,                   -- burnable
        {                      -- deployable_data
        master_postinit = function(inst)
            MakeCraftingMaterialRecycler(inst, { gelblob_bottle = "messagebottleempty" })
        end
        }
    )