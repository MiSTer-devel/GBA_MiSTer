library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;

entity gba_reservedregs is
   port 
   (
      clk100      : in    std_logic;  
      gb_bus      : in    proc_bus_gb_type;
      wired_out   : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done  : out   std_logic
   );
end entity;

architecture arch of gba_reservedregs is

   signal addr : unsigned(27 downto 0);
   
begin 

   addr <= unsigned(gb_bus.Adr);

   wired_out  <= (others => '0');
   wired_done <= '0';

   --wired_done  <=  '0' when (addr  = 16#58#                   ) else 
   --                '0' when (addr  = 16#5C#                   ) else 
   --                '0' when (addr  = 16#8C#                   ) else 
   --                '0' when (addr  = 16#A8#                   ) else 
   --                '0' when (addr  = 16#AC#                   ) else 
   --                '0' when (addr >= 16#E0# and addr <= 16#FC#) else
   --                'Z';
   
end architecture;





