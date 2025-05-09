library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   

entity gba_drawer_mode2 is
   generic
   (
      DXYBITS      : integer := 16;
      ACCURACYBITS : integer := 28;
      PIXELCOUNT   : integer := 240
   );
   port 
   (
      clk                  : in  std_logic;                     
                           
      line_trigger         : in  std_logic;
      drawline             : in  std_logic;
      busy                 : out std_logic := '0';
      
      mapbase              : in  unsigned(4 downto 0);
      tilebase             : in  unsigned(1 downto 0);
      screensize           : in  unsigned(1 downto 0);
      wrapping             : in  std_logic;
      mosaic               : in  std_logic;
      Mosaic_H_Size        : in  unsigned(3 downto 0);
      refX                 : in  signed;
      refY                 : in  signed;      
      refX_mosaic          : in  signed(27 downto 0);
      refY_mosaic          : in  signed(27 downto 0);
      dx                   : in  signed(DXYBITS - 1 downto 0);
      dy                   : in  signed(DXYBITS - 1 downto 0);
      
      pixel_we             : out std_logic := '0';
      pixeldata            : buffer std_logic_vector(15 downto 0) := (others => '0');
      pixel_x              : out integer range 0 to (PIXELCOUNT - 1);
      
      PALETTE_Drawer_addr  : out integer range 0 to 127;
      PALETTE_Drawer_data  : in  std_logic_vector(31 downto 0);
      PALETTE_Drawer_valid : in  std_logic;
      
      VRAM_Drawer_addr     : out integer range 0 to 16383;
      VRAM_Drawer_data     : in  std_logic_vector(31 downto 0);
      VRAM_Drawer_valid    : in  std_logic
   );
end entity;

architecture arch of gba_drawer_mode2 is
   
   type tVRAMState is
   (
      IDLE,
      CALCADDR,
      WAITREAD_TILE,
      EVALTILE,
      WAITREAD_COLOR
   );
   signal vramfetch    : tVRAMState := IDLE;
   
   type tPALETTEState is
   (
      IDLE,
      STARTREAD,
      WAITREAD
   );
   signal palettefetch : tPALETTEState := IDLE;
  
   signal VRAM_byteaddr        : unsigned(16 downto 0) := (others => '0'); 
   signal VRAM_byteaddr_low    : unsigned(1 downto 0) := (others => '0'); 
   signal VRAM_lasttile_addr   : unsigned(14 downto 0) := (others => '0');
   signal VRAM_lasttile_data   : std_logic_vector(31 downto 0) := (others => '0');
   signal VRAM_lasttile_valid  : std_logic := '0';
                               
   signal PALETTE_byteaddr     : std_logic_vector(8 downto 0) := (others => '0');
   signal palette_readwait     : integer range 0 to 1;
                               
   signal mapbaseaddr          : integer;
                               
   signal realX                : signed(ACCURACYBITS - 1 downto 0);
   signal realY                : signed(ACCURACYBITS - 1 downto 0);
   signal xxx                  : signed(19 downto 0);
   signal yyy                  : signed(19 downto 0);
   signal xxx_pre              : signed(19 downto 0);
   signal yyy_pre              : signed(19 downto 0);
                               
   signal tileindex            : integer range -524288 to 524287;
                               
   signal x_cnt                : integer range 0 to (PIXELCOUNT - 1);
   signal scroll_mod           : integer range 128 to 1024; 
   signal tileinfo             : std_logic_vector(7 downto 0) := (others => '0');
                               
   signal colordata            : std_logic_vector(7 downto 0) := (others => '0');
      
   signal mosaik_cnt           : integer range 0 to 15 := 0;
   
