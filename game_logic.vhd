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
generic (
   time_to_wait : natural := 500000;
   max_snake_length : natural := 20
);
port (
    --<port_name> : <direction> <type>;
    button_l, button_r, button_s : IN std_logic;
    lcd_ready_in : IN  std_logic;
    clk_in : IN std_logic;

    food_x_in : IN std_logic_vector(7 downto 0);
    food_y_in : IN std_logic_vector(7 downto 0);

    x_draw_out : OUT   std_logic_vector(7 downto 0);
    y_draw_out : OUT   std_logic_vector(7 downto 0);
    color_draw_out : OUT std_logic_vector(1 downto 0);
    send_draw_out : OUT std_logic;
    lcd_reset_out : OUT std_logic;
    new_food_out : OUT std_logic
);
end game_logic;

architecture architecture_game_logic of game_logic is
   --Split RESET into RESET_LCD, RESET_GB, RESET_SNAKE, NEW_FOOD
   type state_type is (IDLE, RESET_LCD, RESET_GB, RESET_GB_SEND, RESET_GB_INC, RESET_SNAKE, RESET_SNAKE_SEND, RESET_SNAKE_INC, 
                     MOVE_HEAD, SEND_HEAD, CHECK_HEAD, ERASE_TAIL, 
                     ADD_LENGTH, NEW_FOOD, NEW_FOOD_CHECK, NEW_FOOD_SEND, 
                     DELAY_INPUT, WIN, LOSE);
   signal PS : state_type;
   signal NS : state_type;
   
   signal time_since_start_of_cycle : natural;
   signal button_pressed : std_logic;
   signal new_cycle : std_logic;

   signal reset_x_idx : natural range 0 to 24;
   signal reset_y_idx : natural range 0 to 24;
   signal reset_snake_idx : natural range 0 to max_snake_length;
   
   --Coordinates of everything
   type coord_type is array(0 to 1) of natural range 0 to 24;
   type direction_list_type is array(0 to 3) of coord_type;
   constant UP : coord_type := (0,1);
   constant LEFT : coord_type := (-1,0);
   constant RIGHT : coord_type := (1,0);
   constant DOWN : coord_type := (0,-1);
   constant direction_list : direction_list_type := (UP,LEFT,DOWN,RIGHT);
   signal direction : coord_type;
   signal direction_idx : integer range -1 to 4 := 0;
   signal direction_changed : std_logic := '0';
   signal reset_dir : std_logic;
   
   type snake_array_type is array(0 to max_snake_length-1) of coord_type;
   signal food_coord : coord_type;
   signal snake_array : snake_array_type;
   signal snake_length : natural range 0 to (max_snake_length);
   signal snake_length_temp : natural range 0 to (max_snake_length-2);

   type snake_reset_array_type is array(0 to 2) of coord_type;
   constant snake_reset_array : snake_reset_array_type := ((3,3),(3,2),(3,1));

