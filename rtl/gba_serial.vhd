library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_serial.all;

entity gba_serial is
   port 
   (
      clk100            : in    std_logic;  
      gb_bus            : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
      
      new_exact_cycle   : in  std_logic;
      
      clockout          : out std_logic;
      clockin           : in  std_logic;
      dataout           : buffer std_logic := '1';
      datain            : in  std_logic;
      si_terminal       : in  std_logic;
      sd_terminal       : in  std_logic;
      
      IRP_Serial        : out std_logic := '0'
   );
end entity;

architecture arch of gba_serial is

   signal REG_SIODATA32   : std_logic_vector(SIODATA32  .upper downto SIODATA32  .lower) := (others => '0');
   signal REG_SIOMULTI0   : std_logic_vector(SIOMULTI0  .upper downto SIOMULTI0  .lower) := (others => '0');
   signal REG_SIOMULTI1   : std_logic_vector(SIOMULTI1  .upper downto SIOMULTI1  .lower) := (others => '0');
   signal REG_SIOMULTI2   : std_logic_vector(SIOMULTI2  .upper downto SIOMULTI2  .lower) := (others => '0');
   signal REG_SIOMULTI3   : std_logic_vector(SIOMULTI3  .upper downto SIOMULTI3  .lower) := (others => '0');
   signal REG_SIOCNT      : std_logic_vector(SIOCNT     .upper downto SIOCNT     .lower) := (others => '0');
   signal REG_SIODATA8    : std_logic_vector(15 downto 0) := (others => '0');
   signal REG_RCNT        : std_logic_vector(RCNT       .upper downto RCNT       .lower) := (others => '0');
   signal REG_IR          : std_logic_vector(IR         .upper downto IR         .lower) := (others => '0');
   signal REG_JOYCNT      : std_logic_vector(JOYCNT     .upper downto JOYCNT     .lower) := (others => '0');
   signal REG_JOY_RECV    : std_logic_vector(JOY_RECV   .upper downto JOY_RECV   .lower) := (others => '0');
   signal REG_JOY_TRANS   : std_logic_vector(JOY_TRANS  .upper downto JOY_TRANS  .lower) := (others => '0');
   signal REG_JOYSTAT     : std_logic_vector(JOYSTAT    .upper downto JOYSTAT    .lower) := (others => '0');

   signal SIOCNT_READBACK : std_logic_vector(SIOCNT     .upper downto SIOCNT     .lower) := (others => '0');
   signal SIOCNT_written  : std_logic;
   
   signal REG_SIODATA32_READBACK  : std_logic_vector(SIODATA32  .upper downto SIODATA32  .lower) := (others => '0');
   signal REG_SIODATA8_READBACK   : std_logic_vector(15 downto 0) := (others => '0');
   signal SIODATA32_written  : std_logic;
   signal SIODATA8_written  : std_logic;
   
   signal RCNT_READBACK   : std_logic_vector(RCNT       .upper downto RCNT       .lower) := (others => '0');

   signal SIO_start       : std_logic := '0';
   signal cycles          : unsigned(11 downto 0) := (others => '0');
   signal bitcount        : integer range 0 to 31 := 0;
   
   signal clockin_1       : std_logic := '1';
   
   signal multispeed       : integer range 145 to 1747 := 145;
   signal multidataout     : std_logic_vector(17 downto 0);
   signal multidatain      : std_logic_vector(17 downto 0);
   signal multisendmode    : std_logic := '0';
   signal startbitreceived : std_logic := '0';

