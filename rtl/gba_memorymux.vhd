library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;

use work.pProc_bus_gba.all;
use work.pReg_savestates.all;

entity gba_memorymux is
   generic
   (
      is_simu : std_logic;
      Softmap_GBA_Gamerom_ADDR : integer; -- count: 8388608  -- 32 Mbyte Data for GameRom   
      Softmap_GBA_WRam_ADDR    : integer; -- count:   65536  -- 256 Kbyte Data for GBA WRam Large
      Softmap_GBA_FLASH_ADDR   : integer; -- count:  131072  -- 128/512 Kbyte Data for GBA Flash
      Softmap_GBA_EEPROM_ADDR  : integer  -- count:    8192  -- 8/32 Kbyte Data for GBA EEProm
   );
   port 
   (
      clk100               : in     std_logic; 
      gb_on                : in     std_logic;
      reset                : in     std_logic;
      
      savestate_bus        : inout  proc_bus_gb_type;
      
      sdram_read_ena       : out    std_logic := '0';
      sdram_read_done      : in     std_logic := '0';
      sdram_read_addr      : buffer std_logic_vector(24 downto 0) := (others => '0'); -- all addresses are DWORD addresses!
      sdram_read_data      : in     std_logic_vector(31 downto 0);
      sdram_second_dword   : in     std_logic_vector(31 downto 0);
                                    
      bus_out_Din          : out    std_logic_vector(31 downto 0) := (others => '0');
      bus_out_Dout         : in     std_logic_vector(31 downto 0);
      bus_out_Adr          : out    std_logic_vector(25 downto 0) := (others => '0'); -- all addresses are DWORD addresses!
      bus_out_rnw          : out    std_logic := '0';
      bus_out_ena          : out    std_logic := '0';
      bus_out_done         : in     std_logic;
                                    
      gb_bus_out           : inout  proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');          
                                    
      mem_bus_Adr          : in     std_logic_vector(31 downto 0);
      mem_bus_rnw          : in     std_logic;
      mem_bus_ena          : in     std_logic;
      mem_bus_acc          : in     std_logic_vector(1 downto 0);
      mem_bus_dout         : in     std_logic_vector(31 downto 0);
      mem_bus_din          : out    std_logic_vector(31 downto 0) := (others => '0');
      mem_bus_done         : out    std_logic;
      mem_bus_unread       : out    std_logic;
      
      bios_wraddr          : in     std_logic_vector(11 downto 0) := (others => '0');
      bios_wrdata          : in     std_logic_vector(31 downto 0) := (others => '0');
      bios_wr              : in     std_logic := '0';
      
      bus_lowbits          : in     std_logic_vector(1 downto 0);
      
      dma_soon             : in     std_logic;
      settle               : out    std_logic;
      
      save_eeprom          : out    std_logic := '0';
      save_sram            : out    std_logic := '0';
      save_flash           : out    std_logic := '0';
                                    
      new_cycles           : in     unsigned(7 downto 0);
      new_cycles_valid     : in     std_logic;
                                    
      PC_in_BIOS           : in     std_logic;
      lastread             : in     std_logic_vector(31 downto 0);
      lastread_dma         : in     std_logic_vector(31 downto 0);
      last_access_dma      : in     std_logic;
                                    
      dma_eepromcount      : in     unsigned(16 downto 0);
      flash_1m             : in     std_logic;
      MaxPakAddr           : in     std_logic_vector(24 downto 0);
      SramFlashEnable      : in     std_logic;
      memory_remap         : in     std_logic;
      
      bitmapdrawmode       : in     std_logic;
                                    
      VRAM_Lo_addr         : out    integer range 0 to 16383;
      VRAM_Lo_datain       : out    std_logic_vector(31 downto 0);
      VRAM_Lo_dataout      : in     std_logic_vector(31 downto 0);
      VRAM_Lo_we           : out    std_logic;
      VRAM_Lo_be           : out    std_logic_vector(3 downto 0);
      VRAM_Hi_addr         : out    integer range 0 to 8191;
      VRAM_Hi_datain       : out    std_logic_vector(31 downto 0);
      VRAM_Hi_dataout      : in     std_logic_vector(31 downto 0);
      VRAM_Hi_we           : out    std_logic;
      VRAM_Hi_be           : out    std_logic_vector(3 downto 0);
      vram_blocked         : in     std_logic;      
      vram_cycle           : out    std_logic := '0';
                                    
      OAMRAM_PROC_addr     : out    integer range 0 to 255;
      OAMRAM_PROC_datain   : out    std_logic_vector(31 downto 0);
      OAMRAM_PROC_dataout  : in     std_logic_vector(31 downto 0);
      OAMRAM_PROC_we       : out    std_logic_vector(3 downto 0);
                                    
      PALETTE_BG_addr      : out    integer range 0 to 128;
      PALETTE_BG_datain    : out    std_logic_vector(31 downto 0);
      PALETTE_BG_dataout   : in     std_logic_vector(31 downto 0);
      PALETTE_BG_we        : out    std_logic_vector(3 downto 0);
      PALETTE_OAM_addr     : out    integer range 0 to 128;
      PALETTE_OAM_datain   : out    std_logic_vector(31 downto 0);
      PALETTE_OAM_dataout  : in     std_logic_vector(31 downto 0);
      PALETTE_OAM_we       : out    std_logic_vector(3 downto 0);
      
      specialmodule        : in     std_logic;
      GPIO_readEna         : out    std_logic;
      GPIO_done            : in     std_logic;
      GPIO_Din             : in     std_logic_vector(3 downto 0);
      GPIO_Dout            : out    std_logic_vector(3 downto 0);
      GPIO_writeEna        : out    std_logic := '0';
      GPIO_addr            : out    std_logic_vector(1 downto 0);
      
      tilt                 : in     std_logic;
      AnalogTiltX          : in     signed(7 downto 0);
      AnalogTiltY          : in     signed(7 downto 0);
      
      debug_mem            : out    std_logic_vector(31 downto 0)  
   );
end entity;

