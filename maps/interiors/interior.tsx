<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.10" tiledversion="1.12.0" name="interior" tilewidth="16" tileheight="16" tilecount="5" columns="5">
 <image source="../../assets/interior.png" width="80" height="16"/>
 <tile id="0">
  <properties>
   <property name="terrain" value="FLOOR"/>
  </properties>
 </tile>
 <tile id="1">
  <properties>
   <property name="terrain" value="WALL"/>
  </properties>
 </tile>
 <tile id="2">
  <properties>
   <property name="exit" type="bool" value="true"/>
   <property name="terrain" value="FLOOR"/>
  </properties>
 </tile>
 <tile id="3">
  <properties>
   <property name="object_type" value="small_bed"/>
  </properties>
 </tile>
 <tile id="4">
  <properties>
   <property name="object_type" value="table"/>
  </properties>
 </tile>
</tileset>
