# Love2D-Simple-Multiplayer

A simple multiplayer implementation where there's a server and multiple clients can connect and control squares on the display.

## Networking Logic

- The [synchronised table](common/SynchronisedTable.lua) has seamless integration with Lua's table data structure - you're able to use it normally, and then it can be later polled for any updates that have happened to it and it's sub tables
- Serialisation will create a tree like representation of the updates
  - With data and sub tables: `outerTable{key1=value1,key2=value2}[subTable1{}[],subTable2{}[]]`
  - With no data: `outerTable[subTable1{}[],subTable2{}[]]`
  - With no sub tables: `outerTable{key1=value1,key2=value2}`

### Packet Loss

- Add an age to each state data table
  - This is updated whenever the data table is updated
- The other side will store the last known age, then send that back so the original state can then see whats been updated since that last known age
- Both server and client will do this, as packet loss can occur on either side
- This then handles packet loss, since if a packet gets lost, the last known age doesn't update, and then when the side requests the next updates, it will include the lost packet's data.
