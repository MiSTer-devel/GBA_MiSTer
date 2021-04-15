library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library MEM;

use work.pProc_bus_gba.all;

entity gba_savestates is
   generic
   (
      Softmap_GBA_WRam_ADDR    : integer; -- count:   65536  -- 256 Kbyte Data for GBA WRam Large
      Softmap_GBA_FLASH_ADDR   : integer; -- count:  131072  -- 128/512 Kbyte Data for GBA Flash
      Softmap_GBA_EEPROM_ADDR  : integer; -- count:    8192  -- 8/32 Kbyte Data for GBA EEProm 
      is_simu                  : std_logic := '0'
   );
   port 
   (
      clk100                 : in     std_logic;  
      gb_on                  : in     std_logic;
      reset                  : out    std_logic := '0';

      load_done              : out    std_logic := '0';
      
      increaseSSHeaderCount  : in     std_logic;  
      save                   : in     std_logic;  
      load                   : in     std_logic;
      savestate_address      : in     integer;
      savestate_busy         : out    std_logic;

      cpu_jump               : in     std_logic;
      
      internal_bus_out       : inout  proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
      loading_savestate      : out    std_logic := '0';
      saving_savestate       : out    std_logic := '0';
      sleep_savestate        : out    std_logic := '0';
      bus_ena_in             : in     std_logic;
      
      gb_bus                 : inout  proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
       
      SAVE_BusAddr           : buffer std_logic_vector(27 downto 0);
      SAVE_BusRnW            : out    std_logic;
      SAVE_BusACC            : out    std_logic_vector(1 downto 0);
      SAVE_BusWriteData      : out    std_logic_vector(31 downto 0);
      SAVE_Bus_ena           : out    std_logic := '0';
      
      SAVE_BusReadData       : in     std_logic_vector(31 downto 0);
      SAVE_BusReadDone       : in     std_logic;
      
      bus_out_Din            : out    std_logic_vector(63 downto 0) := (others => '0');
      bus_out_Dout           : in     std_logic_vector(63 downto 0);
      bus_out_Adr            : buffer std_logic_vector(25 downto 0) := (others => '0');
      bus_out_rnw            : out    std_logic := '0';
      bus_out_ena            : out    std_logic := '0';
      bus_out_active         : out    std_logic := '0'; 
      bus_out_be             : out    std_logic_vector(7 downto 0) := (others => '0');
      bus_out_done           : in     std_logic
   );
end entity;

architecture arch of gba_savestates is

   constant STATESIZE      : integer := 16#18346#;
   
   constant SETTLECOUNT    : integer := 100;
   constant HEADERCOUNT    : integer := 2;
   constant INTERNALSCOUNT : integer := 68;
   constant REGISTERCOUNT  : integer := 256;
   
   constant SAVETYPESCOUNT : integer := 5;
   signal savetype_counter : integer range 0 to SAVETYPESCOUNT;
   type t_savetype is record
      addr  : std_logic_vector(27 downto 0);
      count : integer;
   end record;
   type t_savetypes is array(0 to SAVETYPESCOUNT - 1) of t_savetype;
   constant savetypes : t_savetypes := 
   (
      (x"2000000", 65536),
      (x"3000000", 8192),
      --(x"4000000", 256),
      (x"5000000", 256),
      (x"6000000", 24576),
      (x"7000000", 256)
      --(x"D000000", 8192),
      --(x"E000000", 131072)
   );
   
   constant REGDEFAULTCOUNT : integer := 6;
   signal regdefault_counter : integer range 0 to REGDEFAULTCOUNT;
   type t_regdefaulttype is record
      addr  : std_logic_vector(7 downto 0);
      def   : std_logic_vector(31 downto 0);
   end record;
   type t_regdefaults is array(0 to REGDEFAULTCOUNT - 1) of t_regdefaulttype;
   constant regdefaults : t_regdefaults := 
   (
      (x"00", x"00000080"),
      (x"20", x"00000100"),
      (x"24", x"01000000"),
      (x"30", x"00000100"),
      (x"34", x"01000000"),
      (x"88", x"00000200")
   );

   type tstate is
   (
      IDLE,
      RESET_CLEAR,
      RESET_REGISTER,
      SAVE_WAITJUMP,
      SAVE_WAITSETTLE,
      SAVEINTERNALS_WAIT,
      SAVEINTERNALS_READ,
      SAVEINTERNALS_WRITE,
      SAVEREGISTER_READ,
      SAVEREGISTER_WRITE,
      SAVEMEMORY_NEXT,
      SAVEMEMORY_READ,
      SAVEMEMORY_WRITE,
      SAVESIZEAMOUNT,
      LOAD_WAITSETTLE,
      LOAD_HEADERAMOUNTCHECK,
      LOADINTERNALS_READ,
      LOADINTERNALS_WRITEFIRST,
      LOADINTERNALS_WRITE,
      LOADREGISTER_READ,
      LOADREGISTER_WRITEFIRST,
      LOADREGISTER_WRITE,
      LOADMEMORY_NEXT,
      LOADMEMORY_READ,
      LOADMEMORY_WRITEFIRST,
      LOADMEMORY_WRITE
   );
   signal state : tstate := RESET_CLEAR;
   
   signal count    : integer range 0 to 131072 := 0;
   signal maxcount : integer range 0 to 131072;
   
   signal settle   : integer range 0 to SETTLECOUNT := 0;
   
   signal gb_on_1  : std_logic := '0';
   
   signal registerram_addr_r    : integer range 0 to 255 := 0;
   signal registerram_addr_w    : integer range 0 to 255 := 0;
   signal registerram_DataOut   : std_logic_vector(31 downto 0) := (others => '0');
   signal registerram_DataIn    : std_logic_vector(31 downto 0) := (others => '0');
   signal registerram_we        : std_logic_vector(3 downto 0) := (others => '0');
   
   signal registerram_readen    : std_logic;
   signal registerram_readvalid : std_logic;
   
   signal internal_databuffer   : std_logic_vector(63 downto 0) := (others => '0');
   signal first_dword           : std_logic := '0';
   
   signal header_amount         : unsigned(31 downto 0) := (others => '0');

