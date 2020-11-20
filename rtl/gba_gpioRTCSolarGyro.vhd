library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_savestates.all;

entity gba_gpioRTCSolarGyro is
   port 
   (
      clk100               : in     std_logic; 
      reset                : in     std_logic;
      GBA_on               : in     std_logic;
      
      savestate_bus        : inout  proc_bus_gb_type;
      
      GPIO_readEna         : in     std_logic;                     -- request pulse coming together with address
      GPIO_done            : out    std_logic := '0';              -- pulse for 1 clock cycle when read value in Din is valid
      GPIO_Din             : out    std_logic_vector(3 downto 0);  -- 
      GPIO_Dout            : in     std_logic_vector(3 downto 0);  --
      GPIO_writeEna        : in     std_logic;                     -- request pulse coming together with address, no response required
      GPIO_addr            : in     std_logic_vector(1 downto 0);  -- 0..2 for 0x80000C4..0x80000C8
   
      vblank_trigger       : in     std_logic;  
      RTC_timestampNew     : in     std_logic;                     -- new current timestamp from system
      RTC_timestampIn      : in     std_logic_vector(31 downto 0); -- timestamp in seconds, current time
      RTC_timestampSaved   : in     std_logic_vector(31 downto 0); -- timestamp in seconds, saved time
      RTC_savedtimeIn      : in     std_logic_vector(41 downto 0); -- time structure, loaded
      RTC_saveLoaded       : in     std_logic;                     -- must be 0 when loading new game, should go and stay 1 when RTC was loaded and values are valid
      RTC_timestampOut     : out    std_logic_vector(31 downto 0); -- timestamp to be saved
      RTC_savedtimeOut     : out    std_logic_vector(41 downto 0); -- time structure to be saved
      RTC_inuse            : out    std_logic := '0';              -- will indicate that RTC is in use and should be saved on next saving
   
      rumble               : out    std_logic := '0';
      AnalogX              : in     signed(7 downto 0);
      solar_in             : in     std_logic_vector(2 downto 0)
   );
end entity;

architecture arch of gba_gpioRTCSolarGyro is

   type GPIOState is
   (
      IDLE,
      COMMANDSTATE,
      DATASTATE,
      READDATA
   );
   signal state : GPIOState := IDLE;
   
   signal retval    : std_logic_vector(3 downto 0);
   signal selected  : std_logic_vector(3 downto 0);
   signal enable    : std_logic;
   signal command   : std_logic_vector(7 downto 0);
   signal dataLen   : unsigned(2 downto 0);
   signal bits      : unsigned(5 downto 0); -- 0..55 max (8*7)
   signal clockslow : unsigned(7 downto 0);
   
   type t_data is array(0 to 6) of std_logic_vector(7 downto 0);
   signal data : t_data := (others => (others => '0'));
   
   signal bitcheck : integer range 0 to 55;
   
   signal solarsensor : unsigned(7 downto 0);
   signal gyrosensor  : unsigned(15 downto 0);
   
   constant GYRO_MIN    : integer := 16#0BC1#;
   constant GYRO_MIDDLE : integer := 16#0D80#;
   constant GYRO_MAX    : integer := 16#0EFF#;
   
   -- RTC
   signal RTC_timestampNew_1 : std_logic := '0';
   
   signal saveRTC          : std_logic := '0';
   signal saveRTC_next     : std_logic := '0';
   signal rtc_change       : std_logic := '0';
   signal RTC_saveLoaded_1 : std_logic := '0';
   
   signal saveCTL          : std_logic := '0';
   signal saveCTL_next     : std_logic := '0';
   signal CTLval           : std_logic_vector(7 downto 0) := x"40";
   
   signal RTC_timestamp    : std_logic_vector(31 downto 0);
   signal diffSeconds      : unsigned(31 downto 0) := (others => '0');
   
   signal secondcount      : integer range 0 to 100000000 := 0; -- 1 second at 100 Mhz
                           
   signal tm_year          : unsigned(7 downto 0) := x"09";
   signal tm_mon           : unsigned(4 downto 0) := '1' & x"2";
   signal tm_mday          : unsigned(5 downto 0) := "11" & x"1";
   signal tm_wday          : unsigned(2 downto 0) := "110";
   signal tm_hour          : unsigned(5 downto 0) := "10" & x"3";
   signal tm_min           : unsigned(6 downto 0) := "101" & x"9";
   signal tm_sec           : unsigned(6 downto 0) := "100" & x"5";
                           
   signal buf_tm_year      : std_logic_vector(7 downto 0);
   signal buf_tm_mon       : std_logic_vector(4 downto 0);
   signal buf_tm_mday      : std_logic_vector(5 downto 0);
   signal buf_tm_wday      : std_logic_vector(2 downto 0);
   signal buf_tm_hour      : std_logic_vector(5 downto 0);
   signal buf_tm_min       : std_logic_vector(6 downto 0);
   signal buf_tm_sec       : std_logic_vector(6 downto 0);
   
   -- savestate
   signal SAVESTATE_GPIO          : std_logic_vector(29 downto 0);
   signal SAVESTATE_GPIO_BACK     : std_logic_vector(29 downto 0);
                                  
   signal SAVESTATE_GPIOBITS      : std_logic_vector(21 downto 16);
   signal SAVESTATE_GPIOBITS_BACK : std_logic_vector(21 downto 16);
   
