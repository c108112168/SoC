LIBRARY IEEE;

USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

entity taiko is

    port(
   	    clk  	    : in std_logic;
        rst 	    : in std_logic;
	    BUTTON_R    : in std_logic;
	    BUTTON_L	: in std_logic;
	    speed       : in std_logic_vector((2-1) downto 0);
	    SW          : in std_logic_vector ((8-1) downto 0);
--**
        led         : out std_logic_vector ((8-1) downto 0);
        IRQ0,IRQ1, IRQ2         : out std_logic;
        test , buzzer       : out std_logic
--**        
--        SEG1 : out std_logic_vector(6 downto 0);
--        SEG2 : out std_logic_vector(6 downto 0)
        );
		  
		  
end taiko;

architecture Behavioral of taiko is
component music
  generic (
		clk_length_2   : integer := 100000000
    );
    port(
        clk100MHz, reset: in std_logic;
        sw_start: in std_logic;
        SW : in integer;
        buzzer: out std_logic
    );
end component;

component B_ram
  generic (
    data_depth : integer    :=  16;
    data_bits  : integer    :=  1
);

port
(
    wclk  : in std_logic;
    wen   : in std_logic;
    waddr : in integer range 0 to data_depth-1;
    wdata : in std_logic_vector(data_bits-1 downto 0);
    rclk  : in std_logic;
    raddr : in integer range 0 to data_depth-1;
    rdata :out std_logic_vector(data_bits-1 downto 0)
);
end component;

type gamestate is(right_to_left, left_to_right, right_win, left_win, wait_BUTTON_L, wait_BUTTON_R,wait_R_start,wait_L_start);
signal ball_state : gamestate;
signal LED_s, LED_s2, LED_a,LED_s1 : std_logic_vector(8 downto 0):="000000000";

signal Data_in : std_logic_vector(15 downto 0);
signal bram_cnt ,bram_r_cnt, time_cnt, bram_r: integer range 0 to 16-1;
signal bram_data_in , out_data: std_logic_vector(3-1 downto 0);

signal light_cnt : std_logic_vector(7 downto 0);

signal count_R,  count_L: std_logic_vector(3 downto 0);
signal clk_new   : std_logic_vector(25 downto 0);
signal clk_pingpong, clk_PWM, buttom_clk :  std_logic;

signal flag  :  std_logic;

signal Q     : std_logic_vector(5 downto 0):="000001";
signal random_num : std_logic_vector(1 downto 0);
signal random_cnt : std_logic_vector(1 downto 0);
signal temp  : std_logic;
signal random_clk, buzzer_reg, buzzer_reg_1 : std_logic;
signal BUTTON_L_F, BUTTON_R_F : std_logic;
--signal SEG1 :  std_logic_vector(6 downto 0);
--signal SEG2 :  std_logic_vector(6 downto 0);

signal IRQ_0 , IRQ_1 , IRQ_2, IRQ_3, BUTTON_R_wait: std_logic;
signal music_cnt : integer;
type type_led_ram is array (integer range 9-1 downto 0) of std_logic_vector(3-1 downto 0);
signal led_ram : type_led_ram;
type sheet is array(0 to 15) of std_logic_vector(3-1 downto 0);
    signal music_data: sheet := (
	    "111", -- 0
	    "110", -- 1
	    "101", -- 2
	    "110", -- 3
	    "111", -- 4
	    "111", -- 5
	    "111", -- 6
	    "000", -- 7
	    "110", -- 8
	    "110", -- 9
	    "110", -- 10
	    "000", -- 11
	    "111", -- 12
	    "111", -- 13
	    "111", -- 14
	    "000" -- 15
    );

begin

LFSR_random:process(rst, clk)
begin
    if rst = '1'then 
