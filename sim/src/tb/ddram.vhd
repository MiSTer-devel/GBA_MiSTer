library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;     

entity ddram is
   port 
   (
      DDRAM_CLK        :     in  std_logic;     
      DDRAM_BUSY       :     in  std_logic;     
      DDRAM_BURSTCNT   :     out std_logic_vector( 7 downto 0);
      DDRAM_ADDR       :     out std_logic_vector(28 downto 0);
      DDRAM_DOUT       :     in  std_logic_vector(63 downto 0);
      DDRAM_DOUT_READY :     in  std_logic;      
      DDRAM_RD         :     out std_logic;       
      DDRAM_DIN        :     out std_logic_vector(63 downto 0);
      DDRAM_BE         :     out std_logic_vector( 7 downto 0);
      DDRAM_WE         :     out std_logic;       
                                
      ch1_addr         :     in  std_logic_vector(27 downto 1);
      ch1_dout         :     out std_logic_vector(63 downto 0);
      ch1_din          :     in  std_logic_vector(15 downto 0);
      ch1_req          :     in  std_logic;      
      ch1_rnw          :     in  std_logic;      
      ch1_ready        :     out std_logic;       
                                
      ch2_addr         :     in  std_logic_vector(27 downto 1);
      ch2_dout         :     out std_logic_vector(31 downto 0);
      ch2_din          :     in  std_logic_vector(31 downto 0);
      ch2_req          :     in  std_logic;      
      ch2_rnw          :     in  std_logic;      
      ch2_ready        :     out std_logic;       
                                
      -- data is packed 64bit -> 16bit            
      ch3_addr         :     in  std_logic_vector(25 downto 1);
      ch3_dout         :     out std_logic_vector(15 downto 0);
      ch3_din          :     in  std_logic_vector(15 downto 0);
      ch3_req          :     in  std_logic;      
      ch3_rnw          :     in  std_logic;      
      ch3_ready        :     out std_logic;       
                                
      -- save state             
      ch4_addr         :     in  std_logic_vector(27 downto 1);
      ch4_dout         :     out std_logic_vector(63 downto 0);
      ch4_din          :     in  std_logic_vector(63 downto 0);
      ch4_req          :     in  std_logic;          
      ch4_rnw          :     in  std_logic;      
      ch4_be           :     in  std_logic_vector( 7 downto 0);
      ch4_ready        :     out std_logic;        
                                
      -- framebuffer            
      ch5_addr         :     in  std_logic_vector(27 downto 1);
      ch5_din          :     in  std_logic_vector(63 downto 0);
      ch5_req          :     in  std_logic;        
      ch5_ready        :     out std_logic      
   );
end entity;

architecture arch of ddram is

   type tram_q is array(1 to 4) of std_logic_vector(63 downto 0);
   signal ram_q           : tram_q;
   
   signal ram_burst       : std_logic_vector( 7 downto 0);
   signal ram_data        : std_logic_vector(63 downto 0);
   signal ram_address     : std_logic_vector(27 downto 1);
   signal ram_read        : std_logic := '0';            
   signal ram_write       : std_logic := '0';           
   signal ram_be          : std_logic_vector( 7 downto 0);
                     
   signal ready           : std_logic_vector( 5 downto 1); 
                              
   signal next_q1         : std_logic_vector(63 downto 0);
   signal next_q2         : std_logic_vector(63 downto 0);
   signal cache_addr1     : std_logic_vector(27 downto 1);
   signal cache_addr2     : std_logic_vector(27 downto 1);
   signal state           : integer range 0 to 2 := 0;
   signal cached          : std_logic_vector( 2 downto 1);
   signal ch              : integer range 0 to 5 := 0;
   signal ch_rq           : std_logic_vector( 5 downto 1);
  