begin 

   iSAVESTATE_GPIO     : entity work.eProcReg_gba generic map (REG_SAVESTATE_GPIO)     port map (clk100, savestate_bus, SAVESTATE_GPIO_BACK,     SAVESTATE_GPIO);
   iSAVESTATE_GPIOBITS : entity work.eProcReg_gba generic map (REG_SAVESTATE_GPIOBITS) port map (clk100, savestate_bus, SAVESTATE_GPIOBITS_BACK, SAVESTATE_GPIOBITS);

   SAVESTATE_GPIO_BACK( 7 downto  0) <= std_logic_vector(clockslow);
   SAVESTATE_GPIO_BACK(15 downto  8) <= command;
   SAVESTATE_GPIO_BACK(18 downto 16) <= std_logic_vector(dataLen);
   SAVESTATE_GPIO_BACK(19)           <= enable;
   SAVESTATE_GPIO_BACK(23 downto 20) <= retval;
   SAVESTATE_GPIO_BACK(27 downto 24) <= selected;
   SAVESTATE_GPIO_BACK(29 downto 28) <= std_logic_vector(to_unsigned(GPIOState'POS(state), 2));
   
   SAVESTATE_GPIOBITS_BACK <= std_logic_vector(bits);

   process (clk100)
      variable new_command : std_logic_vector(7 downto 0);
   begin
      if rising_edge(clk100) then
      
         -- overwritten later
         GPIO_done    <= '0';
         saveRTC_next <= '0';
         saveCTL_next <= '0';
         
         if (saveCTL_next = '1') then
            CTLval <= data(0);
         end if;
         
         -- precalc for timing purpose
         case (solar_in) is
            when "000" => solarsensor <= x"FA";
            when "001" => solarsensor <= x"F0";
            when "010" => solarsensor <= x"E9";
            when "011" => solarsensor <= x"D5";
            when "100" => solarsensor <= x"B4";
            when "101" => solarsensor <= x"A7";
            when "110" => solarsensor <= x"75";
            when "111" => solarsensor <= x"44";
            when others => null;
         end case;
         
         if (AnalogX < -110) then -- maximum = shock speed
            gyrosensor <= to_unsigned(GYRO_MIN, 16);
         elsif (AnalogX > 110) then
            gyrosensor <= to_unsigned(GYRO_MAX, 16);
         elsif (AnalogX > 5 or AnalogX < -5) then -- dead zone check
            gyrosensor <= to_unsigned(GYRO_MIDDLE + (to_integer(AnalogX) / 2), 16);
         else -- idle;
            gyrosensor <= to_unsigned(GYRO_MIDDLE, 16);
         end if;
         
         if (dataLen > 0) then
            bitcheck <= (8 * to_integer(dataLen)) - 1; 
         else
            bitcheck <= 0;
         end if;
      
         if (reset = '1') then
         
            clockslow <= unsigned(SAVESTATE_GPIO(7 downto 0));
            command   <= SAVESTATE_GPIO(15 downto 8);
            dataLen   <= unsigned(SAVESTATE_GPIO(18 downto 16));
            enable    <= SAVESTATE_GPIO(19);
            retval    <= SAVESTATE_GPIO(23 downto 20);
            selected  <= SAVESTATE_GPIO(27 downto 24);
            state     <= GPIOState'VAL(to_integer(unsigned(SAVESTATE_GPIO(29 downto 28))));
            
            bits      <= unsigned(SAVESTATE_GPIOBITS(21 downto 16));
            
            rumble    <= '0';
            
            saveRTC   <= '0';
            
            RTC_inuse <= RTC_saveLoaded;
            
         elsif (gba_on = '1') then
         
            if (RTC_saveLoaded = '1') then
               RTC_inuse <= '1';
            end if;
      
            if (GPIO_readEna = '1') then
            
               GPIO_done <= '1';
               GPIO_Din  <= x"0";
               
               case GPIO_addr is
                  when "10" => -- 0x80000c8
                     GPIO_Din <= "000" & enable;
                     
                  when "01" => -- 0x80000c6
                     GPIO_Din <= selected;
               
                  when "00" => -- 0x80000c4
                     if (enable = '1') then
                        
                        -- RTC
                        if (selected(2) = '1') then
                           GPIO_Din <= retval;
                        end if;
                        
                        -- gyro
                        if (selected = x"B") then
                           GPIO_Din(2) <= gyrosensor(to_integer(clockslow(3 downto 0)));
                        end if;
                        
                        -- solar
                        if (selected = x"7") then
                           if (clockslow >= solarsensor) then
                              GPIO_Din(3) <= '1';
                           end if;
                        end if;
                        
                     end if;
               
                  when others => null;
               end case;
            end if;
         
      
            if (GPIO_writeEna = '1') then
               
               case GPIO_addr is
                  when "10" => -- 0x80000c8
                     enable <= GPIO_Dout(0);
                     
                  when "01" => -- 0x80000c6
                     selected <= GPIO_Dout; 
                     if (GPIO_Dout(3) = '0') then
                        rumble   <= '0';
                     end if;
               
                  when "00" => -- 0x80000c4
               
                     -- rumble
                     if (selected(3) = '1') then
                        rumble   <= GPIO_Dout(3);
                     end if;
                     
                     -- solar
                     if (selected = x"7") then
                        if (GPIO_Dout(1) = '1') then
                           clockslow <= (others => '0');
                        elsif (GPIO_Dout(0) = '1') then
                           clockslow <= clockslow + 1;  -- 8 bit wraparound
                        end if;
                     end if;
                     
                     -- gyro
                     if (selected = x"B") then
                        if (GPIO_Dout(1) = '1') then
                           -- clock goes high in preperation for reading a bit
                           clockslow <= clockslow - 1;
                        end if;
      
                        if (GPIO_Dout(0) = '1') then
                           -- start ADC conversion
                           clockslow <= to_unsigned(15, 8);
                        end if;
      
                        retval <= GPIO_Dout and selected;
                     end if;
                     
                     -- RTC
                     --if (selected(2) = '1') then -- don't check for clock as Sennen Kazoku doesn't handle it "correct"
                     
                        if (state = IDLE and retval = x"1" and GPIO_Dout = x"5") then
                        
                           state   <= COMMANDSTATE;
                           bits    <= (others => '0');
                           command <= (others => '0');
                           
                           RTC_inuse <= '1';
                              
                        elsif (retval(0) = '0' and GPIO_Dout(0) = '1') then -- bit transfer

                           retval <= GPIO_Dout;
      
                           case (state) is

                              when COMMANDSTATE =>
                                 new_command := command;                             
                                 new_command(7 - to_integer(bits)) := command(7 - to_integer(bits)) or GPIO_Dout(1);
                                 command <= new_command;
                                 
                                 bits <= bits + 1;
      
                                 if (bits = 7) then -- would be 8 next step
      
                                    bits <= (others => '0');
      
                                    case (new_command) is

                                       when x"60" => -- reset
                                          state <= IDLE;
      
                                       when x"62" => --control state
                                          state   <= READDATA;
                                          dataLen <= to_unsigned(1, dataLen'length);
                                          saveCTL <= '1';
      
                                       when x"63" =>
                                          dataLen <= to_unsigned(1, dataLen'length);
                                          data(0) <= CTLval;
                                          state   <= DATASTATE;
                                               
                                       when x"64" =>
                                          state   <= READDATA;
                                          dataLen <= to_unsigned(7, dataLen'length);
                                          saveRTC <= '1';
      
                                       when x"65" =>
                                          dataLen <= to_unsigned(7, dataLen'length);
                                          data(0) <= buf_tm_year;
                                          data(1) <= "000" & buf_tm_mon;
                                          data(2) <= "00" & buf_tm_mday;
                                          data(3) <= "00000" & buf_tm_wday;
                                          data(4) <= "00" & buf_tm_hour;
                                          data(5) <= '0' & buf_tm_min;
                                          data(6) <= '0' & buf_tm_sec;
                                          state   <= DATASTATE;
      
                                       when x"67" => 
                                          dataLen <= to_unsigned(3, dataLen'length);
                                          data(0) <= "00" & buf_tm_hour;
                                          data(1) <= '0' & buf_tm_min;
                                          data(2) <= '0' & buf_tm_sec;
                                          state   <= DATASTATE;

                                       when others => state <= IDLE;
                                          
                                    end case;
                                    
                                 end if;
      
                              when DATASTATE =>
                                 if (selected(1) = '1') then

                                 elsif (selected(2) = '1') then
                                 
                                    retval(1) <= data(to_integer(bits) / 8)(to_integer(bits(2 downto 0)));
                                    bits <= bits + 1;
      
                                    if (bits = bitcheck) then
                                       bits  <= (others => '0');
                                       state <= IDLE;
                                    end if;
                                    
                                 end if;
      
                              when READDATA =>
                                 if (selected(1) = '1') then
                                 
                                    data(to_integer(bits) / 8) <= GPIO_Dout(1) & data(to_integer(bits) / 8)(7 downto 1);
                                    bits <= bits + 1;
      
                                    if (bits = bitcheck) then
                                       bits  <= (others => '0');
                                       state <= IDLE;
                                       saveRTC_next <= saveRTC;
                                       saveCTL_next <= saveCTL;
                                       saveRTC      <= '0';
                                       saveCTL      <= '0';
                                    end if;
                                    
                                 end if;
                                 
                              when others => null;
                                 
                           end case;
                        
                        else
                        
                           retval <= GPIO_Dout;
                              
                        end if;
                     --end if;
                  
                  when others => null;
               end case;
               
            end if;
            
         end if; 
         
      end if;
   end process;
   
   RTC_timestampOut <= RTC_timestamp;
   RTC_savedtimeOut(41 downto 34) <= buf_tm_year;
   RTC_savedtimeOut(33 downto 29) <= buf_tm_mon; 
   RTC_savedtimeOut(28 downto 23) <= buf_tm_mday;
   RTC_savedtimeOut(22 downto 20) <= buf_tm_wday;
   RTC_savedtimeOut(19 downto 14) <= buf_tm_hour;
   RTC_savedtimeOut(13 downto 7)  <= buf_tm_min; 
   RTC_savedtimeOut(6 downto 0)   <= buf_tm_sec; 
   
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         if (rtc_change = '0') then
            buf_tm_year <= std_logic_vector(tm_year);
            buf_tm_mon  <= std_logic_vector(tm_mon); 
            buf_tm_mday <= std_logic_vector(tm_mday);
            buf_tm_wday <= std_logic_vector(tm_wday);
            buf_tm_hour <= std_logic_vector(tm_hour);
            buf_tm_min  <= std_logic_vector(tm_min); 
            buf_tm_sec  <= std_logic_vector(tm_sec); 
         end if;
      
         rtc_change <= '0';
         
         secondcount <= secondcount + 1;
         
         RTC_saveLoaded_1 <= RTC_saveLoaded;
         if (RTC_saveLoaded_1 = '0' and  RTC_saveLoaded = '1') then
         
            if (unsigned(RTC_timestamp) > unsigned(RTC_timestampSaved)) then
               diffSeconds <= unsigned(RTC_timestamp) - unsigned(RTC_timestampSaved);
            end if;
         
            tm_year <= unsigned(RTC_savedtimeIn(41 downto 34));
            tm_mon  <= unsigned(RTC_savedtimeIn(33 downto 29));
            tm_mday <= unsigned(RTC_savedtimeIn(28 downto 23));
            tm_wday <= unsigned(RTC_savedtimeIn(22 downto 20));
            tm_hour <= unsigned(RTC_savedtimeIn(19 downto 14));
            tm_min  <= unsigned(RTC_savedtimeIn(13 downto 7));
            tm_sec  <= unsigned(RTC_savedtimeIn(6 downto 0));
         
           
         elsif (saveRTC_next = '1') then
            
            tm_year <= unsigned(data(0));
            tm_mon  <= unsigned(data(1)(4 downto 0));
            tm_mday <= unsigned(data(2)(5 downto 0));
            tm_wday <= unsigned(data(3)(2 downto 0));
            tm_hour <= unsigned(data(4)(5 downto 0));
            tm_min  <= unsigned(data(5)(6 downto 0));
            tm_sec  <= unsigned(data(6)(6 downto 0));
            
         else
            
            if (tm_year(7 downto 4) > 9)  then tm_year(7 downto 4) <= (others => '0'); rtc_change <= '1'; end if;    
            if (tm_year(3 downto 0) > 9)  then tm_year(3 downto 0) <= (others => '0'); tm_year(7 downto 4) <= tm_year(7 downto 4) + 1;  rtc_change <= '1'; end if;
            
            -- 0x12 = 18
            if (tm_mon > 18) then tm_mon <= "00001"; tm_year(3 downto 0) <= tm_year(3 downto 0) + 1; rtc_change <= '1'; end if;
            if (tm_mon(3 downto 0) > 9) then tm_mon(3 downto 0) <= (others => '0'); tm_mon(4) <= '1'; rtc_change <= '1'; end if;


            case (tm_mon) is -- 0x31 = 49, 0x30 = 48, 0x28 = 40
               when "00001" => if (tm_mday > 49) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "00010" => if (tm_mday > 40) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "00011" => if (tm_mday > 49) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "00100" => if (tm_mday > 48) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "00101" => if (tm_mday > 49) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "00110" => if (tm_mday > 48) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "00111" => if (tm_mday > 49) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "01000" => if (tm_mday > 49) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "01001" => if (tm_mday > 48) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "10000" => if (tm_mday > 49) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "10001" => if (tm_mday > 48) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when "10010" => if (tm_mday > 49) then tm_mday <= "000001"; tm_mon(3 downto 0) <= tm_mon(3 downto 0) + 1; rtc_change <= '1'; end if;
               when others => null;
            end case;
            if (tm_mday(3 downto 0) > 9) then tm_mday(3 downto 0) <= (others => '0'); tm_mday(5 downto 4) <= tm_mday(5 downto 4) + 1; rtc_change <= '1'; end if;

            if (tm_wday > 6) then tm_wday <= (others => '0'); rtc_change <= '1'; end if;

            -- 0x23 = 35
            if (tm_hour > 35) then tm_hour <= (others => '0'); tm_wday <= tm_wday + 1; tm_mday(3 downto 0) <= tm_mday(3 downto 0) + 1; rtc_change <= '1'; end if;
            if (tm_hour(3 downto 0) > 9) then tm_hour(3 downto 0) <= (others => '0'); tm_hour(5 downto 4) <= tm_hour(5 downto 4) + 1; rtc_change <= '1'; end if;
            
            if (tm_min(6 downto 4) > 5)  then tm_min(6 downto 4)  <= (others => '0'); tm_hour(3 downto 0) <= tm_hour(3 downto 0) + 1; rtc_change <= '1'; end if;    
            if (tm_min(3 downto 0) > 9)  then tm_min(3 downto 0)  <= (others => '0'); tm_min(6 downto 4)  <= tm_min(6 downto 4) + 1;  rtc_change <= '1'; end if;
                                                                                                                        
            if (tm_sec(6 downto 4) > 5)  then tm_sec(6 downto 4)  <= (others => '0'); tm_min(3 downto 0)  <= tm_min(3 downto 0) + 1;  rtc_change <= '1'; end if;    
            if (tm_sec(3 downto 0) > 9)  then tm_sec(3 downto 0)  <= (others => '0'); tm_sec(6 downto 4)  <= tm_sec(6 downto 4) + 1;  rtc_change <= '1'; end if;
            
            if (secondcount >= 99999999) then 
               secondcount        <= 0; 
               RTC_timestamp      <= std_logic_vector(unsigned(RTC_timestamp) + 1);
               tm_sec(3 downto 0) <= tm_sec(3 downto 0) + 1;  
               rtc_change         <= '1'; 
            elsif (diffSeconds > 0 and rtc_change = '0') then   
               diffSeconds        <= diffSeconds - 1; 
               tm_sec(3 downto 0) <= tm_sec(3 downto 0) + 1;  
               rtc_change         <= '1'; 
            end if;
   
         end if;
         
         RTC_timestampNew_1 <= RTC_timestampNew;
         if (RTC_timestampNew /= RTC_timestampNew_1) then
            RTC_timestamp <= RTC_timestampIn;
         end if;
   
      end if;
   end process;
   

end architecture;