begin 

   SAVE_BusACC          <= ACCESS_32BIT;
   internal_bus_out.acc <= ACCESS_32BIT;
   
   internal_bus_out.bEna <= x"F";
   
   gregisterram : for i in 0 to 3 generate
      signal registerram_dout_single : std_logic_vector(7 downto 0);
      signal registerram_din_single  : std_logic_vector(7 downto 0);
   begin
      iregisterram: entity MEM.SyncRamDual
      generic map
      (
         DATA_WIDTH => 8,
         ADDR_WIDTH => 8
      )
      port map
      (
         clk        => clk100,
         
         addr_a     => registerram_addr_r,
         datain_a   => x"00",
         dataout_a  => registerram_dout_single,
         we_a       => '0',
         re_a       => '1',
                  
         addr_b     => registerram_addr_w,
         datain_b   => registerram_din_single,
         dataout_b  => open,
         we_b       => registerram_we(i),
         re_b       => '0' 
      );
      
      registerram_din_single <= registerram_DataIn(((i+1) * 8) - 1 downto (i * 8));
      registerram_DataOut(((i+1) * 8) - 1 downto (i * 8)) <= registerram_dout_single;
   end generate;
   
   savestate_busy <= '0' when state = IDLE else '1';

   process (clk100)
   begin
      if rising_edge(clk100) then
   
         SAVE_Bus_ena         <= '0';
         bus_out_ena          <= '0';
         internal_bus_out.ena <= '0';
         internal_bus_out.rst <= '0';
         reset                <= '0';
         registerram_we       <= "0000";
         registerram_readen   <= '0';
         load_done            <= '0';
         
         bus_out_be    <= x"FF";

         gb_on_1 <= gb_on;
         
         registerram_readvalid <= registerram_readen;

         case state is
         
            when IDLE =>
               savetype_counter <= 0;
               if (gb_on = '0' and gb_on_1 = '1') then
                  state                <= RESET_CLEAR;
               elsif (gb_bus.ena = '1' and gb_bus.rnw = '0') then
                  registerram_DataIn   <= gb_bus.Din;
                  registerram_addr_w   <= to_integer(unsigned(gb_bus.adr(9 downto 2)));
                  registerram_we       <= gb_bus.bEna;
               elsif (save = '1') then
                  state                <= SAVE_WAITJUMP;
                  header_amount        <= header_amount + 1;
               elsif (load = '1') then
                  state                <= LOAD_WAITSETTLE;
                  settle               <= 0;
                  sleep_savestate      <= '1';
               end if;
               
            -- #################
            -- Reset
            -- #################   
               
            when RESET_CLEAR =>
               state                <= RESET_REGISTER;
               internal_bus_out.rst <= '1';
               regdefault_counter   <= 0;
               
            when RESET_REGISTER => 
               if (regdefault_counter < REGDEFAULTCOUNT) then
                  registerram_DataIn   <= regdefaults(regdefault_counter).def;
                  registerram_addr_w   <= to_integer(unsigned("00" & regdefaults(regdefault_counter).addr(7 downto 2)));
                  registerram_we       <= "1111";
                  regdefault_counter   <= regdefault_counter + 1;
               else
                  state <= IDLE;
                  reset <= '1';
               end if;

            -- #################
            -- SAVE
            -- #################
            
            when SAVE_WAITJUMP =>
               if (cpu_jump = '1') then
                  state                <= SAVE_WAITSETTLE;
                  settle               <= 0;
                  sleep_savestate      <= '1';
               end if;
            
            when SAVE_WAITSETTLE =>
               if (bus_ena_in = '1') then
                  settle <= 0;
               elsif (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               else
                  state                <= SAVEINTERNALS_WAIT;
                  first_dword          <= '1';
                  SAVE_BusRnW          <= '1';
                  bus_out_Adr          <= std_logic_vector(to_unsigned(savestate_address + HEADERCOUNT, 26));
                  bus_out_rnw          <= '0';
                  internal_bus_out.adr <= (others => '0');
                  internal_bus_out.rnw <= '1';
                  internal_bus_out.ena <= '1';
                  count                <= 2;
                  saving_savestate     <= '1';
               end if;            
            
            when SAVEINTERNALS_WAIT =>
               if (internal_bus_out.done = '1') then
                  if (first_dword = '1') then
                     first_dword          <= '0';
                     internal_bus_out.adr <= std_logic_vector(unsigned(internal_bus_out.adr) + 1);
                     internal_bus_out.ena <= '1';
                     if (is_simu = '0') then
                        internal_databuffer(31 downto 0) <= internal_bus_out.Dout;
                     else
                        for i in 0 to 31 loop
                           if (internal_bus_out.Dout(i) = '0') then internal_databuffer(i) <= '0'; else internal_databuffer(i) <= '1'; end if;
                        end loop;
                     end if;
                  else
                     if (is_simu = '0') then
                        internal_databuffer(63 downto 32) <= internal_bus_out.Dout;
                     else
                        for i in 0 to 31 loop
                           if (internal_bus_out.Dout(i) = '0') then internal_databuffer(32 + i) <= '0'; else internal_databuffer(32 + i) <= '1'; end if;
                        end loop;
                     end if;
                     state       <= SAVEINTERNALS_READ;
                  end if;
               end if;
              
            when SAVEINTERNALS_READ =>
               if (internal_bus_out.done = '1') then
                  state          <= SAVEINTERNALS_WRITE;
                  bus_out_Din    <= internal_databuffer;
                  bus_out_ena    <= '1';
                  bus_out_active <= '1';
               end if;
            
            when SAVEINTERNALS_WRITE => 
               if (bus_out_done = '1') then
                  bus_out_active <= '0';
                  bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < INTERNALSCOUNT) then
                     state                <= SAVEINTERNALS_WAIT;
                     first_dword          <= '1';
                     count                <= count + 2;
                     internal_bus_out.adr <= std_logic_vector(unsigned(internal_bus_out.adr) + 1);
                     internal_bus_out.ena <= '1';
                  else 
                     state              <= SAVEREGISTER_READ;
                     first_dword        <= '1';
                     registerram_addr_r <= 0;
                     registerram_readen <= '1';
                     count              <= 2;
                  end if;
               end if;
            
             when SAVEREGISTER_READ =>
               if (registerram_readvalid = '1') then
                  if (first_dword = '1') then
                     first_dword              <= '0';
                     registerram_addr_r       <= registerram_addr_r + 1;
                     registerram_readen       <= '1';
                     bus_out_Din(31 downto 0) <= registerram_DataOut;
                  else
                     state                     <= SAVEREGISTER_WRITE;
                     bus_out_Din(63 downto 32) <= registerram_DataOut;
                     bus_out_ena               <= '1';
                     bus_out_active            <= '1';
                  end if;
               end if;
            
            when SAVEREGISTER_WRITE => 
               if (bus_out_done = '1') then
                  bus_out_active <= '0';
                  bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < REGISTERCOUNT) then
                     state                <= SAVEREGISTER_READ;
                     first_dword          <= '1';
                     count                <= count + 2;
                     registerram_addr_r   <= registerram_addr_r + 1;
                     registerram_readen   <= '1';
                  else 
                     state <= SAVEMEMORY_NEXT;
                  end if;
               end if;
            
            when SAVEMEMORY_NEXT =>
               if (savetype_counter < SAVETYPESCOUNT) then
                  state        <= SAVEMEMORY_READ;
                  first_dword  <= '1';
                  count        <= 2;
                  maxcount     <= savetypes(savetype_counter).count;
                  SAVE_BusAddr <= savetypes(savetype_counter).addr;
                  SAVE_Bus_ena <= '1';
               else
                  state          <= SAVESIZEAMOUNT;
                  bus_out_Adr    <= std_logic_vector(to_unsigned(savestate_address, 26));
                  bus_out_Din    <= std_logic_vector(to_unsigned(STATESIZE, 32)) & std_logic_vector(header_amount);
                  bus_out_ena    <= '1';
                  bus_out_active <= '1';
                  if (increaseSSHeaderCount = '0') then
                     bus_out_be  <= x"F0";
                  end if;
               end if;
            
            when SAVEMEMORY_READ =>
               if (SAVE_BusReadDone = '1') then
                  if (first_dword = '1') then
                     first_dword               <= '0';
                     bus_out_Din(31 downto 0)  <= SAVE_BusReadData;
                     SAVE_BusAddr              <= std_logic_vector(unsigned(SAVE_BusAddr) + 4);
                     SAVE_Bus_ena              <= '1';
                  else
                     state                      <= SAVEMEMORY_WRITE;
                     bus_out_Din(63 downto 32)  <= SAVE_BusReadData;
                     bus_out_ena                <= '1';
                     bus_out_active             <= '1';
                  end if;
               end if;
               
            when SAVEMEMORY_WRITE =>
               if (bus_out_done = '1') then
                  bus_out_active <= '0';
                  bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < maxcount) then
                     state        <= SAVEMEMORY_READ;
                     first_dword  <= '1';
                     count        <= count + 2;
                     SAVE_BusAddr <= std_logic_vector(unsigned(SAVE_BusAddr) + 4);
                     SAVE_Bus_ena <= '1';
                  else 
                     savetype_counter <= savetype_counter + 1;
                     state            <= SAVEMEMORY_NEXT;
                  end if;
               end if;
            
            when SAVESIZEAMOUNT =>
               if (bus_out_done = '1') then
                  state            <= IDLE;
                  saving_savestate <= '0';
                  sleep_savestate  <= '0';
                  bus_out_active   <= '0';
               end if;
            
            
            -- #################
            -- LOAD
            -- #################
            
            when LOAD_WAITSETTLE =>
               if (bus_ena_in = '1') then
                  settle <= 0;
               elsif (settle < SETTLECOUNT) then
                  settle <= settle + 1;
               else
                  state                <= LOAD_HEADERAMOUNTCHECK;
                  bus_out_Adr          <= std_logic_vector(to_unsigned(savestate_address, 26));
                  bus_out_rnw          <= '1';
                  bus_out_ena          <= '1';
                  bus_out_active       <= '1';
               end if;
               
            when LOAD_HEADERAMOUNTCHECK =>
               if (bus_out_done = '1') then
                  bus_out_active       <= '0';
                  if (bus_out_Dout(63 downto 32) = std_logic_vector(to_unsigned(STATESIZE, 32))) then
                     header_amount        <= unsigned(bus_out_Dout(31 downto 0));
                     state                <= LOADINTERNALS_READ;
                     SAVE_BusRnW          <= '0';
                     bus_out_Adr          <= std_logic_vector(to_unsigned(savestate_address + HEADERCOUNT, 26));
                     bus_out_rnw          <= '1';
                     bus_out_ena          <= '1';
                     bus_out_active       <= '1';
                     internal_bus_out.adr <= (others => '0');
                     internal_bus_out.rnw <= '0';
                     count                <= 2;
                     loading_savestate    <= '1';
                  else
                     state                <= IDLE;
                     sleep_savestate      <= '0';
                  end if;
               end if;
            
            when LOADINTERNALS_READ =>
               if (bus_out_done = '1') then
                  bus_out_active       <= '0';
                  state                <= LOADINTERNALS_WRITEFIRST;
                  internal_bus_out.Din <= bus_out_Dout(31 downto 0);
                  internal_bus_out.ena <= '1';
               end if;
               
            when LOADINTERNALS_WRITEFIRST =>
               if (internal_bus_out.done = '1') then
                  state                <= LOADINTERNALS_WRITE;
                  internal_bus_out.adr <= std_logic_vector(unsigned(internal_bus_out.adr) + 1);
                  internal_bus_out.Din <= bus_out_Dout(63 downto 32);
                  internal_bus_out.ena <= '1';
               end if;
            
            when LOADINTERNALS_WRITE => 
               if (internal_bus_out.done = '1') then
                  bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < INTERNALSCOUNT) then
                     state          <= LOADINTERNALS_READ;
                     count          <= count + 2;
                     bus_out_ena    <= '1';
                     bus_out_active <= '1';
                     internal_bus_out.adr <= std_logic_vector(unsigned(internal_bus_out.adr) + 1);
                  else 
                     state              <= LOADREGISTER_READ;
                     SAVE_BusAddr       <= x"4000000";
                     registerram_addr_w <= 0;
                     count              <= 2;
                     bus_out_ena        <= '1';
                     bus_out_active     <= '1';
                  end if;
               end if;
               
            when LOADREGISTER_READ =>
               if (bus_out_done = '1') then
                  bus_out_active       <= '0';
                  state                <= LOADREGISTER_WRITEFIRST;
                  SAVE_BusWriteData    <= bus_out_Dout(31 downto 0);
                  SAVE_Bus_ena         <= '1';
                  registerram_DataIn   <= bus_out_Dout(31 downto 0);
                  registerram_we       <= "1111";
               end if;
               
            when LOADREGISTER_WRITEFIRST => 
               if (SAVE_BusReadDone = '1') then
                  state                <= LOADREGISTER_WRITE;
                  SAVE_BusAddr         <= std_logic_vector(unsigned(SAVE_BusAddr) + 4);
                  SAVE_BusWriteData    <= bus_out_Dout(63 downto 32);
                  SAVE_Bus_ena         <= '1';
                  registerram_DataIn   <= bus_out_Dout(63 downto 32);
                  registerram_we       <= "1111";
                  registerram_addr_w   <= registerram_addr_w + 1;
               end if;
            
            when LOADREGISTER_WRITE => 
               if (SAVE_BusReadDone = '1') then
                  SAVE_BusAddr <= std_logic_vector(unsigned(SAVE_BusAddr) + 4);
                  bus_out_Adr <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < REGISTERCOUNT) then
                     state              <= LOADREGISTER_READ;
                     count              <= count + 2;
                     bus_out_ena        <= '1';
                     bus_out_active     <= '1';
                     registerram_addr_w <= registerram_addr_w + 1;
                  else 
                     state       <= LOADMEMORY_NEXT;
                  end if;
               end if;
            
            when LOADMEMORY_NEXT =>
               if (savetype_counter < SAVETYPESCOUNT) then
                  state          <= LOADMEMORY_READ;
                  count          <= 2;
                  maxcount       <= savetypes(savetype_counter).count;
                  SAVE_BusAddr   <= savetypes(savetype_counter).addr;
                  bus_out_ena    <= '1';
                  bus_out_active <= '1';
               else
                  state             <= IDLE;
                  reset             <= '1';
                  loading_savestate <= '0';
                  sleep_savestate   <= '0';
                  load_done         <= '1';
               end if;
            
            when LOADMEMORY_READ =>
               if (bus_out_done = '1') then
                  bus_out_active    <= '0';
                  state             <= LOADMEMORY_WRITEFIRST;
                  SAVE_BusWriteData <= bus_out_Dout(31 downto 0);
                  SAVE_Bus_ena      <= '1';
               end if;
               
            when LOADMEMORY_WRITEFIRST =>
               if (SAVE_BusReadDone = '1') then
                  state             <= LOADMEMORY_WRITE;
                  SAVE_BusAddr      <= std_logic_vector(unsigned(SAVE_BusAddr) + 4);
                  SAVE_BusWriteData <= bus_out_Dout(63 downto 32);
                  SAVE_Bus_ena      <= '1';
               end if;
               
            when LOADMEMORY_WRITE =>
               if (SAVE_BusReadDone = '1') then
                  SAVE_BusAddr <= std_logic_vector(unsigned(SAVE_BusAddr) + 4);
                  bus_out_Adr  <= std_logic_vector(unsigned(bus_out_Adr) + 2);
                  if (count < maxcount) then
                     state          <= LOADMEMORY_READ;
                     count          <= count + 2;
                     bus_out_ena    <= '1';
                     bus_out_active <= '1';
                  else 
                     savetype_counter <= savetype_counter + 1;
                     state            <= LOADMEMORY_NEXT;
                  end if;
               end if;
         
         
         end case;
         
      end if;
   end process;
   

end architecture;





