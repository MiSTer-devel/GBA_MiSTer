library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;
use work.pProc_bus_gba.all;
use work.pReg_savestates.all;

entity memorymux_extern is
   generic
   (
      is_simu                  : std_logic;
      Softmap_GBA_Gamerom_ADDR : integer; -- count: 8388608  -- 32 Mbyte Data for GameRom   
      Softmap_GBA_FLASH_ADDR   : integer; -- count:  131072  -- 128/512 Kbyte Data for GBA Flash
      Softmap_GBA_EEPROM_ADDR  : integer  -- count:    8192  -- 8/32 Kbyte Data for GBA EEProm
   );
   port 
   (
      clk1x                : in     std_logic; 
      clk6x                : in     std_logic;
      clk6xIndex           : in     unsigned(2 downto 0);
      reset                : in     std_logic;
      
      SramFlashEnable      : in     std_logic;
      
      error_refresh        : out    std_logic := '0';
      flash_busy           : out    std_logic := '0';
      
      savestate_bus        : in     proc_bus_gb_type;
      ss_wired_out         : out    std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      ss_wired_done        : out    std_logic;
      
      cart_ena             : in     std_logic := '0';
      cart_idle            : in     std_logic := '0';
      cart_32              : in     std_logic := '0';
      cart_rnw             : in     std_logic := '0';
      cart_addr            : in     std_logic_vector(27 downto 0) := (others => '0');
      cart_writedata       : in     std_logic_vector(7 downto 0) := (others => '0');
      cart_done            : out    std_logic := '0';
      cart_readdata        : out    std_logic_vector(31 downto 0);
      
      cart_waitcnt         : in     std_logic_vector(15 downto 0);
                                    
      sdram_Din            : out    std_logic_vector(31 downto 0) := (others => '0');
      sdram_Adr            : buffer std_logic_vector(26 downto 0) := (others => '0');
      sdram_rnw            : out    std_logic := '0';                     
      sdram_ena            : out    std_logic := '0';       
      sdram_cancel         : out    std_logic;       
      sdram_refresh        : out    std_logic;              
      sdram_Dout           : in     std_logic_vector(31 downto 0);      
      sdram_done16         : in     std_logic;                     
      sdram_done32         : in     std_logic;                   
      
      specialmodule        : in     std_logic;
      GPIO_readEna         : out    std_logic;
      GPIO_done            : in     std_logic;
      GPIO_Din             : in     std_logic_vector(3 downto 0);
      GPIO_Dout            : out    std_logic_vector(3 downto 0);
      GPIO_writeEna        : out    std_logic := '0';
      GPIO_addr            : out    std_logic_vector(1 downto 0);
      
      dma_eepromcount      : in     unsigned(16 downto 0);
      flash_1m             : in     std_logic;
      MaxPakAddr           : in     std_logic_vector(24 downto 0);
      memory_remap         : in     std_logic;
      
      save_eeprom          : out    std_logic := '0';
      save_sram            : out    std_logic := '0';
      save_flash           : out    std_logic := '0';
      
      tilt                 : in     std_logic;
      AnalogTiltX          : in     signed(7 downto 0);
      AnalogTiltY          : in     signed(7 downto 0)
   );
end entity;

