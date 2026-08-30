#include "ScriptMgr.h"
#include "WorldSession.h"
#include "WorldPacket.h"
#include "MobLootTrackerServer.h"

class MobLootTrackerWorld : public WorldScript
{
public:
    MobLootTrackerWorld() : WorldScript("MobLootTrackerWorld") { }

    void OnPacketReceive(WorldSession* session, WorldPacket& packet)
    {
        switch (packet.GetOpcode())
        {
            case CMSG_MLT_SEND_LOOT:
                HandleSendLoot(session, packet);
                break;

            case CMSG_MLT_REQUEST_NPC:
                HandleRequestNPC(session, packet);
                break;

            default:
                break;
        }
    }

private:
    void HandleSendLoot(WorldSession* /*session*/, WorldPacket& packet)
    {
        uint32 npcId, itemId, count;
        packet >> npcId >> itemId >> count;

        MobLootTrackerServer::AddLoot(npcId, itemId, count);
    }

    void HandleRequestNPC(WorldSession* session, WorldPacket& packet)
    {
        uint32 npcId;
        packet >> npcId;

        MobLootTrackerServer::SendNPCData(session, npcId);
    }
};

void AddMobLootTrackerServerScripts()
{
    new MobLootTrackerWorld();
}
