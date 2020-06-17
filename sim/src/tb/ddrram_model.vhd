library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

library tb;
use tb.globals.all;

entity ddrram_model is
   port 
   (
      DDRAM_CLK        : in  std_logic;                    
      DDRAM_BUSY       : out std_logic := '0';                    
      DDRAM_BURSTCNT   : in  std_logic_vector(7 downto 0); 
      DDRAM_ADDR       : in  std_logic_vector(28 downto 0);
      DDRAM_DOUT       : out std_logic_vector(63 downto 0) := (others => '0');
      DDRAM_DOUT_READY : out std_logic := '0';                    
      DDRAM_RD         : in  std_logic;                    
      DDRAM_DIN        : in  std_logic_vector(63 downto 0);
      DDRAM_BE         : in  std_logic_vector(7 downto 0); 
      DDRAM_WE         : in  std_logic                    
   );
end entity;

architecture arch of ddrram_model is

   -- not full size, because of memory required
   type t_data is array(0 to (2**28)-1) of integer;
   type bit_vector_file is file of bit_vector;
   
begin

   process
   
      variable data : t_data := (others => 0);
      variable cmd_address_save : STD_LOGIC_VECTOR(DDRAM_ADDR'left downto 0);
      variable cmd_burst_save   : STD_LOGIC_VECTOR(DDRAM_BURSTCNT'left downto 0);
      variable cmd_din_save     : STD_LOGIC_VECTOR(63 downto 0);
      variable cmd_be_save      : STD_LOGIC_VECTOR(7 downto 0);
      
      file infile             : bit_vector_file;
      variable f_status       : FILE_OPEN_STATUS;
      variable read_byte0     : std_logic_vector(7 downto 0);
      variable read_byte1     : std_logic_vector(7 downto 0);
      variable read_byte2     : std_logic_vector(7 downto 0);
      variable read_byte3     : std_logic_vector(7 downto 0);
      variable next_vector    : bit_vector (3 downto 0);
      variable actual_len     : natural;
      variable targetpos      : integer;
      
      -- copy from std_logic_arith, not used here because numeric std is also included
      function CONV_STD_LOGIC_VECTOR(ARG: INTEGER; SIZE: INTEGER) return STD_LOGIC_VECTOR is
        variable result: STD_LOGIC_VECTOR (SIZE-1 downto 0);
        variable temp: integer;
      begin
 
         temp := ARG;
         for i in 0 to SIZE-1 loop
 
         if (temp mod 2) = 1 then
            result(i) := '1';
         else 
            result(i) := '0';
         end if;
 
         if temp > 0 then
            temp := temp / 2;
         elsif (temp > integer'low) then
            temp := (temp - 1) / 2; -- simulate ASR
         else
            temp := temp / 2; -- simulate ASR
         end if;
        end loop;
 
        return result;  
      end;
   
   begin
      wait until rising_edge(DDRAM_CLK);
      
      if (DDRAM_RD = '1') then 
         cmd_address_save := DDRAM_ADDR;
         cmd_burst_save   := DDRAM_BURSTCNT;
         wait until rising_edge(DDRAM_CLK);
         for i in 0 to (to_integer(unsigned(cmd_burst_save)) - 1) loop
            DDRAM_DOUT       <= std_logic_vector(to_signed(data(to_integer(unsigned(cmd_address_save)) * 2 + (i * 2) + 1), 32)) & 
                                std_logic_vector(to_signed(data(to_integer(unsigned(cmd_address_save)) * 2 + (i * 2) + 0), 32));
            DDRAM_DOUT_READY <= '1';
            wait until rising_edge(DDRAM_CLK);
         end loop;
         DDRAM_DOUT_READY <= '0';
      end if;  
      
      if (DDRAM_WE = '1') then
         DDRAM_BUSY       <= '1';
         cmd_address_save := DDRAM_ADDR;
         cmd_burst_save   := DDRAM_BURSTCNT;
         cmd_din_save     := DDRAM_DIN;
         cmd_be_save      := DDRAM_BE;
         for i in 0 to (to_integer(unsigned(cmd_burst_save)) - 1) loop                                                         
            if (cmd_be_save(7 downto 4) = x"F") then                        
               data(to_integer(unsigned(cmd_address_save)) * 2 + (i * 2) + 1) := to_integer(signed(cmd_din_save(63 downto 32)));
            end if;                                                      
            if (cmd_be_save(3 downto 0) = x"F") then                        
               data(to_integer(unsigned(cmd_address_save)) * 2 + (i * 2) + 0) := to_integer(signed(cmd_din_save(31 downto  0)));
            end if;
            wait until rising_edge(DDRAM_CLK);
         end loop;
         --wait for 200 ns;
         DDRAM_BUSY       <= '0';
      end if;  
      
      COMMAND_FILE_ACK <= '0';
      if COMMAND_FILE_START = '1' then
         
         assert false report "received" severity note;
         assert false report COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN) severity note;
      
         file_open(f_status, infile, COMMAND_FILE_NAME(1 to COMMAND_FILE_NAMELEN), read_mode);
      
         targetpos := COMMAND_FILE_TARGET;
      
         while (not endfile(infile)) loop
            
            read(infile, next_vector, actual_len);  
             
            read_byte0 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(0)), 8);
            read_byte1 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(1)), 8);
            read_byte2 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(2)), 8);
            read_byte3 := CONV_STD_LOGIC_VECTOR(bit'pos(next_vector(3)), 8);
         
            if (COMMAND_FILE_ENDIAN = '1') then
               data(targetpos) := to_integer(signed(read_byte3 & read_byte2 & read_byte1 & read_byte0));
            else
               data(targetpos) := to_integer(signed(read_byte0 & read_byte1 & read_byte2 & read_byte3));
            end if;
            targetpos       := targetpos + 1;
            
         end loop;
      
         file_close(infile);
      
         COMMAND_FILE_ACK <= '1';
      
      end if;
      
   
   
   end process;
   
end architecture;


