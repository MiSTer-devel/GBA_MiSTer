require("vsim_comm")
require("luareg")

function SplitFilename(strFilename)
   -- Returns the Path, Filename, and Extension as 3 values
   return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
end

function FindArray(array, pattern_in)

   pattern = {}

   for i = 1, #pattern_in do
      pattern[i] = string.sub(pattern_in, i, i)
   end

   local success = 0
   for i = 1, #array do
      if (array[i] == pattern[success + 1]) then
         success = success + 1
      else
         success = 0
      end
  
      if (#pattern == success) then
         return true
      end
   end
   
   return false
end

gba_savegame_path = ""
gba_loadsavegame = false

function transmit_rom(filename, baseaddress, transmit_dwords)

   -- load filecontent as binary
   local filecontent_char = {}

   local filecontent = {}
   local index = 0
   local input = io.open(filename, "rb")
   local dwordsum = 0
   local dwordpos = 0
   local byteindex = 0
   while true do
      local byte = input:read(1)
      if not byte then 
            if (dwordpos > 0) then
               filecontent[index] = dwordsum
            end
         break 
      end
      filecontent_char[#filecontent_char + 1] = string.char(string.byte(byte))
      --dwordsum = dwordsum + (string.byte(byte) * (2^((3 - dwordpos) * 8)))  -- little endian
      dwordsum = dwordsum + (string.byte(byte) * (2^((dwordpos) * 8))) -- big endian
      dwordpos = dwordpos + 1
      byteindex = byteindex + 1
      if (dwordpos == 4) then
         filecontent[index] = dwordsum
         index = index + 1
         if (transmit_dwords ~= nil) then
            if (index == transmit_dwords) then
               break
            end
         end
         dwordpos = 0
         dwordsum = 0
      end
   end
   input:close()
   
   print("Transmitting ROM: "..filename)

   --print(string.format("%08X", filecontent[0]))
   
   reg_set(#filecontent_char, gameboy.Reg_GBA_MaxPakAddr)
   
   reg_set_file(filename, baseaddress, 0, 0)

end

function write_gbbus_32bit(data, address)

   reg_set_connection(data, gameboy.Reg_GBA_BusWriteData)
   reg_set_connection(address + 0x40000000, gameboy.Reg_GBA_BusAddr) 
   
end
function read_gbbus_32bit(address)

   reg_set_connection(address + 0x50000000, gameboy.Reg_GBA_BusAddr)
   return reg_get(gameboy.Reg_GBA_BusReadData)
   
end
function compare_gbbus_32bit(comparevalue, address)

   reg_set_connection(address + 0x50000000, gameboy.Reg_GBA_BusAddr)
   local value = reg_get(gameboy.Reg_GBA_BusReadData)
   if (value == comparevalue) then
      print ("Address 0x"..string.format("%X", address).." = "..string.format("%X", value).." - OK")
   else
      testerrorcount = testerrorcount + 1
      print ("Address 0x"..string.format("%X", address).." = 0x"..string.format("%X", value).." | should be = 0x"..string.format("%X", comparevalue).." - ERROR")
   end
   
end

function write_gbbus_16bit(data, address)

   reg_set_connection(data, gameboy.Reg_GBA_BusWriteData)
   reg_set_connection(address + 0x20000000, gameboy.Reg_GBA_BusAddr) 
   
end
function read_gbbus_16bit(address)

   reg_set_connection(address + 0x30000000, gameboy.Reg_GBA_BusAddr)
   return reg_get(gameboy.Reg_GBA_BusReadData)
   
end
function compare_gbbus_16bit(comparevalue, address)

   reg_set_connection(address + 0x30000000, gameboy.Reg_GBA_BusAddr)
   local value = reg_get(gameboy.Reg_GBA_BusReadData)
   value = value % 0x10000
   if (value == comparevalue) then
      print ("Address 0x"..string.format("%X", address).." = "..string.format("%X", value).." - OK")
   else
      testerrorcount = testerrorcount + 1
      print ("Address 0x"..string.format("%X", address).." = 0x"..string.format("%X", value).." | should be = 0x"..string.format("%X", comparevalue).." - ERROR")
   end
   
end
function compare_gbbus_1632bit(comparevalue, address)

   reg_set_connection(address + 0x30000000, gameboy.Reg_GBA_BusAddr)
   local value = reg_get(gameboy.Reg_GBA_BusReadData)
   if (value == comparevalue) then
      print ("Address 0x"..string.format("%X", address).." = "..string.format("%X", value).." - OK")
   else
      testerrorcount = testerrorcount + 1
      print ("Address 0x"..string.format("%X", address).." = 0x"..string.format("%X", value).." | should be = 0x"..string.format("%X", comparevalue).." - ERROR")
   end
   
end

function write_gbbus_8bit(data, address)

   reg_set_connection(data, gameboy.Reg_GBA_BusWriteData)
   reg_set_connection(address + 0x00000000, gameboy.Reg_GBA_BusAddr) 
   
end
function read_gbbus_8bit(address)

   reg_set_connection(address + 0x10000000, gameboy.Reg_GBA_BusAddr)
   return reg_get(gameboy.Reg_GBA_BusReadData)
   
end
function compare_gbbus_8bit(comparevalue, address)

   reg_set_connection(address + 0x10000000, gameboy.Reg_GBA_BusAddr)
   local value = reg_get(gameboy.Reg_GBA_BusReadData)
   value = value % 0x100
   if (value == comparevalue) then
      print ("Address 0x"..string.format("%X", address).." = "..value.." - OK")
   else
      testerrorcount = testerrorcount + 1
      print ("Address 0x"..string.format("%X", address).." = 0x"..string.format("%X", value).." | should be = 0x"..string.format("%X", comparevalue).." - ERROR")
   end
   
end


function write_tilemap(mapindex, baseblock, h_flip, v_flip, palette, tileid)

   local data = tileid + h_flip * 1024 + v_flip * 2048 + palette * 4096
   write_gbbus_16bit(data, 0x06000000 + baseblock * 2048 + mapindex * 2)

end

function write_tilemap_mode2(mapindex, baseblock, tileid1, tileid2)

   local data = tileid1 + tileid2 * 256
   write_gbbus_16bit(data, 0x06000000 + baseblock * 2048 + mapindex)

end

function write_tile_4bit(baseaddress, index, tiledata)

   for y = 0, 7 do
      local data = 0
      for x = 7, 0, -1 do 
         data = data * 16
         data = data + tiledata[x][y]
      end
      write_gbbus_32bit(data, 0x06000000 + baseaddress + index * 32 + y * 4)
   end
      
end

function write_tile_8bit(baseaddress, index, tiledata)

   for y = 0, 7 do
      local data = 0
      for x = 7, 0, -1 do 
         data = data * 256
         data = data + tiledata[x][y]
         if (x == 4) then
            write_gbbus_32bit(data, 0x06000000 + baseaddress + index * 64 + y * 8 + 4)
            data = 0
         end
      end
      write_gbbus_32bit(data, 0x06000000 + baseaddress + index * 64 + y * 8)
   end
      
end

function write_object(index, obj)

      -- Atr0
   local OAM_Y_LO        = 0;
   local OAM_AFFINE      = 8;
   local OAM_DBLSIZE     = 9;
   local OAM_OFF         = 9;
   local OAM_MODE_LO     = 10;
   local OAM_MOSAIC      = 12;
   local OAM_HICOLOR     = 13;
   local OAM_OBJSHAPE_LO = 14;
   
   local atr0 = 0
   atr0 = atr0 + obj.y       * 2^OAM_Y_LO
   atr0 = atr0 + obj.affine  * 2^OAM_AFFINE
   atr0 = atr0 + obj.dblsize * 2^OAM_DBLSIZE
   atr0 = atr0 + obj.off     * 2^OAM_OFF
   atr0 = atr0 + obj.mode    * 2^OAM_MODE_LO
   atr0 = atr0 + obj.mosaic  * 2^OAM_MOSAIC
   atr0 = atr0 + obj.hicolor * 2^OAM_HICOLOR
   atr0 = atr0 + obj.shape   * 2^OAM_OBJSHAPE_LO
                           
   -- Atr1                 
   local OAM_X_LO        = 0;
   local OAM_AFF_LO      = 9;
   local OAM_HFLIP       = 12;
   local OAM_VFLIP       = 13;
   local OAM_OBJSIZE_LO  = 14;
   
   local atr1 = 0
   atr1 = atr1 + obj.x        * 2^OAM_X_LO
   atr1 = atr1 + obj.affindex * 2^OAM_AFF_LO
   atr1 = atr1 + obj.hflip    * 2^OAM_HFLIP
   atr1 = atr1 + obj.vlip     * 2^OAM_VFLIP
   atr1 = atr1 + obj.objsize  * 2^OAM_OBJSIZE_LO
                           
   -- Atr2                 
   local OAM_TILE_LO     = 0;
   local OAM_PRIO_LO     = 10;
   local OAM_PALETTE_LO  = 12;
   
   local atr2 = 0
   atr2 = atr2 + obj.tile    * 2^OAM_TILE_LO
   atr2 = atr2 + obj.prio    * 2^OAM_PRIO_LO
   atr2 = atr2 + obj.palette * 2^OAM_PALETTE_LO

   write_gbbus_16bit(atr0, 0x07000000 + index * 8)
   write_gbbus_16bit(atr1, 0x07000000 + index * 8 + 2)
   write_gbbus_16bit(atr2, 0x07000000 + index * 8 + 4)
      
end


function write_affine_set(index, dx, dmx, dy, dmy)

   write_gbbus_16bit(dx,  0x07000000 + index * 32 + 6)
   write_gbbus_16bit(dmx, 0x07000000 + index * 32 + 14)
   write_gbbus_16bit(dy,  0x07000000 + index * 32 + 22)
   write_gbbus_16bit(dmy, 0x07000000 + index * 32 + 30)

end

