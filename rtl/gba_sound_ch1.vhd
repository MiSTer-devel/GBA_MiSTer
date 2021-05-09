library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegmap_gba.all;
use work.pProc_bus_gba.all;
use work.pReg_gba_sound.all;

entity gba_sound_ch1 is
   generic
   (
      has_sweep                      : boolean;
      Reg_Number_of_sweep_shift      : regmap_type;
      Reg_Sweep_Frequency_Direction  : regmap_type;
      Reg_Sweep_Time                 : regmap_type;
      Reg_Sound_length               : regmap_type;
      Reg_Wave_Pattern_Duty          : regmap_type;
      Reg_Envelope_Step_Time         : regmap_type;
      Reg_Envelope_Direction         : regmap_type;
      Reg_Initial_Volume_of_envelope : regmap_type;
      Reg_Frequency                  : regmap_type;
      Reg_Length_Flag                : regmap_type;
      Reg_Initial                    : regmap_type;
      Reg_HighZero                   : regmap_type
   );
   port 
   (
      clk100              : in    std_logic; 
      reset               : in    std_logic;
      gb_on               : in    std_logic;  
      ch_on_ss            : in    std_logic;  
      loading_savestate   : in    std_logic;  
      
      gb_bus              : inout proc_bus_gb_type := ((others => 'Z'), (others => 'Z'), (others => 'Z'), 'Z', 'Z', 'Z', "ZZ", "ZZZZ", 'Z');
      
      new_cycles_valid    : in    std_logic;
      
      sound_out           : out   signed(15 downto 0) := (others => '0');
      sound_on            : out   std_logic := '0'
   );
end entity;

architecture arch of gba_sound_ch1 is

   signal Channel_Number_of_sweep_shift      : std_logic_vector(Reg_Number_of_sweep_shift     .upper downto Reg_Number_of_sweep_shift     .lower) := (others => '0');
   signal Channel_Sweep_Frequency_Direction  : std_logic_vector(Reg_Sweep_Frequency_Direction .upper downto Reg_Sweep_Frequency_Direction .lower) := (others => '0');
   signal Channel_Sweep_Time                 : std_logic_vector(Reg_Sweep_Time                .upper downto Reg_Sweep_Time                .lower) := (others => '0');
   signal Channel_Sound_length               : std_logic_vector(Reg_Sound_length              .upper downto Reg_Sound_length              .lower) := (others => '0');
   signal Channel_Wave_Pattern_Duty          : std_logic_vector(Reg_Wave_Pattern_Duty         .upper downto Reg_Wave_Pattern_Duty         .lower) := (others => '0');
   signal Channel_Envelope_Step_Time         : std_logic_vector(Reg_Envelope_Step_Time        .upper downto Reg_Envelope_Step_Time        .lower) := (others => '0');
   signal Channel_Envelope_Direction         : std_logic_vector(Reg_Envelope_Direction        .upper downto Reg_Envelope_Direction        .lower) := (others => '0');
   signal Channel_Initial_Volume_of_envelope : std_logic_vector(Reg_Initial_Volume_of_envelope.upper downto Reg_Initial_Volume_of_envelope.lower) := (others => '0');
   signal Channel_Frequency                  : std_logic_vector(Reg_Frequency                 .upper downto Reg_Frequency                 .lower) := (others => '0');
   signal Channel_Length_Flag                : std_logic_vector(Reg_Length_Flag               .upper downto Reg_Length_Flag               .lower) := (others => '0');
   signal Channel_Initial                    : std_logic_vector(Reg_Initial                   .upper downto Reg_Initial                   .lower) := (others => '0');
   signal Channel_HighZero                   : std_logic_vector(Reg_HighZero                  .upper downto Reg_HighZero                  .lower) := (others => '0');
                                                                                                                                                     
   signal Channel_Sound_length_written                : std_logic;                                                                                                                                                      
   signal Channel_Wave_Pattern_Duty_written           : std_logic;                                                                                                                                                                                                                                                                                                            
   signal Channel_Initial_Volume_of_envelope_written  : std_logic;                                                                                                                                                      
   signal Channel_Frequency_written                   : std_logic;                                                                                                                                                                                                                                                                                                                                                                                                                                                               
                                                                                                                                                     
   signal wavetable_ptr        : unsigned(2 downto 0)  := (others => '0');
   signal wavetable            : std_logic_vector(0 to 7)  := (others => '0');
   signal wave_on              : std_logic := '0';      
                               
   signal sweepcnt             : unsigned(7 downto 0) := (others => '0');
                               
   signal length_left          : unsigned(6 downto 0) := (others => '0');
                               
   signal envelope_cnt         : unsigned(5 downto 0) := (others => '0');
   signal envelope_add         : unsigned(5 downto 0) := (others => '0');
                               
   signal volume               : integer range 0 to 15 := 0;
                               
   signal freq_divider         : unsigned(11 downto 0) := (others => '0');
   signal freq_check           : unsigned(11 downto 0) := (others => '0');
   signal length_on            : std_logic := '0';
   signal ch_on                : std_logic := '0';
   signal freq_cnt             : unsigned(11 downto 0) := (others => '0');
   signal sweep_next           : unsigned(11 downto 0);
   
   signal soundcycles_freq     : unsigned(7 downto 0)  := (others => '0');
   signal soundcycles_sweep    : unsigned(16 downto 0) := (others => '0');
   signal soundcycles_envelope : unsigned(17 downto 0) := (others => '0');
   signal soundcycles_length   : unsigned(16 downto 0) := (others => '0');
   
