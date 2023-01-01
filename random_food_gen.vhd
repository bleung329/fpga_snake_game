--------------------------------------------------------------------------------
-- Company: <Name>
--
-- File: random_food_gen.vhd
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

entity random_food_gen is
port (
    new_in : IN std_logic;
    reset_in : IN std_logic;
    
    x_out : OUT  unsigned(7 downto 0);
    y_out : OUT  unsigned(7 downto 0)
);
end random_food_gen;
architecture architecture_random_food_gen of random_food_gen is
	signal lfsr : unsigned(15 downto 0); -- a 9 bit lfsr
   type state_type is (IDLE,SHIFT,NEW_XOR);
   signal PS : state_type;
   signal NS : state_type;
begin
   rng_sync_proc : process(PS, reset_in, new_in, lfsr)
   begin
      if (reset_in = '1') then
         lfsr <= x"117B";
         PS <= NEW_XOR;
      elsif (rising_edge(new_in)) then
         case PS is
            when NEW_XOR =>
               lfsr(0) <= lfsr(15) xor lfsr(14) xor lfsr(12) xor lfsr(3);
            when SHIFT =>
               for i in 0 to 14 loop
                  lfsr(i+1) <= lfsr(i);
               end loop;
            when others =>
               --Do nothing
         end case;
         PS <= NS;
      end if;
   end process rng_sync_proc;

   rng_comb_proc : process(PS)
   begin
      case PS is
         when SHIFT =>
            NS <= NEW_XOR;
         when NEW_XOR =>
            NS <= SHIFT;
         when others =>
            NS <= IDLE;
      end case;
   end process rng_comb_proc;
   
   x_out(7 downto 5) <= "000";
   x_out(4 downto 0) <= lfsr(10 downto 6);
   y_out(7 downto 4) <= "0000";
   y_out(3 downto 0) <= lfsr(4 downto 1);
   
end architecture_random_food_gen;
