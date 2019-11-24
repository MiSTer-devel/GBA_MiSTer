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
      KeyL       : in std_logic
   );
end entity;

architecture arch of gba_joypad is

   signal REG_KEYINPUT  : std_logic_vector(KEYINPUT.upper downto KEYINPUT.lower) := (others => '0');
   signal REG_KEYCNT    : std_logic_vector(KEYCNT  .upper downto KEYCNT  .lower) := (others => '0');

begin 

   iReg_KEYINPUT  : entity work.eProcReg_gba generic map (KEYINPUT) port map  (clk100, gb_bus, REG_KEYINPUT);  
   iReg_KEYCNT    : entity work.eProcReg_gba generic map (KEYCNT  ) port map  (clk100, gb_bus, REG_KEYCNT, REG_KEYCNT);  

   
   process (clk100)
   begin
      if rising_edge(clk100) then

         IRP_Joypad <= '0';
         
         REG_KEYINPUT(0) <= not KeyA; 
         REG_KEYINPUT(1) <= not KeyB;
         REG_KEYINPUT(2) <= not KeySelect;
         REG_KEYINPUT(3) <= not KeyStart;
         REG_KEYINPUT(4) <= not KeyRight;
         REG_KEYINPUT(5) <= not KeyLeft;
         REG_KEYINPUT(6) <= not KeyUp;
         REG_KEYINPUT(7) <= not KeyDown;
         REG_KEYINPUT(8) <= not KeyR;
         REG_KEYINPUT(9) <= not KeyL;
         
         if (REG_KEYCNT(30) = '1') then
            if (REG_KEYCNT(31) = '1') then -- logical and
               if ((not REG_KEYINPUT(9 downto 0)) = REG_KEYCNT(25 downto 16)) then
                  IRP_Joypad <= '1';
               end if;
            else -- logical or
               if (unsigned((not REG_KEYINPUT(9 downto 0)) and REG_KEYCNT(25 downto 16)) /= 0) then
                  IRP_Joypad <= '1';
               end if;
            end if;
         end if;
      
      end if;
   end process; 
    

end architecture;





