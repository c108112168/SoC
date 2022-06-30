library ieee;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_1164.all;

entity music is
	generic (
		clk_length_2   : integer := 100000000
    );
    port(
        clk100MHz, reset: in std_logic;
        sw_start: in std_logic;
        SW : in integer;
        buzzer: out std_logic
    );
end entity;

architecture Behavioral of music is
    -- little star (music sheet)
    type sheet is array(0 to 7) of std_logic_vector(25 downto 0);
    signal music: sheet := (
	    "00000000000000000000000000", -- 0
        "00000000101110101011100100", -- 1
		"00000000101001100101100111", -- 2
		"00000000100101000011001111", -- 3
		"00000000100010111110001001", -- 4
        "00000000011111001001111101", -- 5
        "00000000011011110000011010", -- 6
        "00000000011000101111000101"  -- 7
    );
    signal sheet_data: std_logic_vector(25 downto 0);
    signal i,SW_int: integer;

    -- clock divider
    signal clk_div, clk_div_2: std_logic_vector(25 downto 0);

    -- control musical scale (frequency)
    signal scale, scale_2: std_logic_vector(25 downto 0);

    -- control (musical) length (time)
    signal clk_length: std_logic;
--    signal clk_length_2:integer;
    -- assume: each length is 0.25s (24, 22, 21, 20, 19, 18, 16, 14, 13, 12, 11, 6)
    signal time_out: std_logic;
    
    signal buzzer_cnt: std_logic;
    

begin
    buzzer <= buzzer_cnt and time_out;
    -- ?Ÿ³?•·(?›ºå®?0.25s)
    clk_length <= clk_div(24) and clk_div(22) and clk_div(23) and clk_div(20) and clk_div(19) and clk_div(18) and clk_div(16) and clk_div(14) and clk_div(13) and clk_div(12) and clk_div(11) and clk_div(6);
    
    -- ?™¤? »
    divider: process(clk100MHz, reset)
    begin
        if reset = '1' then
            clk_div <= (others => '0');
        elsif clk100MHz 'event and clk100MHz = '1' then
            clk_div <= clk_div + '1';
        end if;
    end process;
    
    divider_2: process(clk100MHz, reset, scale)
    begin
        if reset = '1' then
            buzzer_cnt <= '0';
            clk_div_2 <= (others => '0');
            scale_2 <= (others => '0');
        elsif clk100MHz 'event and clk100MHz = '1' then
            scale_2 <= '0' & scale(25 downto 1);
            if(scale>= clk_div_2)then   
                clk_div_2 <= clk_div_2 + '1'; 
                if(scale_2>= clk_div_2)then    
                    buzzer_cnt <= '1';
                else
                    buzzer_cnt <= '0';
                end if;
                
                
            else
                clk_div_2 <= (others => '0'); 
                buzzer_cnt <= '0';
            end if;
        end if;
    end process;

    -- ?Ÿ³? »
    Start_scale: process(clk_length, reset, sw_start, time_out)
    begin
        if reset = '1' then
            scale <= (others => '0');

        elsif clk_length 'event and clk_length = '1' then
            if sw_start = '1' then
                if time_out = '1' then
                    


                    scale <= sheet_data;


                elsif time_out = '0' then
                    scale <= (others => '0');
                end if;
            end if;
        end if;
    end process;

    -- ?Ÿ³?•·?Ž§?ˆ¶
    Start_length: process(clk_length, reset, sw_start)
    begin
        if reset = '1' then
            time_out <= '0';
        elsif sw_start = '1' then
                time_out <= '1';
        elsif sw_start = '0' then
                time_out <= '0';
        elsif clk_length 'event and clk_length = '1' then

            time_out <= '0';

  
            
        end if;
    end process;

    -- ?Ÿ³æ¨‚ä?ç½®
--    Read_sheet: process(clk_length, reset, sheet_data, i)
--    begin
--        if reset = '1' then
--            sheet_data <= (others => '0');
--            i <= 0;

--        elsif clk_length 'event and clk_length = '1' then
--            if i = 47 then
--                i <= 0;
--                sheet_data <= (others => '0');
--            else
--                sheet_data <= music(i);
--                i <= i + 1;
--            end if;
--        end if; 
--    end process;
    SW_int <= SW;
        Read_sheet: process(SW_int, reset, sheet_data, i)
    begin
        if reset = '1' then
            sheet_data <= (others => '0');
--            i <= 0;

        elsif SW_int<=47 then
          
--            sheet_data <= (others => '0');

                sheet_data <= music(SW_int);
--                i <= i + 1;
--            end if;
        end if; 
    end process;
end Behavioral;