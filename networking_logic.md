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
  - With no data: `outerTable[subTable1{}[],subTable2{}[]]`
  - With data: `outerTable{key1=value1,key2=value2}[subTable1{}[],subTable2{}[]]`
