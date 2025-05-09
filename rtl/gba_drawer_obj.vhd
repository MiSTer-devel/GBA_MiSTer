library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   

entity gba_drawer_obj is
   generic
   (
      RESMULT      : integer := 1;
      PIXELCOUNT   : integer := 240
   );
   port 
   (
      clk                  : in  std_logic;                     
          
      drawline             : in  std_logic;
      ypos                 : in  integer range 0 to 159;
      ypos_mosaic          : in  integer range 0 to 159;
      
      BG_Mode              : in  std_logic_vector(2 downto 0);
      one_dim_mapping      : in  std_logic;
      Mosaic_H_Size        : in  unsigned(3 downto 0);
      
      hblankfree           : in  std_logic;
      
      pixel_we_color       : out std_logic := '0';
      pixeldata_color      : out std_logic_vector(15 downto 0) := (others => '0');
      pixel_we_settings    : out std_logic := '0';
      pixeldata_settings   : out std_logic_vector(2 downto 0) := (others => '0');
      pixel_x              : out integer range 0 to (PIXELCOUNT - 1);
      pixel_objwnd         : out std_logic := '0';
      
      OAMRAM_Drawer_addr   : buffer integer range 0 to 255;
      OAMRAM_Drawer_data   : in  std_logic_vector(31 downto 0);
      
      PALETTE_Drawer_addr  : out integer range 0 to 127;
      PALETTE_Drawer_data  : in  std_logic_vector(31 downto 0);
      
      VRAM_Drawer_addr     : out integer range 0 to 8191;
      VRAM_Drawer_data     : in  std_logic_vector(31 downto 0);
      VRAM_Drawer_valid    : in  std_logic
   );
end entity;