begin 

   iSIODATA32   : entity work.eProcReg_gba generic map (SIODATA32  ) port map  (clk100, gb_bus, REG_SIODATA32_READBACK, REG_SIODATA32  , SIODATA32_written);  
   --iSIOMULTI0   : entity work.eProcReg_gba generic map (SIOMULTI0  ) port map  (clk100, gb_bus, REG_SIOMULTI0         , REG_SIOMULTI0  );  
   --iSIOMULTI1   : entity work.eProcReg_gba generic map (SIOMULTI1  ) port map  (clk100, gb_bus, REG_SIOMULTI1         , REG_SIOMULTI1  );  
   iSIOMULTI2   : entity work.eProcReg_gba generic map (SIOMULTI2  ) port map  (clk100, gb_bus, x"FFFF"               , REG_SIOMULTI2  );  
   iSIOMULTI3   : entity work.eProcReg_gba generic map (SIOMULTI3  ) port map  (clk100, gb_bus, x"FFFF"               , REG_SIOMULTI3  );  
   iSIOCNT      : entity work.eProcReg_gba generic map (SIOCNT     ) port map  (clk100, gb_bus, SIOCNT_READBACK       , REG_SIOCNT     , SIOCNT_written);  
   iSIODATA8    : entity work.eProcReg_gba generic map (SIODATA8   ) port map  (clk100, gb_bus, REG_SIODATA8_READBACK , REG_SIODATA8   , SIODATA8_written);  
   iRCNT        : entity work.eProcReg_gba generic map (RCNT       ) port map  (clk100, gb_bus, RCNT_READBACK         , REG_RCNT       );  
   iIR          : entity work.eProcReg_gba generic map (IR         ) port map  (clk100, gb_bus, REG_IR                , REG_IR         );  
   iJOYCNT      : entity work.eProcReg_gba generic map (JOYCNT     ) port map  (clk100, gb_bus, REG_JOYCNT            , REG_JOYCNT     );  
   iJOY_RECV    : entity work.eProcReg_gba generic map (JOY_RECV   ) port map  (clk100, gb_bus, REG_JOY_RECV          , REG_JOY_RECV   );  
   iJOY_TRANS   : entity work.eProcReg_gba generic map (JOY_TRANS  ) port map  (clk100, gb_bus, REG_JOY_TRANS         , REG_JOY_TRANS  );  
   iJOYSTAT     : entity work.eProcReg_gba generic map (JOYSTAT    ) port map  (clk100, gb_bus, REG_JOYSTAT           , REG_JOYSTAT    );  
   
   SIOCNT_READBACK <= REG_SIOCNT(15 downto 8) & SIO_start & REG_SIOCNT(6 downto 0) when REG_SIOCNT(13) = '0' else
                      REG_SIOCNT(15 downto 8) & SIO_start & '0' & '0' & si_terminal & sd_terminal & si_terminal & REG_SIOCNT(1 downto 0);
   
   
   RCNT_READBACK <= REG_RCNT when REG_SIOCNT(13) = '0' else
                    REG_RCNT(15 downto 4) & dataout & si_terminal & sd_terminal & '1';
   
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         IRP_Serial <= '0';
         clockout   <= '1';
         
         clockin_1 <= clockin;
         
         case (REG_SIOCNT(1 downto 0)) is
            when "00" => multispeed <= 1747; -- baud 9600
            when "01" => multispeed <=  436; -- baud 38400
            when "10" => multispeed <=  291; -- baud 57600
            when "11" => multispeed <=  145; -- baud 115200
            when others => null;
         end case;

         if (REG_SIOCNT(13) = '1') then -- multiplayer mode

            if (SIO_start = '1') then
               clockout <= '0';
            else
               clockout <= '1';
            end if;
            
            if (new_exact_cycle = '1') then
               cycles <= cycles + 1;
            elsif (multisendmode = '1') then -- sending data
               if (cycles = multispeed) then
                  
                  cycles  <= cycles - multispeed;
                  dataout <= multidataout(17);
                  multidataout <= multidataout(16 downto 0) & '1';
                  
                  if (bitcount = 17) then
                     bitcount <= 0;
                     multisendmode <= '0';
                     if (si_terminal = '1') then -- slave is done after sending
                        if (REG_SIOCNT(14) = '1') then
                           IRP_Serial <= '1';
                        end if;
                     end if;
                  else
                     bitcount      <= bitcount + 1;
                  end if;
               end if;
            else  -- receiving data
               if (startbitreceived = '0') then
                  if (datain = '0') then
                     cycles           <= to_unsigned(multispeed / 2, 12);
                     bitcount         <= 1;
                     startbitreceived <= '1';
                  end if;
               elsif (cycles = multispeed) then
                  cycles      <= cycles - multispeed;
                  multidatain <= multidatain(16 downto 0) & datain;
                  
                  if (bitcount = 18) then
                     bitcount         <= 0;
                     startbitreceived <= '0';
                     if (si_terminal = '0') then -- master is done after receiving
                        REG_SIODATA32_READBACK <= multidatain(15 downto 0) & REG_SIODATA8;
                        if (REG_SIOCNT(14) = '1') then
                           IRP_Serial <= '1';
                        end if;
                        SIO_start <= '0';
                     else -- slave must send now
                        REG_SIODATA32_READBACK <= REG_SIODATA8 & multidatain(15 downto 0);
                        multisendmode          <= '1';
                        multidataout           <= '0' & REG_SIODATA8 & '1';
                     end if;
                  else
                     bitcount      <= bitcount + 1;
                  end if;
               end if;
            end if;
            
            
            if (multisendmode = '0') then
               dataout <= '1';
            end if;

         else -- normal mode
         
            if (SIO_start = '1') then
               if (REG_SIOCNT(0) = '0') then -- external clock
            
                  if (clockin_1 = '1' and clockin = '0') then
                     if (REG_SIOCNT(12) = '1') then
                        dataout  <= REG_SIODATA32_READBACK(31);
                     else  
                        dataout  <= REG_SIODATA8_READBACK(7);
                     end if;
                  end if;
                  
                  if (clockin_1 = '0' and clockin = '1') then
                     if (REG_SIOCNT(12) = '1') then
                        REG_SIODATA32_READBACK <= REG_SIODATA32_READBACK(30 downto 0) & datain;
                     else  
                        REG_SIODATA8_READBACK <= x"00" & REG_SIODATA8_READBACK(6 downto 0) & datain;
                     end if;
                     
                     if ((REG_SIOCNT(12) = '0' and bitcount = 7) or (REG_SIOCNT(12) = '1' and bitcount = 31)) then
                        if (REG_SIOCNT(14) = '1') then
                           IRP_Serial <= '1';
                        end if;
                        SIO_start <= '0';
                     else
                        bitcount <= bitcount + 1;
                     end if;
                     
                  end if;
               
               else
            
                  if (new_exact_cycle = '1') then
                     cycles <= cycles + 1;
                     if ((REG_SIOCNT(1) = '0' and cycles = 32) or (REG_SIOCNT(1) = '1' and cycles = 4)) then
                        clockout <= '0';
                        if (REG_SIOCNT(12) = '1') then
                           dataout  <= REG_SIODATA32_READBACK(31);
                        else  
                           dataout  <= REG_SIODATA8_READBACK(7);
                        end if;
                     end if;
                  else
                     if ((REG_SIOCNT(1) = '0' and cycles = 64) or (REG_SIOCNT(1) = '1' and cycles = 8)) then
                        clockout <= '1';
                        if (REG_SIOCNT(12) = '1') then
                           REG_SIODATA32_READBACK <= REG_SIODATA32_READBACK(30 downto 0) & datain;
                        else  
                           REG_SIODATA8_READBACK <= x"00" & REG_SIODATA8_READBACK(6 downto 0) & datain;
                        end if;
                        
                        if (REG_SIOCNT(1) = '1') then
                           cycles <= cycles - 8;
                        else
                           cycles <= cycles - 64;
                        end if;
                        
                        if ((REG_SIOCNT(12) = '0' and bitcount = 7) or (REG_SIOCNT(12) = '1' and bitcount = 31)) then
                           if (REG_SIOCNT(14) = '1') then
                              IRP_Serial <= '1';
                           end if;
                           SIO_start <= '0';
                        else
                           bitcount <= bitcount + 1;
                        end if;
                     end if;
                  end if;
                  
               end if;
            else
               --dataout <= REG_SIOCNT(3);
            end if;
            
         end if;

   
         if (SIOCNT_written = '1') then
            if (REG_SIOCNT(7) = '1') then
               SIO_start        <= '1';
               bitcount         <= 0;
               cycles           <= (others => '0');
               multidataout     <= '0' & REG_SIODATA8 & '1';
               multisendmode    <= not si_terminal;
               startbitreceived <= '0';
               if (REG_SIOCNT(13) = '1') then -- multimode
                  REG_SIODATA32_READBACK <= (others => '1');
               end if;
            end if;
         end if;
         
         if (SIODATA32_written = '1') then
            REG_SIODATA32_READBACK <= REG_SIODATA32;
         end if;
         
         if (SIODATA8_written = '1') then
            REG_SIODATA8_READBACK <= REG_SIODATA8;
         end if;
    
      end if;
   end process;

end architecture;





