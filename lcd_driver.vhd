--------------------------------------------------------------------------------
-- Company: <Name>
--
-- File: lcd_driver.vhd
-- File history:
--      <Revision number>: <Date>: <Comments>
--      <Revision number>: <Date>: <Comments>
--      <Revision number>: <Date>: <Comments>
--
-- Description: 
--
-- <Description here>
--
-- Targeted device: <Family::SmartFusion2> <Die::M2S010> <Package::256 VF>
-- Author: <Name>
--
--------------------------------------------------------------------------------

library IEEE;

use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use IEEE.std_logic_arith.all;


entity lcd_driver is
port (
    --<port_name> : <direction> <type>;
	x_in : IN unsigned(7 downto 0);
    y_in : IN unsigned(7 downto 0);
    color_in : IN unsigned(3 downto 0);
    send_in : IN std_logic;
    clk_in : IN std_logic;
    
    lcd_ready : OUT std_logic := '1';
    lcd_d : OUT std_logic_vector(7 downto 0);
    lcd_dcx : OUT std_logic;
    lcd_cs : OUT std_logic :='0';
    lcd_wr : OUT std_logic;
    lcd_rd : OUT std_logic := '1'
    --<other_ports>;
);
end lcd_driver;
architecture architecture_lcd_driver of lcd_driver is
    type state_type is (RST,LD,WR,IDLE);
    
    signal PS : state_type := IDLE;
    signal NS : state_type;
    
    signal pixel_sent_counter : integer := 0;
    signal data_idx : integer := 0;

    type color_mem is array (0 to 1) of unsigned(7 downto 0);
    constant RED : color_mem := ("11111000","00000000");
    constant GREEN : color_mem := ("00000111","11100000");
    constant BLUE : color_mem := ("00000000","00011111");
    constant WHITE : color_mem := ("00000000","00000000");

    type gen_mem is array (0 to 12) of unsigned(7 downto 0);
    signal data : gen_mem := (
        others => x"00"
    );

begin
    data(0) <= x"2a";
    data(5) <= x"2b";
    data(10) <= x"2c";
    -- Just hold rd, cs low.
    sync_proc: process(clk_in,send_in)
        variable start_col : unsigned(15 downto 0);
        variable end_col : unsigned(15 downto 0);
        variable start_page : unsigned(15 downto 0);
        variable end_page : unsigned(15 downto 0);
        
    begin
        if (rising_edge(send_in)) then
            
            -- Calculate and set bytes for page address and column address
            start_col := x_in * conv_unsigned(20,8);
            end_col := start_col + 20;
            start_page := y_in * conv_unsigned(20,8);
            end_page := start_page + 20;
            
            data(1) <= start_col(15 downto 8);
            data(2) <= start_col(7 downto 0);
            data(3) <= end_col(15 downto 8);
            data(4) <= end_col(7 downto 0);

            data(6) <= start_page(15 downto 8);
            data(7) <= start_page(7 downto 0);
            data(8) <= end_page(15 downto 8);
            data(9) <= end_page(7 downto 0);

            -- Set bytes for colors
            case (conv_integer(color_in)) is
                when 0 =>
                    data(11) <= WHITE(0);
                    data(12) <= WHITE(1);
            
                when 1 =>
                    data(11) <= RED(0);
                    data(12) <= RED(1);

                when 2 =>
                    data(11) <= GREEN(0);
                    data(12) <= GREEN(1);
            
                when 3 =>
                    data(11) <= BLUE(0);
                    data(12) <= BLUE(1);
                
                when others =>
                    data(11) <= BLUE(0);
                    data(12) <= BLUE(1);

            end case;
            PS <= RST;
        elsif (rising_edge(clk_in)) then
            PS <= NS;
        end if;
    end process sync_proc;

    comb_proc: process(PS)
    begin
        case PS is
            when RST =>
                -- Upon reset, turn off lcd_ready
                lcd_ready <= '0';
                NS <= LD;

            when LD =>
                lcd_wr <= '0';    
                lcd_d <= std_logic_vector(data(data_idx));

                case (data_idx) is
                    when 0 => lcd_dcx <= '1';
                    when 5 => lcd_dcx <= '1';
                    when 10 => lcd_dcx <= '1';
                    when others => lcd_dcx <= '0';
                end case;

                -- When we've sent 400 pixels, then it's over, go to idle.
                if (pixel_sent_counter > 400) then
                    NS <= IDLE;
                else
                    NS <= WR;
                end if;

            when WR =>
                lcd_wr <= '1';    
                if (data_idx = 12) then
                    pixel_sent_counter <= pixel_sent_counter + 1;
                    data_idx <= 11;
                else
                    data_idx <= data_idx+1;
                end if;                
                NS <= LD;

            when IDLE =>
                pixel_sent_counter <= 0;
                data_idx <= 0;
                lcd_ready <= '1';
                NS <= IDLE;

        end case;
    end process comb_proc;
    

end architecture_lcd_driver;