architecture arch of gba_drawer_obj is
   
   constant RESMULTACCDIV : integer := 256 * RESMULT;
   
   -- Atr0
   constant OAM_Y_HI         : integer := 7;
   constant OAM_Y_LO         : integer := 0;
   constant OAM_AFFINE       : integer := 8;
   constant OAM_DBLSIZE      : integer := 9;
   constant OAM_OFF_HI       : integer := 9;
   constant OAM_OFF_LO       : integer := 8;
   constant OAM_MODE_HI      : integer := 11;
   constant OAM_MODE_LO      : integer := 10;
   constant OAM_MOSAIC       : integer := 12;
   constant OAM_HICOLOR      : integer := 13;
   constant OAM_OBJSHAPE_HI  : integer := 15;
   constant OAM_OBJSHAPE_LO  : integer := 14;
                        
   -- Atr1      
   constant OAM_X_HI         : integer := 8;
   constant OAM_X_LO         : integer := 0;
   constant OAM_AFF_HI       : integer := 13;
   constant OAM_AFF_LO       : integer := 9;
   constant OAM_HFLIP        : integer := 12;
   constant OAM_VFLIP        : integer := 13;
   constant OAM_OBJSIZE_HI   : integer := 15;
   constant OAM_OBJSIZE_LO   : integer := 14;
   
   -- Atr2
   constant OAM_TILE_HI      : integer := 9;
   constant OAM_TILE_LO      : integer := 0;
   constant OAM_PRIO_HI      : integer := 11;
   constant OAM_PRIO_LO      : integer := 10;
   constant OAM_PALETTE_HI   : integer := 15;
   constant OAM_PALETTE_LO   : integer := 12;
   
   type t_OAMFetch is
   (
      IDLE,
      READFIRST,
      WAITFIRST,
      READSECOND,
      WAITSECOND,
      READAFFINE0,
      WAITAFFINE0,
      READAFFINE1,
      WAITAFFINE1,
      READAFFINE2,
      WAITAFFINE2,
      READAFFINE3,
      WAITAFFINE3,
      DONE
   );
   signal OAMFetch : t_OAMFetch := IDLE;
   
   signal output_ok : std_logic := '0';
   signal overdraw  : std_logic := '0';
   
   signal OAM_currentobj : integer range 0 to 127;
   
   signal OAM_data0 : std_logic_vector(15 downto 0) := (others => '0');
   signal OAM_data1 : std_logic_vector(15 downto 0) := (others => '0');
   signal OAM_data2 : std_logic_vector(15 downto 0) := (others => '0');
   
   signal OAM_data_aff0 : std_logic_vector(15 downto 0) := (others => '0');
   signal OAM_data_aff1 : std_logic_vector(15 downto 0) := (others => '0');
   signal OAM_data_aff2 : std_logic_vector(15 downto 0) := (others => '0');
   signal OAM_data_aff3 : std_logic_vector(15 downto 0) := (others => '0');
   
   signal OAM_sizeX     : integer range 8 to 64;
   signal OAM_sizeY     : integer range 8 to 64;
   signal OAM_sizeX2    : integer range 8 to 128;
   signal OAM_sizeY2    : integer range 8 to 128;
   signal OAM_posy      : integer range -256 to 255;
   signal OAM_posyMos   : integer range -512 to 511;
   
   signal OAMfetch_sizeX         : integer range 8 to 64;
   signal OAMfetch_sizeY         : integer range 8 to 64;
   signal OAMfetch_fieldX        : integer range 8 to 128;
   signal OAMfetch_fieldY        : integer range 8 to 128;
   signal OAMfetch_ty            : integer range -256 to 255;
   signal OAMfetch_sizemult      : integer range 32 to 512;
   signal OAMfetch_x_flip_offset : integer range 3 to 7;
   signal OAMfetch_y_flip_offset : integer range 28 to 56;
   signal OAMfetch_x_div         : integer range 1 to 2;
   signal OAMfetch_x_size        : integer range 4 to 8;
   signal OAMfetch_addrbase      : integer range 0 to 32767;
   
   type t_PIXELGen is
   (
      WAITOAM,
      NEXTADDR,
      PIXELISSUE
   );
   signal PIXELGen : t_PIXELGen := WAITOAM;
   
   signal Pixel_data0       : std_logic_vector(15 downto 0) := (others => '0');
   signal Pixel_data1       : std_logic_vector(15 downto 0) := (others => '0');
   signal Pixel_data2       : std_logic_vector(15 downto 0) := (others => '0');
   signal dx                : integer range -32768 to 32767;
   signal dy                : integer range -32768 to 32767;
       
   signal posx              : integer range -512 to 511;
   signal sizeX             : integer range 8 to 64;
   signal sizeY             : integer range 8 to 64;
   signal fieldX            : integer range 8 to 128;
   signal pixeladdr_base    : integer range 0 to 32767;
   signal pixeladdr         : integer range -32768 to 32767;
       
   signal sizemult          : integer range 32 to 512;
       
   signal x_flip_offset     : integer range 3 to 7;
   signal x_div             : integer range 1 to 2;
   signal x_size            : integer range 4 to 8;
       
   signal x                 : integer range 0 to 255;
   signal realX             : integer range -8388608 to 8388607;
   signal realY             : integer range -8388608 to 8388607;
   signal target            : integer range 0 to (PIXELCOUNT - 1);
   signal second_pix        : std_logic := '0';
   signal vram_reuse        : std_logic := '0';
   signal firstpix          : std_logic;
   signal skippixel         : std_logic;
   signal issue_pixel       : std_logic;
   signal pixeladdr_x       : unsigned(14 downto 0) := (others => '0');
   
   signal rescounter        : integer range 0 to RESMULT - 1;
   signal rescounter_current: integer range 0 to RESMULT - 1;
   
   signal pixeladdr_x_aff0  : unsigned(14 downto 0);
   signal pixeladdr_x_aff1  : unsigned(14 downto 0);
   signal pixeladdr_x_aff2  : unsigned(14 downto 0);
   signal pixeladdr_x_aff3  : unsigned(14 downto 0);
   signal pixeladdr_x_aff4  : unsigned(14 downto 0);
   signal pixeladdr_x_aff5  : unsigned(14 downto 0);
   
   -- Pixel Pipeline
   signal PALETTE_byteaddr : std_logic_vector(8 downto 0);
   
   type tpixel is record
      transparent : std_logic;
      prio        : std_logic_vector(1 downto 0);
      alpha       : std_logic;
      objwnd      : std_logic;
   end record;
   
   type t_pixelarray is array(0 to (PIXELCOUNT - 1)) of tpixel;
   signal pixelarray : t_pixelarray;
   
   signal Pixel_wait        : tpixel;
   signal Pixel_readback    : tpixel;
   signal Pixel_merge       : tpixel;
                            
   signal target_eval       : integer range 0 to (PIXELCOUNT - 1);
   signal target_wait       : integer range 0 to (PIXELCOUNT - 1);
   signal target_merge      : integer range 0 to (PIXELCOUNT - 1);    
                            
   signal enable_eval       : std_logic;
   signal enable_wait       : std_logic;
   signal enable_merge      : std_logic;
                            
   signal second_pix_eval   : std_logic;   
   
   signal vram_reuse_eval   : std_logic;
   signal VRAM_data_next    : std_logic_vector(7 downto 0) := (others => '0');
   
   signal zeroread_eval     : std_logic;
                            
   signal readaddr_mux_eval : unsigned(1 downto 0);
   
   signal prio_eval         : std_logic_vector(1 downto 0);
   signal mode_eval         : std_logic_vector(1 downto 0);
   signal hicolor_eval      : std_logic;
   signal affine_eval       : std_logic;
   signal hflip_eval        : std_logic;
   signal palette_eval      : std_logic_vector(3 downto 0);
   signal mosaic_eval       : std_logic;
   signal mosaic_wait       : std_logic;
   
   signal mosaik_cnt        : integer range 0 to 15 := 0;
   signal mosaik_merge      : std_logic;
   
   signal PALETTE_addrlow   : std_logic;
   
   signal pixeltime         : integer range 0 to 1210;
   signal maxpixeltime      : integer range 0 to 1210;
   