architecture arch of memorymux_extern is
   
   constant busadr_bits   : integer := 27;
   
   type tState1X is
   (
      IDLE1X,
      WAITDATA
   );
   signal state1X : tState1X := IDLE1X;
   
   type tState is
   (
      IDLE,
      WAIT_SDRAM,
      READAFTERPAK,
      READ_GPIO,
      EEPROMREAD,
      EEPROM_WAITREAD,
      EEPROMWRITE,
      FLASHREAD,
      FLASH_WAITREAD,
      FLASHSRAMWRITEDECIDE1,
      FLASHSRAMWRITEDECIDE2,
      SRAMWRITE,
      FLASHWRITE,
      FLASH_WRITEBLOCK,
      FLASH_BLOCKWAIT
   );
   signal state : tState := IDLE;
   
   signal cart_ena_1             : std_logic := '0';
   signal cart_32_1              : std_logic := '0';
   signal cart_idle_1            : std_logic := '0';
   signal cart_rnw_1             : std_logic := '0';
   signal cart_addr_1            : std_logic_vector(27 downto 0) := (others => '0');
   signal cart_writedata_1       : std_logic_vector(7 downto 0) := (others => '0');
   
   signal cart_readdata_6x       : std_logic_vector(31 downto 0) := (others => '0');
   
   signal adr_save               : std_logic_vector(27 downto 0);
   signal Dout_save              : std_logic_vector(7 downto 0) := (others => '0');
   
   type tCacheState is
   (
      CACHE_IDLE,
      WAIT_CACHE16,
      WAIT_CACHE32
   );
   signal cacheState : tCacheState := CACHE_IDLE;
   
   signal cacheEnable            : std_logic:= '0';
   signal cache_valid            : std_logic_vector(0 to 7) := (others => '0');
   type t_cache_data is array(0 to 7) of std_logic_vector(15 downto 0);
   signal cache_data             : t_cache_data := (others => (others => '0'));
   signal cache_next             : unsigned(27 downto 0) := (others => '0');
   signal cachecount             : integer range 0 to 8;
   
   signal cache_index16          : integer range 0 to 7;
   signal cache_index32          : integer range 0 to 7;
   signal cache_hit16            : std_logic;
   signal cache_hit32            : std_logic;
   signal cache_remove           : std_logic := '0';
                                 
   signal refresh_timer          : unsigned(9 downto 0) := (others => '0');
   signal refresh_block_cnt      : integer range 0 to 31  := 0;
   signal refresh_block          : std_logic := '0';
   
   -- EEPROM
   type tEEPROMSTATE is
   (
      EEPROM_IDLE,
      EEPROM_READADDRESS,
      EEPROM_READDATA,
      EEPROM_READDATA2,
      EEPROM_WRITEDATA
   );
   signal eepromMode : tEEPROMSTATE := EEPROM_IDLE;
   signal eepromBuffer  : std_logic_vector(7 downto 0) := (others => '0');
   signal eepromBits    : unsigned(7 downto 0) := (others => '0');
   signal eepromByte    : unsigned(5 downto 0) := (others => '0');
   signal eepromAddress : unsigned(9 downto 0) := (others => '0');
   signal eeprombitpos  : integer range 0 to 7 := 0;
   signal eeprom_rnw    : std_logic;
   
   -- FLASH
   signal flashDeviceID       : std_logic_vector(7 downto 0);
   signal flashManufacturerID : std_logic_vector(7 downto 0);
   
   type tFLASHSTATE is
   (
      FLASH_READ_ARRAY,
      FLASH_CMD_1,
      FLASH_CMD_2,
      FLASH_AUTOSELECT,
      FLASH_CMD_3,
      FLASH_CMD_4,
      FLASH_CMD_5,
      FLASH_ERASE_COMPLETE,
      FLASH_PROGRAM,
      FLASH_SETBANK
   );
   signal flashState      : tFLASHSTATE := FLASH_READ_ARRAY;
   signal flashReadState  : tFLASHSTATE := FLASH_READ_ARRAY;
   signal flashbank       : std_logic := '0';
   signal flashNotSRam    : std_logic := '0';
   signal flashSRamdecide : std_logic := '0';
   
   signal flash_saveaddr  : std_logic_vector(busadr_bits-1 downto 0);
   signal flash_savecount : integer range 0 to 131072;
   signal flash_savedata  : std_logic_vector(7 downto 0);
   
   -- tilt
   signal tilt_x : unsigned(11 downto 0);
   signal tilt_y : unsigned(11 downto 0);
   
   -- savestate
   signal SAVESTATE_EEPROM  : std_logic_vector(31 downto 0);
   signal SAVESTATE_FLASH   : std_logic_vector(16 downto 0);
   
   signal SAVESTATE_EEPROM_BACK : std_logic_vector(31 downto 0);
   signal SAVESTATE_FLASH_BACK  : std_logic_vector(16 downto 0);
   
   type t_ss_wired_or is array(0 to 1) of std_logic_vector(31 downto 0);
   signal save_wired_or        : t_ss_wired_or;   
   signal save_wired_done      : unsigned(0 to 1);
   
   -- debug
   signal rom_debug_cnt     : unsigned(31 downto 0) := (others => '0');
   signal rom_debug_ena     : unsigned(31 downto 0) := (others => '0');
   signal rom_debug_cancel  : unsigned(31 downto 0) := (others => '0');
   signal rom_debug_refresh : unsigned(31 downto 0) := (others => '0');
   signal rom_debug_done16  : unsigned(31 downto 0) := (others => '0');
   signal rom_debug_data    : unsigned(31 downto 0) := (others => '0');
   
