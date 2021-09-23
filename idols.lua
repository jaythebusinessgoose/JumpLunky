IDOL_COLLECTED_STATE = {
    NOT_COLLECTED = 0,
    COLLECTED = 1,
    COLLECTED_ON_RUN = 2,
}

function spawn_idol(x, y , layer, collected, isEasy)
	local idol_uid
	if isEasy then
		spawn_entity(ENT_TYPE.ITEM_MADAMETUSK_IDOLNOTE, x, y, layer, 0, 0)
		return true
	elseif collected == IDOL_COLLECTED_STATE.COLLECTED_ON_RUN then
		-- Do not spawn the idol if it has already been collected on this run. This should be pretty rare because the
		-- the idol can only be deposited at the exit door, and the player cannot return to the level after exiting.
		return true
	elseif collected == IDOL_COLLECTED_STATE.COLLECTED then
		-- If the idol for the level has _ever_ been collected, spawn a tusk idol instead.
		idol_uid = spawn_entity_snapped_to_floor(ENT_TYPE.ITEM_MADAMETUSK_IDOL, x, y, layer, 0, 0)
	else
		idol_uid = spawn_entity_snapped_to_floor(ENT_TYPE.ITEM_IDOL, x, y, layer, 0, 0)
	end
	local idol = get_entity(idol_uid)
	-- Set the price to 0 so the player doesn't get gold for returning the idol.
	idol.price = 0
	return true
end