--        temp <= '0';
        Q    <= "000001";
    elsif(clk'event and clk = '1')then
--        temp <= Q(5) xor '1';
        Q(5) <= Q(4);
        Q(4) <= Q(3);
        Q(3) <= Q(2) xor Q(5);
        Q(2) <= Q(1);
        Q(1) <= Q(0) xor Q(5);
        Q(0) <=  Q(5) xor '1';
        
    end if;
end process;


random_CLK_cnt:process(rst, clk_pingpong, speed)
begin
    if rst = '1'then 
        random_clk <= '0';
        random_cnt <= "00";
    elsif(clk_pingpong'event and clk_pingpong = '1')then
        if (random_cnt + 1) < speed  then
            random_cnt <= random_cnt + '1';
        else
            random_clk <= not random_clk;
            random_cnt <= "00";
        end if;      
    end if;
end process;

clock:process(clk, rst)   --¤é »
begin
	if(rst = '1') then
		 clk_new <= (others => '0');
	elsif(clk'event and clk = '1') then
		 clk_new <= clk_new + 1;	
	end if;
end process;



wait_button:process(clk, rst, ball_state, BUTTON_R, BUTTON_L)   --¤é »
begin
	if(rst = '1') then
		 BUTTON_L_F <= '0';
		 BUTTON_R_F <= '0';
	elsif(clk'event and clk = '1') then
		case ball_state is
		    when wait_BUTTON_R =>
		        if(BUTTON_R = '1')then
		            BUTTON_R_F <= '1';
		        end if;
		    when wait_BUTTON_L =>
		        if(BUTTON_L = '1')then
                    BUTTON_L_F <= '1';
                end if; 
            when right_to_left =>
                BUTTON_R_F <= '0';
            when left_to_right =>
                BUTTON_L_F <= '0';
            when others =>
                null;
         end case;	
	end if;
end process;

STATE: PROCESS(clk, rst, ball_state, LED_s, flag, BUTTON_R_F, BUTTON_L_F, BUTTON_R, BUTTON_L)
begin  
	if(rst = '1')then
		ball_state <=  left_to_right;
		count_R <= "0000";
		count_L <= "0000";
		
	elsif(clk'event and clk = '1')then	
		case ball_state is
			when left_to_right =>--å¾?³ç™¼
				
--				if LED_s(0) = '1' and BUTTON_R ='1'then
--					test <= '1';
--				else
--				    test <= '0';
--				end if;
				

			when others =>
                if flag = '1'then
                    ball_state <= left_to_right;
                end if;
		end case;
		
	end if;
end process;
--LED_concent: PROCESS(LED_s, BUTTON_R, clk)
--begin 
--    if LED_s(0) = '1' and BUTTON_R ='1'then
--        LED_a(0) <= '0';
--    elsif (LED_s'event)then  
--        LED_a <=  LED_s;
--    end if;    
--end process; 
LED_concent: PROCESS(rst, BUTTON_R, buttom_clk)
begin 
    if rst ='1'then
        BUTTON_R_wait <= '0';
    elsif(buttom_clk'event and buttom_clk = '1')then
        if BUTTON_R ='1'then
            BUTTON_R_wait <= '1';
        else
            BUTTON_R_wait <= '0';
        end if;   
    end if;    
end process; 

music_concent: PROCESS(rst, LED_s1)
begin 
    if rst ='1'then
        music_cnt <= 0;
    elsif LED_s1(1) ='1' and random_clk = '0' then
        music_cnt <= Conv_Integer(led_ram(1));
    else
        music_cnt <= Conv_Integer(led_ram(1));
    end if;   
end process; 

LED_counter: PROCESS(random_clk, rst, ball_state,BUTTON_R_wait)
begin  
	if(rst = '1')then
		LED_s <= "000000000";	
		LED_s1 <= "000000000";	
		flag <= '0';
		bram_r_cnt <= 0;
		time_cnt <= 0;
		bram_r <= 0;
		IRQ_0 <= '0';
		IRQ_1 <= '0';
		IRQ_2 <= '0';
	elsif BUTTON_R_wait = '0'and flag='1' then
        flag <='0';	
	elsif LED_s(0) = '1' and BUTTON_R_wait ='1'and flag ='0'then
        LED_s(0) <= '0';
        IRQ_0 <= '1';
        flag <='1';
    elsif LED_s(1) = '1' and BUTTON_R_wait ='1'and flag ='0'then
        LED_s(1) <= '0';
        IRQ_1 <= '1';
        flag <='1';
    elsif LED_s(2) = '1' and BUTTON_R_wait ='1'and flag ='0'then
        LED_s(2) <= '0';
        IRQ_2 <= '1';
        flag <='1';
    elsif LED_s(3) = '1' and BUTTON_R_wait ='1'and flag ='0'then
        LED_s(3) <= '1';
        IRQ_3 <= '1';
        flag <='0';
    
	elsif(random_clk'event and random_clk = '1')then	
		case ball_state is
			when right_to_left =>--å¾?å·¦ç™¼

                				
			when left_to_right =>--å¾?³ç™¼
			    IRQ_0 <= '0';
		        IRQ_1 <= '0';
		        IRQ_2 <= '0';  
		        IRQ_3 <= '0';
		    if out_data>0 then
                LED_s <=  '1' & LED_s(8 downto 1);

                LED_s1 <=  '1' & LED_s1(8 downto 1);
		    else
                LED_s <=  '0' & LED_s(8 downto 1);

                LED_s1 <=  '0' & LED_s1(8 downto 1);
		    end if;
		    led_ram <= out_data & led_ram(8 downto 1);

--                test <= '0';         
                flag <= '0';
                time_cnt <= time_cnt +1;
                
                if time_cnt <= 3 then
                    time_cnt <= 0;
                    bram_r_cnt <= bram_r_cnt + 1;
                    bram_r <= bram_r_cnt;
                else
                    time_cnt <= time_cnt +1;
                    bram_r <= 0;
                end if;
			when wait_BUTTON_L => --³éè´

				flag <= '1';
				
            when wait_BUTTON_R => --³éè´

                flag <= '1';

			when wait_R_start =>
			
			    LED_s <= "000001111";
				
--			when left_win => --å·¦éè´
--				LED_s <= "11110000";

			when wait_L_start =>
			    LED_s <= "111100000";
			    
			when others =>
				null;
		end case;
		
	end if;
end process;

light_PWM:process(clk_PWM, LED_s, SW,flag)   --¤é »
begin
	if(rst = '1') then
		LED_s2 <= (others => '0');
		light_cnt <= (others => '0');
    elsif flag = '0' then
        LED_s2 <=  LED_s;
	elsif(clk_PWM'event and clk_PWM = '1') then
		if(light_cnt< SW)then
		    LED_s2 <=  LED_s;
		elsif(light_cnt >= SW and light_cnt < "11111111")then
		    LED_s2 <= LED_s;
		end if;
		if(light_cnt = "11111111")then
		    light_cnt <= (others => '0');
		else 
		    light_cnt <= light_cnt + '1';
		end if;	
	end if;
end process;
Bram_in:process(clk, LED_s, SW)   --¤é »
begin
	if(rst = '1') then
--		Data_in <= "0010001010110011";
		bram_cnt <= 0;
		
	elsif(clk'event and clk = '1') then

        bram_cnt <= bram_cnt + 1;
        bram_data_in <= music_data(bram_cnt);
	end if;
end process;
buzzer <= buzzer_reg;
test <= flag;
led <= LED_s(7 downto 0);
clk_pingpong <= clk_new(23);
buttom_clk <= clk_new(21);
clk_PWM <= clk_new(8);
random_num <= Q(1 downto 0);
--random_num <= speed;
IRQ0<= IRQ_0;
IRQ1<=  IRQ_1;
IRQ2<=  IRQ_2;

binarization_ram_0 : B_ram
generic map(
    data_depth  =>  16,
    data_bits   =>  3
)
port map (
    wclk     => clk  ,
    wen      => '1',
    waddr    => bram_cnt,
    wdata    =>  bram_data_in,
    rclk     => random_clk ,
    raddr    => bram_r_cnt,
    rdata    => out_data 
);
music_0 : music
port map (
    clk100MHz     => clk  ,
    reset      => rst,
    sw_start    => '1',
    SW    =>  music_cnt,
    buzzer     => buzzer_reg  
);
end Behavioral;