begin

   DDRAM_BURSTCNT <= ram_burst;
   DDRAM_BE       <= x"FF" when (ram_read = '1') else ram_be;
   DDRAM_ADDR     <= "0011" & ram_address(27 downto 3); -- RAM at 0x30000000
   DDRAM_RD       <= ram_read;
   DDRAM_DIN      <= ram_data;
   DDRAM_WE       <= ram_write;
   
   ch1_dout  <= ram_q(1)(31 downto 0) & ram_q(1)(63 downto 32) when (ch1_addr(2) = '1') else ram_q(1);
   ch2_dout  <= ram_q(2)(63 downto 32) when (ch2_addr(2) = '1') else ram_q(2)(31 downto 0);
   ch3_dout  <= ram_q(3)(39 downto 32) & ram_q(3)(7 downto 0);
   ch4_dout  <= ram_q(4);
   ch1_ready <= ready(1);
   ch2_ready <= ready(2);
   ch3_ready <= ready(3);
   ch4_ready <= ready(4);
   ch5_ready <= ready(5);

   process (DDRAM_CLK) 
   begin
      if rising_edge(DDRAM_CLK) then

         ch_rq <= ch_rq or (ch5_req & ch4_req & ch3_req & ch2_req & ch1_req);
         ready <= (others => '0');
      
         if (DDRAM_BUSY = '0') then
            ram_write <= '0';
            ram_read  <= '0';
      
            case (state) is
               when 0 => 
                  if(ch_rq(1) = '1' or ch1_req = '1') then
                     ch_rq(1)         <= '0';
                     ch               <= 1;
                     ram_data         <= ch1_din & ch1_din & ch1_din & ch1_din;
                     case (ch1_addr(2 downto 1)) is
                        when "00" => ram_be <= "00000011";
                        when "01" => ram_be <= "00001100";
                        when "10" => ram_be <= "00110000";
                        when "11" => ram_be <= "11000000";
                        when others => null;
                     end case;
                     if(ch1_rnw = '0') then
                        ram_address   <= ch1_addr;
                        ram_write     <= '1';
                        ram_burst     <= x"01";
                        cached(1)     <= '0';
                        ready(1)      <= '1';
                     elsif(cached(1) = '1' and (cache_addr1(27 downto 3) = ch1_addr(27 downto 3))) then
                        ready(1)      <= '1';
                     elsif(cached(1) = '1' and ((unsigned(cache_addr1(27 downto 3))+1) = unsigned(ch1_addr(27 downto 3)))) then
                        ram_q(1)      <= next_q1;
                        cache_addr1   <= ch1_addr;
                        ram_address   <= std_logic_vector(unsigned(ch1_addr) + 4);
                        ram_read      <= '1';
                        ram_burst     <= x"01";
                        cached(1)     <= '1';
                        ready(1)      <= '1';
                        state         <= 2;
                     else
                        ram_address   <= ch1_addr;
                        cache_addr1   <= ch1_addr;
                        ram_read      <= '1';
                        ram_burst     <= x"02";
                        cached(1)     <= '1';
                        state         <= 1;
                     end if;
                  elsif(ch_rq(2) = '1' or ch2_req = '1') then
                     ch_rq(2)         <= '0';
                     ch               <= 2;
                     ram_data         <= ch2_din & ch2_din;
                     if (ch2_addr(2) = '1') then
                        ram_be <= "11110000";
                     else
                        ram_be <= "00001111";
                     end if;
                     if(ch2_rnw = '0') then
                        ram_address   <= ch2_addr;
                        ram_write     <= '1';
                        ram_burst     <= x"01";
                        cached(2)     <= '0';
                        ready(2)      <= '1';
                     elsif(cached(2) = '1' and (cache_addr2(27 downto 3) = ch2_addr(27 downto 3))) then
                        ready(2)      <= '1';
                     elsif(cached(2) = '1' and ((unsigned(cache_addr2(27 downto 3))+1) = unsigned(ch2_addr(27 downto 3)))) then
                        ram_q(2)      <= next_q2;
                        cache_addr2   <= ch2_addr;
                        ram_address   <= std_logic_vector(unsigned(ch2_addr) + 4);
                        ram_read      <= '1';
                        ram_burst     <= x"01";
                        cached(2)     <= '1';
                        ready(2)      <= '1';
                        state         <= 2;
                     else
                        ram_address   <= ch2_addr;
                        cache_addr2   <= ch2_addr;
                        ram_read      <= '1';
                        ram_burst     <= x"02";
                        cached(2)     <= '1';
                        state         <= 1;
                     end if;
                  elsif(ch_rq(3) = '1' or ch3_req = '1') then
                     ch_rq(3)         <= '0';
                     ch               <= 3;
                     ram_address      <= ch3_addr & "00";
                     ram_data         <= x"000000" & ch3_din(15 downto 8) & x"000000" & ch3_din(7 downto 0);
                     ram_be           <= x"FF";
                     ram_burst        <= x"01";
                     if(ch3_rnw = '0') then
                        ram_write     <= '1';
                        cached(2)     <= '0';
                        ready(3)      <= '1';
                     else
                        ram_read      <= '1';
                        state         <= 1;
                     end if;
                  elsif(ch_rq(4) = '1' or ch4_req = '1') then
                     ch_rq(4)         <= '0';
                     ch               <= 4;
                     ram_data         <= ch4_din;
                     ram_be           <= ch4_be;
                     ram_address      <= ch4_addr;
                     ram_burst        <= x"01";
                     if(ch4_rnw = '0') then
                        ram_write     <= '1';
                        ready(4)      <= '1';
                     else 
                        ram_read      <= '1';
                        state         <= 1;
                     end if;
                  elsif(ch_rq(5) = '1' or ch5_req = '1') then
                     ch_rq(5)         <= '0';
                     ch               <= 5;
                     ram_data         <= ch5_din;
                     ram_be           <= x"FF";
                     ram_address      <= ch5_addr;
                     ram_write        <= '1';
                     ram_burst        <= x"01";
                     ready(5)         <= '1';
                  end if;
      
               when 1 => 
                  if(DDRAM_DOUT_READY = '1') then
                     ram_q(ch)        <= DDRAM_DOUT;
                     ready(ch)        <= '1';
                     if (ram_burst(1) = '1') then
                        state <= 2;
                     else
                        state <= 0;
                     end if;
                  end if;
      
               when 2 =>  
                  if(DDRAM_DOUT_READY = '1') then
                     if (ch = 1) then
                        next_q1 <= DDRAM_DOUT;
                     elsif (ch = 2) then
                        next_q2 <= DDRAM_DOUT;
                     end if;
                     state            <= 0;
                  end if;
                  
            end case;
         end if;
      end if;
   end process;

end architecture;
