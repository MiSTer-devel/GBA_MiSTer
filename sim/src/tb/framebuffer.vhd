library IEEE;
use IEEE.std_logic_1164.all;  
use IEEE.numeric_std.all;  
use STD.textio.all;

entity framebuffer is
   generic
   (
      FRAMESIZE_X : integer;
      FRAMESIZE_Y : integer
   );
   port 
   (
      clk100               : in  std_logic; 
       
      pixel_in_x           : in  integer range 0 to (FRAMESIZE_X - 1);
      pixel_in_y           : in  integer range 0 to (FRAMESIZE_Y - 1);
      pixel_in_data        : in  std_logic_vector(17 downto 0);  
      pixel_in_we          : in  std_logic        
   );
end entity;

architecture arch of framebuffer is
   
   -- data write
   signal pixel_in_addr   : integer range 0 to (FRAMESIZE_X * FRAMESIZE_Y) - 1;
   signal pixel_in_data_1 : std_logic_vector(17 downto 0);
   signal pixel_in_we_1   : std_logic;

   type tPixelArray is array(0 to (FRAMESIZE_X * FRAMESIZE_Y) - 1) of std_logic_vector(17 downto 0);
   signal PixelArray : tPixelArray := (others => (others => '0'));
   
begin 

   -- fill framebuffer
   process (clk100)
   begin
      if rising_edge(clk100) then
         
         pixel_in_addr   <= pixel_in_x + (pixel_in_y * 240);
         pixel_in_data_1 <= pixel_in_data;
         pixel_in_we_1   <= pixel_in_we; 
         
         if (pixel_in_we_1 = '1') then
            PixelArray(pixel_in_addr) <= pixel_in_data_1;
         end if;
      
      end if;
   end process;

-- synthesis translate_off
   
   goutput : if 1 = 1 generate
   begin
   
      process
      
         file outfile: text;
         variable f_status: FILE_OPEN_STATUS;
         variable line_out : line;
         variable color : unsigned(31 downto 0);
         variable linecounter_int : integer;
         
      begin
   
         file_open(f_status, outfile, "gra_fb_out.gra", write_mode);
         file_close(outfile);
         
         file_open(f_status, outfile, "gra_fb_out.gra", append_mode);
         write(line_out, string'("480#320")); 
         writeline(outfile, line_out);
         
         while (true) loop
            wait until ((pixel_in_x mod 240) = (240 - 1)) and pixel_in_we = '1';
            linecounter_int := pixel_in_y;
   
            wait for 100 ns;
   
            for x in 0 to 239 loop
               color := (31 downto 18 => '0') & unsigned(PixelArray(x + linecounter_int * 240));
               color := x"00" & unsigned(color(17 downto 12)) & "00" & unsigned(color(11 downto 6)) & "00" & unsigned(color(5 downto 0)) & "00";
            
               for doublex in 0 to 1 loop
                  for doubley in 0 to 1 loop
                     write(line_out, to_integer(color));
                     write(line_out, string'("#"));
                     write(line_out, x * 2 + doublex);
                     write(line_out, string'("#")); 
                     write(line_out, linecounter_int * 2 + doubley);
                     writeline(outfile, line_out);
                  end loop;
               end loop;
   
            end loop;
            
            file_close(outfile);
            file_open(f_status, outfile, "gra_fb_out.gra", append_mode);
            
         end loop;
         
      end process;
   
   end generate goutput;
   
-- synthesis translate_on

end architecture;





