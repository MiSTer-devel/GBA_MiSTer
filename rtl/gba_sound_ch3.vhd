library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

use work.pRegmap_gba.all;
use work.pProc_bus_gba.all;
use work.pReg_gba_sound.all;

entity gba_sound_ch3 is
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

architecture arch of gba_sound_ch3 is

   signal REG_SOUND3CNT_L_Wave_RAM_Dimension   : std_logic_vector(SOUND3CNT_L_Wave_RAM_Dimension   .upper downto SOUND3CNT_L_Wave_RAM_Dimension   .lower) := (others => '0');
   signal REG_SOUND3CNT_L_Wave_RAM_Bank_Number : std_logic_vector(SOUND3CNT_L_Wave_RAM_Bank_Number .upper downto SOUND3CNT_L_Wave_RAM_Bank_Number .lower) := (others => '0');
   signal REG_SOUND3CNT_L_Sound_Channel_3_Off  : std_logic_vector(SOUND3CNT_L_Sound_Channel_3_Off  .upper downto SOUND3CNT_L_Sound_Channel_3_Off  .lower) := (others => '0');
          
   signal REG_SOUND3CNT_H_Sound_length         : std_logic_vector(SOUND3CNT_H_Sound_length         .upper downto SOUND3CNT_H_Sound_length         .lower) := (others => '0');
   signal REG_SOUND3CNT_H_Sound_Volume         : std_logic_vector(SOUND3CNT_H_Sound_Volume         .upper downto SOUND3CNT_H_Sound_Volume         .lower) := (others => '0');
   signal REG_SOUND3CNT_H_Force_Volume         : std_logic_vector(SOUND3CNT_H_Force_Volume         .upper downto SOUND3CNT_H_Force_Volume         .lower) := (others => '0');
          
   signal REG_SOUND3CNT_X_Sample_Rate          : std_logic_vector(SOUND3CNT_X_Sample_Rate          .upper downto SOUND3CNT_X_Sample_Rate          .lower) := (others => '0');
   signal REG_SOUND3CNT_X_Length_Flag          : std_logic_vector(SOUND3CNT_X_Length_Flag          .upper downto SOUND3CNT_X_Length_Flag          .lower) := (others => '0');
   signal REG_SOUND3CNT_X_Initial              : std_logic_vector(SOUND3CNT_X_Initial              .upper downto SOUND3CNT_X_Initial              .lower) := (others => '0');
 
   signal REG_WAVE_RAM                         : std_logic_vector(WAVE_RAM .upper downto WAVE_RAM .lower) := (others => '0');
   signal REG_WAVE_RAM2                        : std_logic_vector(WAVE_RAM2.upper downto WAVE_RAM2.lower) := (others => '0');
   signal REG_WAVE_RAM3                        : std_logic_vector(WAVE_RAM3.upper downto WAVE_RAM3.lower) := (others => '0');
   signal REG_WAVE_RAM4                        : std_logic_vector(WAVE_RAM4.upper downto WAVE_RAM4.lower) := (others => '0');
 
   signal SOUND3CNT_L_Wave_RAM_Bank_Number_written : std_logic;    
   signal SOUND3CNT_L_Sound_Channel_3_Off_written  : std_logic;    
   signal SOUND3CNT_H_Sound_length_written         : std_logic;    
   signal SOUND3CNT_H_Sound_Volume_written         : std_logic;    
   signal SOUND3CNT_X_Sample_Rate_written          : std_logic;    

   signal waveram_written  : std_logic;
   signal waveram_written2 : std_logic;
   signal waveram_written3 : std_logic;
   signal waveram_written4 : std_logic;
 
   type t_waveram is array(0 to 1, 0 to 31) of std_logic_vector(3 downto 0);
   signal waveram : t_waveram := (others => (others => (others => '0')));
   
   signal bank_access         : integer range 0 to 1;
   signal bank_play           : integer range 0 to 1 := 0;
      
   signal choutput_on         : std_logic := '0';
                              
   signal wavetable_ptr       : unsigned(4 downto 0)  := (others => '0');
   signal wave_vol            : integer range -16 to 15;         
                              
   signal length_left         : unsigned(8 downto 0) := (others => '0');   
                           
   signal volume_shift        : integer range 0 to 3    := 0;
   signal wave_vol_shifted    : integer range -16 to 15 := 0;
                           
   signal freq_divider        : unsigned(11 downto 0) := (others => '0');
   signal freq_check          : unsigned(11 downto 0) := (others => '0');
   signal length_on           : std_logic := '0';
   signal ch_on               : std_logic := '0';
   signal freq_cnt            : unsigned(11 downto 0) := (others => '0');
   
   signal soundcycles_freq    : unsigned(7 downto 0)  := (others => '0');
   signal soundcycles_length  : unsigned(16 downto 0) := (others => '0');
   