begin 

   flashDeviceID       <= x"13" when flash_1m = '1' else x"1B"; -- 0x09; for 1m?
   flashManufacturerID <= x"62" when flash_1m = '1' else x"32"; -- 0xc2; for 1m?
   
   -- savestate
   iSAVESTATE_EEPROM : entity work.eProcReg_gba generic map (REG_SAVESTATE_EEPROM) port map (clk1x, savestate_bus, save_wired_or(0), save_wired_done(0), SAVESTATE_EEPROM_BACK, SAVESTATE_EEPROM);
   iSAVESTATE_FLASH  : entity work.eProcReg_gba generic map (REG_SAVESTATE_FLASH ) port map (clk1x, savestate_bus, save_wired_or(1), save_wired_done(1), SAVESTATE_FLASH_BACK , SAVESTATE_FLASH );
   
   process (save_wired_or)
      variable wired_or : std_logic_vector(31 downto 0);
   begin
      wired_or := save_wired_or(0);
      for i in 1 to (save_wired_or'length - 1) loop
         wired_or := wired_or or save_wired_or(i);
      end loop;
      ss_wired_out <= wired_or;
   end process;
   ss_wired_done <= '0' when (save_wired_done = 0) else '1';
   
   SAVESTATE_EEPROM_BACK(7 downto 0)   <= eepromBuffer; 
   SAVESTATE_EEPROM_BACK(15 downto 8)  <= std_logic_vector(eepromBits);   
   SAVESTATE_EEPROM_BACK(21 downto 16) <= std_logic_vector(eepromByte);   
   SAVESTATE_EEPROM_BACK(31 downto 22) <= std_logic_vector(eepromAddress);
   
   SAVESTATE_FLASH_BACK(2 downto 0)   <= std_logic_vector(to_unsigned(eeprombitpos, 3));
   SAVESTATE_FLASH_BACK(3)            <= flashbank;      
   SAVESTATE_FLASH_BACK(4)            <= flashNotSRam;   
   SAVESTATE_FLASH_BACK(5)            <= flashSRamdecide;
   SAVESTATE_FLASH_BACK(8  downto 6)  <= std_logic_vector(to_unsigned(tEEPROMSTATE'POS(eepromMode), 3));
   SAVESTATE_FLASH_BACK(12 downto 9)  <= std_logic_vector(to_unsigned(tFLASHSTATE'POS(flashState), 4));
   SAVESTATE_FLASH_BACK(16 downto 13) <= std_logic_vector(to_unsigned(tFLASHSTATE'POS(flashReadState), 4));
   
   cache_index16 <= to_integer(unsigned(cart_addr(3 downto 1)));
   cache_index32 <= to_integer(unsigned(cart_addr(3 downto 1)) + 1);
   
   cache_hit16 <= '1' when (cache_valid(cache_index16) = '1' and unsigned(cart_addr(27 downto 1)) >= cache_next(27 downto 1) and unsigned(cart_addr(27 downto 1)) < (cache_next(27 downto 1) + 8)) else '0';
   cache_hit32 <= '1' when (cache_valid(cache_index32) = '1'                                                                 and unsigned(cart_addr(27 downto 1)) < (cache_next(27 downto 1) + 7)) else '0';
   
   process (clk1x)
   begin
      if rising_edge(clk1x) then
      
         cart_ena_1  <= '0';
         cart_idle_1 <= '0';
         cart_done   <= '0';
         
         cache_remove <= '0';
      
         if (reset = '1') then  
            state1X  <= IDLE1X;
         else
            case (state1X) is
               when IDLE1X =>
                  cart_idle_1 <= cart_idle;
                  if (cart_ena = '1') then
                     cart_addr_1      <= cart_addr;
                     cart_rnw_1       <= cart_rnw;      
                     cart_32_1        <= cart_32;      
                     cart_writedata_1 <= cart_writedata;                  
                     if (cart_rnw = '1' and cache_hit16 = '1' and (cart_32 = '0' or cache_hit32 = '1')) then
                        cart_done        <= '1';
                        if (cart_32 = '1') then
                           cart_readdata <= cache_data(cache_index32) & cache_data(cache_index16);
                        elsif (cart_addr(1) = '1') then
                           cart_readdata <= cache_data(cache_index16) & x"0000";
                        else
                           cart_readdata <= x"0000" & cache_data(cache_index16);
                        end if;
                        cache_remove     <= '1';
                     else
                        state1X          <= WAITDATA;
                        cart_ena_1       <= '1';             
                     end if;
                  end if;
                  
               when WAITDATA =>
                  if (state = IDLE) then
                     state1X       <= IDLE1X;
                     cart_done     <= '1';
                     if (cart_32_1 = '0' and cart_addr_1(1) = '1') then
                        cart_readdata <= cart_readdata_6x(15 downto 0) & cart_readdata_6x(31 downto 16);
                     else
                        cart_readdata <= cart_readdata_6x;
                     end if;

                     
                  end if;
               
            end case;
         end if;
      end if;
   end process;
   
   process (all)
      variable cachecounter : integer range 0 to 8;
   begin
      cachecounter := 0;
      for i in 0 to 7 loop
         if (cache_valid(i) = '1') then
            cachecounter := cachecounter + 1;
         end if;
      end loop;
      cachecount <= cachecounter;
   end process;
   
   sdram_refresh <= '1' when (state = IDLE and cacheState = CACHE_IDLE and clk6xIndex = 0 and refresh_block = '0' and cart_ena_1 = '0' and cart_done = '0' and cache_remove = '0' and (cacheEnable = '0' or cachecount > 1)) else 
                    '0';
                    
   sdram_cancel  <= '1' when (state = IDLE and clk6xIndex = 0 and cart_ena_1 = '1') else 
                    '1' when (cacheState /= CACHE_IDLE and clk6xIndex = 0 and cache_remove = '1' and cache_next /= unsigned(cart_addr_1)) else
                    '0';
   
   process (clk6x)
      
   begin
      if rising_edge(clk6x) then
      
         -- default pulse regs
         save_eeprom     <= '0';
         save_sram       <= '0';
         save_flash      <= '0';
      
         sdram_ena       <= '0';
         
         if (clk6xIndex = 5) then
            GPIO_readEna    <= '0';
            GPIO_writeEna   <= '0';
         end if;
         
         error_refresh <= refresh_timer(9);
         if (refresh_timer(9) = '0') then
            refresh_timer <= refresh_timer + 1;
         end if;
         if (sdram_refresh = '1' or state = FLASH_BLOCKWAIT) then
            refresh_timer     <= (others => '0');
            refresh_block     <= '1';
            refresh_block_cnt <= 29;
         elsif (refresh_block_cnt > 0) then
            refresh_block_cnt <= refresh_block_cnt - 1;
            if (refresh_block_cnt = 1) then
               refresh_block <= '0';
            end if;
         end if;
         
         -- tilt
         tilt_x <= to_unsigned(16#3A0# + to_integer(AnalogTiltX), 12);
         tilt_y <= to_unsigned(16#3A0# + to_integer(AnalogTiltY), 12);
      
         if (reset = '1') then  
            eepromBuffer      <= SAVESTATE_EEPROM(7 downto 0);
            eepromBits        <= unsigned(SAVESTATE_EEPROM(15 downto 8));
            eepromByte        <= unsigned(SAVESTATE_EEPROM(21 downto 16));
            eepromAddress     <= unsigned(SAVESTATE_EEPROM(31 downto 22));
            eeprombitpos      <= to_integer(unsigned(SAVESTATE_FLASH(2 downto 0)));
                              
            flashbank         <= SAVESTATE_FLASH(3);
            flashNotSRam      <= SAVESTATE_FLASH(4);
            flashSRamdecide   <= SAVESTATE_FLASH(5);
                              
            eepromMode        <= tEEPROMSTATE'VAL(to_integer(unsigned(SAVESTATE_FLASH(8 downto 6))));
            flashState        <= tFLASHSTATE'VAL(to_integer(unsigned(SAVESTATE_FLASH(12 downto 9))));
            flashReadState    <= tFLASHSTATE'VAL(to_integer(unsigned(SAVESTATE_FLASH(16 downto 13))));
                              
            state             <= IDLE;
            cacheEnable       <= '0';
            cache_valid       <= (others => '0');
            cacheState        <= CACHE_IDLE;
                              
            rom_debug_cnt     <= (others => '0');
            rom_debug_ena     <= (others => '0');
            rom_debug_cancel  <= (others => '0');
            rom_debug_refresh <= (others => '0');
            rom_debug_done16  <= (others => '0');
            rom_debug_data    <= (others => '0');
            
            refresh_timer     <= (others => '0');
            refresh_block     <= '0';
            refresh_block_cnt <= 0;
         else
         
            rom_debug_cnt    <= rom_debug_cnt + 1;
            if (sdram_ena     = '1') then rom_debug_ena     <= rom_debug_ena     + rom_debug_cnt; end if;
            if (sdram_cancel  = '1') then rom_debug_cancel  <= rom_debug_cancel  + rom_debug_cnt; end if;
            if (sdram_refresh = '1') then rom_debug_refresh <= rom_debug_refresh + rom_debug_cnt; end if;
            if (sdram_done16  = '1') then rom_debug_done16  <= rom_debug_done16  + rom_debug_cnt; end if;
            if (cart_done = '1' and clk6xIndex = 0) then rom_debug_data  <= rom_debug_data + unsigned(cart_readdata); end if;
            if (rom_debug_cnt(31) = '1' and rom_debug_ena(31) = '1' and rom_debug_cancel(31) = '1' and rom_debug_refresh(31) = '1' and rom_debug_done16(31) = '1' and rom_debug_data(31) = '1') then
               tilt_y(0) <= '1';
            end if;
         
            case (cacheState) is
               when CACHE_IDLE =>
                  if (cacheEnable = '1' and state = IDLE and clk6xIndex = 0 and cart_ena_1 = '0' and sdram_refresh = '0') then
                     cacheState <= WAIT_CACHE16;
                     sdram_ena  <= '1';
                     sdram_Adr  <= std_logic_vector(unsigned(sdram_Adr) + 2);
   
                     if (cachecount > 6 or (refresh_timer(8) = '1' and cachecount > 3)) then
                        sdram_ena  <= '0'; 
                        cacheState <= CACHE_IDLE;
                        sdram_Adr  <= sdram_Adr;
                     end if;
                  end if;
                              
               when WAIT_CACHE16 =>
                  if (sdram_cancel = '1') then
                     cacheState <= CACHE_IDLE;
                     sdram_Adr  <= std_logic_vector(unsigned(sdram_Adr) - 2);
                  elsif (sdram_done16 = '1') then
                     if (sdram_Adr(1) = '0') then
                        cacheState <= WAIT_CACHE32;
                        sdram_Adr <= std_logic_vector(unsigned(sdram_Adr) + 2);
                     else
                        cacheState <= CACHE_IDLE;
                     end if;
                     cache_valid(to_integer(unsigned(sdram_Adr(3 downto 1)))) <= '1';
                     cache_data(to_integer(unsigned(sdram_Adr(3 downto 1))))  <= sdram_Dout(15 downto 0); 
                  end if;
                  
               when WAIT_CACHE32 =>
                  if (sdram_done32 = '1') then
                     cacheState <= CACHE_IDLE;
                     if (cache_valid /= x"FF") then -- prevent exceeding 8 cached words, rather drop it
                        cache_valid(to_integer(unsigned(sdram_Adr(3 downto 1)))) <= '1';
                        cache_data(to_integer(unsigned(sdram_Adr(3 downto 1))))  <= sdram_Dout(31 downto 16); 
                     end if;
                  end if;   
               
            end case;
            
            if (clk6xIndex = 0 and cache_remove = '1') then
               if (cart_32_1 = '1') then
                  cache_next <= unsigned(cart_addr_1) + 4;
                  cache_valid(to_integer(unsigned(cart_addr_1(3 downto 1))))     <= '0';
                  cache_valid(to_integer(unsigned(cart_addr_1(3 downto 1))) + 1) <= '0';
               else
                  cache_next <= unsigned(cart_addr_1) + 2;
                  cache_valid(to_integer(unsigned(cart_addr_1(3 downto 1)))) <= '0';
               end if;
               if (cache_next /= unsigned(cart_addr_1)) then
                  cache_valid <= (others => '0');
                  cacheState <= WAIT_CACHE16;
                  sdram_ena  <= '1';
                  sdram_Adr  <= std_logic_vector(unsigned(sdram_Adr) + 2);
   
                  if (memory_remap = '1') then
                     sdram_Adr <= std_logic_vector(to_unsigned(Softmap_GBA_Gamerom_ADDR, busadr_bits) + unsigned(cart_addr_1(19 downto 0)) + 2);
                  else
                     sdram_Adr <= std_logic_vector(to_unsigned(Softmap_GBA_Gamerom_ADDR, busadr_bits) + unsigned(cart_addr_1(24 downto 0)) + 2);
                  end if; 
               end if;
            end if;
            
            case state is
            
               when IDLE =>
               
                  flash_busy  <= '0';
               
                  if (cart_ena_1 = '1' and clk6xIndex = 0) then
                  
                     cacheState  <= CACHE_IDLE;
                     
                     adr_save    <= cart_addr_1;
                     Dout_save   <= cart_writedata_1;
      
                     if (cart_rnw_1 = '1') then  -- read
                     
                        cacheEnable <= '0';
                        sdram_rnw   <= '1';
                        cache_valid <= (others => '0');
                        if (cart_32_1 = '1') then
                           cache_next  <= unsigned(cart_addr_1) + 4;
                        else
                           cache_next  <= unsigned(cart_addr_1) + 2;
                        end if;
      
                        case (cart_addr_1(27 downto 24)) is
                        
                           when x"8" | x"9" | x"A" | x"B" | x"C" =>
                              if (unsigned(cart_addr_1(24 downto 2)) >= unsigned(MaxPakAddr)) then
                                 state <= READAFTERPAK;
                              else
                                 sdram_ena   <= '1';
                                 state       <= WAIT_SDRAM;
                                 cacheEnable <= '1';
                              end if;
                              
                              if (memory_remap = '1') then
                                 sdram_Adr <= std_logic_vector(to_unsigned(Softmap_GBA_Gamerom_ADDR, busadr_bits) + unsigned(cart_addr_1(19 downto 0)));
                              else
                                 sdram_Adr <= std_logic_vector(to_unsigned(Softmap_GBA_Gamerom_ADDR, busadr_bits) + unsigned(cart_addr_1(24 downto 0)));
                              end if;  
                              
                              if (specialmodule = '1') then
                                 if (unsigned(cart_addr_1(27 downto 0)) >= 16#80000C4# and unsigned(cart_addr_1(27 downto 0)) <= 16#80000C8#) then
                                    state        <= READ_GPIO;
                                    GPIO_readEna <= '1';
                                    GPIO_addr    <= std_logic_vector(to_unsigned(to_integer(unsigned(cart_addr_1(3 downto 1))) - 4 / 2, 2));
                                    cacheEnable  <= '0';
                                 end if;
                              end if;
                           
                           when x"D" =>
                              state <= EEPROMREAD;  
         
                           when x"E" | x"F" =>
                              state <= FLASHREAD; 
                           
                           when others => null;
                           
                        end case;
                        
                     else -- write
                     
                        case (cart_addr_1(27 downto 24)) is
                           when x"8" =>
                              state      <= IDLE; 
                              if (specialmodule = '1') then
                                 if (unsigned(cart_addr_1(27 downto 0)) >= 16#80000C4# and unsigned(cart_addr_1(27 downto 0)) <= 16#80000C8#) then
                                    GPIO_writeEna <= '1';
                                    GPIO_addr     <= std_logic_vector(to_unsigned(to_integer(unsigned(cart_addr_1(3 downto 1))) - 4 / 2, 2));
                                    GPIO_Dout     <= cart_writedata_1(3 downto 0);
                                 end if;
                              end if;
                           
                           when x"D" => 
                              cacheEnable <= '0';
                              cache_valid <= (others => '0');
                              state       <= EEPROMWRITE;
                              
                           when x"E" | x"F" => 
                              cacheEnable <= '0';
                              cache_valid <= (others => '0');
                              state       <= FLASHSRAMWRITEDECIDE1;
                              flash_busy  <= '1';
                              
                           when others => 
                              state <= IDLE;
      
                        end case;
                        
                     end if;
                  
                  end if;
                  
               -- reading
               when WAIT_SDRAM =>
                  if (cart_32_1 = '1' and sdram_done32 = '1') then 
                     state            <= IDLE;
                     cart_readdata_6x <= sdram_Dout;
                     sdram_Adr        <= std_logic_vector(unsigned(sdram_Adr) + 2);
                  elsif (cart_32_1 = '0' and sdram_done16 = '1') then
                     state      <= IDLE;
                     cart_readdata_6x <= x"0000" & sdram_Dout(15 downto 0); 
                     if (cacheEnable = '1' and sdram_Adr(1) = '0' and sdram_rnw = '1') then
                        cacheState <= WAIT_CACHE32;
                        sdram_Adr  <= std_logic_vector(unsigned(sdram_Adr) + 2);
                     end if;
                  end if;
                  
               when READAFTERPAK =>
                  state             <= IDLE;
                  cart_readdata_6x  <= std_logic_vector(unsigned(adr_save(16 downto 1)) + 1) & adr_save(16 downto 1);
                  
               when READ_GPIO =>
                  if (GPIO_done = '1') then
                     state          <= IDLE; 
                     cart_readdata_6x  <= x"0000000" & GPIO_Din;
                  end if;
                  
               ----- writing
               when EEPROMREAD =>
                  case (eepromMode) is
                     when EEPROM_IDLE | EEPROM_READADDRESS | EEPROM_WRITEDATA =>
                        cart_readdata_6x <= x"00000001";
                        state            <= IDLE;  
                        
                     when EEPROM_READDATA =>
                           if (eepromBits < 3) then
                              eepromBits <= eepromBits + 1;
                           else
                              eepromMode <= EEPROM_READDATA2;
                              eepromBits <= (others => '0');
                              eepromByte <= (others => '0');
                           end if;
                           cart_readdata_6x <= (others => '0');
                           state            <= IDLE; 
                           
                     when EEPROM_READDATA2 =>
                        state        <= EEPROM_WAITREAD;
                        sdram_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_EEPROM_ADDR, busadr_bits) + resize((eepromAddress * 8 + eepromByte) * 4, busadr_bits));
                        sdram_rnw  <= '1';
                        sdram_ena  <= '1';  
                        eeprombitpos <= 7 - to_integer((eepromBits(2 downto 0)));
                        eepromBits <= eepromBits + 1;
                        if (eepromBits(2 downto 0) = "111") then
                           eepromByte <= eepromByte + 1;
                        end if;
                        if (eepromBits = x"3F") then
                           eepromMode <= EEPROM_IDLE;
                        end if;
   
                     when others => 
                        cart_readdata_6x <= (others => '0');
                        state            <= IDLE;  
                  end case;
                  
               when EEPROM_WAITREAD =>
                  if (sdram_done16 = '1') then
                     cart_readdata_6x <= (others => '0');
                     state            <= IDLE;  
                     if (sdram_Dout(eeprombitpos) = '1') then 
                        cart_readdata_6x(0) <= '1'; 
                     end if;
                  end if;
               
               when EEPROMWRITE => 
                  if (dma_eepromcount = 0) then
                     state <= IDLE;
                  else
                     case (eepromMode) is
                        when EEPROM_IDLE =>
                           eepromByte   <= (others => '0');
                           eepromBits   <= to_unsigned(1, eepromBits'length);
                           eepromBuffer <= "0000000" & Dout_save(0);
                           eepromMode   <= EEPROM_READADDRESS;
                           state        <= IDLE;
   
                        when EEPROM_READADDRESS =>
                           state        <= IDLE; 
                           eepromBuffer <= eepromBuffer(6 downto 0) & Dout_save(0);
                           eepromBits   <= eepromBits + 1;
                           if (eepromBits(2 downto 0) = "111") then
                              eepromByte <= eepromByte + 1;
                           end if;
                           
                           if (eepromBits = 1) then
                              eeprom_rnw <= Dout_save(0);
                           end if;
                        
                           if (dma_eepromcount = 16#11# or dma_eepromcount = 16#51#) then
                              if (eepromBits >= 2 and eepromBits <= 15) then
                                 eepromAddress <= eepromAddress(8 downto 0) & Dout_save(0);
                              end if;
                           else
                              if (eepromBits >= 2 and eepromBits <= 7) then
                                 eepromAddress <= "0000" & eepromAddress(4 downto 0) & Dout_save(0);
                              end if;
                           end if;
                           
                           if ((dma_eepromcount = 16#11# or dma_eepromcount = 16#51#) and eepromBits = 16) or 
                              ((dma_eepromcount /= 16#11# and dma_eepromcount /= 16#51#) and eepromBits = 8)
                           then
                              --eepromInUse = true;
                              if (eeprom_rnw = '0') then
                                 eepromBuffer <= "0000000" & Dout_save(0);
                                 eepromBits   <= to_unsigned(1, eepromBits'length);
                                 eepromByte   <= (others => '0');
                                 eepromMode   <= EEPROM_WRITEDATA;
                              else
                                 eepromMode <= EEPROM_READDATA;
                                 eepromByte <= (others => '0');
                                 eepromBits <= (others => '0');
                              end if;
                           end if;
   
                        when EEPROM_READDATA | EEPROM_READDATA2 =>
                           -- should we reset here?
                           eepromMode   <= EEPROM_IDLE;
                           state        <= IDLE; 
                           
                        when EEPROM_WRITEDATA =>
                           eepromBuffer <= eepromBuffer(6 downto 0) & Dout_save(0);
                           eepromBits   <= eepromBits + 1;
                           if (eepromBits(2 downto 0) = "000") then
                              eepromByte <= eepromByte + 1;
                              sdram_Din  <= x"000000" & eepromBuffer;
                              sdram_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_EEPROM_ADDR, busadr_bits) + resize((eepromAddress * 8 + eepromByte) * 4, busadr_bits));
                              sdram_rnw  <= '0';
                              sdram_ena  <= '1';
                              save_eeprom  <= '1';
                              state        <= WAIT_SDRAM;
                           else
                              state <= IDLE; 
                           end if;
                           
                           if (eepromBits = 16#40#) then
                              eepromMode <= EEPROM_IDLE;
                              eepromByte <= (others => '0');
                              eepromBits <= (others => '0');
                           end if;
   
                     end case;
                  end if;
               
               when FLASHREAD =>
                  state            <= IDLE; 
                  cart_readdata_6x <= (others => '0');
                  
                  if (tilt = '1') then
                  
                     if (adr_save = x"E008200") then cart_readdata_6x(7 downto 0) <= std_logic_vector(tilt_x( 7 downto 0)); end if;
                     if (adr_save = x"E008300") then cart_readdata_6x(3 downto 0) <= std_logic_vector(tilt_x(11 downto 8)); cart_readdata_6x(7) <= '1'; end if; -- bit 7 for sampling done
                     if (adr_save = x"E008400") then cart_readdata_6x(7 downto 0) <= std_logic_vector(tilt_y( 7 downto 0)); end if;
                     if (adr_save = x"E008500") then cart_readdata_6x(3 downto 0) <= std_logic_vector(tilt_y(11 downto 8)); end if;
                  
                  elsif (SramFlashEnable = '0') then
                     
                     cart_readdata_6x <= (others => '1');
                     
                  else
                  
                     case (flashReadState) is
                        when FLASH_READ_ARRAY =>
                           state        <= FLASH_WAITREAD;
                           sdram_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits) + resize(4 * unsigned((flashBank & adr_save(15 downto 0))), busadr_bits));
                           sdram_rnw  <= '1';
                           sdram_ena  <= '1'; 
                           
                        when FLASH_AUTOSELECT => 
                           if (adr_save(7 downto 0) = x"00") then
                              cart_readdata_6x <= flashManufacturerID & flashManufacturerID & flashManufacturerID & flashManufacturerID;
                           elsif (adr_save(7 downto 0) = x"01") then
                              cart_readdata_6x <= flashDeviceID & flashDeviceID & flashDeviceID & flashDeviceID;
                           end if;
                           
                        when FLASH_ERASE_COMPLETE =>
                           flashState        <= FLASH_READ_ARRAY;
                           flashReadState    <= FLASH_READ_ARRAY;
                           cart_readdata_6x  <= (others => '1');
                           
                        when others => null;
                     end case;
                  
                  end if;
                  
               when FLASH_WAITREAD =>
                  if (sdram_done16 = '1') then
                     cart_readdata_6x <= sdram_Dout(15 downto 0) & sdram_Dout(15 downto 0);
                     state            <= IDLE;
                  end if;
               
               when FLASHSRAMWRITEDECIDE1 =>
                  if (SramFlashEnable = '0') then
                     state           <= IDLE;
                  else
                     state           <= FLASHSRAMWRITEDECIDE2;
                     flashSRamdecide <= '1';
                     if (flashSRamdecide = '0' and adr_save = x"e005555") then
                        flashNotSRam <= '1';
                     end if;
                  end if;
                  
               when FLASHSRAMWRITEDECIDE2 =>
                  if (flashNotSRam = '1') then
                     state <= FLASHWRITE;
                  else
                     state <= SRAMWRITE;
                  end if;
               
               when SRAMWRITE => 
                  sdram_Din  <= x"000000" & Dout_save(7 downto 0);
                  sdram_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits) + resize(4 * unsigned(adr_save(15 downto 0)), busadr_bits));
                  sdram_rnw  <= '0';
                  sdram_ena  <= '1'; 
                  save_sram    <= '1';
                  state        <= WAIT_SDRAM;
               
               when FLASHWRITE =>
                  -- only default, maybe overwritten
                  state <= IDLE;
               
                  case (flashState) is
                     when FLASH_READ_ARRAY =>
                        if (adr_save(15 downto 0) = x"5555" and Dout_save(7 downto 0) = x"AA") then
                              flashState <= FLASH_CMD_1;
                        end if;
                        
                     when FLASH_CMD_1 =>
                        if (adr_save(15 downto 0) = x"2AAA" and Dout_save(7 downto 0) = x"55") then
                           flashState <= FLASH_CMD_2;
                        else
                           flashState <= FLASH_READ_ARRAY;
                        end if;
                        
                     when FLASH_CMD_2 =>
                        if (adr_save(15 downto 0) = x"5555") then
                           if (Dout_save(7 downto 0) = x"90") then
                              flashState     <= FLASH_AUTOSELECT;
                              flashReadState <= FLASH_AUTOSELECT;
                           elsif (Dout_save(7 downto 0) = x"80") then
                              flashState <= FLASH_CMD_3;
                           elsif (Dout_save(7 downto 0) = x"F0") then
                              flashState     <= FLASH_READ_ARRAY;
                              flashReadState <= FLASH_READ_ARRAY;
                           elsif (Dout_save(7 downto 0) = x"A0") then
                              flashState <= FLASH_PROGRAM;
                           elsif (Dout_save(7 downto 0) = x"B0" and flash_1m = '1') then
                              flashState <= FLASH_SETBANK;
                           else
                              flashState     <= FLASH_READ_ARRAY;
                              flashReadState <= FLASH_READ_ARRAY;
                           end if;
                        else
                           flashState     <= FLASH_READ_ARRAY;
                           flashReadState <= FLASH_READ_ARRAY;
                        end if;
                        
                     when FLASH_CMD_3 =>
                        if (adr_save(15 downto 0) = x"5555" and Dout_save(7 downto 0) = x"AA") then
                           flashState <= FLASH_CMD_4;
                        else
                           flashState     <= FLASH_READ_ARRAY;
                           flashReadState <= FLASH_READ_ARRAY;
                        end if;
                        
                     when FLASH_CMD_4 =>
                        if (adr_save(15 downto 0) = x"2AAA" and Dout_save(7 downto 0) = x"55") then
                           flashState <= FLASH_CMD_5;
                        else
                           flashState     <= FLASH_READ_ARRAY;
                           flashReadState <= FLASH_READ_ARRAY;
                        end if;
                     
                     when FLASH_CMD_5 => -- SECTOR ERASE
                        if (Dout_save(7 downto 0) = x"30") then
                           flash_saveaddr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits));
                           flash_saveaddr(13 downto  0) <= 14x"0";
                           flash_saveaddr(17 downto 14) <= adr_save(15 downto 12);
                           flash_saveaddr(18) <= flashBank;
                           flash_savecount <= 4096;
                           flash_savedata  <= (others => '1');
                           state           <= FLASH_WRITEBLOCK;
                           flashReadState <= FLASH_ERASE_COMPLETE;
                        elsif (Dout_save(7 downto 0) = x"10") then -- CHIP ERASE
                           flash_saveaddr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits));
                           flash_savecount <= 131072;
                           flash_savedata  <= (others => '1');
                           state           <= FLASH_WRITEBLOCK;
                           flashReadState  <= FLASH_ERASE_COMPLETE;
                        else
                           flashState     <= FLASH_READ_ARRAY;
                           flashReadState <= FLASH_READ_ARRAY;
                        end if;
                        
                     when FLASH_AUTOSELECT =>
                        if (Dout_save(7 downto 0) = x"F0") then
                           flashState     <= FLASH_READ_ARRAY;
                           flashReadState <= FLASH_READ_ARRAY;
                        elsif (adr_save(15 downto 0) = x"5555" and Dout_save(7 downto 0) = x"AA")  then
                           flashState <= FLASH_CMD_1;
                        else
                           flashState     <= FLASH_READ_ARRAY;
                           flashReadState <= FLASH_READ_ARRAY;
                        end if;
                     
                     when FLASH_PROGRAM =>
                        flash_saveaddr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits) + resize(4 * unsigned((flashBank & adr_save(15 downto 0))), busadr_bits));
                        flash_savecount <= 1;
                        flash_savedata  <= Dout_save(7 downto 0);
                        state           <= FLASH_WRITEBLOCK;
                        flashState      <= FLASH_READ_ARRAY;
                        flashReadState  <= FLASH_READ_ARRAY;
                        
                     when FLASH_SETBANK =>
                        if (adr_save(15 downto 0) = x"0000") then
                           flashBank <= Dout_save(0);
                        end if;
                        flashState     <= FLASH_READ_ARRAY;
                        flashReadState <= FLASH_READ_ARRAY;
                     
                     when others => null;
                     
                  end case;
                  
               when FLASH_WRITEBLOCK =>
                  sdram_Din         <= x"000000" & flash_savedata;
                  sdram_Adr         <= flash_saveaddr;
                  sdram_rnw         <= '0';
                  sdram_ena         <= '1';
                  save_flash        <= '1';               
                  state             <= FLASH_BLOCKWAIT;
                  flash_saveaddr    <= std_logic_vector(unsigned(flash_saveaddr) + 4);
                  flash_savecount   <= flash_savecount - 1;
               
               when FLASH_BLOCKWAIT =>
                  if (sdram_done16 = '1') then
                     if (flash_savecount = 0) then
                        state <= IDLE;
                     else
                        state <= FLASH_WRITEBLOCK;
                     end if;
                  end if;
                  
            end case;
            
         end if;
      
      end if;
   end process;
   

end architecture;





