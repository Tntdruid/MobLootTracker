#ifndef _MOB_LOOT_VALUE_H_
#define _MOB_LOOT_VALUE_H_

#include "Playerbots.h"
#include "MobLootTrackerServer.h"

inline uint32 GetMobLootValue(PlayerbotAI* ai)
{
    Unit* target = ai->GetBot()->GetSelectedUnit();

    if (!target)
        target = ai->GetBot()->GetVictim();

    if (!target)
        return 0;

    uint32 npcId = target->GetEntry();
    uint32 itemId = 21887; // Knothide Leather

    return MobLootTrackerServer::GetLootCount(npcId, itemId);
}

#endif