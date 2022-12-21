--------------------------------------------------------------------------------
-- Company: <Name>
--
-- File: game_logic.vhd
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

entity game_logic is
port (
    --<port_name> : <direction> <type>;
    button_l, button_r, button_s : IN std_logic;
    lcd_ready_in : IN  std_logic;
    clk_in : IN std_logic;

    food_x_in : IN unsigned(7 downto 0);
    food_y_in : IN unsigned(7 downto 0);

    x_draw_out : OUT   unsigned(7 downto 0) := x"00";
    y_draw_out : OUT   unsigned(7 downto 0) := x"00";
    color_draw_out : OUT unsigned(1 downto 0) := x"1";
    send_draw_out : OUT std_logic;
    lcd_reset_out : OUT std_logic;
    new_food_out : OUT std_logic
);
end game_logic;

architecture architecture_game_logic of game_logic is
   type state_type is (IDLE, RESET_LOAD, RESET_SEND, MOVE_HEAD, SEND_HEAD, CHECK_HEAD, NEW_FOOD, NEW_FOOD_CHECK, NEW_FOOD_SEND, DELAY_INPUT, WIN, LOSE);
   signal PS : state_type;
   signal NS : state_type;

   signal food_x : unsigned(7 downto 0);
   signal food_y : unsigned(7 downto 0);

   signal tick_counter : integer;
   signal button_pressed : std_logic;
   signal snake_length : unsigned(5 downto 0);

   type direction_type is array(0 to 1) of integer;
   type direction_list_type is array(0 to 3) of direction_type;
   constant UP : direction_type := (0,1);
   constant LEFT : direction_type := (-1,0);
   constant RIGHT : direction_type := (1,0);
   constant DOWN : direction_type := (0,-1);
   constant direction_list : direction_list_type := (UP,LEFT,DOWN,RIGHT);
   signal direction : direction_type;
   signal direction_changed : std_logic;
begin
   button_pressed <= button_l xor button_r;

   sync_proc: process(clk_in,button_s)
   begin
   --If the reset button is hit
   if (button_s = '1') then
      PS <= RESET_LOAD;
   elsif rising_edge(clk_in) then
      -- Only move to the next state if the lcd is ready
      if (lcd_ready_in = '1') then
         PS <= NS;
      else
         --Do nothing
      end if;
   end if;
   end process sync_proc;

   comb_proc : process(PS)
   begin
      case PS is
         when IDLE =>
            send_draw_out <= '0';
            NS <= IDLE;    
         when RESET_LOAD =>
            send_draw_out <= '0';

         when RESET_SEND =>
            send_draw_out <= '1';
            NS <= RESET_LOAD;
         when MOVE_HEAD =>
            direction_changed <= '0';
            send_draw_out <= '0';
            NS <= SEND_HEAD;
         when SEND_HEAD =>
            send_draw_out <= '1';
            NS <= CHECK_HEAD;
         when CHECK_HEAD =>
            send_draw_out <= '0';
         when NEW_FOOD =>
            new_food_out <= '1';
            NS <= NEW_FOOD_CHECK;
         when NEW_FOOD_CHECK =>
            new_food_out <= '0';
            food_x <= food_x_in;
            food_y <= food_y_in;
            x_draw_out <= food_x_in;
            y_draw_out <= food_y_in;
            NS <= NEW_FOOD;
         when NEW_FOOD_SEND =>
            send_draw_out <= '1';
            NS <= DELAY_INPUT;
         when DELAY_INPUT =>
            send_draw_out <= '0';
         when WIN =>
         when LOSE =>
         when others =>
            send_draw_out <= '0';
            NS <= IDLE;
      end case;
   end process comb_proc;

   direction_change_proc: process(PS,button_pressed)
   variable direction_idx : integer := 0;
   begin
      if (rising_edge(button_pressed) and PS = DELAY_INPUT and direction_changed = '0') then 
         if (button_r = '1') then
            direction_idx := direction_idx + 1;
            if (direction_idx > 3) then
               direction_idx := 0;
            end if;
         elsif (button_l = '1') then
            direction_idx := direction_idx - 1;
            if (direction_idx < 0) then
               direction_idx := 3;
            end if;
         end if;
         direction_changed <= '1';
      end if;
      direction <= direction_list(direction_idx);
   end process direction_change_proc;

end architecture_game_logic;
