--------------------------------------------------------------------------------
-- Company: <Name>
--
-- File: clk_div.vhd
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
use IEEE.std_logic_arith.all;

entity clk_div is
port (
    --<port_name> : <direction> <type>;
	clk_in : IN  std_logic; -- example
    clk_out : OUT std_logic  -- example
    --<other_ports>;
);
end clk_div;
architecture architecture_clk_div of clk_div is
   -- signal, component etc. declarations
	signal counter : integer := 0; -- example
	signal tmp : std_logic ; -- example

begin
    clk_out <= tmp;
    process(clk_in)
    begin
    if rising_edge(clk_in) then
        counter <= counter+1;
        if (counter > 1024) then
            tmp <= not tmp;
            counter <= 1;
        end if;
    end if;
    end process;
   -- architecture body
end architecture_clk_div;