architecture arch of gba_memorymux is

   constant busadr_bits   : integer := 26;
   constant gbbusadr_bits : integer := work.pProc_bus_gba.proc_busadr;
   
   type tState is
   (
      IDLE,
      READBIOS,
      READSMALLRAM,
      READPALETTERAM,
      PALETTEDONE,
      READVRAM,
      VRAMDONE,
      READOAMRAM,
      OAMDONE,
      WAIT_GBBUS,
      WAIT_PROCBUS,
      WAIT_SDRAM,
      READAFTERPAK,
      READ_UNREADABLE,
      ROTATE,
      READ_GPIO,
      WAIT_WRAMREADMODIFYWRITE,
      WRITE_WRAMLARGE,
      WRITE_WRAMSMALL,
      WRITE_REG,
      WRITE_PALETTE,
      WRITE_VRAM,
      VRAMWAITWRITE,
      WRITE_OAM,
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
   
   signal gb_on_1            : std_logic := '0';
   
   signal adr_save           : std_logic_vector(gbbusadr_bits-1 downto 0);
   signal acc_save           : std_logic_vector(1 downto 0);
   signal Dout_save          : std_logic_vector(31 downto 0) := (others => '0');
                             
   signal return_rotate      : std_logic_vector(1 downto 0);
   signal rotate_data        : std_logic_vector(31 downto 0) := (others => '0');
   signal unread_next        : std_logic := '0';
      
   signal bios_data          : std_logic_vector(31 downto 0);
   signal bios_data_last     : std_logic_vector(31 downto 0) := (others => '0');
                             
   signal smallram_addr_r    : integer range 0 to 8191 := 0;
   signal smallram_addr_w    : integer range 0 to 8191 := 0;
   signal smallram_DataOut   : std_logic_vector(31 downto 0) := (others => '0');
   signal smallram_we        : std_logic_vector(0 to 3) := (others => '0');
                             
   signal read_operation     : std_logic := '0';
                             
   signal rotate_writedata   : std_logic_vector(31 downto 0) := (others => '0');
   
   signal registersettle     : std_logic := '0';
   signal registersettle_cnt : integer range 0 to 7 := 0;
   signal wait_timer         : integer range 0 to 7 := 0;
   
   signal vramwait           : std_logic := '0';
   
   -- minicache
   signal sdram_addr_buf     : std_logic_vector(21 downto 0) := (others => '1');
   signal sdram_data_buf     : std_logic_vector(63 downto 0);
   signal sdram_read_done_1  : std_logic := '0';
   
   -- gamepak cache
   signal cache_read_enable  : std_logic := '0';
   signal cache_read_addr    : std_logic_vector(22 downto 0);
   signal cache_read_data    : std_logic_vector(31 downto 0);
   signal cache_read_done    : std_logic;
   signal cache_read_full    : std_logic_vector(63 downto 0);
   
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
   
begin 

   settle <= '1' when registersettle = '1' or (new_cycles_valid = '1' and dma_soon = '1') else '0';

   igba_bios : entity work.gba_bios
   port map
   (
      clk       => clk100,
      address   => mem_bus_Adr(13 downto 2),
      data      => bios_data,
      
      wraddress => bios_wraddr,
      wrdata    => bios_wrdata,
      wren      => bios_wr    
   );
   
   gsmallram : for i in 0 to 3 generate
      signal smallram_dout_single : std_logic_vector(7 downto 0);
      signal smallram_din_single  : std_logic_vector(7 downto 0);
   begin
      ismallram: entity MEM.SyncRamDual
      generic map
      (
         DATA_WIDTH => 8,
         ADDR_WIDTH => 13
      )
      port map
      (
         clk      => clk100,
         
         addr_a     => smallram_addr_r,
         datain_a   => x"00",
         dataout_a  => smallram_dout_single,
         we_a       => '0',
         re_a       => '1',
                  
         addr_b     => smallram_addr_w,
         datain_b   => smallram_din_single,
         dataout_b  => open,
         we_b       => smallram_we(i),
         re_b       => '0' 
      );
      
      smallram_din_single <= rotate_writedata(((i+1) * 8) - 1 downto (i * 8));
      smallram_DataOut(((i+1) * 8) - 1 downto (i * 8)) <= smallram_dout_single;
   end generate;
   
   smallram_addr_r <= to_integer(unsigned(mem_bus_Adr(14 downto 2)));
   
   
   i_gamepak_cache : entity work.cache
   generic map
   (
      SIZE                     => 1024,
      SIZEBASEBITS             => 23,
      BITWIDTH                 => 32,
      Softmap_GBA_Gamerom_ADDR => Softmap_GBA_Gamerom_ADDR
   )
   port map
   (
      clk               => clk100,
      gb_on             => gb_on,
                       
      read_enable       => cache_read_enable,
      read_addr         => cache_read_addr,  
      read_data         => cache_read_data,  
      read_done         => cache_read_done,  
      read_full         => cache_read_full,  
                        
      mem_read_ena      => sdram_read_ena, 
      mem_read_done     => sdram_read_done,
      mem_read_addr     => sdram_read_addr,
      mem_read_data     => sdram_read_data,
      mem_read_data2    => sdram_second_dword
   );
  
   flashDeviceID       <= x"13" when flash_1m = '1' else x"1B"; -- 0x09; for 1m?
   flashManufacturerID <= x"62" when flash_1m = '1' else x"32"; -- 0xc2; for 1m?
   
   -- savestate
   iSAVESTATE_EEPROM : entity work.eProcReg_gba generic map (REG_SAVESTATE_EEPROM) port map (clk100, savestate_bus, SAVESTATE_EEPROM_BACK, SAVESTATE_EEPROM);
   iSAVESTATE_FLASH  : entity work.eProcReg_gba generic map (REG_SAVESTATE_FLASH ) port map (clk100, savestate_bus, SAVESTATE_FLASH_BACK , SAVESTATE_FLASH );
   
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
   
   debug_mem(7 downto 0)  <= std_logic_vector(to_unsigned(tState'POS(state), 8));
   debug_mem(31 downto 8) <= (others => '0');
   
   process (clk100)
      variable palette_we : std_logic_vector(3 downto 0);
      variable VRAM_be    : std_logic_vector(3 downto 0);
   begin
      if rising_edge(clk100) then
      
         if (reset = '1') then  
            eepromBuffer    <= SAVESTATE_EEPROM(7 downto 0);
            eepromBits      <= unsigned(SAVESTATE_EEPROM(15 downto 8));
            eepromByte      <= unsigned(SAVESTATE_EEPROM(21 downto 16));
            eepromAddress   <= unsigned(SAVESTATE_EEPROM(31 downto 22));
            eeprombitpos    <= to_integer(unsigned(SAVESTATE_FLASH(2 downto 0)));

            flashbank       <= SAVESTATE_FLASH(3);
            flashNotSRam    <= SAVESTATE_FLASH(4);
            flashSRamdecide <= SAVESTATE_FLASH(5);
            
            eepromMode      <= tEEPROMSTATE'VAL(to_integer(unsigned(SAVESTATE_FLASH(8 downto 6))));
            flashState      <= tFLASHSTATE'VAL(to_integer(unsigned(SAVESTATE_FLASH(12 downto 9))));
            flashReadState  <= tFLASHSTATE'VAL(to_integer(unsigned(SAVESTATE_FLASH(16 downto 13))));
            
            sdram_addr_buf  <= (others => '1');
            state           <= IDLE;
         end if;
         
         -- register settle
         registersettle <= '0';
         if (registersettle_cnt > 0) then
            registersettle     <= '1';
            registersettle_cnt <= registersettle_cnt - 1;
         end if;
      
         -- mini cache
         if (sdram_read_done = '1') then
            if (sdram_read_addr(0) = '0') then
               sdram_data_buf(31 downto 0) <= sdram_read_data;
            else
               sdram_data_buf(63 downto 32) <= sdram_read_data;
            end if;
         end if;         
         
         sdram_read_done_1 <= sdram_read_done;
         if (sdram_read_done_1 = '1') then
            if (sdram_read_addr(0) = '1') then
               sdram_data_buf(31 downto 0) <= sdram_second_dword;
            else
               sdram_data_buf(63 downto 32) <= sdram_second_dword;
            end if;
         end if;
         
         -- tilt
         tilt_x <= to_unsigned(16#3A0# + to_integer(AnalogTiltX), 12);
         tilt_y <= to_unsigned(16#3A0# + to_integer(AnalogTiltY), 12);

         -- default pulse regs
         bus_out_ena      <= '0';
         gb_bus_out.ena   <= '0';
         
         save_eeprom      <= '0';
         save_sram        <= '0';
         save_flash       <= '0';
         
         gb_on_1          <= gb_on;
         gb_bus_out.rst   <= not gb_on and gb_on_1;
         
         smallram_we     <= (others => '0');
         VRAM_Hi_we      <= '0';
         VRAM_Lo_we      <= '0';
         OAMRAM_PROC_we  <= (others => '0');
         PALETTE_BG_we   <= (others => '0');
         PALETTE_OAM_we  <= (others => '0');
         GPIO_readEna    <= '0';
         GPIO_writeEna   <= '0';
         
         mem_bus_done    <= '0';
         mem_bus_unread  <= '0';
         unread_next     <= '0';
         
         cache_read_enable <= '0';
         
         vram_cycle <= '0';

         case state is
         
            when IDLE =>
            
               wait_timer <= 0;
         
               if (mem_bus_ena = '1') then
               
                  adr_save  <= mem_bus_Adr(27 downto 0);
                  acc_save  <= mem_bus_acc;
                  Dout_save <= mem_bus_dout;
               
                  if (mem_bus_rnw = '1') then  -- read
                  
                     read_operation <= '1';
                  
                     return_rotate <= mem_bus_Adr(1 downto 0);
                     
                     if (mem_bus_Adr(31 downto 28) /= x"0") then

                        state <= READ_UNREADABLE;
                        
                     else
                     
                        case (mem_bus_Adr(27 downto 24)) is
                        
                           when x"0" => 
                              if (PC_in_BIOS = '0') then
                                 if (unsigned(mem_bus_Adr) < 16#4000#) then
                                    --rotate_data <= x"E3A02004"; -- only applies for one situation! -> after irq
                                    --rotate_data <= x"E55EC002"; -- only applies for one situation! -> after swi
                                    --rotate_data <= x"E129F000"; -- only applies for one situation! -> after startup
                                    --rotate_data <= x"E25EF004"; -- only applies for one situation! -> while irq
                                    rotate_data <= bios_data_last;
                                    state       <= ROTATE;
                                 else
                                    state <= READ_UNREADABLE;
                                 end if;
                              else
                                 state <= READBIOS;
                              end if;
                           
                           when x"2" =>
                              bus_out_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_WRam_ADDR, busadr_bits) + unsigned(mem_bus_Adr(17 downto 2)));
                              bus_out_rnw  <= '1';
                              bus_out_ena  <= '1';
                              state        <= WAIT_PROCBUS;
                              
                           when x"3" =>
                              state         <= READSMALLRAM;
                           
                           when x"4" =>
                              if (unsigned(mem_bus_Adr) < x"4000400") then
                                 gb_bus_out.adr <= (gb_bus_out.adr'left downto 12 => '0') & mem_bus_Adr(11 downto 2) & "00";
                                 gb_bus_out.acc <= mem_bus_acc;
                                 gb_bus_out.rnw <= '1';
                                 gb_bus_out.ena <= '1';
                                 state <= WAIT_GBBUS;
                                 if ((unsigned(mem_bus_Adr(11 downto 0)) >= x"100") and (unsigned(mem_bus_Adr(11 downto 0)) <= x"10C")) then
                                    wait_timer <= 7;
                                 end if;
                              else
                                 state <= READ_UNREADABLE;
                              end if;
                              
                           when x"5" =>
                              PALETTE_BG_addr   <= to_integer(unsigned(mem_bus_Adr(8 downto 2)));
                              PALETTE_OAM_addr  <= to_integer(unsigned(mem_bus_Adr(8 downto 2)));
                              state             <= READPALETTERAM;   
                              
                           when x"6" =>
                              VRAM_Hi_addr   <= to_integer(unsigned(mem_bus_Adr(14 downto 2)));
                              VRAM_Lo_addr   <= to_integer(unsigned(mem_bus_Adr(15 downto 2)));
                              state          <= READVRAM; 
   
                           when x"7" =>
                              OAMRAM_PROC_addr <= to_integer(unsigned(mem_bus_Adr(9 downto 2)));
                              state         <= READOAMRAM;  
   
                           when x"8" | x"9" | x"A" | x"B" | x"C" =>
                              --bus_out_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_Gamerom.adr, busadr_bits) + unsigned(mem_bus_Adr(24 downto 2)));
                              --bus_out_rnw  <= '1';
                              --bus_out_ena  <= '1';
                              --state             <= WAIT_PROCBUS;
                              if (unsigned(mem_bus_Adr(24 downto 2)) >= unsigned(MaxPakAddr)) then
                                 state       <= READAFTERPAK;
                              elsif (sdram_addr_buf = mem_bus_Adr(24 downto 3) and mem_bus_Adr(0) = '0' and mem_bus_acc = ACCESS_16BIT) then
                                 mem_bus_done <= '1'; 
                                 if (mem_bus_Adr(2) = '0') then
                                    if (mem_bus_Adr(1) = '0') then
                                       mem_bus_din <= x"0000" & sdram_data_buf(15 downto 0);
                                    else
                                       mem_bus_din <= x"0000" & sdram_data_buf(31 downto 16);
                                    end if;
                                 else
                                    if (mem_bus_Adr(1) = '0') then
                                       mem_bus_din <= x"0000" & sdram_data_buf(47 downto 32);
                                    else
                                       mem_bus_din <= x"0000" & sdram_data_buf(63 downto 48);
                                    end if;
                                 end if;
                              elsif (sdram_addr_buf = mem_bus_Adr(24 downto 3) and mem_bus_Adr(1 downto 0) = "00" and mem_bus_acc = ACCESS_32BIT) then
                                 mem_bus_done <= '1';
                                 if (mem_bus_Adr(2) = '0') then
                                    mem_bus_din <= sdram_data_buf(31 downto 0);
                                 else
                                    mem_bus_din <= sdram_data_buf(63 downto 32);
                                 end if;
                              else
                                 cache_read_enable <= '1';
                                 if (memory_remap = '1') then
                                    cache_read_addr   <= "00000" & mem_bus_Adr(19 downto 2);
                                 else
                                    cache_read_addr   <= mem_bus_Adr(24 downto 2);
                                 end if;
                                 state             <= WAIT_SDRAM;
                              end if;
                              if (specialmodule = '1') then
                                 if (unsigned(mem_bus_Adr(27 downto 0)) >= 16#80000C4# and unsigned(mem_bus_Adr(27 downto 0)) <= 16#80000C8#) then
                                    state             <= READ_GPIO;
                                    mem_bus_done      <= '0';
                                    cache_read_enable <= '0';
                                    GPIO_readEna      <= '1';
                                    GPIO_addr         <= std_logic_vector(to_unsigned(to_integer(unsigned(mem_bus_Adr(3 downto 1))) - 4 / 2, 2));
                                 end if;
                              end if;
                           
                           when x"D" =>
                              state            <= EEPROMREAD;  
   
                           when x"E" | x"F" =>
                              if (SramFlashEnable = '1') then
                                 state                <= FLASHREAD; 
                                 adr_save(1 downto 0) <= mem_bus_Adr(1 downto 0) or bus_lowbits;
                                 if (mem_bus_acc = ACCESS_16BIT and (mem_bus_Adr(0) or bus_lowbits(0)) = '1') then
                                    return_rotate        <= "01";
                                 else
                                    return_rotate        <= "00";
                                 end if;
                              else
                                 state <= READ_UNREADABLE;
                              end if;
                           
                           when others => state <= READ_UNREADABLE; --report "reading here not implemented!" severity failure;
                           
                        end case;
                        
                     end if;
                     
                  else -- write
                  
                     read_operation   <= '0';
                     
                     if (mem_bus_Adr(31 downto 28) /= x"0") then

                        mem_bus_done <= '1';
                        
                     else
                     
                        case (mem_bus_Adr(27 downto 24)) is
                           when x"2" => 
                              if (mem_bus_acc = ACCESS_32BIT) then
                                 state <= WRITE_WRAMLARGE;
                              else
                                 bus_out_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_WRam_ADDR, busadr_bits) + unsigned(mem_bus_Adr(17 downto 2)));
                                 bus_out_rnw  <= '1';
                                 bus_out_ena  <= '1';
                                 state             <= WAIT_WRAMREADMODIFYWRITE;
                              end if;
                               
                           -- done is ok, if the next state goes back to idle without conditions
                           when x"3" => state <= WRITE_WRAMSMALL; mem_bus_done <= '1'; 
                           
                           when x"4" => 
                              state <= WRITE_REG;
                              registersettle_cnt <= 7;
                              registersettle     <= '1';
                           
                           when x"5" => state <= WRITE_PALETTE;   mem_bus_done <= '1';
                           when x"6" => state <= WRITE_VRAM;      mem_bus_done <= not vram_blocked or mem_bus_Adr(16); vramwait <= vram_blocked;
                           when x"7" => state <= WRITE_OAM;       mem_bus_done <= '1';
                           when x"8" =>
                              mem_bus_done <= '1';
                              if (specialmodule = '1') then
                                 if (unsigned(mem_bus_Adr(27 downto 0)) >= 16#80000C4# and unsigned(mem_bus_Adr(27 downto 0)) <= 16#80000C8#) then
                                    GPIO_writeEna <= '1';
                                    GPIO_addr     <= std_logic_vector(to_unsigned(to_integer(unsigned(mem_bus_Adr(3 downto 1))) - 4 / 2, 2));
                                    GPIO_Dout     <= mem_bus_dout(3 downto 0);
                                 end if;
                              end if;
                           
                           when x"D" => state <= EEPROMWRITE;  
                           when x"E" | x"F" => state <= FLASHSRAMWRITEDECIDE1; adr_save(1 downto 0) <= mem_bus_Adr(1 downto 0) or bus_lowbits;
                           when others => mem_bus_done <= '1'; --report "writing here not implemented!" severity failure;
                        end case;
                     
                     end if;
                     
                     rotate_writedata <= mem_bus_dout; -- default, full dword
                     if (mem_bus_acc = ACCESS_8BIT) then
                        case(mem_bus_Adr(1 downto 0)) is
                           when "00" => rotate_writedata( 7 downto  0) <= mem_bus_dout(7 downto 0);
                           when "01" => rotate_writedata(15 downto  8) <= mem_bus_dout(7 downto 0);
                           when "10" => rotate_writedata(23 downto 16) <= mem_bus_dout(7 downto 0);
                           when "11" => rotate_writedata(31 downto 24) <= mem_bus_dout(7 downto 0);
                           when others => null;
                        end case;
                     elsif (mem_bus_acc = ACCESS_16BIT and mem_bus_Adr(1) = '1') then
                        rotate_writedata(31 downto 16) <= mem_bus_dout(15 downto 0);
                     end if;
               
                  end if;
               
               end if;
               
            -- reading
               
            when READBIOS => 
               bios_data_last <= bios_data;
               if (acc_save = ACCESS_8BIT or acc_save = ACCESS_16BIT) then
                  rotate_data  <= bios_data;
                  state        <= ROTATE;
               else
                  mem_bus_done <= '1'; 
                  state <= IDLE;
                  case (return_rotate) is
                     when "00" => mem_bus_din <= bios_data;
                     when "01" => mem_bus_din <= bios_data(7 downto 0) & bios_data(31 downto 8);
                     when "10" => mem_bus_din <= bios_data(15 downto 0) & bios_data(31 downto 16);
                     when "11" => mem_bus_din <= bios_data(23 downto 0) & bios_data(31 downto 24);
                     when others => null;
                  end case;
               end if;
               
            when READSMALLRAM =>
               if (acc_save = ACCESS_8BIT) then
                  rotate_data  <= smallram_DataOut;
                  state        <= ROTATE;
               elsif (acc_save = ACCESS_16BIT) then
                  mem_bus_done <= '1'; 
                  state <= IDLE;
                  case (return_rotate) is
                     when "00" => mem_bus_din <= x"0000" & smallram_DataOut(15 downto 0);
                     when "01" => mem_bus_din <= smallram_DataOut(7 downto 0) & x"0000" & smallram_DataOut(15 downto 8);
                     when "10" => mem_bus_din <= x"0000" & smallram_DataOut(31 downto 16);
                     when "11" => mem_bus_din <= smallram_DataOut(23 downto 16) & x"0000" & smallram_DataOut(31 downto 24);
                     when others => null;
                  end case;
               else
                  mem_bus_done <= '1'; 
                  state <= IDLE;
                  case (return_rotate) is
                     when "00" => mem_bus_din <= smallram_DataOut;
                     when "01" => mem_bus_din <= smallram_DataOut(7 downto 0) & smallram_DataOut(31 downto 8);
                     when "10" => mem_bus_din <= smallram_DataOut(15 downto 0) & smallram_DataOut(31 downto 16);
                     when "11" => mem_bus_din <= smallram_DataOut(23 downto 0) & smallram_DataOut(31 downto 24);
                     when others => null;
                  end case;
               end if;
               
            when READPALETTERAM =>
               state <= PALETTEDONE;
            when PALETTEDONE =>
               if (adr_save(9) = '1') then
                  rotate_data  <= PALETTE_OAM_dataout;
               else
                  rotate_data  <= PALETTE_BG_dataout;
               end if;
               state        <= ROTATE;
            
            when READVRAM =>
               state <= VRAMDONE;
            when VRAMDONE =>
               if (adr_save(16) = '1') then
                  rotate_data  <= VRAM_Hi_dataout;
               else
                  rotate_data  <= VRAM_Lo_dataout;
               end if;
               state        <= ROTATE;

            when READOAMRAM =>
               state <= OAMDONE;
            when OAMDONE =>
               rotate_data  <= OAMRAM_PROC_dataout;
               state        <= ROTATE;               
               
            when WAIT_GBBUS =>
               if (wait_timer > 0) then
                  wait_timer <= wait_timer - 1;
               else
                  if (gb_bus_out.done /= '0') then
                     if (read_operation = '1') then
                        if (is_simu = '0') then
                           rotate_data <= gb_bus_out.Dout;
                        else
                           for i in 0 to 31 loop
                              if (gb_bus_out.Dout(i) = '1') then rotate_data(i) <= '1'; else rotate_data(i) <= '0'; end if;
                           end loop;
                        end if;
                        state <= rotate;
                     else
                        mem_bus_done <= '1'; 
                        state <= IDLE;
                     end if;
                  else
                     if (read_operation = '1') then
                        state <= READ_UNREADABLE;
                     else
                        mem_bus_done <= '1'; 
                        state <= IDLE;
                     end if;
                  end if;
               end if;
               
            when WAIT_PROCBUS =>
               if (bus_out_done = '1') then
                  if (read_operation = '1') then
                     rotate_data  <= bus_out_Dout;
                     state        <= ROTATE;
                  else
                     mem_bus_done <= '1'; 
                     state <= IDLE;
                  end if;
               end if;
               
            when WAIT_SDRAM =>
               if (sdram_read_done = '1') then
                  if (read_operation = '1') then
                     sdram_addr_buf <= adr_save(24 downto 3);
                     if (acc_save = ACCESS_8BIT) then
                        rotate_data  <= sdram_read_data;
                        state        <= ROTATE;
                     elsif (acc_save = ACCESS_16BIT) then
                        mem_bus_done <= '1'; 
                        state <= IDLE;
                        case (return_rotate) is
                           when "00" => mem_bus_din <= x"0000" & sdram_read_data(15 downto 0);
                           when "01" => mem_bus_din <= sdram_read_data(7 downto 0) & x"0000" & sdram_read_data(15 downto 8);
                           when "10" => mem_bus_din <= x"0000" & sdram_read_data(31 downto 16);
                           when "11" => mem_bus_din <= sdram_read_data(23 downto 16) & x"0000" & sdram_read_data(31 downto 24);
                           when others => null;
                        end case;
                     else
                        mem_bus_done <= '1'; 
                        state <= IDLE;
                        case (return_rotate) is
                           when "00" => mem_bus_din <= sdram_read_data;
                           when "01" => mem_bus_din <= sdram_read_data(7 downto 0)  & sdram_read_data(31 downto 8);
                           when "10" => mem_bus_din <= sdram_read_data(15 downto 0) & sdram_read_data(31 downto 16);
                           when "11" => mem_bus_din <= sdram_read_data(23 downto 0) & sdram_read_data(31 downto 24);
                           when others => null;
                        end case;
                     end if;
                  else
                     mem_bus_done <= '1'; 
                     state <= IDLE;
                  end if;
               end if;
               if (cache_read_done = '1') then
                  sdram_addr_buf <= adr_save(24 downto 3);
                  sdram_data_buf <= cache_read_full;
                  if (acc_save = ACCESS_8BIT) then
                     rotate_data  <= cache_read_data;
                     state        <= ROTATE;
                  elsif (acc_save = ACCESS_16BIT) then
                     mem_bus_done <= '1'; 
                     state <= IDLE;
                     case (return_rotate) is
                        when "00" => mem_bus_din <= x"0000" & cache_read_data(15 downto 0);
                        when "01" => mem_bus_din <= cache_read_data(7 downto 0) & x"0000" & cache_read_data(15 downto 8);
                        when "10" => mem_bus_din <= x"0000" & cache_read_data(31 downto 16);
                        when "11" => mem_bus_din <= cache_read_data(23 downto 16) & x"0000" & cache_read_data(31 downto 24);
                        when others => null;
                     end case;
                  else
                     mem_bus_done <= '1'; 
                     state <= IDLE;
                     case (return_rotate) is
                        when "00" => mem_bus_din <= cache_read_data;
                        when "01" => mem_bus_din <= cache_read_data(7 downto 0)  & cache_read_data(31 downto 8);
                        when "10" => mem_bus_din <= cache_read_data(15 downto 0) & cache_read_data(31 downto 16);
                        when "11" => mem_bus_din <= cache_read_data(23 downto 0) & cache_read_data(31 downto 24);
                        when others => null;
                     end case;
                  end if;
               end if;
               
            when READAFTERPAK =>
               rotate_data <= adr_save(16 downto 2) & "1" & adr_save(16 downto 2) & "0";
               state       <= ROTATE; 
               
            when READ_UNREADABLE =>
               if (last_access_dma = '1') then
                  rotate_data <= lastread_dma;
               else
                  rotate_data <= lastread;
               end if;
               state       <= ROTATE; 
               unread_next <= '1';               
               
            when ROTATE =>
               if (acc_save = ACCESS_8BIT) then
                  case (return_rotate) is
                     when "00" => mem_bus_din <= x"000000" & rotate_data(7 downto 0);
                     when "01" => mem_bus_din <= x"000000" & rotate_data(15 downto 8);
                     when "10" => mem_bus_din <= x"000000" & rotate_data(23 downto 16);
                     when "11" => mem_bus_din <= x"000000" & rotate_data(31 downto 24);
                     when others => null;
                  end case;
               elsif (acc_save = ACCESS_16BIT) then
                  case (return_rotate) is
                     when "00" => mem_bus_din <= x"0000" & rotate_data(15 downto 0);
                     when "01" => mem_bus_din <= rotate_data(7 downto 0) & x"0000" & rotate_data(15 downto 8);
                     when "10" => mem_bus_din <= x"0000" & rotate_data(31 downto 16);
                     when "11" => mem_bus_din <= rotate_data(23 downto 16) & x"0000" & rotate_data(31 downto 24);
                     when others => null;
                  end case;
               else
                  case (return_rotate) is
                     when "00" => mem_bus_din <= rotate_data;
                     when "01" => mem_bus_din <= rotate_data(7 downto 0) & rotate_data(31 downto 8);
                     when "10" => mem_bus_din <= rotate_data(15 downto 0) & rotate_data(31 downto 16);
                     when "11" => mem_bus_din <= rotate_data(23 downto 0) & rotate_data(31 downto 24);
                     when others => null;
                  end case;
               end if;
               mem_bus_done   <= '1'; 
               mem_bus_unread <= unread_next;
               state <= IDLE;
               
            when READ_GPIO =>
               if (GPIO_done = '1') then
                  mem_bus_done   <= '1'; 
                  mem_bus_din    <= x"0000000" & GPIO_Din;
                  state <= IDLE;
               end if;
               
            
            ----- writing
            
            when WAIT_WRAMREADMODIFYWRITE =>
               if (bus_out_done = '1') then
                  state            <= WRITE_WRAMLARGE;
                  rotate_writedata <= bus_out_Dout;
                  if (acc_save = ACCESS_8BIT) then
                     case(adr_save(1 downto 0)) is
                        when "00" => rotate_writedata( 7 downto  0) <= Dout_save(7 downto 0);
                        when "01" => rotate_writedata(15 downto  8) <= Dout_save(7 downto 0);
                        when "10" => rotate_writedata(23 downto 16) <= Dout_save(7 downto 0);
                        when "11" => rotate_writedata(31 downto 24) <= Dout_save(7 downto 0);
                        when others => null;
                     end case;
                  else
                     if (adr_save(1) = '1') then
                        rotate_writedata(31 downto 16) <= Dout_save(15 downto 0);
                     else
                        rotate_writedata(15 downto  0) <= Dout_save(15 downto 0);
                     end if;
                  end if;
               end if;
            
            when WRITE_WRAMLARGE =>
               bus_out_Din  <= rotate_writedata;
               bus_out_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_WRam_ADDR, busadr_bits) + unsigned(adr_save(17 downto 2)));
               bus_out_rnw  <= '0';
               bus_out_ena  <= '1';
               state        <= WAIT_PROCBUS;
            
            when WRITE_WRAMSMALL =>
               smallram_addr_w  <= to_integer(unsigned(adr_save(14 downto 2)));
               state <= IDLE;
               if (acc_save = ACCESS_8BIT) then
                  case(adr_save(1 downto 0)) is
                     when "00" => smallram_we(0) <= '1';
                     when "01" => smallram_we(1) <= '1';
                     when "10" => smallram_we(2) <= '1';
                     when "11" => smallram_we(3) <= '1';
                     when others => null;
                  end case;
               elsif (acc_save = ACCESS_16BIT) then
                  if (adr_save(1) = '1') then
                     smallram_we(2) <= '1';
                     smallram_we(3) <= '1';
                  else                                                               
                     smallram_we(0) <= '1';
                     smallram_we(1) <= '1';
                  end if;
               else
                  smallram_we <= (others => '1');
               end if;
                  
            when WRITE_REG =>
               if (unsigned(adr_save) < x"4000400") then
                  gb_bus_out.adr <= (gb_bus_out.adr'left downto 12 => '0') & adr_save(11 downto 2) & "00";
                  gb_bus_out.Din <= rotate_writedata;
                  gb_bus_out.acc <= acc_save;
                  gb_bus_out.rnw <= '0';
                  gb_bus_out.ena <= '1';
                  case (acc_save) is
                     when ACCESS_8BIT  => 
                        case (adr_save(1 downto 0)) is
                           when "00" => gb_bus_out.BEna <= "0001";
                           when "01" => gb_bus_out.BEna <= "0010";
                           when "10" => gb_bus_out.BEna <= "0100";
                           when "11" => gb_bus_out.BEna <= "1000";
                           when others => null;
                        end case;
                     when ACCESS_16BIT => 
                        if (adr_save(1) = '1') then
                           gb_bus_out.BEna <= "1100";
                        else
                           gb_bus_out.BEna <= "0011";
                        end if;
                     when ACCESS_32BIT => gb_bus_out.BEna <= "1111";
                     when others => null;
                  end case;
                  state <= WAIT_GBBUS;
               else
                  mem_bus_done <= '1'; 
                  state <= IDLE;
               end if;
            
            -- Writing 8bit Data to Video Memory
            -- Video Memory(BG, OBJ, OAM, Palette) can be written to in 16bit and 32bit units only.Attempts to write 8bit data(by STRB opcode) won't work:
            -- Writes to OBJ(6010000h - 6017FFFh)(or 6014000h - 6017FFFh in Bitmap mode) and to OAM(7000000h - 70003FFh) are ignored, the memory content remains unchanged.
            -- Writes to BG(6000000h - 600FFFFh)(or 6000000h - 6013FFFh in Bitmap mode) and to Palette(5000000h - 50003FFh) are writing the new 8bit value to BOTH upper and lower 8bits of the addressed halfword, ie. "[addr AND NOT 1]=data*101h".
            
            when WRITE_PALETTE =>
               PALETTE_BG_addr     <= to_integer(unsigned(adr_save(8 downto 2)));
               PALETTE_OAM_addr    <= to_integer(unsigned(adr_save(8 downto 2)));
               PALETTE_BG_datain   <= rotate_writedata;
               PALETTE_OAM_datain  <= rotate_writedata;
               if (acc_save = ACCESS_8BIT) then
                  PALETTE_BG_datain(15 downto 8)  <= rotate_writedata(7 downto 0);
                  PALETTE_OAM_datain(15 downto 8) <= rotate_writedata(7 downto 0);
               end if;
               state <= IDLE;
               palette_we := "0000";
               if (acc_save = ACCESS_8BIT) then
                  case(adr_save(1 downto 0)) is
                     when "00" => palette_we(0) := '1'; palette_we(1) := '1';
                     when "01" => palette_we(1) := '1'; palette_we(0) := '1';
                     when "10" => palette_we(2) := '1'; palette_we(3) := '1';
                     when "11" => palette_we(3) := '1'; palette_we(2) := '1';
                     when others => null;
                  end case;
               elsif (acc_save = ACCESS_16BIT) then
                  if (adr_save(1) = '1') then
                     palette_we(2) := '1';
                     palette_we(3) := '1';
                  else                                                               
                     palette_we(0) := '1';
                     palette_we(1) := '1';
                  end if;
               else
                  palette_we := (others => '1');
               end if;
               if (adr_save(9) = '1') then
                  PALETTE_OAM_we <= palette_we;
               else
                  PALETTE_BG_we <= palette_we;
               end if;
               
               
            when WRITE_VRAM =>
               VRAM_Hi_addr   <= to_integer(unsigned(adr_save(14 downto 2)));
               VRAM_Lo_addr   <= to_integer(unsigned(adr_save(15 downto 2)));
               VRAM_Hi_datain <= rotate_writedata;
               VRAM_Lo_datain <= rotate_writedata;
               if (acc_save = ACCESS_8BIT) then
                  case (to_integer(unsigned(adr_save(1 downto 0)))) is
                     when 0 => VRAM_Hi_datain(15 downto  8) <= rotate_writedata( 7 downto  0); VRAM_Lo_datain(15 downto  8) <= rotate_writedata( 7 downto  0);
                     when 1 => VRAM_Hi_datain( 7 downto  0) <= rotate_writedata(15 downto  8); VRAM_Lo_datain( 7 downto  0) <= rotate_writedata(15 downto  8);
                     when 2 => VRAM_Hi_datain(31 downto 24) <= rotate_writedata(23 downto 16); VRAM_Lo_datain(31 downto 24) <= rotate_writedata(23 downto 16);
                     when 3 => VRAM_Hi_datain(23 downto 16) <= rotate_writedata(31 downto 24); VRAM_Lo_datain(23 downto 16) <= rotate_writedata(31 downto 24);
                     when others => null;
                  end case;
               end if;
               state <= IDLE;
               VRAM_be := (others => '0');
               if (acc_save = ACCESS_8BIT) then
                  -- maybe also just check like 16/32 bit?
                  if ((bitmapdrawmode = '0' and unsigned(adr_save(16 downto 0)) <= 16#FFFF#) or (bitmapdrawmode = '1' and unsigned(adr_save(16 downto 0)) <= 16#13FFF#)) then
                     case(adr_save(1 downto 0)) is
                        when "00" => VRAM_be(0) := '1'; VRAM_be(1) := '1';
                        when "01" => VRAM_be(1) := '1'; VRAM_be(0) := '1';
                        when "10" => VRAM_be(2) := '1'; VRAM_be(3) := '1';
                        when "11" => VRAM_be(3) := '1'; VRAM_be(2) := '1';
                        when others => null;
                     end case;
                  end if;
               elsif (acc_save = ACCESS_16BIT) then
                  if ((bitmapdrawmode = '0' or unsigned(adr_save(16 downto 14)) /= "110")) then
                     if (adr_save(1) = '1') then
                        VRAM_be(2) := '1';
                        VRAM_be(3) := '1';
                     else                                                               
                        VRAM_be(0) := '1';
                        VRAM_be(1) := '1';
                     end if;
                  end if;
               else
                  if ((bitmapdrawmode = '0' or unsigned(adr_save(16 downto 14)) /= "110")) then
                     VRAM_be := (others => '1');
                  end if;
               end if;
               VRAM_Hi_be <= VRAM_be;
               VRAM_Lo_be <= VRAM_be;
               if (adr_save(16) = '1') then
                  VRAM_Hi_we <= '1';
               else
                  VRAM_Lo_we <= '1';
                  if (vramwait = '1') then
                     state        <= VRAMWAITWRITE;
                  end if;
               end if;
               
            when VRAMWAITWRITE =>
               if (vram_blocked = '0') then
                  state        <= IDLE;
                  mem_bus_done <= '1';
               else
                  vram_cycle <= '1';
               end if;
               
            when WRITE_OAM =>
               OAMRAM_PROC_addr   <= to_integer(unsigned(adr_save(9 downto 2)));
               OAMRAM_PROC_datain <= rotate_writedata;
               state <= IDLE;
               if (acc_save = ACCESS_8BIT) then
                  OAMRAM_PROC_we <= (others => '0'); -- dont write bytes
               elsif (acc_save = ACCESS_16BIT) then
                  if (adr_save(1) = '1') then
                     OAMRAM_PROC_we(2) <= '1';
                     OAMRAM_PROC_we(3) <= '1';
                  else                                                               
                     OAMRAM_PROC_we(0) <= '1';
                     OAMRAM_PROC_we(1) <= '1';
                  end if;
               else
                  OAMRAM_PROC_we <= (others => '1');
               end if;
               
            when EEPROMREAD =>
               case (eepromMode) is
                  when EEPROM_IDLE | EEPROM_READADDRESS | EEPROM_WRITEDATA =>
                     rotate_data <= x"00000001";
                     state       <= rotate;
                     
                  when EEPROM_READDATA =>
                        if (eepromBits < 3) then
                           eepromBits <= eepromBits + 1;
                        else
                           eepromMode <= EEPROM_READDATA2;
                           eepromBits <= (others => '0');
                           eepromByte <= (others => '0');
                        end if;
                        rotate_data <= (others => '0');
                        state       <= rotate;
                        
                  when EEPROM_READDATA2 =>
                     state <= EEPROM_WAITREAD;
                     bus_out_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_EEPROM_ADDR, busadr_bits) + eepromAddress * 8 + eepromByte);
                     bus_out_rnw  <= '1';
                     bus_out_ena  <= '1';  
                     eeprombitpos <= 7 - to_integer((eepromBits(2 downto 0)));
                     eepromBits <= eepromBits + 1;
                     if (eepromBits(2 downto 0) = "111") then
                        eepromByte <= eepromByte + 1;
                     end if;
                     if (eepromBits = x"3F") then
                        eepromMode <= EEPROM_IDLE;
                     end if;

                  when others => 
                     rotate_data <= (others => '0');
                     state       <= rotate;
                end case;
                
            when EEPROM_WAITREAD =>
               if (bus_out_done = '1') then
                  rotate_data    <= (others => '0');
                  state          <= rotate;
                  if (bus_out_Dout(eeprombitpos) = '1') then 
                     if (adr_save(1) = '1') then
                        rotate_data(16) <= '1';
                     else
                        rotate_data(0) <= '1'; 
                     end if;
                  end if;
               end if;
            
            when EEPROMWRITE => 
               if (dma_eepromcount = 0) then
                  state        <= IDLE;
                  mem_bus_done <= '1';
               else
                  case (eepromMode) is
                     when EEPROM_IDLE =>
                        eepromByte   <= (others => '0');
                        eepromBits   <= to_unsigned(1, eepromBits'length);
                        eepromBuffer <= "0000000" & rotate_writedata(0);
                        eepromMode   <= EEPROM_READADDRESS;
                        state        <= IDLE;
                        mem_bus_done <= '1';
 
                     when EEPROM_READADDRESS =>
                        state        <= IDLE;
                        mem_bus_done <= '1';
                        eepromBuffer <= eepromBuffer(6 downto 0) & rotate_writedata(0);
                        eepromBits   <= eepromBits + 1;
                        if (eepromBits(2 downto 0) = "111") then
                           eepromByte <= eepromByte + 1;
                        end if;
                        
                        if (eepromBits = 1) then
                           eeprom_rnw <= rotate_writedata(0);
                        end if;
                       
                        if (dma_eepromcount = 16#11# or dma_eepromcount = 16#51#) then
                           if (eepromBits >= 2 and eepromBits <= 15) then
                              eepromAddress <= eepromAddress(8 downto 0) & rotate_writedata(0);
                           end if;
                        else
                           if (eepromBits >= 2 and eepromBits <= 7) then
                              eepromAddress <= "0000" & eepromAddress(4 downto 0) & rotate_writedata(0);
                           end if;
                        end if;
                        
                        if ((dma_eepromcount = 16#11# or dma_eepromcount = 16#51#) and eepromBits = 16) or 
                           ((dma_eepromcount /= 16#11# and dma_eepromcount /= 16#51#) and eepromBits = 8)
                        then
                           --eepromInUse = true;
                           if (eeprom_rnw = '0') then
                              eepromBuffer <= "0000000" & rotate_writedata(0);
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
                        mem_bus_done <= '1';
                        
                     when EEPROM_WRITEDATA =>
                        eepromBuffer <= eepromBuffer(6 downto 0) & rotate_writedata(0);
                        eepromBits   <= eepromBits + 1;
                        if (eepromBits(2 downto 0) = "000") then
                           eepromByte <= eepromByte + 1;
                           bus_out_Din  <= x"000000" & eepromBuffer;
                           bus_out_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_EEPROM_ADDR, busadr_bits) + eepromAddress * 8 + eepromByte);
                           bus_out_rnw  <= '0';
                           bus_out_ena  <= '1';
                           save_eeprom  <= '1';
                           state        <= WAIT_PROCBUS;
                        else
                           state        <= IDLE;
                           mem_bus_done <= '1';
                        end if;
                        
                        if (eepromBits = 16#40#) then
                           eepromMode <= EEPROM_IDLE;
                           eepromByte <= (others => '0');
                           eepromBits <= (others => '0');
                        end if;

                  end case;
               end if;
            
            when FLASHREAD =>
               state       <= rotate;
               rotate_data <= (others => '0');
               
               if (tilt = '1') then
               
                  if (adr_save = x"E008200") then rotate_data(7 downto 0) <= std_logic_vector(tilt_x( 7 downto 0)); end if;
                  if (adr_save = x"E008300") then rotate_data(3 downto 0) <= std_logic_vector(tilt_x(11 downto 8)); rotate_data(7) <= '1'; end if; -- bit 7 for sampling done
                  if (adr_save = x"E008400") then rotate_data(7 downto 0) <= std_logic_vector(tilt_y( 7 downto 0)); end if;
                  if (adr_save = x"E008500") then rotate_data(3 downto 0) <= std_logic_vector(tilt_y(11 downto 8)); end if;
               
               else
               
                  case (flashReadState) is
                     when FLASH_READ_ARRAY =>
                        state <= FLASH_WAITREAD;
                        bus_out_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits) + unsigned((flashBank & adr_save(15 downto 0))));
                        bus_out_rnw  <= '1';
                        bus_out_ena  <= '1'; 
                        
                     when FLASH_AUTOSELECT => 
                        if (adr_save(7 downto 0) = x"00") then
                           rotate_data <= flashManufacturerID & flashManufacturerID & flashManufacturerID & flashManufacturerID;
                        elsif (adr_save(7 downto 0) = x"01") then
                           rotate_data <= flashDeviceID & flashDeviceID & flashDeviceID & flashDeviceID;
                        end if;
                        
                     when FLASH_ERASE_COMPLETE =>
                        flashState     <= FLASH_READ_ARRAY;
                        flashReadState <= FLASH_READ_ARRAY;
                        rotate_data    <= (others => '1');
                        
                     when others => null;
                  end case;
               
               end if;
               
            when FLASH_WAITREAD =>
               if (bus_out_done = '1') then
                  rotate_data( 7 downto  0) <= bus_out_Dout(7 downto 0);
                  if (acc_save = ACCESS_16BIT or acc_save = ACCESS_32BIT) then
                     rotate_data(15 downto  8) <= bus_out_Dout(7 downto 0);
                  end if;
                  if (acc_save = ACCESS_32BIT) then
                     rotate_data(23 downto 16) <= bus_out_Dout(7 downto 0);
                     rotate_data(31 downto 24) <= bus_out_Dout(7 downto 0);
                  end if;
                  state          <= rotate;
               end if;
            
            when FLASHSRAMWRITEDECIDE1 =>
               state           <= FLASHSRAMWRITEDECIDE2;
               flashSRamdecide <= '1';
               if (flashSRamdecide = '0' and adr_save = x"e005555") then
                   flashNotSRam <= '1';
               end if;
               
            when FLASHSRAMWRITEDECIDE2 =>
               if (flashNotSRam = '1') then
                  state <= FLASHWRITE;
               else
                  state <= SRAMWRITE;
               end if;
            
            when SRAMWRITE => 
               bus_out_Din  <= x"000000" & Dout_save(7 downto 0);
               bus_out_Adr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits) + unsigned(adr_save(15 downto 0)));
               bus_out_rnw  <= '0';
               bus_out_ena  <= '1'; 
               save_sram    <= '1';
               state        <= WAIT_PROCBUS;
            
            when FLASHWRITE =>
               -- only default, maybe overwritten
               state        <= IDLE;
               mem_bus_done <= '1';
            
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
                        flash_saveaddr(11 downto  0) <= x"000";
                        flash_saveaddr(15 downto 12) <= adr_save(15 downto 12);
                        flash_saveaddr(16) <= flashBank;
                        flash_savecount <= 4096;
                        flash_savedata  <= (others => '1');
                        state           <= FLASH_WRITEBLOCK;
                        mem_bus_done    <= '0';
                        flashReadState <= FLASH_ERASE_COMPLETE;
                     elsif (Dout_save(7 downto 0) = x"10") then -- CHIP ERASE
                        flash_saveaddr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits));
                        flash_savecount <= 131072;
                        flash_savedata  <= (others => '1');
                        state           <= FLASH_WRITEBLOCK;
                        mem_bus_done    <= '0';
                        flashReadState <= FLASH_ERASE_COMPLETE;
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
                     flash_saveaddr  <= std_logic_vector(to_unsigned(Softmap_GBA_FLASH_ADDR, busadr_bits) + unsigned((flashBank & adr_save(15 downto 0))));
                     flash_savecount <= 1;
                     flash_savedata  <= Dout_save(7 downto 0);
                     state           <= FLASH_WRITEBLOCK;
                     mem_bus_done    <= '0';
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
               bus_out_Din       <= x"000000" & flash_savedata;
               bus_out_Adr       <= flash_saveaddr;
               bus_out_rnw       <= '0';
               bus_out_ena       <= '1';
               save_flash        <= '1';               
               state             <= FLASH_BLOCKWAIT;
               flash_saveaddr    <= std_logic_vector(unsigned(flash_saveaddr) + 1);
               flash_savecount   <= flash_savecount - 1;
            
            when FLASH_BLOCKWAIT =>
               if (bus_out_done = '1') then
                  if (flash_savecount = 0) then
                     state        <= IDLE;
                     mem_bus_done <= '1';
                  else
                     state <= FLASH_WRITEBLOCK;
                  end if;
               end if;
               
         end case;
      
      end if;
   end process;
   

end architecture;