begin
   snake_length_temp <= max_snake_length-1;
   button_pressed <= button_l xor button_r;

   sync_proc: process(clk_in,button_s)
      variable reset_x_temp_idx : natural range 0 to 24 := 0;
      variable reset_y_temp_idx : natural range 0 to 24 := 0;
   begin
   --If the reset button is hit, start the reset process.
   if (button_s = '1') then
      --TODO: Setup reset process
      --Set init snake length
      snake_length <= 3;
      --Set initial snake coords
      snake_reset_for_loop: for i in 0 to 2 loop
         snake_array(i) <= snake_reset_array(i);
      end loop snake_reset_for_loop;

      --Set initial indices for game board and snake index
      reset_x_idx <= 0;
      reset_y_idx <= 0;
      reset_x_temp_idx := 0;
      reset_y_temp_idx := 0;
      reset_snake_idx <= 0;
      PS <= RESET_LCD;

   elsif rising_edge(clk_in) then
      
      case PS is
         when RESET_GB_INC =>
            reset_x_temp_idx := reset_x_temp_idx + 1;
            if (reset_x_temp_idx > 23) then
               reset_x_temp_idx := 0;
               reset_y_temp_idx := reset_y_temp_idx + 1;
            end if;
            reset_x_idx <= reset_x_temp_idx;
            reset_y_idx <= reset_y_temp_idx;

         when RESET_SNAKE_INC =>
            reset_snake_idx <= reset_snake_idx + 1;

         when MOVE_HEAD =>
            --Shift the array to the right 
            snake_shift_loop: for i in 1 to snake_length_temp loop
               snake_array(i+1) <= snake_array(i);
            end loop snake_shift_loop;
            --Calculate new head
            snake_array(0)(0) <= snake_array(0)(0) + direction(0);
            snake_array(0)(1) <= snake_array(0)(1) + direction(1);

         when ADD_LENGTH =>
            snake_length <= snake_length + 1;
         when ERASE_TAIL =>
            snake_array(snake_length-1) <= (0,0);
         when DELAY_INPUT =>
            time_since_start_of_cycle <= time_since_start_of_cycle + 1;
         when NEW_FOOD_CHECK =>
            food_coord(0) <= conv_integer(unsigned(food_x_in));
            food_coord(1) <= conv_integer(unsigned(food_y_in));

         when others =>
            time_since_start_of_cycle <= 0;
      end case;

      -- Only move to the next state if the lcd is finished drawing/setting up/etc.
      if (lcd_ready_in = '1') then
         PS <= NS;
      end if;

   end if;
   end process sync_proc;

   color_draw_out_proc: process(PS,reset_x_idx,reset_y_idx)
   begin
      case PS is
         when RESET_GB =>
            if reset_x_idx = 0 or 
               reset_x_idx = 23 or 
               reset_y_idx = 0 or
               reset_y_idx = 15 then
               color_draw_out <= "10";
            else
               color_draw_out <= "00";
            end if;
         when RESET_GB_SEND =>
            if reset_x_idx = 0 or 
               reset_x_idx = 23 or 
               reset_y_idx = 0 or
               reset_y_idx = 15 then
               color_draw_out <= "10";
            else
               color_draw_out <= "00";
            end if;
         when MOVE_HEAD =>
            color_draw_out <= "01";
         when SEND_HEAD =>
            color_draw_out <= "01";
         when CHECK_HEAD =>
            color_draw_out <= "11";
         when ERASE_TAIL =>
            color_draw_out <= "11";
         when NEW_FOOD_CHECK =>
            color_draw_out <= "00";
         when NEW_FOOD_SEND =>
            color_draw_out <= "00";
         when NEW_FOOD =>
            color_draw_out <= "00"; 
         when others =>
            color_draw_out <= "00";
      end case;
   end process color_draw_out_proc;

   lcd_reset_out_proc: process(PS)
   begin
      case PS is
         when RESET_LCD =>
            reset_dir <= '1';
            lcd_reset_out <= '1';
         when others =>
            reset_dir <= '0';
            lcd_reset_out <= '0';
      end case;
   end process lcd_reset_out_proc;

   send_draw_out_proc: process(PS)
   begin
      case PS is
         when RESET_GB_SEND => 
            send_draw_out <= '1';
         when RESET_SNAKE_SEND =>
            send_draw_out <= '1';
         when SEND_HEAD =>
            send_draw_out <= '1';
         when ERASE_TAIL =>
            send_draw_out <= '1';
         when NEW_FOOD_SEND =>
            send_draw_out <= '1';
         when others =>
            send_draw_out <= '0';
      end case;
   end process send_draw_out_proc;

   new_food_out_proc: process(PS)
   begin
      case PS is
         when NEW_FOOD =>
            new_food_out <= '1';
         when others =>
            new_food_out <= '0';
      end case;
   end process new_food_out_proc;

   draw_coord_proc: process(PS,reset_x_idx,reset_y_idx,snake_length,food_x_in,food_y_in,reset_snake_idx)
   begin
      case PS is
         when RESET_GB =>
            x_draw_out <= conv_std_logic_vector(reset_x_idx,8);
            y_draw_out <= conv_std_logic_vector(reset_y_idx,8);
         when RESET_GB_SEND =>
            x_draw_out <= conv_std_logic_vector(reset_x_idx,8);
            y_draw_out <= conv_std_logic_vector(reset_y_idx,8);
         when RESET_SNAKE =>
            x_draw_out <= conv_std_logic_vector(snake_array(reset_snake_idx)(0),8);
            y_draw_out <= conv_std_logic_vector(snake_array(reset_snake_idx)(1),8);
         when RESET_SNAKE_SEND =>
            x_draw_out <= conv_std_logic_vector(snake_array(reset_snake_idx)(0),8);
            y_draw_out <= conv_std_logic_vector(snake_array(reset_snake_idx)(1),8);
         when MOVE_HEAD =>
            x_draw_out <= conv_std_logic_vector(snake_array(0)(0),8);
            y_draw_out <= conv_std_logic_vector(snake_array(0)(1),8);
         when SEND_HEAD =>
            x_draw_out <= conv_std_logic_vector(snake_array(0)(0),8);
            y_draw_out <= conv_std_logic_vector(snake_array(0)(1),8);
         when CHECK_HEAD =>
            x_draw_out <= conv_std_logic_vector(snake_array(snake_length-1)(0),8);
            y_draw_out <= conv_std_logic_vector(snake_array(snake_length-1)(1),8);
         when ERASE_TAIL =>
            x_draw_out <= conv_std_logic_vector(snake_array(snake_length-1)(0),8);
            y_draw_out <= conv_std_logic_vector(snake_array(snake_length-1)(1),8);
         when NEW_FOOD_CHECK =>
            x_draw_out <= food_x_in;
            y_draw_out <= food_y_in;
         when NEW_FOOD_SEND =>
            x_draw_out <= food_x_in;
            y_draw_out <= food_y_in;
         when others =>
            x_draw_out <= x"00";
            y_draw_out <= x"00";
      end case;
   end process draw_coord_proc;

   new_cycle_proc: process(PS)
   begin
      case PS is
         when MOVE_HEAD =>
            new_cycle <= '1';
         when others =>
            new_cycle <= '0';
      end case;
   end process new_cycle_proc;

   NS_comb_proc : process(PS,snake_array,food_coord,food_x_in,food_y_in)
      variable snake_hit : std_logic := '0';
      variable food_hit : std_logic := '0';
      
   begin
      case PS is
         when IDLE =>
            NS <= IDLE;
         when RESET_LCD =>
            NS <= RESET_GB;
         when RESET_GB =>
            if (reset_y_idx > 15) then
               NS <= RESET_SNAKE;
            else
               NS <= RESET_GB_SEND;
            end if;
         when RESET_GB_SEND =>
            NS <= RESET_GB_INC;
         when RESET_GB_INC =>
            NS <= RESET_GB;
         when RESET_SNAKE =>
            if (reset_snake_idx > snake_length) then
               NS <= NEW_FOOD;
            else
               NS <= RESET_SNAKE_SEND;
            end if;
         when RESET_SNAKE_SEND =>
            NS <= RESET_SNAKE_INC;
         when RESET_SNAKE_INC =>
            NS <= RESET_SNAKE;
         when MOVE_HEAD =>
            NS <= SEND_HEAD;
         when SEND_HEAD =>
            NS <= CHECK_HEAD;
         when CHECK_HEAD =>
            --Check if there are collisions
            snake_hit := '0';
            snake_collision_check_loop : for i in 1 to snake_length_temp loop
               --TODO: Can we possibly forgo the latter statement?
               if (snake_array(0)(0) = snake_array(i)(0) and 
                  snake_array(0)(1) = snake_array(i)(1)) then
                  snake_hit := snake_hit or '1';
               else
                  snake_hit := snake_hit or '0';
               end if;
            end loop snake_collision_check_loop;

            --If on food, add length to the snake
            if (snake_array(0)(0) = food_coord(0) and snake_array(0)(1) = food_coord(1)) then
               NS <= ADD_LENGTH;
            --If out of bounds or collision, lose
            elsif (snake_array(0)(0) = 0 or 
                  snake_array(0)(0) = 23 or 
                  snake_array(0)(1) = 0 or 
                  snake_array(0)(1) = 15 or snake_hit = '1') then
               NS <= LOSE;
            --Else, nothing happened, erase the tail.
            else
               NS <= ERASE_TAIL;
            end if;

         when ERASE_TAIL =>
            NS <= DELAY_INPUT;
         
         when ADD_LENGTH =>
            --Note: snake_length is incremented in the synchronous process.
            NS <= NEW_FOOD;

         when NEW_FOOD =>
            NS <= NEW_FOOD_CHECK;

         when NEW_FOOD_CHECK =>
            
            --Ensure the new food placement doesnt land on a snake part. Else, ask for a new one.
            food_hit := '0';
            food_collision_check_loop : for i in 0 to snake_length_temp loop
               if (conv_integer(unsigned(food_x_in)) = snake_array(i)(0) and 
                  conv_integer(unsigned(food_y_in)) = snake_array(i)(1)) then
                  food_hit := food_hit or '1';
               else
                  food_hit := food_hit or '0';
               end if;
            end loop food_collision_check_loop;

            if (food_hit = '1') then 
               NS <= NEW_FOOD;
            else
               NS <= NEW_FOOD_SEND;
            end if;

         when NEW_FOOD_SEND =>
            NS <= DELAY_INPUT;

         when DELAY_INPUT =>
            if (time_since_start_of_cycle > time_to_wait) then
               NS <= MOVE_HEAD;
            else
               NS <= DELAY_INPUT;
            end if;
         when WIN =>
            NS <= IDLE;
         when LOSE =>
            NS <= IDLE;
         when others =>
            NS <= IDLE;
      end case;
   end process NS_comb_proc;
   
   direction_change_proc: process(PS,button_pressed,reset_dir,new_cycle)
   begin
      if (reset_dir = '1') then
         direction_idx <= 0;
         direction_changed <= '0';
      elsif (new_cycle = '1') then
         direction_changed <= '0';
      elsif (rising_edge(button_pressed) and 
            PS = DELAY_INPUT and 
            direction_changed = '0') then 
         direction_changed <= '1';
         if (button_r = '1') then
            if (direction_idx < 3) then
               direction_idx <= direction_idx + 1;
            else
               direction_idx <= 0;
            end if;
         elsif (button_l = '1') then
            if (direction_idx > 0) then
               direction_idx <= direction_idx - 1; 
            else
               direction_idx <= 3;
            end if;
         end if;
      end if;
   end process direction_change_proc;
   direction <= direction_list(direction_idx);

end architecture_game_logic;
