library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_keypad.all;

entity gba_joypad is
   port 
   (
      clk100     : in    std_logic;  
      gb_bus     : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
      IRP_Joypad : out   std_logic := '0';
                 
      KeyA       : in std_logic;
      KeyB       : in std_logic;
      KeySelect  : in std_logic;
      KeyStart   : in std_logic;
      KeyRight   : in std_logic;
      KeyLeft    : in std_logic;
      KeyUp      : in std_logic;
      KeyDown    : in std_logic;
      KeyR       : in std_logic;
      KeyL       : in std_logic;
      
      cpu_done   : in std_logic
   );
end entity;

architecture arch of gba_joypad is

   signal REG_KEYINPUT  : std_logic_vector(KEYINPUT.upper downto KEYINPUT.lower) := (others => '0');
   signal REG_KEYCNT    : std_logic_vector(KEYCNT  .upper downto KEYCNT  .lower) := (others => '0');

   signal debug_cnt : integer := 0;
   
   signal Keys    : std_logic_vector(KEYINPUT.upper downto KEYINPUT.lower) := (others => '0');
   signal Keys_1  : std_logic_vector(KEYINPUT.upper downto KEYINPUT.lower) := (others => '0');
   
   signal REG_KEYCNT_1 : std_logic_vector(KEYCNT  .upper downto KEYCNT  .lower) := (others => '0');

begin 

   iReg_KEYINPUT  : entity work.eProcReg_gba generic map (KEYINPUT) port map  (clk100, gb_bus, REG_KEYINPUT);  
   iReg_KEYCNT    : entity work.eProcReg_gba generic map (KEYCNT  ) port map  (clk100, gb_bus, REG_KEYCNT, REG_KEYCNT);  

   REG_KEYINPUT <= Keys;
   
   process (clk100)
   begin
      if rising_edge(clk100) then

         IRP_Joypad <= '0';
         
         Keys_1       <= Keys;
         REG_KEYCNT_1 <= REG_KEYCNT;
         
         Keys(0) <= not KeyA; 
         Keys(1) <= not KeyB;
         Keys(2) <= not KeySelect;
         Keys(3) <= not KeyStart;
         Keys(4) <= not KeyRight;
         Keys(5) <= not KeyLeft;
         Keys(6) <= not KeyUp;
         Keys(7) <= not KeyDown;
         Keys(8) <= not KeyR;
         Keys(9) <= not KeyL;
         
         if (Keys_1 /= Keys or REG_KEYCNT_1 /= REG_KEYCNT) then
            if (REG_KEYCNT(30) = '1') then
               if (REG_KEYCNT(31) = '1') then -- logical and
                  if ((not Keys(9 downto 0)) = REG_KEYCNT(25 downto 16)) then
                     IRP_Joypad <= '1';
                  end if;
               else -- logical or
                  if (unsigned((not Keys(9 downto 0)) and REG_KEYCNT(25 downto 16)) /= 0) then
                     IRP_Joypad <= '1';
                  end if;
               end if;
            end if;
         end if;
         
         -- debug only
         --if (cpu_done = '1') then
         --   debug_cnt <= debug_cnt + 1;
         --   
         --   if (debug_cnt =       0) then REG_KEYINPUT(3) <= '1'; end if;
         --   if (debug_cnt = 3000000) then REG_KEYINPUT(3) <= '0'; end if;
         --   if (debug_cnt = 3100000) then REG_KEYINPUT(3) <= '1'; end if;
         --   if (debug_cnt = 4000000) then REG_KEYINPUT(3) <= '0'; end if;
         --   
         --end if;

      
      end if;
   end process; 
    

end architecture;





