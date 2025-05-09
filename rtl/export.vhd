-----------------------------------------------------------------
--------------- Export Package  --------------------------------
-----------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

package pexport is

   type tExportRegs is array(0 to 14) of unsigned(31 downto 0);

   type cpu_export_type is record
      regs           : tExportRegs;
      pc             : unsigned(31 downto 0);
      opcode         : unsigned(31 downto 0);
      CPSR           : unsigned(31 downto 0);
      SPSR           : unsigned(31 downto 0);
      regs_0_8       : unsigned(31 downto 0);
      regs_0_9       : unsigned(31 downto 0);
      regs_0_10      : unsigned(31 downto 0);
      regs_0_11      : unsigned(31 downto 0);
      regs_0_12      : unsigned(31 downto 0);
      regs_0_13      : unsigned(31 downto 0);
      regs_0_14      : unsigned(31 downto 0);
      regs_1_8       : unsigned(31 downto 0);
      regs_1_9       : unsigned(31 downto 0);
      regs_1_10      : unsigned(31 downto 0);
      regs_1_11      : unsigned(31 downto 0);
      regs_1_12      : unsigned(31 downto 0);
      regs_1_13      : unsigned(31 downto 0);
      regs_1_14      : unsigned(31 downto 0);
      regs_1_17      : unsigned(31 downto 0);
      regs_2_13      : unsigned(31 downto 0);
      regs_2_14      : unsigned(31 downto 0);
      regs_2_17      : unsigned(31 downto 0);
      regs_3_13      : unsigned(31 downto 0);
      regs_3_14      : unsigned(31 downto 0);
      regs_3_17      : unsigned(31 downto 0);
      regs_4_13      : unsigned(31 downto 0);
      regs_4_14      : unsigned(31 downto 0);
      regs_4_17      : unsigned(31 downto 0);
      regs_5_13      : unsigned(31 downto 0);
      regs_5_14      : unsigned(31 downto 0);
      regs_5_17      : unsigned(31 downto 0);
   end record;
   
   constant export_init : cpu_export_type := (
      (others => (others => '0')), 
      (others => '0'), 
      (others => '0'), 
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0'),
      (others => '0')
   );   
  
end package;

-----------------------------------------------------------------
--------------- Export module    --------------------------------
-----------------------------------------------------------------


library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     
use STD.textio.all;

use work.pexport.all;

entity export is
   generic
   (
      export_index      : std_logic := '1';
      export_time       : std_logic := '1'
   );
   port 
   (
      clk               : in std_logic;
      ce                : in std_logic;
      reset             : in std_logic;
         
      new_export        : in std_logic;
      export_cpu        : in cpu_export_type;
      export_line       : in unsigned(7 downto 0);
      export_dispstat   : in unsigned(7 downto 0); 
      export_IRPFLags   : in unsigned(15 downto 0);
      export_timer0     : in unsigned(15 downto 0);
      export_timer1     : in unsigned(15 downto 0);
      export_timer2     : in unsigned(15 downto 0);
      export_timer3     : in unsigned(15 downto 0);
      PF_count          : in unsigned(3 downto 0);
      PF_countdown      : in unsigned(3 downto 0);
      sound_fifocount   : in unsigned(15 downto 0)
   );
end entity;

