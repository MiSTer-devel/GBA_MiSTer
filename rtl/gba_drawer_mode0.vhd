library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   

entity gba_drawer_mode0 is
   port 
   (
      clk                  : in  std_logic;                     
                           
      drawline             : in  std_logic;
      busy                 : out std_logic := '0';
      
      ypos                 : in  integer range 0 to 159;
      ypos_mosaic          : in  integer range 0 to 159;
      mapbase              : in  unsigned(4 downto 0);
      tilebase             : in  unsigned(1 downto 0);
      hicolor              : in  std_logic;
      mosaic               : in  std_logic;
      Mosaic_H_Size        : in  unsigned(3 downto 0);
      screensize           : in  unsigned(1 downto 0);
      scrollX              : in  unsigned(8 downto 0);
      scrollY              : in  unsigned(8 downto 0);
      
      pixel_we             : out std_logic := '0';
      pixeldata            : buffer std_logic_vector(15 downto 0) := (others => '0');
      pixel_x              : out integer range 0 to 239;
      
      PALETTE_Drawer_addr  : out integer range 0 to 127;
      PALETTE_Drawer_data  : in  std_logic_vector(31 downto 0);
      PALETTE_Drawer_valid : in  std_logic;
      
      VRAM_Drawer_addr     : out integer range 0 to 16383;
      VRAM_Drawer_data     : in  std_logic_vector(31 downto 0);
      VRAM_Drawer_valid    : in  std_logic
   );
end entity;

architecture arch of gba_drawer_mode0 is
   
   type tVRAMState is
   (
      IDLE,
      CALCBASE,
      CALCADDR,
      WAITREAD_TILE,
      CALCCOLORADDR,
      WAITREAD_COLOR
   );
   signal vramfetch    : tVRAMState := IDLE;
   
   type tPALETTEState is
   (
      IDLE,
      WAITREAD
   );
   signal palettefetch : tPALETTEState := IDLE;
  
   signal VRAM_byteaddr        : unsigned(16 downto 0) := (others => '0'); 
   signal vram_readwait        : integer range 0 to 1;
                               
   signal PALETTE_byteaddr     : std_logic_vector(8 downto 0) := (others => '0');
   signal PALETTE_byteaddr_1   : std_logic_vector(8 downto 0) := (others => '0');
                               
   signal mapbaseaddr          : integer;
   signal tilebaseaddr         : integer;
                                 
   signal x_cnt                : integer range 0 to 239;
   signal y_scrolled           : integer range 0 to 1023; 
   signal offset_y             : integer range 0 to 1023; 
   signal scroll_x_mod         : integer range 256 to 512; 
   signal scroll_y_mod         : integer range 256 to 512; 
                               
   signal x_flip_offset        : integer range 3 to 7;
   signal x_div                : integer range 1 to 2;
                              
   signal x_scrolled           : unsigned(8 downto 0) := (others => '0');
   signal tileindex            : integer range 0 to 4095;
                               
   signal tileinfo             : std_logic_vector(15 downto 0) := (others => '0');
   signal pixeladdr_base       : integer range 0 to 524287;
                               
   signal colordata            : std_logic_vector(7 downto 0) := (others => '0');
   signal VRAM_lastcolor_addr  : unsigned(14 downto 0) := (others => '0');
   signal VRAM_lastcolor_data  : std_logic_vector(31 downto 0) := (others => '0');
   signal VRAM_lastcolor_valid : std_logic := '0';
   
   signal palette_newPixel     : std_logic := '0';
   signal palette_x_cnt        : integer range 0 to 239;
   signal palette_selecthigh   : std_logic := '0';
   signal mosaik_cnt           : integer range 0 to 15 := 0;
   