begin 

   mapbaseaddr  <= to_integer(mapbase) * 2048;
   
   VRAM_Drawer_addr <= to_integer(VRAM_byteaddr(15 downto 2));
   PALETTE_Drawer_addr <= to_integer(unsigned(PALETTE_byteaddr(8 downto 2)));
  
   xxx_pre <= realX(realX'left downto realX'left  - 19);
   yyy_pre <= realY(realY'left downto realY'left  - 19);
   
   xxx     <= xxx_pre          when (wrapping = '0') else
              xxx_pre mod 128  when (screensize = "00") else 
              xxx_pre mod 256  when (screensize = "01") else 
              xxx_pre mod 512  when (screensize = "10") else 
              xxx_pre mod 1024; 
              
   yyy     <= yyy_pre          when (wrapping = '0') else
              yyy_pre mod 128  when (screensize = "00") else 
              yyy_pre mod 256  when (screensize = "01") else 
              yyy_pre mod 512  when (screensize = "10") else 
              yyy_pre mod 1024; 
              
              
   tileindex <= to_integer((xxx / 8) + shift_left(shift_right(yyy, 3), 4)) when (screensize = "00") else 
                to_integer((xxx / 8) + shift_left(shift_right(yyy, 3), 5)) when (screensize = "01") else 
                to_integer((xxx / 8) + shift_left(shift_right(yyy, 3), 6)) when (screensize = "10") else 
                to_integer((xxx / 8) + shift_left(shift_right(yyy, 3), 7));
   
   VRAM_byteaddr <= to_unsigned(mapbaseaddr + tileindex, VRAM_byteaddr'length) when (vramfetch = CALCADDR) else
                    '0' & tilebase & unsigned(tileinfo) & unsigned(yyy(2 downto 0)) & unsigned(xxx(2 downto 0));
                    
   
   -- vramfetch
   process (clk)
    variable pixeladdr      : integer range 0 to 524287;
   begin
      if rising_edge(clk) then
      
         case (vramfetch) is
         
            when IDLE =>
               if (line_trigger = '1') then
                  realX <= (others => '0');
                  realY <= (others => '0');
                  if (mosaic = '1' and unsigned(Mosaic_H_Size) > 0) then
                     realX(realX'left downto realX'left - refX_mosaic'length + 1) <= refX_mosaic;
                     realY(realY'left downto realY'left - refY_mosaic'length + 1) <= refY_mosaic;
                  else
                     realX(realX'left downto realX'left - refX'length + 1) <= refX;
                     realY(realY'left downto realY'left - refY'length + 1) <= refY;
                  end if;
               elsif (drawline = '1') then
                  busy         <= '1';
                  vramfetch    <= CALCADDR;
                  case (to_integer(screensize)) is
                     when 0 => scroll_mod <= 128; 
                     when 1 => scroll_mod <= 256; 
                     when 2 => scroll_mod <= 512; 
                     when 3 => scroll_mod <= 1024;
                     when others => null;
                  end case;
                  x_cnt     <= 0;
               elsif (palettefetch = IDLE) then
                  busy         <= '0';
               end if;
               
            when CALCADDR =>
               if (VRAM_Drawer_valid = '0') then
                  --VRAM_byteaddr <= to_unsigned(mapbaseaddr + tileindex, VRAM_byteaddr'length);
                  VRAM_byteaddr_low <= VRAM_byteaddr(1 downto 0);
                  vramfetch     <= WAITREAD_TILE;
               
                  if (wrapping = '0') then
                     if (xxx_pre < 0 or yyy_pre < 0 or xxx_pre >= scroll_mod or yyy_pre >= scroll_mod) then
                        realX <= realX + dx;
                        realY <= realy + dy;
                        if (x_cnt < (PIXELCOUNT - 1)) then
                           vramfetch <= CALCADDR;
                           x_cnt     <= x_cnt + 1;
                        else
                           vramfetch <= IDLE;
                        end if;
                     end if;
                  end if;
               end if;
            
            when WAITREAD_TILE =>
               case (to_integer(VRAM_byteaddr_low(1 downto 0))) is
                  when 0 => tileinfo <= VRAM_Drawer_data( 7 downto  0);
                  when 1 => tileinfo <= VRAM_Drawer_data(15 downto  8);
                  when 2 => tileinfo <= VRAM_Drawer_data(23 downto 16);
                  when 3 => tileinfo <= VRAM_Drawer_data(31 downto 24);
                  when others => null;
               end case;
               vramfetch  <= EVALTILE;
               
            when EVALTILE =>
               vramfetch  <= WAITREAD_COLOR;
               --VRAM_byteaddr <= '0' & tilebase & unsigned(tileinfo) & unsigned(yyy(2 downto 0)) & unsigned(xxx(2 downto 0));
               VRAM_byteaddr_low <= VRAM_byteaddr(1 downto 0);
               vramfetch     <= WAITREAD_COLOR;
               
            when WAITREAD_COLOR =>
               realX <= realX + dx;
               realY <= realy + dy;
               if (x_cnt < (PIXELCOUNT - 1)) then
                  vramfetch <= CALCADDR;
                  x_cnt     <= x_cnt + 1;
               else
                  vramfetch <= IDLE;
               end if;
         
         end case;
      
      end if;
   end process;
   
   colordata <= VRAM_Drawer_data(7  downto 0)  when (VRAM_byteaddr_low = "00") else
                VRAM_Drawer_data(15 downto 8)  when (VRAM_byteaddr_low = "01") else
                VRAM_Drawer_data(23 downto 16) when (VRAM_byteaddr_low = "10") else
                VRAM_Drawer_data(31 downto 24);
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         pixel_we      <= '0';
         
         if (drawline = '1') then
            mosaik_cnt    <= 15; -- first pixel must fetch new data
            pixeldata(15) <= '1';
         end if;
      
         case (palettefetch) is
         
            when IDLE =>
               if (vramfetch = WAITREAD_COLOR) then
               
                  pixel_x          <= x_cnt;
               
                  if (mosaik_cnt < Mosaic_H_Size and mosaic = '1') then
                     mosaik_cnt <= mosaik_cnt + 1;
                     pixel_we   <= not pixeldata(15);
                     
                  else
                     mosaik_cnt       <= 0;
                     
                     palettefetch     <= STARTREAD; 
                     PALETTE_byteaddr <= colordata & '0';
                     if (colordata = x"00") then -- transparent
                        palettefetch  <= IDLE;
                        pixeldata(15) <= '1';
                     end if;
                  end if;
               end if;
               
            when STARTREAD => 
               palettefetch     <= WAITREAD;
               palette_readwait <= 1;
            
            when WAITREAD =>
               if (palette_readwait > 0) then
                  palette_readwait <= palette_readwait - 1;
               elsif (PALETTE_Drawer_valid = '1') then
                  palettefetch  <= IDLE;
                  pixel_we      <= '1';
                  if (PALETTE_byteaddr(1) = '1') then
                     pixeldata <= '0' & PALETTE_Drawer_data(30 downto 16);
                  else
                     pixeldata <= '0' & PALETTE_Drawer_data(14 downto 0);
                  end if;
               end if;

         
         end case;
      
      end if;
   end process;

end architecture;