begin 

   gsweep : if has_sweep = true generate
   begin
      iReg_Channel_Number_of_sweep_shift      : entity work.eProcReg_gba generic map ( Reg_Number_of_sweep_shift      ) port map  (clk100, gb_bus, Channel_Number_of_sweep_shift     , Channel_Number_of_sweep_shift     );  
      iReg_Channel_Sweep_Frequency_Direction  : entity work.eProcReg_gba generic map ( Reg_Sweep_Frequency_Direction  ) port map  (clk100, gb_bus, Channel_Sweep_Frequency_Direction , Channel_Sweep_Frequency_Direction );  
      iReg_Channel_Sweep_Time                 : entity work.eProcReg_gba generic map ( Reg_Sweep_Time                 ) port map  (clk100, gb_bus, Channel_Sweep_Time                , Channel_Sweep_Time                );  
   end generate;
   
   iReg_Channel_Sound_length               : entity work.eProcReg_gba generic map ( Reg_Sound_length               ) port map  (clk100, gb_bus, "000000"                          , Channel_Sound_length              , Channel_Sound_length_written              );  
   iReg_Channel_Wave_Pattern_Duty          : entity work.eProcReg_gba generic map ( Reg_Wave_Pattern_Duty          ) port map  (clk100, gb_bus, Channel_Wave_Pattern_Duty         , Channel_Wave_Pattern_Duty         , Channel_Wave_Pattern_Duty_written         );  
   iReg_Channel_Envelope_Step_Time         : entity work.eProcReg_gba generic map ( Reg_Envelope_Step_Time         ) port map  (clk100, gb_bus, Channel_Envelope_Step_Time        , Channel_Envelope_Step_Time        );  
   iReg_Channel_Envelope_Direction         : entity work.eProcReg_gba generic map ( Reg_Envelope_Direction         ) port map  (clk100, gb_bus, Channel_Envelope_Direction        , Channel_Envelope_Direction        );  
   iReg_Channel_Initial_Volume_of_envelope : entity work.eProcReg_gba generic map ( Reg_Initial_Volume_of_envelope ) port map  (clk100, gb_bus, Channel_Initial_Volume_of_envelope, Channel_Initial_Volume_of_envelope, Channel_Initial_Volume_of_envelope_written);  
   iReg_Channel_Frequency                  : entity work.eProcReg_gba generic map ( Reg_Frequency                  ) port map  (clk100, gb_bus, "00000000000"                     , Channel_Frequency                 , Channel_Frequency_written                 );  
   iReg_Channel_Length_Flag                : entity work.eProcReg_gba generic map ( Reg_Length_Flag                ) port map  (clk100, gb_bus, Channel_Length_Flag               , Channel_Length_Flag               );  
   iReg_Channel_Initial                    : entity work.eProcReg_gba generic map ( Reg_Initial                    ) port map  (clk100, gb_bus, "0"                               , Channel_Initial                   );  
   iReg_Channel_HighZero                   : entity work.eProcReg_gba generic map ( Reg_HighZero                   ) port map  (clk100, gb_bus, Channel_HighZero);   
  
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         if (gb_on = '0') then
         
            sound_out <= (others => '0');
            sound_on  <= '0';
            
            wavetable_ptr        <= (others => '0');
            wavetable            <= (others => '0');
            wave_on              <= '0';      
            sweepcnt             <= (others => '0');
            length_left          <= (others => '0');
            envelope_cnt         <= (others => '0');
            envelope_add         <= (others => '0');
            volume               <= 0;
            freq_divider         <= (others => '0');
            freq_check           <= (others => '0');
            length_on            <= '0';  
            ch_on                <= '0';  
            freq_cnt             <= (others => '0');
            soundcycles_freq     <= (others => '0');
            soundcycles_sweep    <= (others => '0');
            soundcycles_envelope <= (others => '0');
            soundcycles_length   <= (others => '0');
         
         elsif (reset = '1') then
         
            sound_out <= (others => '0');
            ch_on     <= ch_on_ss;
         
         else
      
            -- register write triggers
            if (Channel_Wave_Pattern_Duty_written = '1') then
               sweepcnt <= (others => '0');
            end if;
            
            if (Channel_Sound_length_written = '1') then
               length_left <= to_unsigned(64, 7) - unsigned(Channel_Sound_length);
            end if;
            
            if (Channel_Initial_Volume_of_envelope_written = '1') then
               envelope_cnt <= (others => '0');
               envelope_add <= (others => '0');
               volume       <= to_integer(unsigned(Channel_Initial_Volume_of_envelope));
            end if;
            
            if (Channel_Frequency_written = '1') then
               freq_divider <= '0' & unsigned(Channel_Frequency);
               length_on <= Channel_Length_Flag(Channel_Length_Flag'left);
               if (Channel_Initial = "1") then
                  sweepcnt      <= (others => '0');
                  envelope_cnt  <= (others => '0');
                  envelope_add  <= (others => '0');
                  ch_on         <= not loading_savestate;
                  freq_cnt      <= (others => '0');
                  wavetable_ptr <= (others => '0');
               end if;
            end if;
            
            if (ch_on = '1') then
               -- cpu cycle trigger
               if (new_cycles_valid = '1') then
                  soundcycles_freq     <= soundcycles_freq     + 1;
                  soundcycles_sweep    <= soundcycles_sweep    + 1;
                  soundcycles_envelope <= soundcycles_envelope + 1;
                  soundcycles_length   <= soundcycles_length   + 1;
               end if;
               
               -- freq / wavetable
               if (new_cycles_valid = '0' and soundcycles_freq >= 4) then
                  freq_cnt <= freq_cnt + 1;
                  soundcycles_freq <= soundcycles_freq - 4;
               end if;
               
               freq_check <= 2048 - freq_divider;
               
               if (freq_cnt >= freq_check) then
                  freq_cnt <= freq_cnt - freq_check;
                  wavetable_ptr <= wavetable_ptr + 1;
               end if;
               
               -- sweep
               sweep_next <= freq_divider srl to_integer(unsigned(Channel_Number_of_sweep_shift));
               
               if (has_sweep = true) then
                  if (new_cycles_valid = '0' and soundcycles_sweep >= 32768) then -- 128 Hz
                     soundcycles_sweep <= soundcycles_sweep - 32768;
                     if (Channel_Sweep_Time /= "000") then
                        sweepcnt <= sweepcnt + 1;
                     end if;
                  end if;
                  
                  if (Channel_Sweep_Time /= "000") then
                     if (sweepcnt >= unsigned(Channel_Sweep_Time)) then
                        sweepcnt <= (others => '0');
                        if (Channel_Sweep_Frequency_Direction = "0") then -- increase
                           freq_divider <= freq_divider + sweep_next;
                           if (freq_divider + sweep_next >= 2048) then
                              ch_on <= '0';
                           end if;
                        else
                           freq_divider <= freq_divider - sweep_next;
                           if (sweep_next > freq_divider) then
                              ch_on <= '0';
                           end if;
                        end if;
                     end if;
                  end if;
                  
               end if;
               
               
               -- envelope
               if (new_cycles_valid = '0' and soundcycles_envelope >= 65536) then -- 64 Hz
                  soundcycles_envelope <= soundcycles_envelope - 65536;
                  if (Channel_Envelope_Step_Time /= "000") then
                     envelope_cnt <= envelope_cnt + 1;
                  end if;
               end if;
               
               if (Channel_Envelope_Step_Time /= "000") then
                  if (envelope_cnt >= unsigned(Channel_Envelope_Step_Time)) then
                     envelope_cnt <= (others => '0');
                     if (envelope_add < 15) then
                        envelope_add <= envelope_add + 1;
                     end if;
                  end if;
                  
                  if (Channel_Envelope_Direction = "0") then -- decrease
                     if (unsigned(Channel_Initial_Volume_of_envelope) >= envelope_add) then
                        volume <= to_integer(unsigned(Channel_Initial_Volume_of_envelope)) - to_integer(envelope_add);
                     else
                        volume <= 0;
                     end if;
                  else
                     if (unsigned(Channel_Initial_Volume_of_envelope) + envelope_add <= 15) then
                        volume <= to_integer(unsigned(Channel_Initial_Volume_of_envelope)) + to_integer(envelope_add);
                     else
                        volume <= 15;
                     end if;
                  end if;
               end if;
            
               -- length
               if (new_cycles_valid = '0' and soundcycles_length >= 16384) then -- 256 Hz
                  soundcycles_length <= soundcycles_length - 16384;
                  if (length_left > 0 and length_on = '1') then
                     length_left <= length_left - 1;
                     if (length_left = 1) then
                        ch_on <= '0';
                     end if;
                  end if;
               end if;
               
               -- duty
               case to_integer(unsigned(Channel_Wave_Pattern_Duty)) is
                  when 0 => wavetable <= "00000001";
                  when 1 => wavetable <= "10000001";
                  when 2 => wavetable <= "10000111";
                  when 3 => wavetable <= "01111110";
                  when others => null;
               end case;
               
               wave_on <= wavetable(to_integer(wavetable_ptr));
            
               -- sound out
               if (wave_on = '1') then
                  sound_out <= to_signed(1 * volume, 16);
               else
                  sound_out <= to_signed(-1 * volume, 16);
               end if;
            else
               sound_out <= (others => '0');
            end if;
         
            sound_on <= ch_on;
            
         end if;
      
      end if;
   end process;
  

end architecture;





