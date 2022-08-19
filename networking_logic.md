# Networking Logic

- Seamless integration with Lua's table data structure - you're able to use it normally, and then it can be later polled for any updates that have happened to it and it's sub tables
- Serialisation to create a tree like data structure
  - With no data: `outerTable[subTable1{}[],subTable2{}[]]`
  - With data: `outerTable{key1=value1,key2=value2}[subTable1{}[],subTable2{}[]]`