begin 

   VRAM_Drawer_addr <= to_integer(pixeladdr_x(14 downto 2));
   PALETTE_Drawer_addr <= to_integer(unsigned(PALETTE_byteaddr(8 downto 2)));

   OAMRAM_Drawer_addr <= (OAM_currentobj * 2) + 1                                                when (OAMFetch = READSECOND) else
                         (to_integer(unsigned(OAM_data1(OAM_AFF_HI downto OAM_AFF_LO))) * 8) + 1 when (OAMFetch = READAFFINE0) else 
                         (to_integer(unsigned(OAM_data1(OAM_AFF_HI downto OAM_AFF_LO))) * 8) + 3 when (OAMFetch = READAFFINE1) else 
                         (to_integer(unsigned(OAM_data1(OAM_AFF_HI downto OAM_AFF_LO))) * 8) + 5 when (OAMFetch = READAFFINE2) else 
                         (to_integer(unsigned(OAM_data1(OAM_AFF_HI downto OAM_AFF_LO))) * 8) + 7 when (OAMFetch = READAFFINE3) else 
                         OAM_currentobj * 2; -- READFIRST or IDLE

   OAM_sizeX <=  8 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "00" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "00") else -- square size 0
                16 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "00" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "01") else -- square size 1
                32 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "00" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "10") else -- square size 2
                64 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "00" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "11") else -- square size 3
                16 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "01" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "00") else -- Hor size 0
                32 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "01" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "01") else -- Hor size 1
                32 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "01" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "10") else -- Hor size 2
                64 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "01" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "11") else -- Hor size 3
                 8 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "10" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "00") else -- Vert size 0
                 8 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "10" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "01") else -- Vert size 1
                16 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "10" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "10") else -- Vert size 2
                32 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "10" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "11") else -- Vert size 3
                 8;

   OAM_sizeY <=  8 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "00" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "00") else -- square size 0
                16 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "00" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "01") else -- square size 1
                32 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "00" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "10") else -- square size 2
                64 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "00" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "11") else -- square size 3
                 8 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "01" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "00") else -- Hor size 0
                 8 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "01" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "01") else -- Hor size 1
                16 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "01" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "10") else -- Hor size 2
                32 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "01" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "11") else -- Hor size 3
                16 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "10" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "00") else -- Vert size 0
                32 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "10" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "01") else -- Vert size 1
                32 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "10" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "10") else -- Vert size 2
                64 when (OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "10" and OAMRAM_Drawer_data(16 + OAM_OBJSIZE_HI downto 16 + OAM_OBJSIZE_LO) = "11") else -- Vert size 3
                 8;
                 
   OAM_sizeX2 <= 2 * OAM_sizeX when (OAMRAM_Drawer_data(OAM_AFFINE) = '1' and OAMRAM_Drawer_data(OAM_DBLSIZE) = '1') else OAM_sizeX;
   OAM_sizeY2 <= 2 * OAM_sizeY when (OAMRAM_Drawer_data(OAM_AFFINE) = '1' and OAMRAM_Drawer_data(OAM_DBLSIZE) = '1') else OAM_sizeY;

   OAM_posy <= to_integer(unsigned(OAMRAM_Drawer_data(OAM_Y_HI downto OAM_Y_LO))) - 16#100# when (to_integer(unsigned(OAMRAM_Drawer_data(OAM_Y_HI downto OAM_Y_LO))) > (16#100# - OAM_sizeY2)) else
               to_integer(unsigned(OAMRAM_Drawer_data(OAM_Y_HI downto OAM_Y_LO)));

   OAM_posyMos <= ypos_mosaic - OAM_posy when (OAMRAM_Drawer_data(OAM_MOSAIC) = '1') else ypos - OAM_posy;


   -- OAM Fetch
   process (clk)
   begin
      if rising_edge(clk) then
      
         if (hblankfree = '1') then
            maxpixeltime <= 954;
         else
            maxpixeltime <= 1210;
         end if;

         case (OAMFetch) is
         
            when IDLE =>
               OAM_currentobj     <= 0;
               if (drawline = '1') then
                  OAMFetch           <= WAITFIRST;
                  output_ok          <= '1';
                  overdraw           <= '0';
               end if;
            
            when READFIRST =>
               OAMFetch           <= WAITFIRST;
            
            when WAITFIRST =>
               OAM_data0 <= OAMRAM_Drawer_data(15 downto 0);
               OAM_data1 <= OAMRAM_Drawer_data(31 downto 16);
               OAMFetch  <= READSECOND;
               
               OAMfetch_sizeX    <= OAM_sizeX;
               OAMfetch_sizeY    <= OAM_sizeY;
               OAMfetch_fieldX   <= OAM_sizeX2;
               OAMfetch_fieldY   <= OAM_sizeY2;
               
               if (OAMRAM_Drawer_data(OAM_HICOLOR) = '0') then
                  OAMfetch_sizemult <= OAM_sizeX * 4;
               else
                  OAMfetch_sizemult <= OAM_sizeX * 8;
               end if;
               
               if (OAMRAM_Drawer_data(OAM_HICOLOR) = '0') then
                  OAMfetch_x_flip_offset <= 3;
                  OAMfetch_y_flip_offset <= 28;
                  OAMfetch_x_div         <= 2;
                  OAMfetch_x_size        <= 4;
               else
                  OAMfetch_x_flip_offset <= 7;
                  OAMfetch_y_flip_offset <= 56;
                  OAMfetch_x_div         <= 1;
                  OAMfetch_x_size        <= 8;
               end if;
               
               if (OAM_posyMos < 0 or OAM_posyMos >= OAM_sizeY2 or OAMRAM_Drawer_data(OAM_OFF_HI downto OAM_OFF_LO) = "10" or OAMRAM_Drawer_data(OAM_OBJSHAPE_HI downto OAM_OBJSHAPE_LO) = "11") then
                  if (OAM_currentobj = 127) then
                     OAMFetch      <= IDLE;
                  else
                     OAMFetch       <= READFIRST;
                     OAM_currentobj <= OAM_currentobj + 1; 
                  end if;
               else
                  OAMFetch    <= READSECOND;
                  OAMfetch_ty <= OAM_posyMos;
               end if;
               
            when READSECOND =>
               OAMFetch <= WAITSECOND;
            
            when WAITSECOND =>
               OAM_data2 <= OAMRAM_Drawer_data(15 downto 0);
               if (OAM_data0(OAM_AFFINE) = '1') then
                  OAMFetch           <= READAFFINE0;
               else
                  OAMFetch           <= DONE;
               end if;
               
            if (OAM_data0(OAM_HICOLOR) = '1' and one_dim_mapping = '0') then
               OAMfetch_addrbase <= 32 * to_integer(unsigned(OAMRAM_Drawer_data(OAM_TILE_HI downto OAM_TILE_LO+1) & '0'));
            else 
               OAMfetch_addrbase <= 32 * to_integer(unsigned(OAMRAM_Drawer_data(OAM_TILE_HI downto OAM_TILE_LO)));
            end if;
               
               
            when READAFFINE0 => OAMFetch <= WAITAFFINE0;
            when WAITAFFINE0 => OAMFetch <= READAFFINE1; OAM_data_aff0 <= OAMRAM_Drawer_data(31 downto 16);
            when READAFFINE1 => OAMFetch <= WAITAFFINE1;
            when WAITAFFINE1 => OAMFetch <= READAFFINE2; OAM_data_aff1 <= OAMRAM_Drawer_data(31 downto 16);
            when READAFFINE2 => OAMFetch <= WAITAFFINE2;
            when WAITAFFINE2 => OAMFetch <= READAFFINE3; OAM_data_aff2 <= OAMRAM_Drawer_data(31 downto 16);
            when READAFFINE3 => OAMFetch <= WAITAFFINE3;
            when WAITAFFINE3 => OAMFetch <= DONE;        OAM_data_aff3 <= OAMRAM_Drawer_data(31 downto 16);
               
            when DONE =>
               if (PIXELGen = WAITOAM) then
                  if (OAM_currentobj = 127) then
                     OAMFetch      <= IDLE;
                  else
                     OAMFetch           <= READFIRST;
                     OAM_currentobj     <= OAM_currentobj + 1;
                  end if;
               end if;
         
         end case;
         
         if (pixeltime >= maxpixeltime and OAMFetch /= IDLE) then
            OAMFetch <= IDLE;
            overdraw <= '1';
         end if;
      
      end if;
   end process;
   
   -- Pixelgen
   process (clk)
      variable pixeladdr_pre_a0  : integer range -8388608 to 8388607; -- 24 bit
      variable pixeladdr_pre_a1  : integer range -8388608 to 8388607;
      variable pixeladdr_pre_a2  : integer range -8388608 to 8388607;
      variable pixeladdr_pre_a3  : integer range -8388608 to 8388607;
      variable pixeladdr_pre_a4  : integer range -8388608 to 8388607;
      variable pixeladdr_pre_a5  : integer range -8388608 to 8388607;
      variable pixeladdr_pre_a6  : integer range -8388608 to 8388607;
      variable pixeladdr_pre_a7  : integer range -8388608 to 8388607;
      variable pixeladdr_pre_0   : integer range -32768 to 32767;
      variable pixeladdr_pre_1   : integer range -32768 to 32767;
      variable pixeladdr_pre_2   : integer range -32768 to 32767;
      variable pixeladdr_pre_3   : integer range -32768 to 32767;
      variable pixeladdr_pre_4   : integer range -32768 to 32767;
      variable pixeladdr_pre_5   : integer range -32768 to 32767;
      variable pixeladdr_pre_6   : integer range -32768 to 32767;
      variable pixeladdr_pre_7   : integer range -32768 to 32767;
      variable xxx               : integer range 0 to 63;
      variable yyy               : integer range 0 to 63;
      variable pixeladdr_calc    : integer;
   begin
      if rising_edge(clk) then

         issue_pixel <= '0';
         
         if (drawline = '1') then
            pixeltime <= 0;
         elsif (pixeltime < maxpixeltime) then
            pixeltime <= pixeltime + 1;
         end if;

         case (PIXELGen) is
         
            when WAITOAM =>
               rescounter <= 0;
               x          <= 0;
               firstpix   <= '1';
               if (OAMFetch = DONE) then
                  PIXELGen        <= NEXTADDR;
               
                  Pixel_data0     <= OAM_data0;    
                  Pixel_data1     <= OAM_data1;    
                  Pixel_data2     <= OAM_data2;    
                  dx              <= to_integer(signed(OAM_data_aff0));
                  --dmx             <= to_integer(signed(OAM_data_aff1));
                  dy              <= to_integer(signed(OAM_data_aff2));
                  --dmy             <= to_integer(signed(OAM_data_aff3));
   
                  if (unsigned(OAM_data1(OAM_X_HI downto OAM_X_LO)) > 16#100#) then 
                     posx <= to_integer(unsigned(OAM_data1(OAM_X_HI downto OAM_X_LO))) - 16#200#; 
                  else
                     posx <= to_integer(unsigned(OAM_data1(OAM_X_HI downto OAM_X_LO)));
                  end if;
                  
                  sizeX  <= OAMfetch_sizeX;
                  sizeY  <= OAMfetch_sizeY;
                  fieldX <= OAMfetch_fieldX;
                  
                  sizemult      <= OAMfetch_sizemult;
                  x_flip_offset <= OAMfetch_x_flip_offset;
                  x_div         <= OAMfetch_x_div;         
                  x_size        <= OAMfetch_x_size;        
   
                  pixeladdr_base <= OAMfetch_addrbase;
   
                  -- affine
                  pixeladdr_pre_a0 := OAMfetch_sizeX * 128;
                  pixeladdr_pre_a1 := (OAMfetch_fieldX / 2) * to_integer(signed(OAM_data_aff0));
                  pixeladdr_pre_a2 := (OAMfetch_fieldY / 2) * to_integer(signed(OAM_data_aff1));
                  pixeladdr_pre_a3 := OAMfetch_ty * to_integer(signed(OAM_data_aff1));
                  pixeladdr_pre_a4 := OAMfetch_sizeY * 128;
                  pixeladdr_pre_a5 := (OAMfetch_fieldX / 2) * to_integer(signed(OAM_data_aff2));
                  pixeladdr_pre_a6 := (OAMfetch_fieldY / 2) * to_integer(signed(OAM_data_aff3));
                  pixeladdr_pre_a7 := OAMfetch_ty * to_integer(signed(OAM_data_aff3));
                              
                  -- non affine
                  pixeladdr_pre_0 := (OAMfetch_y_flip_offset - (OAMfetch_ty mod 8) * OAMfetch_x_size);
                  pixeladdr_pre_1 := ((((OAMfetch_sizeY / 8) - 1) - (OAMfetch_ty / 8)) * OAMfetch_sizemult);
                  pixeladdr_pre_2 := (OAMfetch_y_flip_offset - (OAMfetch_ty mod 8) * OAMfetch_x_size);
                  pixeladdr_pre_3 := ((((OAMfetch_sizeY / 8) - 1) - (OAMfetch_ty / 8)) * 1024);
                  pixeladdr_pre_4 := ((OAMfetch_ty mod 8) * OAMfetch_x_size);
                  pixeladdr_pre_5 := ((OAMfetch_ty / 8) * OAMfetch_sizemult);
                  pixeladdr_pre_6 := ((OAMfetch_ty mod 8) * OAMfetch_x_size);
                  pixeladdr_pre_7 := ((OAMfetch_ty / 8) * 1024);
                  
                  -- affine
                  realX <= (pixeladdr_pre_a0 - pixeladdr_pre_a1 - pixeladdr_pre_a2 + pixeladdr_pre_a3) * resmult;
                  realY <= (pixeladdr_pre_a4 - pixeladdr_pre_a5 - pixeladdr_pre_a6 + pixeladdr_pre_a7) * resmult;
                  
                  -- non affine
                  if (OAM_data1(OAM_VFLIP) = '1') then
                     if (one_dim_mapping = '1') then
                        pixeladdr <= OAMfetch_addrbase + pixeladdr_pre_0 + pixeladdr_pre_1;
                     else
                        pixeladdr <= OAMfetch_addrbase + pixeladdr_pre_2 + pixeladdr_pre_3;
                     end if;
                  else
                     if (one_dim_mapping = '1') then
                        pixeladdr <= OAMfetch_addrbase + pixeladdr_pre_4 + pixeladdr_pre_5;
                     else
                        pixeladdr <= OAMfetch_addrbase + pixeladdr_pre_6 + pixeladdr_pre_7;
                     end if;
                  end if;
               end if;

            when NEXTADDR =>
               firstpix  <= '0';
               skippixel <= '0';
               if ((x + posX) < 240 and (x + posX) >= 0) then
                  target    <= x + posX;
               else
                  skippixel <= '1';
               end if;
               
               pixeladdr_calc := pixeladdr;
               
               vram_reuse <= '0';
               
               if (Pixel_data0(OAM_AFFINE) = '1') then
                  if (realX < 0 or (realX / RESMULTACCDIV) >= sizeX or realY < 0 or (realY / RESMULTACCDIV) >= sizeY) then
                     skippixel <= '1';
                  end if;
               
                  -- synthesis translate_off
                  if (realX >= 0 and (realX / RESMULTACCDIV) < sizeX and realY >= 0 and (realY / RESMULTACCDIV) < sizeY) then
                  -- synthesis translate_on
               
                     xxx := realX / RESMULTACCDIV;
                     yyy := realY / RESMULTACCDIV;
                     if (xxx mod 2 = 1) then second_pix <= '1'; else second_pix <= '0'; end if;
                     
                     pixeladdr_x_aff0 <= to_unsigned(((yyy mod 8) * x_size), 15);
                     pixeladdr_x_aff1 <= to_unsigned(((yyy / 8) * sizemult), 15);

                     pixeladdr_x_aff2 <= to_unsigned(((yyy mod 8) * x_size), 15);
                     pixeladdr_x_aff3 <= to_unsigned(((yyy / 8) * 1024), 15);

                     pixeladdr_x_aff4 <= to_unsigned(((xxx mod 8) / x_div), 15);
                     if (Pixel_data0(OAM_HICOLOR) = '0') then
                        pixeladdr_x_aff5 <= to_unsigned(((xxx / 8) * 32), 15);
                     else
                        pixeladdr_x_aff5 <= to_unsigned(((xxx / 8) * 64), 15);
                     end if;
                     
                  -- synthesis translate_off
                  end if;
                  -- synthesis translate_on   
               else
               
                  if (x mod 2 = 1) then second_pix <= '1'; else second_pix <= '0'; end if;
                  
                  if (Pixel_data1(OAM_HFLIP) = '1') then
                     pixeladdr_calc := pixeladdr_calc + (x_flip_offset - ((x mod 8) / x_div));
                     if (Pixel_data0(OAM_HICOLOR) = '0') then
                        pixeladdr_calc := pixeladdr_calc - (((x / 8) - ((sizeX / 8) - 1)) * 32);
                     else
                        pixeladdr_calc := pixeladdr_calc - (((x / 8) - ((sizeX / 8) - 1)) * 64);
                     end if;
                  else
                     pixeladdr_calc := pixeladdr_calc + ((x mod 8) / x_div);
                     if (Pixel_data0(OAM_HICOLOR) = '0') then
                        pixeladdr_calc := pixeladdr_calc + ((x / 8) * 32);
                     else
                        pixeladdr_calc := pixeladdr_calc + ((x / 8) * 64);
                     end if;
                  end if;
                  
                  pixeladdr_x <= to_unsigned(pixeladdr_calc, 15);
               
               end if;
               
               realX <= realX + dx;
               realY <= realY + dy;
               
               if (pixeltime >= maxpixeltime) then
                  PIXELGen <= WAITOAM;
               elsif (x >= fieldX) then
                  PIXELGen <= WAITOAM;
               else
                  rescounter_current <= rescounter;
                  if (rescounter = RESMULT - 1) then
                     x <= x + 1;
                     rescounter <= 0;
                  else
                     rescounter <= rescounter + 1;
                  end if;
                  PIXELGen <= PIXELISSUE;
                  if (Pixel_data0(OAM_AFFINE) = '0') then
                     if ((pixeladdr_calc = pixeladdr_x and firstpix = '0') or VRAM_Drawer_valid = '1') then
                        if (pixeladdr_calc = pixeladdr_x and firstpix = '0') then
                           vram_reuse  <= '1';
                        end if;
                        PIXELGen    <= NEXTADDR;
                        if ((x + posX) < 240 and (x + posX) >= 0) then
                           issue_pixel <= '1';
                        end if;
                     end if;
                  end if;
               end if;
            
            when PIXELISSUE =>
               if (VRAM_Drawer_valid = '1') then -- sync on vram mux
                  PIXELGen    <= NEXTADDR;
                  
                  issue_pixel <= not skippixel;
                  if (skippixel = '0') then
                  
                     if (Pixel_data0(OAM_AFFINE) = '1') then
                        if (one_dim_mapping = '1') then
                           pixeladdr_x <= pixeladdr_base + pixeladdr_x_aff0 + pixeladdr_x_aff1 + pixeladdr_x_aff4 + pixeladdr_x_aff5;
                        else
                           pixeladdr_x <= pixeladdr_base + pixeladdr_x_aff2 + pixeladdr_x_aff3 + pixeladdr_x_aff4 + pixeladdr_x_aff5;
                        end if;
                     end if;
                     
                  end if;
                  
               end if;
            
         end case;
      
      end if;
   end process;
   
   
   -- Pixel Pipeline
   process (clk)
      variable colorbyte : std_logic_vector(7 downto 0);
      variable colordata : std_logic_vector(3 downto 0);
   begin
      if rising_edge(clk) then
      
         if (drawline = '1') then
            pixelarray <= (others => ('1', "11", '0', '0'));
         end if;
         
         -- first cycle - wait for vram to deliver data
         enable_eval       <= issue_pixel;
         readaddr_mux_eval <= pixeladdr_x(1 downto 0);
         target_eval       <= (target * RESMULT) + rescounter_current;
         second_pix_eval   <= second_pix;
         vram_reuse_eval   <= vram_reuse;
         
         zeroread_eval <= '0';
         if (unsigned(BG_Mode) >= 3 and pixeladdr_x < 16#4000#) then   -- bitmapmode is on and address in the vram area of bitmap
            zeroread_eval <= '1';
         end if;
         
         -- must save those here, as pixeldata will be overwritten in next cycle
         prio_eval       <= Pixel_data2(OAM_PRIO_HI downto OAM_PRIO_LO);
         mode_eval       <= Pixel_data0(OAM_MODE_HI downto OAM_MODE_LO);
         hicolor_eval    <= Pixel_data0(OAM_HICOLOR);
         affine_eval     <= Pixel_data0(OAM_AFFINE);
         hflip_eval      <= Pixel_data1(OAM_HFLIP);
         palette_eval    <= Pixel_data2(OAM_PALETTE_HI downto OAM_PALETTE_LO);
         mosaic_eval     <= Pixel_data0(OAM_MOSAIC);

         -- second cycle - eval vram
         target_wait <= target_eval;
         enable_wait <= enable_eval;
         mosaic_wait <= mosaic_eval;
         
         Pixel_wait.prio        <= prio_eval;
         if (mode_eval= "01") then Pixel_wait.alpha  <= '1'; else Pixel_wait.alpha  <= '0'; end if;
         if (mode_eval = "10") then Pixel_wait.objwnd <= '1'; else Pixel_wait.objwnd <= '0'; end if;
         
         colorbyte := x"00";
         if (zeroread_eval = '0') then
            case (readaddr_mux_eval(1 downto 0)) is
               when "00" => colorbyte := VRAM_Drawer_data(7  downto 0);
               when "01" => colorbyte := VRAM_Drawer_data(15 downto 8);
               when "10" => colorbyte := VRAM_Drawer_data(23 downto 16);
               when "11" => colorbyte := VRAM_Drawer_data(31 downto 24);
               when others => null;
            end case;
         end if;
         
         if (vram_reuse_eval = '1') then
            colorbyte := VRAM_data_next;
         end if;
         
         VRAM_data_next <= colorbyte;
         
         if (enable_eval = '1') then
            if (hicolor_eval = '0') then
               if (affine_eval = '1') then
                  if (second_pix_eval = '1') then
                     colordata := colorbyte(7 downto 4);
                  else
                     colordata := colorbyte(3 downto 0);
                  end if;
               else
                  if ((hflip_eval = '1' and second_pix_eval = '0') or (hflip_eval = '0' and second_pix_eval = '1')) then
                     colordata := colorbyte(7 downto 4);
                  else
                     colordata := colorbyte(3 downto 0);
                  end if;
               end if;
            
               if (colordata = x"0") then Pixel_wait.transparent <= '1'; else Pixel_wait.transparent <= '0'; end if;
            
               PALETTE_byteaddr <= palette_eval & colordata & '0';
            
            else
            
               if (colorbyte = x"00") then Pixel_wait.transparent <= '1'; else Pixel_wait.transparent <= '0'; end if;
            
               PALETTE_byteaddr <= colorbyte & '0';
               
            end if;
         end if;
         
         -- third cycle - wait palette + mosaic
         enable_merge    <= enable_wait;
         target_merge    <= target_wait;
         Pixel_readback  <= pixelarray(target_wait);
         PALETTE_addrlow <= PALETTE_byteaddr(1);
         
         -- reset mosaic for each line and each sprite turning mosaic it off, maybe needs to reset for each new sprite...
         if (drawline = '1' or mosaic_wait = '0') then 
            mosaik_cnt <= 15;
         end if;
         
         mosaik_merge <= '0';
         if (enable_wait = '1') then
            if (mosaik_cnt < Mosaic_H_Size and mosaic_wait = '1') then
               mosaik_cnt   <= mosaik_cnt + 1;
               mosaik_merge <= '1';
            else
               mosaik_cnt  <= 0;
               Pixel_merge <= Pixel_wait;
            end if;
         end if;   
         
         -- fourth cycle
         pixel_we_color    <= '0';
         pixel_we_settings <= '0';
         pixel_objwnd      <= '0';
         pixel_x           <= target_merge;
         
         if (enable_merge = '1' and mosaik_merge = '0') then
            if (PALETTE_addrlow = '1') then
               pixeldata_color <= '0' & PALETTE_Drawer_data(30 downto 16);
            else
               pixeldata_color <= '0' & PALETTE_Drawer_data(14 downto 0);
            end if;
            pixeldata_settings <= Pixel_merge.prio & Pixel_merge.alpha;
         end if;

         if (enable_merge = '1' and output_ok = '1') then

            if (Pixel_merge.transparent = '0' and Pixel_merge.objwnd = '1') then
               pixel_objwnd <= '1';
            end if;
            
            if (Pixel_merge.objwnd = '0') then
               if (Pixel_readback.transparent = '1' or unsigned(Pixel_merge.prio) < unsigned(Pixel_readback.prio)) then
                  pixel_we_settings             <= '1';
                  pixelarray(target_merge).prio <= Pixel_merge.prio;
                  if (Pixel_merge.transparent = '0') then
                     pixel_we_color                       <= '1';
                     pixelarray(target_merge).transparent <= '0';
                  end if;
               end if;
            end if; 
            
         end if;
      
      end if;
   end process;


end architecture;





