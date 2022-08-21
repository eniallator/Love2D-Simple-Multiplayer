# Networking Logic

- Seamless integration with Lua's table data structure - you're able to use it normally, and then it can be later polled for any updates that have happened to it and it's sub tables
- Serialisation to create a tree like data structure
  - With no data: `outerTable[subTable1{}[],subTable2{}[]]`
  - With data: `outerTable{key1=value1,key2=value2}[subTable1{}[],subTable2{}[]]`

## Packet Loss

- Add an age to each state data collection
  - This is updated whenever the data collection is updated
- The other side will store the last known age, then send that back so the original state can then see whats been updated since that last known age
- Both server and client will do this, as packet loss can occur on either side
- This then handles packet loss, as if a packet gets lost, the last known age doesn't update, and then the client requests the updates, which includes the lost packet's data.