begin 

   iREG_SOUND3CNT_L_Wave_RAM_Dimension   : entity work.eProcReg_gba generic map ( SOUND3CNT_L_Wave_RAM_Dimension   ) port map  (clk100, gb_bus, REG_SOUND3CNT_L_Wave_RAM_Dimension   , REG_SOUND3CNT_L_Wave_RAM_Dimension   );  
   iREG_SOUND3CNT_L_Wave_RAM_Bank_Number : entity work.eProcReg_gba generic map ( SOUND3CNT_L_Wave_RAM_Bank_Number ) port map  (clk100, gb_bus, REG_SOUND3CNT_L_Wave_RAM_Bank_Number , REG_SOUND3CNT_L_Wave_RAM_Bank_Number , SOUND3CNT_L_Wave_RAM_Bank_Number_written );  
   iREG_SOUND3CNT_L_Sound_Channel_3_Off  : entity work.eProcReg_gba generic map ( SOUND3CNT_L_Sound_Channel_3_Off  ) port map  (clk100, gb_bus, REG_SOUND3CNT_L_Sound_Channel_3_Off  , REG_SOUND3CNT_L_Sound_Channel_3_Off  , SOUND3CNT_L_Sound_Channel_3_Off_written  );  
                                                                                                                                                                                                                            
   iREG_SOUND3CNT_H_Sound_length         : entity work.eProcReg_gba generic map ( SOUND3CNT_H_Sound_length         ) port map  (clk100, gb_bus, "00000000"                           , REG_SOUND3CNT_H_Sound_length         , SOUND3CNT_H_Sound_length_written         );  
   iREG_SOUND3CNT_H_Sound_Volume         : entity work.eProcReg_gba generic map ( SOUND3CNT_H_Sound_Volume         ) port map  (clk100, gb_bus, REG_SOUND3CNT_H_Sound_Volume         , REG_SOUND3CNT_H_Sound_Volume         , SOUND3CNT_H_Sound_Volume_written         );  
   iREG_SOUND3CNT_H_Force_Volume         : entity work.eProcReg_gba generic map ( SOUND3CNT_H_Force_Volume         ) port map  (clk100, gb_bus, REG_SOUND3CNT_H_Force_Volume         , REG_SOUND3CNT_H_Force_Volume         );  
                                                                                                                                                                                                                            
   iREG_SOUND3CNT_X_Sample_Rate          : entity work.eProcReg_gba generic map ( SOUND3CNT_X_Sample_Rate          ) port map  (clk100, gb_bus, "00000000000"                        , REG_SOUND3CNT_X_Sample_Rate          , SOUND3CNT_X_Sample_Rate_written          );  
   iREG_SOUND3CNT_X_Length_Flag          : entity work.eProcReg_gba generic map ( SOUND3CNT_X_Length_Flag          ) port map  (clk100, gb_bus, REG_SOUND3CNT_X_Length_Flag          , REG_SOUND3CNT_X_Length_Flag          );  
   iREG_SOUND3CNT_X_Initial              : entity work.eProcReg_gba generic map ( SOUND3CNT_X_Initial              ) port map  (clk100, gb_bus, "0"                                  , REG_SOUND3CNT_X_Initial              );  
   
   iREG_SOUND3CNT_XHighZero              : entity work.eProcReg_gba generic map ( SOUND3CNT_XHighZero              ) port map  (clk100, gb_bus, x"0000");  
   
   iREG_WAVE_RAM  : entity work.eProcReg_gba generic map ( WAVE_RAM  ) port map  (clk100, gb_bus, REG_WAVE_RAM , REG_WAVE_RAM , waveram_written );  
   iREG_WAVE_RAM2 : entity work.eProcReg_gba generic map ( WAVE_RAM2 ) port map  (clk100, gb_bus, REG_WAVE_RAM2, REG_WAVE_RAM2, waveram_written2);  
   iREG_WAVE_RAM3 : entity work.eProcReg_gba generic map ( WAVE_RAM3 ) port map  (clk100, gb_bus, REG_WAVE_RAM3, REG_WAVE_RAM3, waveram_written3);  
   iREG_WAVE_RAM4 : entity work.eProcReg_gba generic map ( WAVE_RAM4 ) port map  (clk100, gb_bus, REG_WAVE_RAM4, REG_WAVE_RAM4, waveram_written4);  
   
   --correct readback logic would need to implemented it as a shift register
   
   bank_access <= 1 - bank_play;
   
   process (clk100)
   begin
      if rising_edge(clk100) then
      
         -- waveram
         if (waveram_written = '1') then 
            for i in 0 to 3 loop
               waveram(bank_access, i * 2 + 0) <= REG_WAVE_RAM((i * 8) + 7 downto (i * 8) + 4);
               waveram(bank_access, i * 2 + 1) <= REG_WAVE_RAM((i * 8) + 3 downto (i * 8) + 0);
            end loop;
         end if;
         
         if (waveram_written2 = '1') then 
            for i in 0 to 3 loop
               waveram(bank_access, i * 2 + 8) <= REG_WAVE_RAM2((i * 8) + 7 downto (i * 8) + 4);
               waveram(bank_access, i * 2 + 9) <= REG_WAVE_RAM2((i * 8) + 3 downto (i * 8) + 0);
            end loop;
         end if;
         
         if (waveram_written3 = '1') then 
            for i in 0 to 3 loop
               waveram(bank_access, i * 2 + 16) <= REG_WAVE_RAM3((i * 8) + 7 downto (i * 8) + 4);
               waveram(bank_access, i * 2 + 17) <= REG_WAVE_RAM3((i * 8) + 3 downto (i * 8) + 0);
            end loop;
         end if;
         
         if (waveram_written4 = '1') then 
            for i in 0 to 3 loop
               waveram(bank_access, i * 2 + 24) <= REG_WAVE_RAM4((i * 8) + 7 downto (i * 8) + 4);
               waveram(bank_access, i * 2 + 25) <= REG_WAVE_RAM4((i * 8) + 3 downto (i * 8) + 0);
            end loop;
         end if;
         
         if (gb_on = '0') then
         
            sound_out <= (others => '0');
            sound_on  <= '0';
            
            bank_play           <= 0;
            choutput_on         <= '0';
            wavetable_ptr       <= (others => '0');
            wave_vol            <= 0;         
            length_left         <= (others => '0');   
            volume_shift        <= 0;
            wave_vol_shifted    <= 0;
            freq_divider        <= (others => '0');
            freq_check          <= (others => '0');
            length_on           <= '0';         
            ch_on               <= '0';         
            freq_cnt            <= (others => '0');
            soundcycles_freq    <= (others => '0');
            soundcycles_length  <= (others => '0');
            
         elsif (reset = '1') then
         
            sound_out <= (others => '0');
            ch_on     <= ch_on_ss;
         
         else
         
            -- other regs
            if (SOUND3CNT_L_Sound_Channel_3_Off_written = '1') then
               choutput_on <= REG_SOUND3CNT_L_Sound_Channel_3_Off(REG_SOUND3CNT_L_Sound_Channel_3_Off'left);
            end if;
            
            if (SOUND3CNT_H_Sound_length_written = '1') then
               length_left <= to_unsigned(256, 9) - unsigned(REG_SOUND3CNT_H_Sound_length);
            end if;
            
            if (SOUND3CNT_H_Sound_Volume_written = '1') then
               volume_shift  <= to_integer(unsigned(REG_SOUND3CNT_H_Sound_Volume));
            end if;
            
            if (SOUND3CNT_X_Sample_Rate_written = '1') then
               freq_divider <= '0' & unsigned(REG_SOUND3CNT_X_Sample_Rate);
               length_on <= REG_SOUND3CNT_X_Length_Flag(REG_SOUND3CNT_X_Length_Flag'left);
               if (REG_SOUND3CNT_X_Initial = "1") then
                  ch_on         <= not loading_savestate;
                  freq_cnt      <= (others => '0');
                  wavetable_ptr <= (others => '0');
               end if;
            end if;
            
            -- setting bank from reg
            if (SOUND3CNT_L_Wave_RAM_Bank_Number_written = '1') then
               bank_play   <= to_integer(unsigned(REG_SOUND3CNT_L_Wave_RAM_Bank_Number));
            end if;
            
            if (ch_on = '1') then
               -- cpu cycle trigger
               if (new_cycles_valid = '1') then
                  soundcycles_freq     <= soundcycles_freq     + 1;
                  soundcycles_length   <= soundcycles_length   + 1;
               end if;
               
               if (new_cycles_valid = '0' and soundcycles_freq >= 2) then -- freq / wavetable
                  freq_cnt             <= freq_cnt + 1;
                  soundcycles_freq     <= soundcycles_freq - 2;
               end if;
               
               freq_check <= 2048 - freq_divider;
               
               if (freq_cnt >= freq_check) then
                  freq_cnt <= freq_cnt - freq_check;
                  wavetable_ptr <= wavetable_ptr + 1;
                  if (wavetable_ptr = 31 and REG_SOUND3CNT_L_Wave_RAM_Dimension = "1" and SOUND3CNT_L_Wave_RAM_Bank_Number_written = '0') then
                     bank_play <= 1 - bank_play;
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
               
               -- wavetable
               wave_vol <= (to_integer(unsigned(waveram(bank_play, to_integer(wavetable_ptr(4 downto 0))))) - 8) * 2;
               
               if (REG_SOUND3CNT_H_Force_Volume = "1") then
                  wave_vol_shifted <= wave_vol * 3 / 4;
               else
                  case volume_shift is
                     when 0 => wave_vol_shifted <= 0;
                     when 1 => wave_vol_shifted <= wave_vol;
                     when 2 => wave_vol_shifted <= wave_vol / 2;
                     when 3 => wave_vol_shifted <= wave_vol / 4;
                     when others => null;
                  end case;
               end if;
               
               if (choutput_on = '1') then
                  -- sound out
                  sound_out <= to_signed(wave_vol_shifted, 16);
                  sound_on  <= '1';
               else
                  sound_out <= (others => '0');
                  sound_on  <= '0';
               end if;
            else
               sound_out <= (others => '0');
               sound_on  <= '0';
            end if;
            
         end if;
      
      end if;
   end process;
  

end architecture;





