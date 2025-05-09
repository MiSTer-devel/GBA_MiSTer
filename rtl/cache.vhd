library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;   
use ieee.math_real.all;  

library mem;

entity cache is
   generic
   (
      SIZE                     : integer;  -- size of  cache to be cached
      SIZEBASEBITS             : integer;  -- size of memory to be cached
      BITWIDTH                 : integer;
      Softmap_GBA_Gamerom_ADDR : integer   -- count: 8388608  -- 32 Mbyte Data for GameRom 
   );
   port 
   (
      clk               : in  std_logic;
      gb_on             : in  std_logic;
                        
      read_enable       : in  std_logic;
      read_addr         : in  std_logic_vector(SIZEBASEBITS-1 downto 0);
      read_data         : out std_logic_vector(BITWIDTH-1 downto 0) := (others => '0');
      read_done         : out std_logic := '0';
      read_full         : out std_logic_vector((BITWIDTH * 2)-1 downto 0) := (others => '0');
      
      mem_read_ena      : out   std_logic := '0';
      mem_read_done     : in    std_logic := '0';
      mem_read_addr     : out   std_logic_vector(24 downto 0) := (others => '0');
      mem_read_data     : in    std_logic_vector(31 downto 0);
      mem_read_data2    : in    std_logic_vector(31 downto 0)
     
   );
end entity;

architecture arch of cache is
   
begin 
   
   mem_read_ena    <= read_enable;
   mem_read_addr   <= std_logic_vector(to_unsigned(Softmap_GBA_Gamerom_ADDR, 25) + unsigned(read_addr));

   read_done        <= mem_read_done;
   read_data        <= mem_read_data;

end architecture;




























