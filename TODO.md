Depth is a parameter not based directly on noise, instead it corresponds approximately to the terrain height. It is roughly 0 at the surface and increases by 1⁄128 (0.0078125) for every 1 block down. The depth parameter affects whether a surface biome or a cave biome is placed.

The table below lists the defined depth values for Overworld biomes, and any additional noise values required for cave biomes to generate. Any other values result in the closest biome interval being used instead. Note that regions of lush caves and dripstone caves overlap.

Depth	Additional requirement	Biomes
Any	N/A	Surface biomes
D=0.2~0.9	Continentalness=0.8~1.0	Dripstone Caves
D=0.2~0.9	Humidity=0.7~1.0	Lush Caves
D=0.2~0.9	Weirdness=-1.1~-0.95	Sulfur Caves​
D≥1.1	Erosion=-1.0~-0.375	Deep Dark

The generation of non-inland biomes is not based on humidity, erosion, or weirdness. The following table lists the relation between non-inland surface biomes and continentalness and temperature.

Temperature	Oceans	Deep oceans	Mushroom fields
T=0	Frozen Ocean	Deep Frozen Ocean	Mushroom Fields
T=1	Cold Ocean	Deep Cold Ocean Mushroom Fields
T=2	Ocean	Deep Ocean Mushroom Fields
T=3	Lukewarm Ocean	Deep Lukewarm Ocean Mushroom Fields
T=4	Warm Ocean Mushroom Fields

In which, the specific biome generation of beach biomes, badland biomes, middle biomes, plateau biomes, and shattered biomes is determined by the temperature, humidity, and weirdness values.

Beach biomes generate in low lying terrain along the coast, and the specific biome generation is related only to the temperature value.

T=0	Snowy Beach
T=1,2,3	Beach
T=4	Desert

Badland biomes usually generate inland with low erosion value, and can also generate along the coast with high terrain and low erosion. The specific biome generation is related to humidity and weirdness.

Humidity	Biomes
H=0,1	Badlands（W<0, Eroded Badlands（W>0）
H=2	Badlands
H=3,4	Wooded Badlands

other biomes are hard to paste in. as they rely on exact temperature and humididy .. etc


at this link: https://minecraft.wiki/w/World_generation

look at the lists.