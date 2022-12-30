--------------------------------------------------------------------------------
-- Company: <Name>
--
-- File: game_logic_2.vhd
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

entity game_logic_2 is
generic (
   time_to_wait : natural := 510000;
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
end game_logic_2;

architecture architecture_game_logic_2 of game_logic_2 is
   --Split RESET into RESET_LCD, RESET_GB, RESET_SNAKE, NEW_FOOD
   type game_state_type is (IDLE, RESET_LCD, RESET_SNAKE, 
                            CHANGE_DIR ,MOVE_HEAD, CHECK_HEAD, ERASE_TAIL, 
                            ADD_LENGTH, NEW_FOOD, NEW_FOOD_CHECK, 
                            DELAY_INPUT, WIN, LOSE);
   signal PSG : game_state_type;
   signal NSG : game_state_type;

   type display_state_type is (IDLE_DISP, LOAD_DISP, SEND_DISP, WAIT_DISP);
   signal PSD : display_state_type;
   signal NSD : display_state_type;

   signal time_since_start_of_cycle : natural;
   signal new_cycle : std_logic;
   signal change_the_dir : std_logic;
   signal r_pressed : std_logic;
   signal l_pressed : std_logic;

   
   --Coordinates of everything
   type game_board_type is array(0 to 23, 0 to 15) of std_logic_vector(1 downto 0);
   signal game_board : game_board_type;
   constant RED : std_logic_vector(1 downto 0) := "00";
   constant GREEN : std_logic_vector(1 downto 0) := "01";
   constant BLUE : std_logic_vector(1 downto 0) := "10";
   constant BLACK : std_logic_vector(1 downto 0) := "11";
   

   type coord_type is array(0 to 1) of natural range 0 to 23;
   type direction_list_type is array(0 to 3) of coord_type;
   constant UP : coord_type := (0,1);
   constant LEFT : coord_type := (-1,0);
   constant RIGHT : coord_type := (1,0);
   constant DOWN : coord_type := (0,-1);
   constant direction_list : direction_list_type := (UP,LEFT,DOWN,RIGHT);

   signal direction : coord_type;
   signal direction_idx : integer range 0 to 3;
   signal reset_dir : std_logic;

   type snake_array_type is array(0 to max_snake_length-1) of coord_type;
   signal food_coord : coord_type;
   signal snake_array : snake_array_type;
   signal snake_length : natural range 0 to (max_snake_length);
   constant snake_length_temp : natural := max_snake_length-1;

   type snake_reset_array_type is array(0 to 2) of coord_type;
   signal snake_reset_array : snake_reset_array_type := ((3,3),(3,2),(3,1));

begin

    display_sync_proc : process(clk_in,button_s,lcd_ready_in)
        variable x_idx : natural range 0 to 23;
        variable y_idx : natural range 0 to 15;
    begin
        if rising_edge(clk_in) then
            if button_s = '1' then
                x_idx := 0;
                y_idx := 0;
                PSD <= LOAD_DISP;
            elsif PSD = LOAD_DISP and lcd_ready_in = '1' then
                if x_idx = 23 then
                    x_idx := 0;
                    if y_idx = 15 then
                        y_idx := 0;
                    else
                        y_idx := y_idx + 1;
                    end if;
                else
                    x_idx := x_idx + 1;
                end if;
            end if;
            if lcd_ready_in = '1' then
                PSD <= NSD;
            end if;
        end if;
        x_draw_out <= conv_std_logic_vector(x_idx,8);
        y_draw_out <= conv_std_logic_vector(y_idx,8);
        color_draw_out <= game_board(x_idx,y_idx);
    end process display_sync_proc;

    display_comb_proc: process(PSD)
    begin
        case PSD is 
            when LOAD_DISP =>
                send_draw_out <= '0';
                NSD <= SEND_DISP;
            when SEND_DISP =>
                send_draw_out <= '1';
                NSD <= WAIT_DISP;
            when WAIT_DISP =>
                send_draw_out <= '0';
                NSD <= LOAD_DISP;
            when others =>
                send_draw_out <= '0';
                NSD <= IDLE_DISP;
        end case;
    end process display_comb_proc;
    
    game_sync_proc: process(clk_in,button_s)
    begin
        if (button_s = '1') then
            PSG <= RESET_LCD;
        elsif rising_edge(clk_in) then
            
            
            case PSG is
                when RESET_SNAKE =>
                    snake_length <= 3;
                    -- Reset game board
                    --Reset snake array
                    for i in 0 to 2 loop
                        snake_array(i) <= snake_reset_array(i);
                    end loop;
                    --Zero fill the rest of the snake array
                    for i in 3 to max_snake_length-1 loop
                        snake_array(i) <= (0,0);
                    end loop;
                when MOVE_HEAD =>
                    for i in 0 to 23 loop
                        for j in 0 to 15 loop
                            if (i = 0 or i = 23 or j = 0 or j = 15) then
                                game_board(i,j) <= BLUE;
                            else
                                game_board(i,j) <= BLACK;
                            end if;
                        end loop;
                    end loop;
                    time_since_start_of_cycle <= 0;
                    --Shift the array to the right 
                    snake_shift_loop: for i in 1 to max_snake_length-2 loop
                        snake_array(i+1) <= snake_array(i);
                    end loop snake_shift_loop;
                    --Calculate new head
                    snake_array(0)(0) <= snake_array(0)(0) + direction(0);
                    snake_array(0)(1) <= snake_array(0)(1) + direction(1);
                when CHECK_HEAD =>
                    --The snake
                    
                    for i in 0 to max_snake_length-1 loop
                        game_board(snake_array(i)(0),snake_array(i)(1)) <= GREEN;
                    end loop;
                    --Food
                    game_board(food_coord(0),food_coord(1)) <= RED;
                when ADD_LENGTH =>
                    snake_length <= snake_length + 1;
                when ERASE_TAIL =>
                    snake_array(snake_length-1) <= (0,0);
                    
                when DELAY_INPUT =>
                    time_since_start_of_cycle <= time_since_start_of_cycle + 1;
                when LOSE =>    
                    for i in 0 to 23 loop
                        for j in 0 to 15 loop
                                game_board(i,j) <= RED;
                        end loop;
                    end loop;
                when others =>

            end case;
            PSG <= NSG;
        end if;
    end process game_sync_proc;

    game_comb_proc : process(PSG,snake_array,food_coord,food_x_in,food_y_in,time_since_start_of_cycle)
        variable snake_hit : std_logic := '0';
        variable food_hit : std_logic := '0'; 
    begin
        
        -- Constantly ensure the snake array values are reflected in the game board.
        case PSG is
            when IDLE =>
                NSG <= IDLE;
            when RESET_LCD =>
                -- LCD reset signal is sent out in another process
                NSG <= RESET_SNAKE;
            when RESET_SNAKE =>
                NSG <= NEW_FOOD;
            when CHANGE_DIR =>
                NSG <= MOVE_HEAD;
            when MOVE_HEAD =>
                NSG <= CHECK_HEAD;
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
                    NSG <= ADD_LENGTH;
                --If out of bounds or collision, lose
                elsif (snake_array(0)(0) = 0 or 
                        snake_array(0)(0) = 23 or 
                        snake_array(0)(1) = 0 or 
                        snake_array(0)(1) = 15 or snake_hit = '1') then
                    NSG <= LOSE;
                --Else, nothing happened, erase the tail.
                else
                    NSG <= ERASE_TAIL;
                end if;

            when ERASE_TAIL =>
                NSG <= DELAY_INPUT;
            
            when ADD_LENGTH =>
                --Note: snake_length is incremented in the synchronous process.
                NSG <= NEW_FOOD;

            when NEW_FOOD =>
                --Note: A New food req signal is sent in the new_food_send_out process
                NSG <= NEW_FOOD_CHECK;

            when NEW_FOOD_CHECK =>
                --Ensure the new food placement doesnt land on a snake part. Else, ask for a new one.
                food_hit := '0';
                food_collision_check_loop : for i in 0 to max_snake_length-1 loop
                    if (conv_integer(unsigned(food_x_in)) = snake_array(i)(0) and 
                        conv_integer(unsigned(food_y_in)) = snake_array(i)(1)) then
                        food_hit := food_hit or '1';
                    else
                        food_hit := food_hit or '0';
                    end if;
                end loop food_collision_check_loop;

                if (food_hit = '1') then 
                    NSG <= NEW_FOOD;
                else
                    NSG <= DELAY_INPUT;
                end if;

            when DELAY_INPUT =>
                if (time_since_start_of_cycle > time_to_wait) then
                    NSG <= CHANGE_DIR;
                else
                    NSG <= DELAY_INPUT;
                end if;
            when WIN =>
                NSG <= IDLE;
            when LOSE =>
                NSG <= IDLE;
            when others =>
                NSG <= IDLE;
        end case;
    end process game_comb_proc;
    
    food_coord(0) <= conv_integer(unsigned(food_x_in));
    food_coord(1) <= conv_integer(unsigned(food_y_in));

    with PSG select
        new_food_out <= '1' when NEW_FOOD, '0' when others;
    reset_dir <= button_s;
    with PSG select
        lcd_reset_out <= '1' when RESET_LCD, '0' when others;
    with PSG select
        new_cycle <= '1' when MOVE_HEAD, '0' when others;
    with PSG select
        change_the_dir <= '1' when CHANGE_DIR, '0' when others;

    left_button_check_proc: process(button_l,new_cycle,reset_dir)
    begin
        if (new_cycle = '1' or reset_dir = '1') then
            l_pressed <= '0';
        elsif rising_edge(button_l) then
            l_pressed <= '1';
        end if;
    end process left_button_check_proc;

    right_button_check_proc: process(button_r,new_cycle,reset_dir)
    begin
        if (new_cycle = '1' or reset_dir = '1') then
            r_pressed <= '0';
        elsif rising_edge(button_r) then
            r_pressed <= '1';
        end if;
    end process right_button_check_proc;

    direction_change_proc: process(change_the_dir,reset_dir)
    begin
        if (reset_dir = '1') then
            direction_idx <= 0;
        elsif rising_edge(change_the_dir) then
            if (l_pressed = '1') then
                if (direction_idx = 3) then
                    direction_idx <= 0;
                else
                    direction_idx <= direction_idx + 1;
                end if;
            elsif (r_pressed = '1') then
                if (direction_idx = 0) then
                    direction_idx <= 3;
                else
                    direction_idx <= direction_idx - 1;
                end if;
            end if;
        end if;
    end process direction_change_proc;

    direction <= direction_list(direction_idx);

end architecture_game_logic_2;
