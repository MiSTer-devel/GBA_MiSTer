library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pProc_bus_gba.all;
use work.pReg_gba_serial.all;

entity gba_serial is
   port 
   (
      clk100            : in    std_logic;  
      ce                : in    std_logic;  
      gb_bus            : in    proc_bus_gb_type;
      wired_out         : out   std_logic_vector(proc_buswidth-1 downto 0) := (others => '0');
      wired_done        : out   std_logic;
      
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
   
   type t_reg_wired_or is array(0 to 13) of std_logic_vector(31 downto 0);
   signal reg_wired_or    : t_reg_wired_or;   
   signal reg_wired_done  : unsigned(0 to 13);

   signal SIO_start       : std_logic := '0';
   signal cycles          : unsigned(11 downto 0) := (others => '0');
   signal bitcount        : integer range 0 to 31 := 0;
   

begin 

   iSIODATA32   : entity work.eProcReg_gba generic map (SIODATA32  ) port map  (clk100, gb_bus, reg_wired_or(0 ), reg_wired_done(0 ), REG_SIODATA32  , REG_SIODATA32  );  
   iSIOMULTI0   : entity work.eProcReg_gba generic map (SIOMULTI0  ) port map  (clk100, gb_bus, reg_wired_or(1 ), reg_wired_done(1 ), REG_SIOMULTI0  , REG_SIOMULTI0  );  
   iSIOMULTI1   : entity work.eProcReg_gba generic map (SIOMULTI1  ) port map  (clk100, gb_bus, reg_wired_or(2 ), reg_wired_done(2 ), REG_SIOMULTI1  , REG_SIOMULTI1  );  
   iSIOMULTI2   : entity work.eProcReg_gba generic map (SIOMULTI2  ) port map  (clk100, gb_bus, reg_wired_or(3 ), reg_wired_done(3 ), REG_SIOMULTI2  , REG_SIOMULTI2  );  
   iSIOMULTI3   : entity work.eProcReg_gba generic map (SIOMULTI3  ) port map  (clk100, gb_bus, reg_wired_or(4 ), reg_wired_done(4 ), REG_SIOMULTI3  , REG_SIOMULTI3  );  
   iSIOCNT      : entity work.eProcReg_gba generic map (SIOCNT     ) port map  (clk100, gb_bus, reg_wired_or(5 ), reg_wired_done(5 ), SIOCNT_READBACK, REG_SIOCNT     , SIOCNT_written);  
   iSIOMLT_SEND : entity work.eProcReg_gba generic map (SIOMLT_SEND) port map  (clk100, gb_bus, reg_wired_or(6 ), reg_wired_done(6 ), REG_SIOMLT_SEND, REG_SIOMLT_SEND);  
   iSIODATA8    : entity work.eProcReg_gba generic map (SIODATA8   ) port map  (clk100, gb_bus, reg_wired_or(7 ), reg_wired_done(7 ), REG_SIODATA8   , REG_SIODATA8   );  
   iRCNT        : entity work.eProcReg_gba generic map (RCNT       ) port map  (clk100, gb_bus, reg_wired_or(8 ), reg_wired_done(8 ), REG_RCNT       , REG_RCNT       );  
   iIR          : entity work.eProcReg_gba generic map (IR         ) port map  (clk100, gb_bus, reg_wired_or(9 ), reg_wired_done(9 ), REG_IR         , REG_IR         );  
   iJOYCNT      : entity work.eProcReg_gba generic map (JOYCNT     ) port map  (clk100, gb_bus, reg_wired_or(10), reg_wired_done(10), REG_JOYCNT     , REG_JOYCNT     );  
   iJOY_RECV    : entity work.eProcReg_gba generic map (JOY_RECV   ) port map  (clk100, gb_bus, reg_wired_or(11), reg_wired_done(11), REG_JOY_RECV   , REG_JOY_RECV   );  
   iJOY_TRANS   : entity work.eProcReg_gba generic map (JOY_TRANS  ) port map  (clk100, gb_bus, reg_wired_or(12), reg_wired_done(12), REG_JOY_TRANS  , REG_JOY_TRANS  );  
   iJOYSTAT     : entity work.eProcReg_gba generic map (JOYSTAT    ) port map  (clk100, gb_bus, reg_wired_or(13), reg_wired_done(13), REG_JOYSTAT    , REG_JOYSTAT    );  

   process (reg_wired_or)
      variable wired_or : std_logic_vector(31 downto 0);
   begin
      wired_or := reg_wired_or(0);
      for i in 1 to (reg_wired_or'length - 1) loop
         wired_or := wired_or or reg_wired_or(i);
      end loop;
      wired_out <= wired_or;
   end process;
   wired_done <= '0' when (reg_wired_done = 0) else '1';
   
   SIOCNT_READBACK <= REG_SIOCNT(15 downto 8) & SIO_start & REG_SIOCNT(6 downto 0);
   
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         IRP_Serial <= '0';

         if (SIO_start = '1') then
            if (ce = '1') then
               cycles <= cycles + 1;

               if ((REG_SIOCNT(1) = '0' and cycles >= 63) or (REG_SIOCNT(1) = '1' and cycles >= 7)) then
                  if (REG_SIOCNT(1) = '1') then
                     cycles <= cycles - 7;
                  else
                     cycles <= cycles - 63;
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





