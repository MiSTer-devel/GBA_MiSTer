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
      
      new_cycles        : in  unsigned(7 downto 0);
      new_cycles_valid  : in  std_logic;
      
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
   signal REG_SIOMLT_SEND : std_logic_vector(SIOMLT_SEND.upper downto SIOMLT_SEND.lower) := (others => '0');
   signal REG_SIODATA8    : std_logic_vector(SIODATA8   .upper downto SIODATA8   .lower) := (others => '0');
   signal REG_RCNT        : std_logic_vector(RCNT       .upper downto RCNT       .lower) := (others => '0');
   signal REG_IR          : std_logic_vector(IR         .upper downto IR         .lower) := (others => '0');
   signal REG_JOYCNT      : std_logic_vector(JOYCNT     .upper downto JOYCNT     .lower) := (others => '0');
   signal REG_JOY_RECV    : std_logic_vector(JOY_RECV   .upper downto JOY_RECV   .lower) := (others => '0');
   signal REG_JOY_TRANS   : std_logic_vector(JOY_TRANS  .upper downto JOY_TRANS  .lower) := (others => '0');
   signal REG_JOYSTAT     : std_logic_vector(JOYSTAT    .upper downto JOYSTAT    .lower) := (others => '0');

   signal SIOCNT_READBACK : std_logic_vector(SIOCNT     .upper downto SIOCNT     .lower) := (others => '0');
   signal SIOCNT_written  : std_logic;

   signal SIO_start       : std_logic := '0';
   signal cycles          : unsigned(11 downto 0) := (others => '0');
   signal bitcount        : integer range 0 to 31 := 0;
   

begin 

   iSIODATA32   : entity work.eProcReg_gba generic map (SIODATA32  ) port map  (clk100, gb_bus, REG_SIODATA32  , REG_SIODATA32  );  
   iSIOMULTI0   : entity work.eProcReg_gba generic map (SIOMULTI0  ) port map  (clk100, gb_bus, REG_SIOMULTI0  , REG_SIOMULTI0  );  
   iSIOMULTI1   : entity work.eProcReg_gba generic map (SIOMULTI1  ) port map  (clk100, gb_bus, REG_SIOMULTI1  , REG_SIOMULTI1  );  
   iSIOMULTI2   : entity work.eProcReg_gba generic map (SIOMULTI2  ) port map  (clk100, gb_bus, REG_SIOMULTI2  , REG_SIOMULTI2  );  
   iSIOMULTI3   : entity work.eProcReg_gba generic map (SIOMULTI3  ) port map  (clk100, gb_bus, REG_SIOMULTI3  , REG_SIOMULTI3  );  
   iSIOCNT      : entity work.eProcReg_gba generic map (SIOCNT     ) port map  (clk100, gb_bus, SIOCNT_READBACK, REG_SIOCNT     , SIOCNT_written);  
   iSIOMLT_SEND : entity work.eProcReg_gba generic map (SIOMLT_SEND) port map  (clk100, gb_bus, REG_SIOMLT_SEND, REG_SIOMLT_SEND);  
   iSIODATA8    : entity work.eProcReg_gba generic map (SIODATA8   ) port map  (clk100, gb_bus, REG_SIODATA8   , REG_SIODATA8   );  
   iRCNT        : entity work.eProcReg_gba generic map (RCNT       ) port map  (clk100, gb_bus, REG_RCNT       , REG_RCNT       );  
   iIR          : entity work.eProcReg_gba generic map (IR         ) port map  (clk100, gb_bus, REG_IR         , REG_IR         );  
   iJOYCNT      : entity work.eProcReg_gba generic map (JOYCNT     ) port map  (clk100, gb_bus, REG_JOYCNT     , REG_JOYCNT     );  
   iJOY_RECV    : entity work.eProcReg_gba generic map (JOY_RECV   ) port map  (clk100, gb_bus, REG_JOY_RECV   , REG_JOY_RECV   );  
   iJOY_TRANS   : entity work.eProcReg_gba generic map (JOY_TRANS  ) port map  (clk100, gb_bus, REG_JOY_TRANS  , REG_JOY_TRANS  );  
   iJOYSTAT     : entity work.eProcReg_gba generic map (JOYSTAT    ) port map  (clk100, gb_bus, REG_JOYSTAT    , REG_JOYSTAT    );  
   
   SIOCNT_READBACK <= REG_SIOCNT(15 downto 8) & SIO_start & REG_SIOCNT(6 downto 0);
   
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         IRP_Serial <= '0';

         if (SIO_start = '1') then
            if (new_cycles_valid = '1') then
               cycles <= cycles + new_cycles;
            else
               if ((REG_SIOCNT(1) = '0' and cycles >= 64) or (REG_SIOCNT(1) = '1' and cycles >= 8)) then
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

   
         if (SIOCNT_written = '1') then
            if (REG_SIOCNT(7) = '1') then
               SIO_start <= '1';
               bitcount  <= 0;
               cycles    <= (others => '0');
            end if;
         end if;
    
      end if;
   end process;

end architecture;





