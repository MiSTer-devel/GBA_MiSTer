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
         GPIO_done <= '0';
         
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
            
            
         elsif (gba_on = '1') then
      
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
                     if (selected(2) = '1') then

                        if (state = IDLE and retval = x"1" and GPIO_Dout = x"5") then
                        
                           state   <= COMMANDSTATE;
                           bits    <= (others => '0');
                           command <= (others => '0');
                              
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

                                       when x"60" =>
                                          -- not sure what this command does but it doesn't take parameters, maybe it is a reset or stop
                                          state <= IDLE;
      
                                       when x"62" =>
                                          -- this sets the control state but not sure what those values are
                                          state   <= READDATA;
                                          dataLen <= to_unsigned(1, dataLen'length);
      
                                       when x"63" =>
                                          dataLen <= to_unsigned(1, dataLen'length);
                                          data(0) <= x"40";
                                          state   <= DATASTATE;
                                               
                                       when x"64" => null;
      
                                       when x"65" =>
                                          --if (gpioEnabled) SetGBATime();
                                          dataLen <= to_unsigned(7, dataLen'length);
                                          data(0) <= x"07"; --toBCD(gba_time.tm_year);
                                          data(1) <= x"01"; --toBCD(gba_time.tm_mon);
                                          data(2) <= x"02"; --toBCD(gba_time.tm_mday);
                                          data(3) <= x"03"; --toBCD(gba_time.tm_wday);
                                          data(4) <= x"04"; --toBCD(gba_time.tm_hour);
                                          data(5) <= x"05"; --toBCD(gba_time.tm_min);
                                          data(6) <= x"06"; --toBCD(gba_time.tm_sec);
                                          state   <= DATASTATE;
      
                                       when x"67" => 
                                          --if (gpioEnabled) SetGBATime();
                                          dataLen <= to_unsigned(3, dataLen'length);
                                          data(0) <= x"04"; --toBCD(gba_time.tm_hour);
                                          data(1) <= x"05"; --toBCD(gba_time.tm_min);
                                          data(2) <= x"06"; --toBCD(gba_time.tm_sec);
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
                                 
                                    data(to_integer(bits) / 8) <= GPIO_Dout(0) & data(to_integer(bits) / 8)(7 downto 1);
                                    bits <= bits + 1;
      
                                    if (bits = bitcheck) then
                                       bits  <= (others => '0');
                                       state <= IDLE;
                                    end if;
                                    
                                 end if;
                                 
                              when others => null;
                                 
                           end case;
                        
                        else
                        
                           retval <= GPIO_Dout;
                              
                        end if;
                     end if;
                  
                  when others => null;
               end case;
               
            end if;
            
         end if; 
         
      end if;
   end process;
   

end architecture;





