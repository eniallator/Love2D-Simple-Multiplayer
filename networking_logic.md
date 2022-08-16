# Networking Logic

- Action based system
- Ideally over TCP since actions may rely on previous ones
  - Possibly UDP for common ones that don't need to rely on previous ones?
- Everything can be serialised
- Update method on all data classes which the networking manager calls
  - Takes in only the updated data
- Draw method takes dt and does linear interpolation between states
- Base data class has interpolation methods/serialisation and deserialisation methods
- Serialisation to create a tree like data structure
  - With no data and 1 subTable: `outerTable.subTable{}[]`
  - With data and 1 subTable: `outerTable{key1=value1,key2=value2}.subTable{}[]`
  - With no data and multiple subTables: `outerTable[subTable1{}[],subTable2{}[]]`
  - With data and multiple subTables: `outerTable{key1=value1,key2=value2}[subTable1{}[],subTable2{}[]]`
