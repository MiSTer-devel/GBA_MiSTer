-----------------------------------------------------------------
--------------- Proc Bus Package --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pProc_bus_gba is

   constant proc_buswidth : integer := 32;
   constant proc_busadr   : integer := 28;
   
   constant ACCESS_8BIT  : std_logic_vector(1 downto 0) := "00";
   constant ACCESS_16BIT : std_logic_vector(1 downto 0) := "01";
   constant ACCESS_32BIT : std_logic_vector(1 downto 0) := "10";
   
   type proc_bus_gb_type is record
      Din  : std_logic_vector(proc_buswidth-1 downto 0);
      Adr  : std_logic_vector(proc_busadr-1 downto 0);
      rnw  : std_logic;
      ena  : std_logic;
      acc  : std_logic_vector(1 downto 0);
      bEna : std_logic_vector(3 downto 0);
      rst  : std_logic;
   end record;
  
end package;


-----------------------------------------------------------------
--------------- Reg Map Package --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library work;
use work.pProc_bus_gba.all;

package pRegmap_gba is

   type regaccess_type is
   (
      readwrite,
      readonly,
      writeonly,
      writeDone -- writeonly, but does send back done, so it is not dead
   );

   type regmap_type is record
      Adr         : integer range 0 to (2**proc_busadr)-1;
      upper       : integer range 0 to proc_buswidth-1;
      lower       : integer range 0 to proc_buswidth-1;
      size        : integer range 0 to (2**proc_busadr)-1;
      startVal    : integer;
      acccesstype : regaccess_type;
   end record;
   
end package;

-----------------------------------------------------------------
--------------- Reg Interface -----------------------------------
-----------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  

library work;
use work.pProc_bus_gba.all;
use work.pRegmap_gba.all;

entity eProcReg_gba  is
   generic
   (
      Reg       : regmap_type;
      index     : integer := 0
   );
   port 
   (
      clk        : in    std_logic;
      proc_bus   : in    proc_bus_gb_type;
      wired_out  : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done : out   std_logic;
      Din        : in    std_logic_vector(Reg.upper downto Reg.lower);
      Dout       : out   std_logic_vector(Reg.upper downto Reg.lower);
      written    : out   std_logic := '0';
      writeValue : out   std_logic_vector(Reg.upper downto Reg.lower);
      writeTo    : out   std_logic := '0';
      bEna       : out   std_logic_vector(3 downto 0) := "0000"
   );
end entity;

architecture arch of eProcReg_gba is

   signal Dout_buffer : std_logic_vector(Reg.upper downto Reg.lower) := std_logic_vector(to_unsigned(Reg.startVal,Reg.upper-Reg.lower+1));
    
   signal Adr : std_logic_vector(proc_bus.adr'left downto 0);
    
begin

   Adr <= std_logic_vector(to_unsigned(Reg.Adr + index, proc_bus.adr'length));

   process (all)
   begin
      writeTo    <= '0';
      writeValue <= Dout_buffer; 
      if (proc_bus.Adr = Adr and proc_bus.rnw = '0' and proc_bus.ena = '1') then
         for i in Reg.lower to Reg.upper loop
            if ((proc_bus.bEna(0) = '1' and i < 8) or 
            (proc_bus.bEna(1) = '1' and i >= 8 and i < 16) or 
            (proc_bus.bEna(2) = '1' and i >= 16 and i < 24) or 
            (proc_bus.bEna(3) = '1' and i >= 24)) then
               writeValue(i) <= proc_bus.Din(i);  
               writeTo       <= '1';
            end if;
         end loop;
      end if;
   end process;

   greadwrite : if (Reg.acccesstype = readwrite or Reg.acccesstype = writeonly or Reg.acccesstype = writeDone) generate
   begin
   
      process (clk)
      begin
         if rising_edge(clk) then
         
            written <= '0';
            bEna    <= "0000";
            
            if (proc_bus.rst = '1') then
            
               Dout_buffer <= std_logic_vector(to_unsigned(Reg.startVal,Reg.upper-Reg.lower+1));
            
            else
         
               if (proc_bus.Adr = Adr and proc_bus.rnw = '0' and proc_bus.ena = '1') then
                  for i in Reg.lower to Reg.upper loop
                     if ((proc_bus.bEna(0) = '1' and i < 8) or 
                     (proc_bus.bEna(1) = '1' and i >= 8 and i < 16) or 
                     (proc_bus.bEna(2) = '1' and i >= 16 and i < 24) or 
                     (proc_bus.bEna(3) = '1' and i >= 24)) then
                        Dout_buffer(i) <= proc_bus.Din(i);  
                        written        <= '1';
                        bEna           <= proc_bus.bEna;
                     end if;
                  end loop;
               end if;
             
            end if;
            
         end if;
      end process;
   end generate;
   
   greadOnly : if (Reg.acccesstype = readonly) generate
   begin
      written     <= '0';
      Dout_buffer <= std_logic_vector(to_unsigned(Reg.startVal,Reg.upper-Reg.lower+1));
   end generate;
   
   Dout <= Dout_buffer;
   
   goutput1 : if ((Reg.acccesstype = readwrite or Reg.acccesstype = readonly) and Reg.lower = 0 and Reg.upper = (proc_buswidth-1)) generate
   begin
      goutputbit: for i in Reg.lower to Reg.upper generate
         wired_out(i) <= Din(i) when proc_bus.Adr = Adr else '0';
      end generate;
   end generate;
   
   goutput2 : if ((Reg.acccesstype = readwrite or Reg.acccesstype = readonly) and Reg.lower > 0 and Reg.upper = (proc_buswidth-1)) generate
   begin
      goutputbit: for i in Reg.lower to Reg.upper generate
         wired_out(i) <= Din(i) when proc_bus.Adr = Adr else '0';
      end generate;
      
      glowzero: for i in 0 to Reg.lower - 1 generate
         wired_out(i) <= '0';
      end generate;
   end generate;
   
   goutput3 : if ((Reg.acccesstype = readwrite or Reg.acccesstype = readonly) and Reg.lower = 0 and Reg.upper < (proc_buswidth-1)) generate
   begin
      goutputbit: for i in Reg.lower to Reg.upper generate
         wired_out(i) <= Din(i) when proc_bus.Adr = Adr else '0';
      end generate;
      
      ghighzero: for i in Reg.upper + 1 to proc_buswidth-1 generate
         wired_out(i) <= '0';
      end generate;
   end generate;
   
   goutput4 : if ((Reg.acccesstype = readwrite or Reg.acccesstype = readonly) and Reg.lower > 0 and Reg.upper < (proc_buswidth-1)) generate
   begin
      goutputbit: for i in Reg.lower to Reg.upper generate
         wired_out(i) <= Din(i) when proc_bus.Adr = Adr else '0';
      end generate;
      
      glowzero: for i in 0 to Reg.lower - 1 generate
         wired_out(i) <= '0';
      end generate;
      
      ghighzero: for i in Reg.upper + 1 to proc_buswidth-1 generate
         wired_out(i) <= '0';
      end generate;
   end generate;
   
   goutputWriteOnly : if (Reg.acccesstype = writeonly or Reg.acccesstype = writeDone) generate
   begin
      wired_out <= (others => '0');
   end generate;
   
   wired_done <= '1' when Reg.lower = 0 and proc_bus.Adr = Adr and Reg.acccesstype /= writeonly else '0';
 
end architecture;




