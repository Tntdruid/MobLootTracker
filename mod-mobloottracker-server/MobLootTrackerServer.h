#ifndef _MOB_LOOT_TRACKER_SERVER_H_
#define _MOB_LOOT_TRACKER_SERVER_H_

#include "DatabaseEnv.h"
#include "QueryResult.h"
#include "WorldSession.h"
#include "WorldPacket.h"

enum MobLootTrackerOpcodes
{
    CMSG_MLT_SEND_LOOT   = 0xB0,
    CMSG_MLT_REQUEST_NPC = 0xB1,
    SMSG_MLT_NPC_DATA    = 0xB2,
};

class MobLootTrackerServer
{
public:
    static void AddLoot(uint32 npcId, uint32 itemId, uint32 count)
    {
        CharacterDatabase.Execute(
            "INSERT INTO mob_loot_tracker (npc_id, item_id, count) "
            "VALUES (%u, %u, %u) "
            "ON DUPLICATE KEY UPDATE count = count + %u",
            npcId, itemId, count, count
        );
    }

    static uint32 GetLootCount(uint32 npcId, uint32 itemId)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT count FROM mob_loot_tracker WHERE npc_id = %u AND item_id = %u",
            npcId, itemId
        );

        if (!result)
            return 0;

        Field* fields = result->Fetch();
        return fields[0].Get<uint32>();
    }

    static void SendNPCData(WorldSession* session, uint32 npcId)
    {
        QueryResult result = CharacterDatabase.Query(
            "SELECT item_id, count FROM mob_loot_tracker WHERE npc_id = %u",
            npcId
        );

        WorldPacket data(SMSG_MLT_NPC_DATA, 4 + (result ? result->GetRowCount() * 8 : 0));
        data << npcId;

        if (result)
        {
            do
            {
                Field* fields = result->Fetch();
                uint32 itemId = fields[0].Get<uint32>();
                uint32 count  = fields[1].Get<uint32>();

                data << itemId;
                data << count;
            } while (result->NextRow());
        }

        session->SendPacket(&data);
    }
};

#endif