architecture arch of export is
     
   signal newticks               : unsigned(31 downto 0) := (others => '0');
   signal totalticks             : unsigned(31 downto 0) := (others => '0');
   signal totalticks_last        : unsigned(31 downto 0) := (others => '0');
   signal cyclenr                : unsigned(31 downto 0) := x"00000001";
                  
   signal reset_1                : std_logic := '0';
   signal export_reset           : std_logic := '0';
   signal export_waspaused       : std_logic := '0';
   signal exportnow              : std_logic;
            
   signal export_cpu_last        : cpu_export_type := export_init;   
   signal export_line_last       : unsigned(7 downto 0) := (others => '1');   
   signal export_dispstat_last   : unsigned(7 downto 0) := (others => '1');   
   
   signal export_IRPFLags_1      : unsigned(15 downto 0) := (others => '1');   
   signal export_IRPFLags_2      : unsigned(15 downto 0) := (others => '1');   
   signal export_IRPFLags_last   : unsigned(15 downto 0) := (others => '1');
   
   signal export_timer0_last     : unsigned(15 downto 0) := (others => '1');   
   signal export_timer1_last     : unsigned(15 downto 0) := (others => '1');   
   signal export_timer2_last     : unsigned(15 downto 0) := (others => '1');   
   signal export_timer3_last     : unsigned(15 downto 0) := (others => '1');   
   
   signal PF_count_last          : unsigned(3 downto 0) := (others => '1');   
   signal PF_countdown_last      : unsigned(3 downto 0) := (others => '1');   
   
   signal sound_fifocount_last   : unsigned(15 downto 0) := (others => '1');   
  
   function to_lower(c: character) return character is
      variable l: character;
   begin
       case c is
        when 'A' => l := 'a';
        when 'B' => l := 'b';
        when 'C' => l := 'c';
        when 'D' => l := 'd';
        when 'E' => l := 'e';
        when 'F' => l := 'f';
        when 'G' => l := 'g';
        when 'H' => l := 'h';
        when 'I' => l := 'i';
        when 'J' => l := 'j';
        when 'K' => l := 'k';
        when 'L' => l := 'l';
        when 'M' => l := 'm';
        when 'N' => l := 'n';
        when 'O' => l := 'o';
        when 'P' => l := 'p';
        when 'Q' => l := 'q';
        when 'R' => l := 'r';
        when 'S' => l := 's';
        when 'T' => l := 't';
        when 'U' => l := 'u';
        when 'V' => l := 'v';
        when 'W' => l := 'w';
        when 'X' => l := 'x';
        when 'Y' => l := 'y';
        when 'Z' => l := 'z';
        when others => l := c;
    end case;
    return l;
   end to_lower;
   
   function to_lower(s: string) return string is
     variable lowercase: string (s'range);
   begin
     for i in s'range loop
        lowercase(i):= to_lower(s(i));
     end loop;
     return lowercase;
   end to_lower;
     
begin  
 
-- synthesis translate_off
   process(clk)
   begin
      if rising_edge(clk) then
         reset_1 <= reset;
         if (reset = '1') then
            totalticks <= x"00000000";
            newticks   <= (others => '0');
         elsif (ce = '1') then
            totalticks <= totalticks + 1;
            newticks   <= newticks + 1;         
            if (exportnow = '1') then
               newticks         <= to_unsigned(1, newticks'length);
               export_waspaused <= '0';
            end if;
         else
            export_waspaused <= '1';
         end if;    
      end if;
   end process;
   
   export_reset <= '1' when (reset = '0' and reset_1 = '1') else '0';
   
   exportnow <=  new_export;

   process
   
      file outfile: text;
      file outfile_irp: text;
      variable f_status: FILE_OPEN_STATUS;
      variable line_out : line;
      variable recordcount : integer := 0;
      
      constant filenamebase               : string := "R:\\cpu_gba_sim";
      variable filename_current           : string(1 to 27);
      
      variable newticks_mod               : unsigned(31 downto 0);
      
   begin
   
      filename_current := filenamebase & "00000000.txt";
   
      file_open(f_status, outfile, filename_current, write_mode);
      file_close(outfile);
      file_open(f_status, outfile, filename_current, append_mode); 
      
      while (true) loop
         wait until rising_edge(clk);
         if (reset = '1') then
            cyclenr <= x"00000001";
            filename_current := filenamebase & "00000000.txt";
            file_close(outfile);
            file_open(f_status, outfile, filename_current, write_mode);
            file_close(outfile);
            file_open(f_status, outfile, filename_current, append_mode);
         end if;
         
         export_IRPFLags_1 <= export_IRPFLags;
         export_IRPFLags_2 <= export_IRPFLags_1;
         
         if (exportnow = '1') then
         
            if (export_index = '1') then
               write(line_out, string'("# "));
               write(line_out, to_lower(to_hstring(cyclenr - 1)) & " ");
            end if;
         
            if (export_time = '1') then
               totalticks_last  <= totalticks;
               write(line_out, string'("# "));
               if (cyclenr = 1) then
                  write(line_out, to_lower(to_hstring(totalticks - 2)) & " ");
                  write(line_out, string'("# "));
                  write(line_out, to_lower(to_hstring(newticks(11 downto 0) - 2)) & " ");
               else
                  write(line_out, to_lower(to_hstring(totalticks - 2)) & " ");
                  write(line_out, string'("# "));
                  
                  newticks_mod := newticks;
                  if (export_waspaused = '1') then
                     newticks_mod := totalticks - totalticks_last;
                  end if;
                  
                  if (newticks_mod(31 downto 12) = 0) then
                     write(line_out, to_lower(to_hstring(newticks_mod(11 downto 0))) & " ");
                  elsif (newticks_mod(31 downto 16) = 0) then
                     write(line_out, to_lower(to_hstring(newticks_mod(15 downto 0))) & " ");
                  else
                     write(line_out, to_lower(to_hstring(newticks_mod)) & " ");
                  end if;
               end if;
            end if;
            
            write(line_out, string'("PC "));
            write(line_out, to_lower(to_hstring(export_cpu.pc)) & " ");
            
            write(line_out, string'("OP "));
            write(line_out, to_lower(to_hstring(export_cpu.opcode)) & " ");
            
            for i in 0 to 14 loop
               if (cyclenr = 1 or export_cpu.regs(i) /= export_cpu_last.regs(i)) then
                  write(line_out, string'("R"));
                  if (i < 10) then 
                     write(line_out, string'("0"));
                  end if;
                  write(line_out, to_lower(to_string(i)));
                  write(line_out, string'(" "));
                  write(line_out, to_lower(to_hstring(export_cpu.regs(i))) & " ");
               end if;
            end loop; 

            if (cyclenr = 1 or export_cpu.CPSR      /= export_cpu_last.CPSR     )   then write(line_out, string'("CPSR "));   write(line_out, to_lower(to_hstring(export_cpu.CPSR     )) & " "); end if;
            if (cyclenr = 1 or export_cpu.SPSR      /= export_cpu_last.SPSR     )   then write(line_out, string'("SPSR "));   write(line_out, to_lower(to_hstring(export_cpu.SPSR     )) & " "); end if;
            
            if (cyclenr = 1 or export_cpu.regs_0_8  /= export_cpu_last.regs_0_8 )   then write(line_out, string'("R0_8 "));   write(line_out, to_lower(to_hstring(export_cpu.regs_0_8 )) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_0_9  /= export_cpu_last.regs_0_9 )   then write(line_out, string'("R0_9 "));   write(line_out, to_lower(to_hstring(export_cpu.regs_0_9 )) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_0_10 /= export_cpu_last.regs_0_10)   then write(line_out, string'("R0_10 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_0_10)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_0_11 /= export_cpu_last.regs_0_11)   then write(line_out, string'("R0_11 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_0_11)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_0_12 /= export_cpu_last.regs_0_12)   then write(line_out, string'("R0_12 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_0_12)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_0_13 /= export_cpu_last.regs_0_13)   then write(line_out, string'("R0_13 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_0_13)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_0_14 /= export_cpu_last.regs_0_14)   then write(line_out, string'("R0_14 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_0_14)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_1_8  /= export_cpu_last.regs_1_8 )   then write(line_out, string'("R1_8 "));   write(line_out, to_lower(to_hstring(export_cpu.regs_1_8 )) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_1_9  /= export_cpu_last.regs_1_9 )   then write(line_out, string'("R1_9 "));   write(line_out, to_lower(to_hstring(export_cpu.regs_1_9 )) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_1_10 /= export_cpu_last.regs_1_10)   then write(line_out, string'("R1_10 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_1_10)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_1_11 /= export_cpu_last.regs_1_11)   then write(line_out, string'("R1_11 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_1_11)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_1_12 /= export_cpu_last.regs_1_12)   then write(line_out, string'("R1_12 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_1_12)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_1_13 /= export_cpu_last.regs_1_13)   then write(line_out, string'("R1_13 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_1_13)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_1_14 /= export_cpu_last.regs_1_14)   then write(line_out, string'("R1_14 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_1_14)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_1_17 /= export_cpu_last.regs_1_17)   then write(line_out, string'("R1_17 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_1_17)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_2_13 /= export_cpu_last.regs_2_13)   then write(line_out, string'("R2_13 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_2_13)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_2_14 /= export_cpu_last.regs_2_14)   then write(line_out, string'("R2_14 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_2_14)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_2_17 /= export_cpu_last.regs_2_17)   then write(line_out, string'("R2_17 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_2_17)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_3_13 /= export_cpu_last.regs_3_13)   then write(line_out, string'("R3_13 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_3_13)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_3_14 /= export_cpu_last.regs_3_14)   then write(line_out, string'("R3_14 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_3_14)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_3_17 /= export_cpu_last.regs_3_17)   then write(line_out, string'("R3_17 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_3_17)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_4_13 /= export_cpu_last.regs_4_13)   then write(line_out, string'("R4_13 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_4_13)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_4_14 /= export_cpu_last.regs_4_14)   then write(line_out, string'("R4_14 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_4_14)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_4_17 /= export_cpu_last.regs_4_17)   then write(line_out, string'("R4_17 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_4_17)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_5_13 /= export_cpu_last.regs_5_13)   then write(line_out, string'("R5_13 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_5_13)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_5_14 /= export_cpu_last.regs_5_14)   then write(line_out, string'("R5_14 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_5_14)) & " "); end if;
            if (cyclenr = 1 or export_cpu.regs_5_17 /= export_cpu_last.regs_5_17)   then write(line_out, string'("R5_17 "));  write(line_out, to_lower(to_hstring(export_cpu.regs_5_17)) & " "); end if;

            if (cyclenr = 1 or export_line /= export_line_last)           then write(line_out, string'("Line "));  write(line_out, to_lower(to_hstring(export_line)) & " ");     end if;
            if (cyclenr = 1 or export_dispstat /= export_dispstat_last)   then write(line_out, string'("DS "));    write(line_out, to_lower(to_hstring(export_dispstat)) & " "); end if;
            
            if (cyclenr = 1 or export_IRPFLags_2 /= export_IRPFLags_last)   then write(line_out, string'("IRQ "));    write(line_out, to_lower(to_hstring(export_IRPFLags_2)) & " "); end if;
            
            if (cyclenr = 1 or export_timer0 /= export_timer0_last)   then write(line_out, string'("T0 "));    write(line_out, to_lower(to_hstring(export_timer0)) & " "); end if;
            if (cyclenr = 1 or export_timer1 /= export_timer1_last)   then write(line_out, string'("T1 "));    write(line_out, to_lower(to_hstring(export_timer1)) & " "); end if;
            if (cyclenr = 1 or export_timer2 /= export_timer2_last)   then write(line_out, string'("T2 "));    write(line_out, to_lower(to_hstring(export_timer2)) & " "); end if;
            if (cyclenr = 1 or export_timer3 /= export_timer3_last)   then write(line_out, string'("T3 "));    write(line_out, to_lower(to_hstring(export_timer3)) & " "); end if;
            
            if (cyclenr = 1 or PF_count     /= PF_count_last)       then write(line_out, string'("PreC "));    write(line_out, to_lower(to_hstring(PF_count)) & " "); end if;
            if (cyclenr = 1 or PF_countdown /= PF_countdown_last)   then write(line_out, string'("PrCD "));    write(line_out, to_lower(to_hstring(PF_countdown)) & " "); end if;
            
            --if (cyclenr = 1 or sound_fifocount /= sound_fifocount_last)   then write(line_out, string'("SDMA "));    write(line_out, to_lower(to_hstring(sound_fifocount)) & " "); end if;

            writeline(outfile, line_out);
            
            cyclenr     <= cyclenr + 1;
            
            --if (cyclenr mod 10000000 = 0) then
            --   filename_current := filenamebase & to_hstring(cyclenr) & ".txt";
            --   file_close(outfile);
            --   file_open(f_status, outfile, filename_current, write_mode);
            --   file_close(outfile);
            --   file_open(f_status, outfile, filename_current, append_mode);
            --end if;
            
            export_cpu_last         <= export_cpu;
            export_line_last        <= export_line; 
            export_dispstat_last    <= export_dispstat;
            export_IRPFLags_last    <= export_IRPFLags_2;
            
            export_timer0_last <= export_timer0;
            export_timer1_last <= export_timer1;
            export_timer2_last <= export_timer2;
            export_timer3_last <= export_timer3;
            
            PF_count_last     <= PF_count;
            PF_countdown_last <= PF_countdown;
            
            sound_fifocount_last <= sound_fifocount;
            
         end if;
            
      end loop;
      
   end process;
-- synthesis translate_on

end architecture;