begin 

   mapbaseaddr  <= to_integer(mapbase) * 2048;
   tilebaseaddr <= to_integer(tilebase) * 16#4000#;
   
   x_scrolled <= to_unsigned((x_cnt + to_integer(scrollX)) mod scroll_x_mod, 9);
   
   VRAM_Drawer_addr <= to_integer(VRAM_byteaddr(15 downto 2));
   PALETTE_Drawer_addr <= to_integer(unsigned(PALETTE_byteaddr(8 downto 2)));
  
   -- vramfetch
   process (clk)
    variable tileindex_var   : integer range 0 to 4095;
    variable tileaddr_var    : integer range 0 to 4095;
    variable pixeladdr       : integer range 0 to 524287;
    variable done_var        : std_logic;
   begin
      if rising_edge(clk) then
      
         palette_newPixel <= '0';
      
         case (vramfetch) is
         
            when IDLE =>
               if (drawline = '1') then
                  busy            <= '1';
                  vramfetch       <= CALCBASE;
                  if (mosaic = '1') then
                     y_scrolled <= ypos_mosaic + to_integer(scrollY);
                  else
                     y_scrolled <= ypos + to_integer(scrollY);
                  end if;
                  scroll_x_mod <= 256;
                  scroll_y_mod <= 256;
                  case (to_integer(screensize)) is
                     when 1 => scroll_x_mod <= 512;
                     when 2 => scroll_y_mod <= 512; 
                     when 3 => scroll_x_mod <= 512; scroll_y_mod <= 512;
                     when others => null;
                  end case;
                  x_cnt     <= 0;
                  VRAM_lastcolor_valid <= '0'; -- invalidate fetch cache
               elsif (palettefetch = IDLE) then
                  busy         <= '0';
               end if;
               
            when CALCBASE =>
               vramfetch  <= CALCADDR;
               y_scrolled <= y_scrolled mod scroll_y_mod;
               offset_y   <= ((y_scrolled mod 256) / 8) * 32;
               if (hicolor = '0') then
                  --tilemult      <= 32;
                  x_flip_offset <= 3;
                  x_div         <= 2;
                  --x_size        <= 4;
               else
                  --tilemult      <= 64;
                  x_flip_offset <= 7;
                  x_div         <= 1;
                  --x_size        <= 8;
               end if;
   
            when CALCADDR =>
               tileindex_var  := 0;
               if (x_scrolled >= 256 or (y_scrolled >= 256 and to_integer(screensize) = 2)) then
                  tileindex_var  := tileindex_var + 1024;
               end if;
               if (y_scrolled >= 256 and to_integer(screensize) = 3) then
                  tileindex_var := tileindex_var + 2048;
               end if;
               tileaddr_var  := tileindex_var + offset_y + to_integer(x_scrolled(7 downto 3));
               VRAM_byteaddr <= to_unsigned(mapbaseaddr + (tileaddr_var * 2), VRAM_byteaddr'length);
               vramfetch     <= WAITREAD_TILE;
               vram_readwait <= 1;
            
            when WAITREAD_TILE =>
               if (vram_readwait > 0) then
                  vram_readwait <= vram_readwait - 1;
               elsif (VRAM_Drawer_valid = '1') then
                  if (VRAM_byteaddr(1) = '1') then
                     tileinfo <= VRAM_Drawer_data(31 downto 16);
                     if (hicolor = '0') then
                        pixeladdr_base <= tilebaseaddr + to_integer(unsigned(VRAM_Drawer_data(25 downto 16))) * 32;
                     else
                        pixeladdr_base <= tilebaseaddr + to_integer(unsigned(VRAM_Drawer_data(25 downto 16))) * 64;
                     end if;
                  else
                     tileinfo <= VRAM_Drawer_data(15 downto 0);
                     if (hicolor = '0') then
                        pixeladdr_base <= tilebaseaddr + to_integer(unsigned(VRAM_Drawer_data(9 downto 0))) * 32;
                     else
                        pixeladdr_base <= tilebaseaddr + to_integer(unsigned(VRAM_Drawer_data(9 downto 0))) * 64;
                     end if;
                  end if;
                  vramfetch  <= CALCCOLORADDR;
               end if;
                
            when CALCCOLORADDR => 
               vramfetch  <= WAITREAD_COLOR;
               if (tileinfo(10) = '1') then -- hoz flip
                  pixeladdr := pixeladdr_base + (x_flip_offset - (to_integer(x_scrolled(2 downto 0)) / x_div));
               else
                  pixeladdr := pixeladdr_base + to_integer(x_scrolled(2 downto 0)) / x_div;
               end if;
               if (tileinfo(11) = '1') then -- vert flip
                  if (hicolor = '0') then
                     pixeladdr := pixeladdr + ((7 - (y_scrolled mod 8)) * 4);
                  else
                     pixeladdr := pixeladdr + ((7 - (y_scrolled mod 8)) * 8);
                  end if;
               else
                  if (hicolor = '0') then
                     pixeladdr := pixeladdr + (y_scrolled mod 8 * 4);
                  else
                     pixeladdr := pixeladdr + (y_scrolled mod 8 * 8);
                  end if;
               end if;
               VRAM_byteaddr <= to_unsigned(pixeladdr, VRAM_byteaddr'length);
               vramfetch     <= WAITREAD_COLOR;
               vram_readwait <= 1;
               
            when WAITREAD_COLOR =>
               done_var := '0';
               if (VRAM_lastcolor_valid = '1' and VRAM_lastcolor_addr = VRAM_byteaddr(VRAM_byteaddr'left downto 2)) then
                  done_var := '1';
                  case (VRAM_byteaddr(1 downto 0)) is
                     when "00" => colordata <= VRAM_lastcolor_data(7  downto 0);
                     when "01" => colordata <= VRAM_lastcolor_data(15 downto 8);
                     when "10" => colordata <= VRAM_lastcolor_data(23 downto 16);
                     when "11" => colordata <= VRAM_lastcolor_data(31 downto 24);
                     when others => null;
                  end case;
               elsif (vram_readwait > 0) then
                  vram_readwait <= vram_readwait - 1;
               elsif (VRAM_Drawer_valid = '1') then
                  done_var := '1';
                  VRAM_lastcolor_addr  <= VRAM_byteaddr(VRAM_byteaddr'left downto 2);
                  VRAM_lastcolor_data  <= VRAM_Drawer_data;
                  VRAM_lastcolor_valid <= '1';
                  case (VRAM_byteaddr(1 downto 0)) is
                     when "00" => colordata <= VRAM_Drawer_data(7  downto 0);
                     when "01" => colordata <= VRAM_Drawer_data(15 downto 8);
                     when "10" => colordata <= VRAM_Drawer_data(23 downto 16);
                     when "11" => colordata <= VRAM_Drawer_data(31 downto 24);
                     when others => null;
                  end case;
               end if;

               if (done_var = '1') then
                  palette_x_cnt      <= x_cnt;
                  palette_selecthigh <= '0';
                  if ((tileinfo(10) = '1' and (x_scrolled mod 2) = 0) or (tileinfo(10) = '0' and (x_scrolled mod 2) = 1)) then
                     palette_selecthigh <= '1';
                  end if;
                  if (PALETTE_Drawer_valid = '1') then
                     palette_newPixel   <= '1';
                     if (x_cnt < 239) then
                        x_cnt     <= x_cnt + 1;
                        if (x_scrolled(2 downto 0) = "111") then
                           vramfetch <= CALCADDR;
                        else
                           vramfetch <= CALCCOLORADDR;
                        end if;
                     else
                        vramfetch <= IDLE;
                     end if;
                  end if;
               end if;
         
         end case;
      
      end if;
   end process;
   
   -- palette
   PALETTE_byteaddr <= PALETTE_byteaddr_1                                   when (palettefetch = WAITREAD) else
                       colordata & '0'                                      when (hicolor = '1') else 
                       tileinfo(15 downto 12) & colordata(7 downto 4) & '0' when (palette_selecthigh = '1') else
                       tileinfo(15 downto 12) & colordata(3 downto 0) & '0';
   
   
   process (clk)
   begin
      if rising_edge(clk) then
      
         pixel_we      <= '0';
      
         if (drawline = '1') then
            mosaik_cnt    <= 15;  -- first pixel must fetch new data
            pixeldata(15) <= '1';
         end if;
      
         case (palettefetch) is
         
            when IDLE =>
               if (palette_newPixel = '1') then
               
                  pixel_x          <= palette_x_cnt;
               
                  if (mosaik_cnt < Mosaic_H_Size and mosaic = '1') then
                     mosaik_cnt <= mosaik_cnt + 1;
                     pixel_we   <= not pixeldata(15);
                  else
                     mosaik_cnt       <= 0;
                     
                     palettefetch       <= WAITREAD;
                     PALETTE_byteaddr_1 <= PALETTE_byteaddr;
               
                     if (hicolor = '0') then
                        if (palette_selecthigh = '1') then
                           if (colordata(7 downto 4) = x"0") then -- transparent
                              palettefetch  <= IDLE;
                              pixeldata(15) <= '1';
                           end if;
                        else
                           if (colordata(3 downto 0) = x"0") then -- transparent
                              palettefetch  <= IDLE;
                              pixeldata(15) <= '1';
                           end if;
                        end if;
                     else
                        if (colordata = x"00") then -- transparent
                           palettefetch  <= IDLE;
                           pixeldata(15) <= '1';
                        end if;
                     end if;
                  end if;
               end if;
            
            when WAITREAD =>
               if (PALETTE_Drawer_valid = '1') then
                  palettefetch  <= IDLE;
                  pixel_we      <= '1';
                  if (PALETTE_byteaddr_1(1) = '1') then
                     pixeldata <= '0' & PALETTE_Drawer_data(30 downto 16);
                  else
                     pixeldata <= '0' & PALETTE_Drawer_data(14 downto 0);
                  end if;
               end if;

         
         end case;
      
      end if;
   end process;

end architecture;





