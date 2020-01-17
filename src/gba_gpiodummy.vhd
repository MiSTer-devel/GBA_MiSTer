library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

-- example module
-- increments written value on address 0 (0x80000C4)
-- delivers static "0110" at address 1 (0x80000C6)
-- delivers negated value at address 2 (0x80000C8)

-- 80000C4h - I/O Port Data (selectable W or R/W)
-- 
--   bit0-3  Data Bits 0..3 (0=Low, 1=High)
--   bit4-15 not used (0)
-- 
-- 80000C6h - I/O Port Direction (for above Data Port) (selectable W or R/W)
-- 
--   bit0-3  Direction for Data Port Bits 0..3 (0=In, 1=Out)
--   bit4-15 not used (0)
-- 
-- 80000C8h - I/O Port Control (selectable W or R/W)
-- 
--   bit0    Register 80000C4h..80000C8h Control (0=Write-Only, 1=Read/Write)
--   bit1-15 not used (0)

entity gba_gpiodummy is
   port 
   (
      clk100               : in     std_logic; 
      
      GPIO_readEna         : in     std_logic;                     -- request pulse coming together with address
      GPIO_done            : out    std_logic := '0';              -- pulse for 1 clock cycle when read value in Din is valid
      GPIO_Din             : out    std_logic_vector(3 downto 0);  -- 
      GPIO_Dout            : in     std_logic_vector(3 downto 0);  --
      GPIO_writeEna        : in     std_logic;                     -- request pulse coming together with address, no response required
      GPIO_addr            : in     std_logic_vector(1 downto 0)   -- 0..2 for 0x80000C4..0x80000C8
   );
end entity;

architecture arch of gba_gpiodummy is

   signal output1 : std_logic_vector(3 downto 0) := "0000";
   signal output2 : std_logic_vector(3 downto 0) := "0110";
   signal output3 : std_logic_vector(3 downto 0) := "0000";
   
begin 

   process (clk100)
   begin
      if rising_edge(clk100) then
      
         GPIO_done <= '0';
      
         if (GPIO_writeEna = '1') then
            
            case GPIO_addr is
               when "00"   => output1 <= std_logic_vector(unsigned(GPIO_Dout) + 1);
               when "10"   => output3 <= not GPIO_Dout;
               when others => null;
            end case;
            
         end if;
         
         if (GPIO_readEna = '1') then
         
            GPIO_done <= '1';
            
            case GPIO_addr is
               when "00"   => GPIO_Din <= output1;
               when "01"   => GPIO_Din <= output2;
               when "10"   => GPIO_Din <= output3;
               when others => null;
            end case;
         end if;
         
      end if;
   end process;
   

end architecture;





