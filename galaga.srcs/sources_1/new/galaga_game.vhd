LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY galaga_game IS
    PORT (
        v_sync : IN STD_LOGIC;
        pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        player_x : IN STD_LOGIC_VECTOR(10 DOWNTO 0); -- player ship x position
        shoot : IN STD_LOGIC; -- fire button
        reset : IN STD_LOGIC; -- reset button
        red : OUT STD_LOGIC;
        green : OUT STD_LOGIC;
        blue : OUT STD_LOGIC;
        score : OUT STD_LOGIC_VECTOR(15 DOWNTO 0); -- score counter
        lives : OUT STD_LOGIC_VECTOR(2 DOWNTO 0); -- lives counter
        game_over : OUT STD_LOGIC -- game over indicator
    );
END galaga_game;

ARCHITECTURE Behavioral OF galaga_game IS
    -- Constants
    CONSTANT player_size : INTEGER := 16; -- player ship size (Increased)
    CONSTANT enemy_size : INTEGER := 16; -- enemy ship size (Increased)
    CONSTANT bullet_size : INTEGER := 4; -- bullet size (Increased)
    CONSTANT SPRITE_SCALE : INTEGER := 2; -- Sprite scaling factor
    CONSTANT player_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(550, 11); -- player y position (bottom)
    -- CONSTANT enemy_start_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(50, 11); -- REPLACED BY SIGNAL
    CONSTANT bullet_speed : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(16, 11); -- bullet speed (Increased from 8)
    CONSTANT enemy_speed : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(4, 11); -- enemy movement speed (Increased from 2)
    CONSTANT enemy_bullet_speed : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(6, 11); -- enemy bullet speed (Increased from 4)
    
    -- Enemy formation: 6 rows x 10 columns (More dense)
    CONSTANT NUM_ENEMY_ROWS : INTEGER := 6;
    CONSTANT NUM_ENEMY_COLS : INTEGER := 10;
    CONSTANT ENEMY_SPACING_X : INTEGER := 50;
    CONSTANT ENEMY_SPACING_Y : INTEGER := 40;
    
    -- Signals
    SIGNAL player_on : STD_LOGIC;
    SIGNAL enemy_on : STD_LOGIC;
    SIGNAL bullet_on : STD_LOGIC;
    SIGNAL enemy_bullet_on : STD_LOGIC;
    SIGNAL game_active : STD_LOGIC := '1';
    
    -- Game State
    TYPE game_state_type IS (START, READY_SCREEN, PLAY, GAMEOVER, RESULTS_SCREEN, NEXT_WAVE, FLY_IN);
    SIGNAL current_state : game_state_type := START;
    SIGNAL ready_timer_counter : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
    SIGNAL text_on : STD_LOGIC;
    SIGNAL wave_number : INTEGER := 1; -- Infinite levels
    SIGNAL shoot_delay : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(60, 11);
    
    -- Stats
    SIGNAL lives_count : INTEGER RANGE 0 TO 3 := 3;
    SIGNAL shots_fired_count : INTEGER := 0;
    SIGNAL hits_count : INTEGER := 0;
    SIGNAL hit_miss_ratio : INTEGER := 0;
    
    -- Player ship position
    SIGNAL player_x_pos : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(400, 11);
    
    -- Bullet position and state
    SIGNAL bullet_x : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(400, 11);
    SIGNAL bullet_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(600, 11);
    SIGNAL bullet_active : STD_LOGIC := '0';
    SIGNAL shoot_prev : STD_LOGIC := '0';
    
    -- Enemy Bullet
    SIGNAL enemy_bullet_x : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
    SIGNAL enemy_bullet_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
    SIGNAL enemy_bullet_active : STD_LOGIC := '0';
    SIGNAL enemy_shoot_timer : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
    SIGNAL random_col : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";
    
    -- Bee Diver Signals
    SIGNAL diver_active : STD_LOGIC := '0';
    SIGNAL diver_x : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
    SIGNAL diver_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
    SIGNAL diver_row : INTEGER RANGE 0 TO NUM_ENEMY_ROWS-1;
    SIGNAL diver_col : INTEGER RANGE 0 TO NUM_ENEMY_COLS-1;
    SIGNAL diver_timer : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
    SIGNAL diver_shot_fired : STD_LOGIC := '0';
    
    -- Triple Shot Signals
    SIGNAL eb_L_active, eb_C_active, eb_R_active : STD_LOGIC := '0';
    SIGNAL eb_L_x, eb_L_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
    SIGNAL eb_C_x, eb_C_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
    SIGNAL eb_R_x, eb_R_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
    
    -- Special Attack Squad (Fly-in from Left)
    SIGNAL squad_active : STD_LOGIC := '0';
    SIGNAL squad_x : STD_LOGIC_VECTOR(10 DOWNTO 0);
    SIGNAL squad_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
    SIGNAL squad_timer : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL squad_phase : INTEGER RANGE 0 TO 3 := 0;
    
    -- Enemy positions and states
    TYPE enemy_array IS ARRAY(0 TO NUM_ENEMY_ROWS-1, 0 TO NUM_ENEMY_COLS-1) OF STD_LOGIC;
    SIGNAL enemy_alive : enemy_array := (OTHERS => (OTHERS => '1'));
    SIGNAL enemy_is_diving : enemy_array := (OTHERS => (OTHERS => '0'));
    SIGNAL enemy_x_pos : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(100, 11);
    SIGNAL enemy_y_offset : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0'); -- vertical offset for moving down
    SIGNAL enemy_direction : STD_LOGIC := '0'; -- 0 = right, 1 = left
    SIGNAL enemy_move_counter : STD_LOGIC_VECTOR(20 DOWNTO 0) := (OTHERS => '0');
    
    -- New Signals for Fly-In and Breathing
    SIGNAL current_start_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(50, 11);
    SIGNAL formation_move_dir : STD_LOGIC := '0'; -- 0 = down, 1 = up (for breathing)
    SIGNAL move_threshold : STD_LOGIC_VECTOR(20 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(5, 21);

    
    -- Score
    SIGNAL score_i : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    
    -- Collision detection signals
    SIGNAL bullet_enemy_collision : STD_LOGIC := '0';
    SIGNAL enemy_player_collision : STD_LOGIC := '0';

    -- Font 5x7 Definitions
    TYPE font_char IS ARRAY(0 TO 6) OF STD_LOGIC_VECTOR(4 DOWNTO 0);
    CONSTANT CHAR_R : font_char := ("11110", "10001", "10001", "11110", "10100", "10010", "10001");
    CONSTANT CHAR_E : font_char := ("11111", "10000", "10000", "11110", "10000", "10000", "11111");
    CONSTANT CHAR_A : font_char := ("01110", "10001", "10001", "11111", "10001", "10001", "10001");
    CONSTANT CHAR_D : font_char := ("11110", "10001", "10001", "10001", "10001", "10001", "11110");
    CONSTANT CHAR_Y : font_char := ("10001", "10001", "01010", "00100", "00100", "00100", "00100");
    CONSTANT CHAR_EX: font_char := ("00100", "00100", "00100", "00100", "00000", "00100", "00000"); -- !
    CONSTANT CHAR_G : font_char := ("01110", "10000", "10000", "10111", "10001", "10001", "01110");
    CONSTANT CHAR_M : font_char := ("10001", "11011", "10101", "10001", "10001", "10001", "10001");
    CONSTANT CHAR_O : font_char := ("01110", "10001", "10001", "10001", "10001", "10001", "01110");
    CONSTANT CHAR_V : font_char := ("10001", "10001", "10001", "10001", "10001", "01010", "00100");
    CONSTANT CHAR_SP: font_char := ("00000", "00000", "00000", "00000", "00000", "00000", "00000");
    CONSTANT CHAR_L : font_char := ("10000", "10000", "10000", "10000", "10000", "10000", "11111");
    CONSTANT CHAR_0 : font_char := ("01110", "10001", "10001", "10001", "10001", "10001", "01110");
    CONSTANT CHAR_1 : font_char := ("00100", "01100", "00100", "00100", "00100", "00100", "01110");
    CONSTANT CHAR_2 : font_char := ("01110", "10001", "00001", "00010", "00100", "01000", "11111");
    CONSTANT CHAR_3 : font_char := ("01110", "10001", "00001", "00110", "00001", "10001", "01110");
    CONSTANT CHAR_4 : font_char := ("00010", "00110", "01010", "10010", "11111", "00010", "00010");
    CONSTANT CHAR_5 : font_char := ("11111", "10000", "11110", "00001", "00001", "10001", "01110");
    CONSTANT CHAR_6 : font_char := ("01110", "10000", "10000", "11110", "10001", "10001", "01110");
    CONSTANT CHAR_7 : font_char := ("11111", "00001", "00010", "00100", "00100", "00100", "00100");
    CONSTANT CHAR_8 : font_char := ("01110", "10001", "10001", "01110", "10001", "10001", "01110");
    CONSTANT CHAR_9 : font_char := ("01110", "10001", "10001", "01111", "00001", "00001", "01110");
    CONSTANT CHAR_S : font_char := ("01111", "10000", "10000", "01110", "00001", "00001", "11110");
    CONSTANT CHAR_H : font_char := ("10001", "10001", "10001", "11111", "10001", "10001", "10001");
    CONSTANT CHAR_T : font_char := ("11111", "00100", "00100", "00100", "00100", "00100", "00100");
    CONSTANT CHAR_F : font_char := ("11111", "10000", "10000", "11110", "10000", "10000", "10000");
    CONSTANT CHAR_I : font_char := ("01110", "00100", "00100", "00100", "00100", "00100", "01110");
    CONSTANT CHAR_N : font_char := ("10001", "11001", "10101", "10011", "10001", "10001", "10001");
    CONSTANT CHAR_U : font_char := ("10001", "10001", "10001", "10001", "10001", "10001", "01110");
    CONSTANT CHAR_B : font_char := ("11110", "10001", "10001", "11110", "10001", "10001", "11110");
    CONSTANT CHAR_COLON: font_char := ("00000", "00100", "00000", "00000", "00000", "00100", "00000"); -- :
    CONSTANT CHAR_PCT: font_char := ("11001", "11010", "00100", "01000", "10011", "00011", "00000"); -- %
    CONSTANT CHAR_P : font_char := ("11110", "10001", "10001", "11110", "10000", "10000", "10000");
    
    -- Starfield Signals
    SIGNAL star_on : STD_LOGIC := '0';
    SIGNAL star_color : STD_LOGIC_VECTOR(2 DOWNTO 0) := "111";
    SIGNAL star_scroll_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0');
    SIGNAL star_speed_counter : STD_LOGIC_VECTOR(1 DOWNTO 0) := "00";

    -- Sprite Definitions
    TYPE sprite_row_t IS ARRAY(0 TO 15) OF STD_LOGIC;
    TYPE sprite_t IS ARRAY(0 TO 15) OF sprite_row_t;
    
    SIGNAL enemy_pixel_color : STD_LOGIC_VECTOR(2 DOWNTO 0) := "100";

    CONSTANT walker_sprite : sprite_t := (
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 0
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 1
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 2
        ( '0','0','0','0','1','1','0','0','0','0','0','0','0','0','0','0' ), -- 3
        ( '0','0','1','1','1','1','1','1','0','0','0','0','0','0','0','0' ), -- 4
        ( '0','0','0','1','1','1','1','0','0','0','0','0','0','0','0','0' ), -- 5
        ( '0','1','1','1','1','1','1','1','0','0','0','0','0','0','0','0' ), -- 6
        ( '1','1','1','1','1','1','1','1','1','1','0','0','0','0','0','0' ), -- 7
        ( '0','1','1','1','1','1','1','1','1','0','0','0','0','0','0','0' ), -- 8
        ( '1','1','1','0','1','1','0','1','1','1','0','0','0','0','0','0' ), -- 9
        ( '1','1','1','0','0','0','0','1','1','1','0','0','0','0','0','0' ), -- 10
        ( '1','1','1','0','0','0','0','1','1','1','0','0','0','0','0','0' ), -- 11
        ( '1','1','1','0','0','0','0','1','1','1','0','0','0','0','0','0' ), -- 12
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 13
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 14
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' )  -- 15
    );

    CONSTANT bee_sprite : sprite_t := (
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 0
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 1
        ( '0','1','1','0','0','0','0','1','1','0','0','0','0','1','1','0' ), -- 2
        ( '0','1','1','1','0','1','1','1','1','1','1','0','1','1','1','0' ), -- 3
        ( '0','0','0','1','1','1','1','1','1','1','1','1','1','1','0','0' ), -- 4
        ( '0','0','0','1','1','1','1','1','1','1','1','1','1','0','0','0' ), -- 5
        ( '0','0','0','0','1','1','1','1','1','1','1','1','0','0','0','0' ), -- 6
        ( '0','0','0','1','1','1','1','1','1','1','1','1','1','0','0','0' ), -- 7
        ( '0','0','1','1','1','1','1','1','1','1','1','1','1','1','0','0' ), -- 8
        ( '0','1','1','1','1','1','1','1','1','1','1','1','1','1','1','0' ), -- 9
        ( '1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1' ), -- 10
        ( '1','1','1','1','1','0','1','1','1','1','0','1','1','1','1','1' ), -- 11
        ( '1','1','1','1','1','0','1','1','1','1','0','0','1','1','1','1' ), -- 12
        ( '1','1','1','1','0','0','0','1','1','0','0','0','1','1','1','1' ), -- 13
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 14
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' )  -- 15
    );

    CONSTANT crab_sprite : sprite_t := (
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 0
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 1
        ( '0','0','1','1','0','0','1','1','1','1','0','0','1','1','0','0' ), -- 2
        ( '1','1','1','1','1','0','1','1','1','1','0','0','1','1','1','1' ), -- 3
        ( '1','1','1','1','1','1','1','1','1','1','1','0','1','1','1','1' ), -- 4
        ( '1','1','1','1','1','1','1','1','1','1','1','0','1','1','1','1' ), -- 5
        ( '1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1' ), -- 6
        ( '0','1','1','1','1','1','1','1','1','1','1','1','1','1','1','0' ), -- 7
        ( '0','0','1','1','1','1','1','1','1','1','1','1','1','1','0','0' ), -- 8
        ( '0','1','1','1','1','1','1','1','1','1','1','1','1','1','1','0' ), -- 9
        ( '1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1' ), -- 10
        ( '1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1' ), -- 11
        ( '0','1','1','1','1','1','1','1','1','1','1','1','1','1','1','0' ), -- 12
        ( '0','0','0','1','1','1','0','0','0','0','1','1','1','0','0','0' ), -- 13
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' ), -- 14
        ( '0','0','0','0','0','0','0','0','0','0','0','0','0','0','0','0' )  -- 15
    );
    
BEGIN
    -- Game Active Logic
    game_active <= '1' WHEN (current_state = PLAY OR current_state = FLY_IN OR current_state = READY_SCREEN OR current_state = NEXT_WAVE) ELSE '0';

    -- Color Logic: Black Background
    -- Priority: Text > Enemy/Bullet > Player > Stars
    red <= text_on OR (game_active AND ((enemy_on AND enemy_pixel_color(2)) OR enemy_bullet_on)) OR (star_on AND star_color(2) AND NOT (text_on OR enemy_on OR enemy_bullet_on OR player_on OR bullet_on));
    green <= (game_active AND (player_on OR bullet_on OR (enemy_on AND enemy_pixel_color(1)))) OR (star_on AND star_color(1) AND NOT (text_on OR enemy_on OR enemy_bullet_on OR player_on OR bullet_on));
    blue <= (star_on AND star_color(0) AND NOT (text_on OR enemy_on OR enemy_bullet_on OR player_on OR bullet_on)) OR (game_active AND (enemy_on AND enemy_pixel_color(0)));
    
    score <= score_i;
    lives <= CONV_STD_LOGIC_VECTOR(lives_count, 3);
    game_over <= '1' WHEN current_state = GAMEOVER ELSE '0';
    
    -- Process to draw starfield
    star_draw : PROCESS (pixel_row, pixel_col, star_scroll_y)
        VARIABLE row_scrolled : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE seed : STD_LOGIC_VECTOR(21 DOWNTO 0);
    BEGIN
        row_scrolled := pixel_row + star_scroll_y;
        
        -- Improved Hash for Randomness
        -- seed = ((x * 129) + (y * 743)) XOR ((x * y) + 93)
        seed := ((pixel_col * CONV_STD_LOGIC_VECTOR(129, 11)) + (row_scrolled * CONV_STD_LOGIC_VECTOR(743, 11))) XOR ((pixel_col * row_scrolled) + 93);
        
        -- Check if star exists (Density check)
        -- Checking 9 bits for 0 -> 1/512 chance
        IF seed(8 DOWNTO 0) = "000000000" THEN 
            star_on <= '1';
            star_color <= seed(11 DOWNTO 9); -- Use middle bits for color
            IF seed(11 DOWNTO 9) = "000" THEN star_color <= "111"; END IF;
        ELSE
            star_on <= '0';
            star_color <= "000";
        END IF;
    END PROCESS;

    -- Player ship: 16x16 Galaga-style pixel sprite
    player_draw : PROCESS (player_x_pos, pixel_row, pixel_col) IS
        CONSTANT SPR_W : INTEGER := 16;
        CONSTANT SPR_H : INTEGER := 16;

        TYPE sprite_row_t IS ARRAY(0 TO SPR_W-1) OF STD_LOGIC;
        TYPE sprite_t IS ARRAY(0 TO SPR_H-1) OF sprite_row_t;

        -- Approximate Galaga ship mask (1 = ship pixel)
        CONSTANT galaga_sprite : sprite_t := (
            -- 0    1    2    3    4    5    6    7    8    9   10   11   12   13   14   15
            ( '0','0','0','0','0','0','0','1','1','0','0','0','0','0','0','0' ), -- 0  nose tip
            ( '0','0','0','0','0','0','0','1','1','0','0','0','0','0','0','0' ), -- 1
            ( '0','0','0','0','0','0','0','1','1','0','0','0','0','0','0','0' ), -- 2
            ( '0','0','0','0','0','0','1','1','1','1','0','0','0','0','0','0' ), -- 3
            ( '0','0','0','0','0','0','1','1','1','1','0','0','0','0','0','0' ), -- 4
            ( '0','0','0','0','0','0','1','1','1','1','0','0','0','0','0','0' ), -- 5
            ( '0','0','0','1','0','0','1','1','1','1','0','0','1','0','0','0' ), -- 6  inner wings
            ( '0','0','0','1','0','1','1','1','1','1','1','0','1','0','0','0' ), -- 7
            ( '1','0','0','1','1','1','1','1','1','1','1','1','1','0','0','1' ), -- 8  outer wings
            ( '1','0','0','1','1','1','1','1','1','1','1','1','1','0','0','1' ), -- 9
            ( '1','0','1','1','1','1','1','1','1','1','1','1','1','1','0','1' ), -- 10
            ( '1','1','1','1','1','1','1','1','1','1','1','1','1','1','1','1' ), -- 11 base
            ( '1','1','1','0','1','1','1','1','1','1','1','1','0','1','1','1' ), -- 12
            ( '1','1','0','0','1','1','1','1','1','1','1','1','0','0','1','1' ), -- 13
            ( '1','0','0','0','0','0','0','1','1','0','0','0','0','0','0','1' ), -- 14 engine pods
            ( '1','0','0','0','0','0','0','1','1','0','0','0','0','0','0','1' )  -- 15

        );

        VARIABLE left_x  : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE top_y   : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE lx, ty  : INTEGER;
        VARIABLE sx, sy  : INTEGER;
    BEGIN
        player_on <= '0';

        -- Compute sprite top-left (Scaled)
        left_x := player_x_pos - CONV_STD_LOGIC_VECTOR((SPR_W * SPRITE_SCALE)/2, 11);
        top_y  := player_y - CONV_STD_LOGIC_VECTOR(SPR_H * SPRITE_SCALE, 11);

        -- Quick bounds check
        IF pixel_col >= left_x AND pixel_col < left_x + CONV_STD_LOGIC_VECTOR(SPR_W * SPRITE_SCALE, 11) AND
           pixel_row >= top_y  AND pixel_row  < top_y  + CONV_STD_LOGIC_VECTOR(SPR_H * SPRITE_SCALE, 11) THEN

            -- Convert to integer indices
            lx := CONV_INTEGER(left_x);
            ty := CONV_INTEGER(top_y);
            sx := (CONV_INTEGER(pixel_col) - lx) / SPRITE_SCALE;
            sy := (CONV_INTEGER(pixel_row) - ty) / SPRITE_SCALE;

            -- Mask test
            IF galaga_sprite(sy)(sx) = '1' THEN
                player_on <= game_active;
            ELSE
                player_on <= '0';
            END IF;
        ELSE
            player_on <= '0';
        END IF;
    END PROCESS;
    
    -- Process to draw enemies
    enemy_draw : PROCESS (enemy_x_pos, pixel_row, pixel_col, enemy_alive, enemy_is_diving, diver_active, diver_x, diver_y, current_start_y, enemy_y_offset, squad_active, squad_x, squad_y, wave_number, diver_row) IS
        VARIABLE enemy_x, enemy_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE found : STD_LOGIC := '0';
        VARIABLE sx, sy : INTEGER;
        VARIABLE current_color : STD_LOGIC_VECTOR(2 DOWNTO 0);
        CONSTANT HALF_SIZE : INTEGER := 8 * SPRITE_SCALE;
    BEGIN
        found := '0';
        enemy_on <= '0';
        current_color := "100"; -- Default Red
        
        -- Draw Formation
        FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
            FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                IF enemy_alive(row, col) = '1' AND enemy_is_diving(row, col) = '0' THEN
                    enemy_x := enemy_x_pos + CONV_STD_LOGIC_VECTOR(col * ENEMY_SPACING_X, 11);
                    enemy_y := current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11);
                    
                    -- Check bounding box (Scaled)
                    IF pixel_col >= enemy_x - HALF_SIZE AND pixel_col < enemy_x + HALF_SIZE AND
                       pixel_row >= enemy_y - HALF_SIZE AND pixel_row < enemy_y + HALF_SIZE THEN
                        
                        sx := (CONV_INTEGER(pixel_col - (enemy_x - HALF_SIZE))) / SPRITE_SCALE;
                        sy := (CONV_INTEGER(pixel_row - (enemy_y - HALF_SIZE))) / SPRITE_SCALE;
                        
                        IF row = 0 OR row = 1 THEN
                            -- Walker (Back) - Only after Level 2
                            IF wave_number > 2 THEN
                                IF walker_sprite(sy)(sx) = '1' THEN
                                    found := '1';
                                    current_color := "101"; -- Magenta
                                END IF;
                            END IF;
                        ELSIF row = 2 OR row = 3 THEN
                            -- Crab (Middle)
                            IF crab_sprite(sy)(sx) = '1' THEN
                                found := '1';
                                current_color := "100"; -- Red
                            END IF;
                        ELSE
                            -- Bee (Front)
                            IF bee_sprite(sy)(sx) = '1' THEN
                                found := '1';
                                current_color := "110"; -- Yellow
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END LOOP;
        END LOOP;
        
        -- Draw Diver
        IF diver_active = '1' THEN
            IF pixel_col >= diver_x - HALF_SIZE AND pixel_col < diver_x + HALF_SIZE AND
               pixel_row >= diver_y - HALF_SIZE AND pixel_row < diver_y + HALF_SIZE THEN
                
                sx := (CONV_INTEGER(pixel_col - (diver_x - HALF_SIZE))) / SPRITE_SCALE;
                sy := (CONV_INTEGER(pixel_row - (diver_y - HALF_SIZE))) / SPRITE_SCALE;
                
                -- Determine sprite based on origin row
                IF diver_row = 0 OR diver_row = 1 THEN
                     IF walker_sprite(sy)(sx) = '1' THEN
                        found := '1';
                        current_color := "101";
                     END IF;
                ELSIF diver_row = 2 OR diver_row = 3 THEN
                     IF crab_sprite(sy)(sx) = '1' THEN
                        found := '1';
                        current_color := "100";
                     END IF;
                ELSE
                     IF bee_sprite(sy)(sx) = '1' THEN
                        found := '1';
                        current_color := "110";
                     END IF;
                END IF;
            END IF;
        END IF;
        
        -- Draw Squad (Special Attack)
        IF squad_active = '1' THEN
            -- Leader (Bee)
            IF pixel_col >= squad_x - HALF_SIZE AND pixel_col < squad_x + HALF_SIZE AND
               pixel_row >= squad_y - HALF_SIZE AND pixel_row < squad_y + HALF_SIZE THEN
                sx := (CONV_INTEGER(pixel_col - (squad_x - HALF_SIZE))) / SPRITE_SCALE;
                sy := (CONV_INTEGER(pixel_row - (squad_y - HALF_SIZE))) / SPRITE_SCALE;
                IF bee_sprite(sy)(sx) = '1' THEN
                    found := '1';
                    current_color := "110"; -- Yellow
                END IF;
            END IF;
            -- Wingman 1 (Crab)
            IF pixel_col >= squad_x - 20 - HALF_SIZE AND pixel_col < squad_x - 20 + HALF_SIZE AND
               pixel_row >= squad_y - 20 - HALF_SIZE AND pixel_row < squad_y - 20 + HALF_SIZE THEN
                sx := (CONV_INTEGER(pixel_col - (squad_x - 20 - HALF_SIZE))) / SPRITE_SCALE;
                sy := (CONV_INTEGER(pixel_row - (squad_y - 20 - HALF_SIZE))) / SPRITE_SCALE;
                IF crab_sprite(sy)(sx) = '1' THEN
                    found := '1';
                    current_color := "100"; -- Red
                END IF;
            END IF;
            -- Wingman 2 (Crab)
            IF pixel_col >= squad_x - 20 - HALF_SIZE AND pixel_col < squad_x - 20 + HALF_SIZE AND
               pixel_row >= squad_y + 20 - HALF_SIZE AND pixel_row < squad_y + 20 + HALF_SIZE THEN
                sx := (CONV_INTEGER(pixel_col - (squad_x - 20 - HALF_SIZE))) / SPRITE_SCALE;
                sy := (CONV_INTEGER(pixel_row - (squad_y + 20 - HALF_SIZE))) / SPRITE_SCALE;
                IF crab_sprite(sy)(sx) = '1' THEN
                    found := '1';
                    current_color := "100"; -- Red
                END IF;
            END IF;
        END IF;
        
        IF found = '1' THEN
            enemy_on <= '1';
            enemy_pixel_color <= current_color;
        END IF;
    END PROCESS;
    
    -- Process to draw bullet
    bullet_draw : PROCESS (bullet_x, bullet_y, pixel_row, pixel_col, bullet_active) IS
        VARIABLE dx, dy : STD_LOGIC_VECTOR(10 DOWNTO 0);
    BEGIN
        IF bullet_active = '1' THEN
            IF pixel_col >= bullet_x - bullet_size AND
               pixel_col <= bullet_x + bullet_size AND
               pixel_row >= bullet_y - bullet_size AND
               pixel_row <= bullet_y + bullet_size THEN
                dx := pixel_col - bullet_x;
                IF dx(10) = '1' THEN
                    dx := (NOT dx) + 1;
                END IF;
                dy := pixel_row - bullet_y;
                IF dy(10) = '1' THEN
                    dy := (NOT dy) + 1;
                END IF;
                IF (dx * dx + dy * dy) < (bullet_size * bullet_size) THEN
                    bullet_on <= '1';
                ELSE
                    bullet_on <= '0';
                END IF;
            ELSE
                bullet_on <= '0';
            END IF;
        ELSE
            bullet_on <= '0';
        END IF;
    END PROCESS;

    -- Process to draw enemy bullet (Triple Shot AND Single Shot)
    enemy_bullet_draw : PROCESS (eb_L_x, eb_L_y, eb_L_active, eb_C_x, eb_C_y, eb_C_active, eb_R_x, eb_R_y, eb_R_active, enemy_bullet_x, enemy_bullet_y, enemy_bullet_active, pixel_row, pixel_col) IS
        VARIABLE dx, dy : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE found : STD_LOGIC := '0';
    BEGIN
        found := '0';
        
        -- Single Bullet (Formation Fire)
        IF enemy_bullet_active = '1' THEN
            IF pixel_col >= enemy_bullet_x - bullet_size AND pixel_col <= enemy_bullet_x + bullet_size AND
               pixel_row >= enemy_bullet_y - bullet_size AND pixel_row <= enemy_bullet_y + bullet_size THEN
                found := '1';
            END IF;
        END IF;

        -- Left Bullet
        IF eb_L_active = '1' THEN
            IF pixel_col >= eb_L_x - bullet_size AND pixel_col <= eb_L_x + bullet_size AND
               pixel_row >= eb_L_y - bullet_size AND pixel_row <= eb_L_y + bullet_size THEN
                found := '1';
            END IF;
        END IF;
        
        -- Center Bullet
        IF eb_C_active = '1' THEN
            IF pixel_col >= eb_C_x - bullet_size AND pixel_col <= eb_C_x + bullet_size AND
               pixel_row >= eb_C_y - bullet_size AND pixel_row <= eb_C_y + bullet_size THEN
                found := '1';
            END IF;
        END IF;
        
        -- Right Bullet
        IF eb_R_active = '1' THEN
            IF pixel_col >= eb_R_x - bullet_size AND pixel_col <= eb_R_x + bullet_size AND
               pixel_row >= eb_R_y - bullet_size AND pixel_row <= eb_R_y + bullet_size THEN
                found := '1';
            END IF;
        END IF;
        
        enemy_bullet_on <= found;
    END PROCESS;

    -- Process to draw text
    text_draw : PROCESS (pixel_row, pixel_col, current_state, wave_number, shots_fired_count, hits_count, hit_miss_ratio)
        VARIABLE x_rel, y_rel : INTEGER;
        VARIABLE char_col, char_row : INTEGER;
        VARIABLE char_idx : INTEGER;
        VARIABLE bit_val : STD_LOGIC;
        CONSTANT SCALE : INTEGER := 4;
        CONSTANT CHAR_W : INTEGER := 6; -- 5 + 1 spacing
        CONSTANT CHAR_HEIGHT : INTEGER := 7;
        VARIABLE digit_tens, digit_ones : INTEGER;
        VARIABLE d1, d2, d3, d4 : INTEGER;
        
        -- Helper to get bit from char
        FUNCTION get_char_bit(c : font_char; r, c_idx : INTEGER) RETURN STD_LOGIC IS
        BEGIN
            IF c_idx >= 0 AND c_idx < 5 THEN
                RETURN c(r)(4 - c_idx);
            ELSE
                RETURN '0';
            END IF;
        END FUNCTION;
        
        -- Helper to get char from digit
        FUNCTION get_digit_char(d : INTEGER) RETURN font_char IS
        BEGIN
            CASE d IS
                WHEN 0 => RETURN CHAR_0;
                WHEN 1 => RETURN CHAR_1;
                WHEN 2 => RETURN CHAR_2;
                WHEN 3 => RETURN CHAR_3;
                WHEN 4 => RETURN CHAR_4;
                WHEN 5 => RETURN CHAR_5;
                WHEN 6 => RETURN CHAR_6;
                WHEN 7 => RETURN CHAR_7;
                WHEN 8 => RETURN CHAR_8;
                WHEN 9 => RETURN CHAR_9;
                WHEN OTHERS => RETURN CHAR_0;
            END CASE;
        END FUNCTION;
        
    BEGIN
        text_on <= '0';
        
        -- Draw Level Counter (Always visible or just during play? Let's make it always visible)
        -- "LEVEL XX" at (550, 10)
        IF pixel_col >= 550 AND pixel_col < 550 + (8 * CHAR_W * SCALE) AND
           pixel_row >= 10 AND pixel_row < 10 + (CHAR_HEIGHT * SCALE) THEN
            
            x_rel := CONV_INTEGER(pixel_col) - 550;
            y_rel := CONV_INTEGER(pixel_row) - 10;
            
            char_idx := x_rel / (CHAR_W * SCALE);
            char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
            char_row := y_rel / SCALE;
            
            digit_tens := (wave_number / 10) MOD 10;
            digit_ones := wave_number MOD 10;
            
            CASE char_idx IS
                WHEN 0 => bit_val := get_char_bit(CHAR_L, char_row, char_col);
                WHEN 1 => bit_val := get_char_bit(CHAR_E, char_row, char_col);
                WHEN 2 => bit_val := get_char_bit(CHAR_V, char_row, char_col);
                WHEN 3 => bit_val := get_char_bit(CHAR_E, char_row, char_col);
                WHEN 4 => bit_val := get_char_bit(CHAR_L, char_row, char_col);
                WHEN 5 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                WHEN 6 => 
                    IF wave_number >= 10 THEN
                        bit_val := get_char_bit(get_digit_char(digit_tens), char_row, char_col);
                    ELSE
                        bit_val := '0'; -- Space
                    END IF;
                WHEN 7 => bit_val := get_char_bit(get_digit_char(digit_ones), char_row, char_col);
                WHEN OTHERS => bit_val := '0';
            END CASE;
            text_on <= bit_val;
        END IF;
        
        IF current_state = READY_SCREEN THEN
            -- Draw "READY!" at (328, 286)
            IF pixel_col >= 328 AND pixel_col < 328 + (6 * CHAR_W * SCALE) AND
               pixel_row >= 286 AND pixel_row < 286 + (CHAR_HEIGHT * SCALE) THEN
                
                x_rel := CONV_INTEGER(pixel_col) - 328;
                y_rel := CONV_INTEGER(pixel_row) - 286;
                
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                
                CASE char_idx IS
                    WHEN 0 => bit_val := get_char_bit(CHAR_R, char_row, char_col);
                    WHEN 1 => bit_val := get_char_bit(CHAR_E, char_row, char_col);
                    WHEN 2 => bit_val := get_char_bit(CHAR_A, char_row, char_col);
                    WHEN 3 => bit_val := get_char_bit(CHAR_D, char_row, char_col);
                    WHEN 4 => bit_val := get_char_bit(CHAR_Y, char_row, char_col);
                    WHEN 5 => bit_val := get_char_bit(CHAR_EX, char_row, char_col);
                    WHEN OTHERS => bit_val := '0';
                END CASE;
                
                text_on <= bit_val;
            END IF;
            
        ELSIF current_state = GAMEOVER THEN
            -- Draw "GAME OVER" at (292, 286)
            IF pixel_col >= 292 AND pixel_col < 292 + (9 * CHAR_W * SCALE) AND
               pixel_row >= 286 AND pixel_row < 286 + (CHAR_HEIGHT * SCALE) THEN
                
                x_rel := CONV_INTEGER(pixel_col) - 292;
                y_rel := CONV_INTEGER(pixel_row) - 286;
                
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                
                CASE char_idx IS
                    WHEN 0 => bit_val := get_char_bit(CHAR_G, char_row, char_col);
                    WHEN 1 => bit_val := get_char_bit(CHAR_A, char_row, char_col);
                    WHEN 2 => bit_val := get_char_bit(CHAR_M, char_row, char_col);
                    WHEN 3 => bit_val := get_char_bit(CHAR_E, char_row, char_col);
                    WHEN 4 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 5 => bit_val := get_char_bit(CHAR_O, char_row, char_col);
                    WHEN 6 => bit_val := get_char_bit(CHAR_V, char_row, char_col);
                    WHEN 7 => bit_val := get_char_bit(CHAR_E, char_row, char_col);
                    WHEN 8 => bit_val := get_char_bit(CHAR_R, char_row, char_col);
                    WHEN OTHERS => bit_val := '0';
                END CASE;
                
                text_on <= bit_val;
            END IF;
            
        ELSIF current_state = RESULTS_SCREEN THEN
            -- Draw "RESULTS" at (316, 100)
            IF pixel_col >= 316 AND pixel_col < 316 + (7 * CHAR_W * SCALE) AND
               pixel_row >= 100 AND pixel_row < 100 + (CHAR_HEIGHT * SCALE) THEN
                x_rel := CONV_INTEGER(pixel_col) - 316;
                y_rel := CONV_INTEGER(pixel_row) - 100;
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                CASE char_idx IS
                    WHEN 0 => bit_val := get_char_bit(CHAR_R, char_row, char_col);
                    WHEN 1 => bit_val := get_char_bit(CHAR_E, char_row, char_col);
                    WHEN 2 => bit_val := get_char_bit(CHAR_S, char_row, char_col);
                    WHEN 3 => bit_val := get_char_bit(CHAR_U, char_row, char_col);
                    WHEN 4 => bit_val := get_char_bit(CHAR_L, char_row, char_col);
                    WHEN 5 => bit_val := get_char_bit(CHAR_T, char_row, char_col);
                    WHEN 6 => bit_val := get_char_bit(CHAR_S, char_row, char_col);
                    WHEN OTHERS => bit_val := '0';
                END CASE;
                text_on <= bit_val;
            END IF;
            
            -- Draw "SHOTS FIRED :" at (100, 200)
            IF pixel_col >= 100 AND pixel_col < 100 + (13 * CHAR_W * SCALE) AND
               pixel_row >= 200 AND pixel_row < 200 + (CHAR_HEIGHT * SCALE) THEN
                x_rel := CONV_INTEGER(pixel_col) - 100;
                y_rel := CONV_INTEGER(pixel_row) - 200;
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                CASE char_idx IS
                    WHEN 0 => bit_val := get_char_bit(CHAR_S, char_row, char_col);
                    WHEN 1 => bit_val := get_char_bit(CHAR_H, char_row, char_col);
                    WHEN 2 => bit_val := get_char_bit(CHAR_O, char_row, char_col);
                    WHEN 3 => bit_val := get_char_bit(CHAR_T, char_row, char_col);
                    WHEN 4 => bit_val := get_char_bit(CHAR_S, char_row, char_col);
                    WHEN 5 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 6 => bit_val := get_char_bit(CHAR_F, char_row, char_col);
                    WHEN 7 => bit_val := get_char_bit(CHAR_I, char_row, char_col);
                    WHEN 8 => bit_val := get_char_bit(CHAR_R, char_row, char_col);
                    WHEN 9 => bit_val := get_char_bit(CHAR_E, char_row, char_col);
                    WHEN 10 => bit_val := get_char_bit(CHAR_D, char_row, char_col);
                    WHEN 11 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 12 => bit_val := get_char_bit(CHAR_COLON, char_row, char_col);
                    WHEN OTHERS => bit_val := '0';
                END CASE;
                text_on <= bit_val;
            END IF;
            
            -- Draw Shots Number at (500, 200)
            IF pixel_col >= 500 AND pixel_col < 500 + (4 * CHAR_W * SCALE) AND
               pixel_row >= 200 AND pixel_row < 200 + (CHAR_HEIGHT * SCALE) THEN
                x_rel := CONV_INTEGER(pixel_col) - 500;
                y_rel := CONV_INTEGER(pixel_row) - 200;
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                
                d1 := (shots_fired_count / 1000) MOD 10;
                d2 := (shots_fired_count / 100) MOD 10;
                d3 := (shots_fired_count / 10) MOD 10;
                d4 := shots_fired_count MOD 10;
                
                CASE char_idx IS
                    WHEN 0 => bit_val := get_char_bit(get_digit_char(d1), char_row, char_col);
                    WHEN 1 => bit_val := get_char_bit(get_digit_char(d2), char_row, char_col);
                    WHEN 2 => bit_val := get_char_bit(get_digit_char(d3), char_row, char_col);
                    WHEN 3 => bit_val := get_char_bit(get_digit_char(d4), char_row, char_col);
                    WHEN OTHERS => bit_val := '0';
                END CASE;
                text_on <= bit_val;
            END IF;
            
            -- Draw "NUMBER OF HITS :" at (100, 250)
            IF pixel_col >= 100 AND pixel_col < 100 + (16 * CHAR_W * SCALE) AND
               pixel_row >= 250 AND pixel_row < 250 + (CHAR_HEIGHT * SCALE) THEN
                x_rel := CONV_INTEGER(pixel_col) - 100;
                y_rel := CONV_INTEGER(pixel_row) - 250;
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                CASE char_idx IS
                    WHEN 0 => bit_val := get_char_bit(CHAR_N, char_row, char_col);
                    WHEN 1 => bit_val := get_char_bit(CHAR_U, char_row, char_col);
                    WHEN 2 => bit_val := get_char_bit(CHAR_M, char_row, char_col);
                    WHEN 3 => bit_val := get_char_bit(CHAR_B, char_row, char_col);
                    WHEN 4 => bit_val := get_char_bit(CHAR_E, char_row, char_col);
                    WHEN 5 => bit_val := get_char_bit(CHAR_R, char_row, char_col);
                    WHEN 6 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 7 => bit_val := get_char_bit(CHAR_O, char_row, char_col);
                    WHEN 8 => bit_val := get_char_bit(CHAR_F, char_row, char_col);
                    WHEN 9 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 10 => bit_val := get_char_bit(CHAR_H, char_row, char_col);
                    WHEN 11 => bit_val := get_char_bit(CHAR_I, char_row, char_col);
                    WHEN 12 => bit_val := get_char_bit(CHAR_T, char_row, char_col);
                    WHEN 13 => bit_val := get_char_bit(CHAR_S, char_row, char_col);
                    WHEN 14 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 15 => bit_val := get_char_bit(CHAR_COLON, char_row, char_col);
                    WHEN OTHERS => bit_val := '0';
                END CASE;
                text_on <= bit_val;
            END IF;
            
            -- Draw Hits Number at (500, 250)
            IF pixel_col >= 500 AND pixel_col < 500 + (4 * CHAR_W * SCALE) AND
               pixel_row >= 250 AND pixel_row < 250 + (CHAR_HEIGHT * SCALE) THEN
                x_rel := CONV_INTEGER(pixel_col) - 500;
                y_rel := CONV_INTEGER(pixel_row) - 250;
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                
                d1 := (hits_count / 1000) MOD 10;
                d2 := (hits_count / 100) MOD 10;
                d3 := (hits_count / 10) MOD 10;
                d4 := hits_count MOD 10;
                
                CASE char_idx IS
                    WHEN 0 => bit_val := get_char_bit(get_digit_char(d1), char_row, char_col);
                    WHEN 1 => bit_val := get_char_bit(get_digit_char(d2), char_row, char_col);
                    WHEN 2 => bit_val := get_char_bit(get_digit_char(d3), char_row, char_col);
                    WHEN 3 => bit_val := get_char_bit(get_digit_char(d4), char_row, char_col);
                    WHEN OTHERS => bit_val := '0';
                END CASE;
                text_on <= bit_val;
            END IF;
            
            -- Draw "HIT MISS RATIO :" at (100, 300)
            IF pixel_col >= 100 AND pixel_col < 100 + (16 * CHAR_W * SCALE) AND
               pixel_row >= 300 AND pixel_row < 300 + (CHAR_HEIGHT * SCALE) THEN
                x_rel := CONV_INTEGER(pixel_col) - 100;
                y_rel := CONV_INTEGER(pixel_row) - 300;
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                CASE char_idx IS
                    WHEN 0 => bit_val := get_char_bit(CHAR_H, char_row, char_col);
                    WHEN 1 => bit_val := get_char_bit(CHAR_I, char_row, char_col);
                    WHEN 2 => bit_val := get_char_bit(CHAR_T, char_row, char_col);
                    WHEN 3 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 4 => bit_val := get_char_bit(CHAR_M, char_row, char_col);
                    WHEN 5 => bit_val := get_char_bit(CHAR_I, char_row, char_col);
                    WHEN 6 => bit_val := get_char_bit(CHAR_S, char_row, char_col);
                    WHEN 7 => bit_val := get_char_bit(CHAR_S, char_row, char_col);
                    WHEN 8 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 9 => bit_val := get_char_bit(CHAR_R, char_row, char_col);
                    WHEN 10 => bit_val := get_char_bit(CHAR_A, char_row, char_col);
                    WHEN 11 => bit_val := get_char_bit(CHAR_T, char_row, char_col);
                    WHEN 12 => bit_val := get_char_bit(CHAR_I, char_row, char_col);
                    WHEN 13 => bit_val := get_char_bit(CHAR_O, char_row, char_col);
                    WHEN 14 => bit_val := get_char_bit(CHAR_SP, char_row, char_col);
                    WHEN 15 => bit_val := get_char_bit(CHAR_COLON, char_row, char_col);
                    WHEN OTHERS => bit_val := '0';
                END CASE;
                text_on <= bit_val;
            END IF;
            
            -- Draw Ratio Number at (500, 300)
            IF pixel_col >= 500 AND pixel_col < 500 + (4 * CHAR_W * SCALE) AND
               pixel_row >= 300 AND pixel_row < 300 + (CHAR_HEIGHT * SCALE) THEN
                x_rel := CONV_INTEGER(pixel_col) - 500;
                y_rel := CONV_INTEGER(pixel_row) - 300;
                char_idx := x_rel / (CHAR_W * SCALE);
                char_col := (x_rel MOD (CHAR_W * SCALE)) / SCALE;
                char_row := y_rel / SCALE;
                
                IF shots_fired_count = 0 THEN
                    -- NAN
                    CASE char_idx IS
                        WHEN 0 => bit_val := get_char_bit(CHAR_N, char_row, char_col);
                        WHEN 1 => bit_val := get_char_bit(CHAR_A, char_row, char_col);
                        WHEN 2 => bit_val := get_char_bit(CHAR_N, char_row, char_col);
                        WHEN OTHERS => bit_val := '0';
                    END CASE;
                ELSE
                    d1 := (hit_miss_ratio / 100) MOD 10;
                    d2 := (hit_miss_ratio / 10) MOD 10;
                    d3 := hit_miss_ratio MOD 10;
                    
                    CASE char_idx IS
                        WHEN 0 => bit_val := get_char_bit(get_digit_char(d1), char_row, char_col);
                        WHEN 1 => bit_val := get_char_bit(get_digit_char(d2), char_row, char_col);
                        WHEN 2 => bit_val := get_char_bit(get_digit_char(d3), char_row, char_col);
                        WHEN 3 => bit_val := get_char_bit(CHAR_PCT, char_row, char_col);
                        WHEN OTHERS => bit_val := '0';
                    END CASE;
                END IF;
                text_on <= bit_val;
            END IF;
        END IF;
    END PROCESS;

    
    -- Main game logic process
    lives <= CONV_STD_LOGIC_VECTOR(lives_count, 3);

    game_logic : PROCESS
        VARIABLE temp : STD_LOGIC_VECTOR(11 DOWNTO 0);
        VARIABLE enemy_x, enemy_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE enemies_remaining : INTEGER;
        VARIABLE collision_found : STD_LOGIC;
        VARIABLE game_over_timer : INTEGER := 0;
    BEGIN
        WAIT UNTIL rising_edge(v_sync);
        
        -- Update Star Scroll
        star_speed_counter <= star_speed_counter + 1;
        IF star_speed_counter = "11" THEN -- Move every 4 frames
            star_scroll_y <= star_scroll_y - 1; -- Move stars down
        END IF;
        
        IF reset = '1' THEN
            current_state <= START;
            lives_count <= 3;
            shots_fired_count <= 0;
            hits_count <= 0;
            hit_miss_ratio <= 0;
        ELSE
            CASE current_state IS
                WHEN START =>
                    score_i <= (OTHERS => '0');
                    wave_number <= 1;
                    lives_count <= 3;
                    shots_fired_count <= 0;
                    hits_count <= 0;
                    hit_miss_ratio <= 0;
                    current_state <= NEXT_WAVE;
                    
                WHEN NEXT_WAVE =>
                    -- Reset positions
                    enemy_x_pos <= CONV_STD_LOGIC_VECTOR(100, 11);
                    enemy_y_offset <= (OTHERS => '0');
                    current_start_y <= (OTHERS => '0'); -- Start at top for Fly-In
                    enemy_direction <= '0';
                    formation_move_dir <= '0'; -- Start moving down
                    bullet_active <= '0';
                    diver_active <= '0';
                    eb_L_active <= '0';
                    eb_C_active <= '0';
                    eb_R_active <= '0';
                    enemy_bullet_active <= '0';
                    enemy_is_diving <= (OTHERS => (OTHERS => '0'));
                    squad_active <= '0';
                    
                    -- Set difficulty and speed
                    -- Infinite scaling
                    IF wave_number <= 10 THEN
                        shoot_delay <= CONV_STD_LOGIC_VECTOR(40 - (wave_number * 3), 11); -- Faster shooting
                        move_threshold <= CONV_STD_LOGIC_VECTOR(6 - (wave_number / 3), 21); -- Faster movement
                    ELSE
                        shoot_delay <= CONV_STD_LOGIC_VECTOR(10, 11); -- Max fire rate
                        move_threshold <= CONV_STD_LOGIC_VECTOR(2, 21); -- Max speed
                    END IF;
                    
                    -- Set Formation
                    FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                        FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                            IF wave_number = 1 THEN
                                -- Wave 1: Small group in middle (Row 1, Cols 3-6)
                                IF row = 1 AND (col >= 3 AND col <= 6) THEN
                                    enemy_alive(row, col) <= '1';
                                ELSE
                                    enemy_alive(row, col) <= '0';
                                END IF;
                            ELSIF wave_number = 2 THEN
                                -- Wave 2: Two rows, slightly wider (Rows 0-1, Cols 2-7)
                                IF row < 2 AND (col >= 2 AND col <= 7) THEN
                                    enemy_alive(row, col) <= '1';
                                ELSE
                                    enemy_alive(row, col) <= '0';
                                END IF;
                            ELSIF wave_number = 3 THEN
                                -- Wave 3: Three rows, wider (Rows 0-2, Cols 1-8)
                                IF row < 3 AND (col >= 1 AND col <= 8) THEN
                                    enemy_alive(row, col) <= '1';
                                ELSE
                                    enemy_alive(row, col) <= '0';
                                END IF;
                            ELSIF wave_number = 4 THEN
                                -- Wave 4: Four rows, full width
                                IF row < 4 THEN
                                    enemy_alive(row, col) <= '1';
                                ELSE
                                    enemy_alive(row, col) <= '0';
                                END IF;
                            ELSE
                                -- Wave 5+: Full formation (6 rows)
                                enemy_alive(row, col) <= '1';
                            END IF;
                        END LOOP;
                    END LOOP;
                    
                    current_state <= READY_SCREEN;
                    ready_timer_counter <= (OTHERS => '0');
                    
                WHEN READY_SCREEN =>
                    ready_timer_counter <= ready_timer_counter + 1;
                    IF ready_timer_counter = CONV_STD_LOGIC_VECTOR(120, 11) THEN -- Approx 2 seconds
                        current_state <= FLY_IN;
                    END IF;
                    
                WHEN FLY_IN =>
                    -- Animate enemies flying in
                    IF current_start_y < CONV_STD_LOGIC_VECTOR(50, 11) THEN
                        current_start_y <= current_start_y + 1;
                    ELSE
                        current_state <= PLAY;
                    END IF;
                    
                    -- Allow player movement during fly-in
                    player_x_pos <= player_x;
                    
                WHEN PLAY =>
                    -- Update player position
                    player_x_pos <= player_x;
                    
                    -- Handle shooting
                    IF shoot = '1' AND shoot_prev = '0' AND bullet_active = '0' THEN
                        bullet_active <= '1';
                        bullet_x <= player_x_pos;
                        bullet_y <= player_y - CONV_STD_LOGIC_VECTOR(player_size, 11);
                        shots_fired_count <= shots_fired_count + 1;
                    END IF;
                    shoot_prev <= shoot;
                    
                    -- Move bullet
                    IF bullet_active = '1' THEN
                        temp := ('0' & bullet_y) - ('0' & bullet_speed);
                        IF temp(11) = '1' OR bullet_y < bullet_size THEN
                            bullet_active <= '0';
                            bullet_y <= CONV_STD_LOGIC_VECTOR(600, 11);
                        ELSE
                            bullet_y <= temp(10 DOWNTO 0);
                        END IF;
                    END IF;
                    
                    -- Handle Diver (Bee) Logic
                    random_col <= random_col + 1; 
                    diver_timer <= diver_timer + 1;
                    
                    -- Start Dive
                    IF diver_active = '0' AND diver_timer > shoot_delay + 20 THEN -- More frequent dives
                        diver_timer <= (OTHERS => '0');
                        -- Try to find a Bee to dive (scan rows from bottom up)
                        IF CONV_INTEGER(random_col) < NUM_ENEMY_COLS THEN
                            IF enemy_alive(5, CONV_INTEGER(random_col)) = '1' AND enemy_is_diving(5, CONV_INTEGER(random_col)) = '0' THEN
                                 diver_active <= '1';
                                 diver_row <= 5;
                                 diver_col <= CONV_INTEGER(random_col);
                                 enemy_is_diving(5, CONV_INTEGER(random_col)) <= '1';
                                 diver_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                 diver_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(5 * ENEMY_SPACING_Y, 11);
                                 diver_shot_fired <= '0';
                            ELSIF enemy_alive(4, CONV_INTEGER(random_col)) = '1' AND enemy_is_diving(4, CONV_INTEGER(random_col)) = '0' THEN
                                 diver_active <= '1';
                                 diver_row <= 4;
                                 diver_col <= CONV_INTEGER(random_col);
                                 enemy_is_diving(4, CONV_INTEGER(random_col)) <= '1';
                                 diver_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                 diver_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(4 * ENEMY_SPACING_Y, 11);
                                 diver_shot_fired <= '0';
                            ELSIF enemy_alive(3, CONV_INTEGER(random_col)) = '1' AND enemy_is_diving(3, CONV_INTEGER(random_col)) = '0' THEN
                                 diver_active <= '1';
                                 diver_row <= 3;
                                 diver_col <= CONV_INTEGER(random_col);
                                 enemy_is_diving(3, CONV_INTEGER(random_col)) <= '1';
                                 diver_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                 diver_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(3 * ENEMY_SPACING_Y, 11);
                                 diver_shot_fired <= '0';
                            ELSIF enemy_alive(2, CONV_INTEGER(random_col)) = '1' AND enemy_is_diving(2, CONV_INTEGER(random_col)) = '0' THEN
                                 diver_active <= '1';
                                 diver_row <= 2;
                                 diver_col <= CONV_INTEGER(random_col);
                                 enemy_is_diving(2, CONV_INTEGER(random_col)) <= '1';
                                 diver_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                 diver_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(2 * ENEMY_SPACING_Y, 11);
                                 diver_shot_fired <= '0';
                            ELSIF enemy_alive(1, CONV_INTEGER(random_col)) = '1' AND enemy_is_diving(1, CONV_INTEGER(random_col)) = '0' THEN
                                 diver_active <= '1';
                                 diver_row <= 1;
                                 diver_col <= CONV_INTEGER(random_col);
                                 enemy_is_diving(1, CONV_INTEGER(random_col)) <= '1';
                                 diver_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                 diver_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(1 * ENEMY_SPACING_Y, 11);
                                 diver_shot_fired <= '0';
                            ELSIF enemy_alive(0, CONV_INTEGER(random_col)) = '1' AND enemy_is_diving(0, CONV_INTEGER(random_col)) = '0' THEN
                                 diver_active <= '1';
                                 diver_row <= 0;
                                 diver_col <= CONV_INTEGER(random_col);
                                 enemy_is_diving(0, CONV_INTEGER(random_col)) <= '1';
                                 diver_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                 diver_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(0 * ENEMY_SPACING_Y, 11);
                                 diver_shot_fired <= '0';
                            END IF;
                        END IF;
                    END IF;
                    
                    -- Move Diver
                    IF diver_active = '1' THEN
                        diver_y <= diver_y + enemy_bullet_speed + 1; -- Dive speed faster than bullets
                        
                        -- Homing X (Simple)
                        IF diver_x < player_x_pos THEN
                            diver_x <= diver_x + 3; -- Faster lateral movement
                        ELSIF diver_x > player_x_pos THEN
                            diver_x <= diver_x - 3; -- Faster lateral movement
                        END IF;
                        
                        -- Shoot Triple Shot
                        IF diver_shot_fired = '0' AND diver_y > CONV_STD_LOGIC_VECTOR(200, 11) THEN
                            diver_shot_fired <= '1';
                            eb_L_active <= '1'; eb_C_active <= '1'; eb_R_active <= '1';
                            eb_L_x <= diver_x; eb_L_y <= diver_y;
                            eb_C_x <= diver_x; eb_C_y <= diver_y;
                            eb_R_x <= diver_x; eb_R_y <= diver_y;
                        END IF;
                        
                        -- Check if off screen
                        IF diver_y > CONV_STD_LOGIC_VECTOR(600, 11) THEN
                            diver_active <= '0';
                            enemy_is_diving(diver_row, diver_col) <= '0'; -- Return to formation
                        END IF;
                        
                        -- Check collision with player
                        IF diver_x >= player_x_pos - player_size AND
                           diver_x <= player_x_pos + player_size AND
                           diver_y >= player_y - player_size AND
                           diver_y <= player_y + player_size THEN
                            IF lives_count > 1 THEN
                                lives_count <= lives_count - 1;
                                diver_active <= '0';
                                enemy_alive(diver_row, diver_col) <= '0'; -- Kill the diver
                                enemy_is_diving(diver_row, diver_col) <= '0';
                                eb_L_active <= '0'; eb_C_active <= '0'; eb_R_active <= '0';
                                bullet_active <= '0';
                            ELSE
                                lives_count <= 0;
                                current_state <= GAMEOVER;
                            END IF;
                        END IF;
                    END IF;
                    
                    -- Move Triple Bullets
                    IF eb_C_active = '1' THEN
                        eb_C_y <= eb_C_y + enemy_bullet_speed;
                        IF eb_C_y > 600 THEN eb_C_active <= '0'; END IF;
                        -- Collision
                        IF eb_C_x >= player_x_pos - player_size AND eb_C_x <= player_x_pos + player_size AND
                           eb_C_y >= player_y - player_size AND eb_C_y <= player_y + player_size THEN
                            IF lives_count > 1 THEN
                                lives_count <= lives_count - 1;
                                diver_active <= '0';
                                enemy_is_diving(diver_row, diver_col) <= '0'; -- Return to formation
                                eb_L_active <= '0'; eb_C_active <= '0'; eb_R_active <= '0';
                                bullet_active <= '0';
                            ELSE
                                lives_count <= 0;
                                current_state <= GAMEOVER;
                            END IF;
                        END IF;
                    END IF;
                    
                    IF eb_L_active = '1' THEN
                        eb_L_y <= eb_L_y + enemy_bullet_speed;
                        eb_L_x <= eb_L_x - 3; -- Wider spread
                        IF eb_L_y > 600 THEN eb_L_active <= '0'; END IF;
                        -- Collision
                        IF eb_L_x >= player_x_pos - player_size AND eb_L_x <= player_x_pos + player_size AND
                           eb_L_y >= player_y - player_size AND eb_L_y <= player_y + player_size THEN
                            IF lives_count > 1 THEN
                                lives_count <= lives_count - 1;
                                diver_active <= '0';
                                enemy_is_diving(diver_row, diver_col) <= '0'; -- Return to formation
                                eb_L_active <= '0'; eb_C_active <= '0'; eb_R_active <= '0';
                                bullet_active <= '0';
                            ELSE
                                lives_count <= 0;
                                current_state <= GAMEOVER;
                            END IF;
                        END IF;
                    END IF;
                    
                    IF eb_R_active = '1' THEN
                        eb_R_y <= eb_R_y + enemy_bullet_speed;
                        eb_R_x <= eb_R_x + 3; -- Wider spread
                        IF eb_R_y > 600 THEN eb_R_active <= '0'; END IF;
                        -- Collision
                        IF eb_R_x >= player_x_pos - player_size AND eb_R_x <= player_x_pos + player_size AND
                           eb_R_y >= player_y - player_size AND eb_R_y <= player_y + player_size THEN
                            IF lives_count > 1 THEN
                                lives_count <= lives_count - 1;
                                diver_active <= '0';
                                enemy_is_diving(diver_row, diver_col) <= '0'; -- Return to formation
                                eb_L_active <= '0'; eb_C_active <= '0'; eb_R_active <= '0';
                                bullet_active <= '0';
                            ELSE
                                lives_count <= 0;
                                current_state <= GAMEOVER;
                            END IF;
                        END IF;
                    END IF;

                    -- Random Enemy Fire Logic
                    enemy_shoot_timer <= enemy_shoot_timer + 1;
                    IF enemy_shoot_timer > shoot_delay THEN
                        enemy_shoot_timer <= (OTHERS => '0');
                        IF enemy_bullet_active = '0' THEN
                             -- Pick shooter (using random_col from diver logic)
                             -- Find bottom-most alive enemy in that column
                             IF CONV_INTEGER(random_col) < NUM_ENEMY_COLS THEN
                                 IF enemy_alive(5, CONV_INTEGER(random_col)) = '1' THEN
                                      enemy_bullet_active <= '1';
                                      enemy_bullet_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                      enemy_bullet_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(5 * ENEMY_SPACING_Y + 16, 11);
                                 ELSIF enemy_alive(4, CONV_INTEGER(random_col)) = '1' THEN
                                      enemy_bullet_active <= '1';
                                      enemy_bullet_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                      enemy_bullet_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(4 * ENEMY_SPACING_Y + 16, 11);
                                 ELSIF enemy_alive(3, CONV_INTEGER(random_col)) = '1' THEN
                                      enemy_bullet_active <= '1';
                                      enemy_bullet_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                      enemy_bullet_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(3 * ENEMY_SPACING_Y + 16, 11);
                                 ELSIF enemy_alive(2, CONV_INTEGER(random_col)) = '1' THEN
                                      enemy_bullet_active <= '1';
                                      enemy_bullet_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                      enemy_bullet_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(2 * ENEMY_SPACING_Y + 16, 11);
                                 ELSIF enemy_alive(1, CONV_INTEGER(random_col)) = '1' THEN
                                      enemy_bullet_active <= '1';
                                      enemy_bullet_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                      enemy_bullet_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(1 * ENEMY_SPACING_Y + 16, 11);
                                 ELSIF enemy_alive(0, CONV_INTEGER(random_col)) = '1' THEN
                                      enemy_bullet_active <= '1';
                                      enemy_bullet_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                                      enemy_bullet_y <= current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(0 * ENEMY_SPACING_Y + 16, 11);
                                 END IF;
                             END IF;
                        END IF;
                    END IF;

                    -- Move Single Enemy Bullet
                    IF enemy_bullet_active = '1' THEN
                        enemy_bullet_y <= enemy_bullet_y + enemy_bullet_speed;
                        IF enemy_bullet_y > 600 THEN
                            enemy_bullet_active <= '0';
                        END IF;
                        
                        -- Collision with Player
                        IF enemy_bullet_x >= player_x_pos - player_size AND enemy_bullet_x <= player_x_pos + player_size AND
                           enemy_bullet_y >= player_y - player_size AND enemy_bullet_y <= player_y + player_size THEN
                            IF lives_count > 1 THEN
                                lives_count <= lives_count - 1;
                                enemy_bullet_active <= '0';
                            ELSE
                                lives_count <= 0;
                                current_state <= GAMEOVER;
                            END IF;
                        END IF;
                    END IF;
                    
                    -- Squad Attack Logic (Fly-in from Left)
                    squad_timer <= squad_timer + 1;
                    
                    -- Trigger Squad Attack (Every ~1000 frames for testing, approx 16s)
                    IF squad_active = '0' AND squad_timer > CONV_STD_LOGIC_VECTOR(1000, 12) THEN 
                         squad_active <= '1';
                         squad_x <= (OTHERS => '0'); -- Start Left Edge
                         squad_y <= CONV_STD_LOGIC_VECTOR(100 + CONV_INTEGER(random_col)*10, 11); -- Random Start Height
                         squad_timer <= (OTHERS => '0');
                    END IF;
                    
                    IF squad_active = '1' THEN
                        -- Movement Pattern: Swoop down and right
                        squad_x <= squad_x + 4; -- Fast lateral
                        squad_y <= squad_y + 2; -- Slow descent
                        
                        -- Fire bullets (reuse triple shot if available)
                        IF (squad_x = CONV_STD_LOGIC_VECTOR(200, 11) OR squad_x = CONV_STD_LOGIC_VECTOR(400, 11) OR squad_x = CONV_STD_LOGIC_VECTOR(600, 11)) THEN
                             IF eb_C_active = '0' THEN
                                 eb_C_active <= '1';
                                 eb_C_x <= squad_x;
                                 eb_C_y <= squad_y;
                             END IF;
                        END IF;
                        
                        -- End of path
                        IF squad_x > 800 OR squad_y > 600 THEN
                            squad_active <= '0';
                        END IF;
                        
                        -- Collision for Squad Leader
                        IF squad_x >= player_x_pos - player_size AND squad_x <= player_x_pos + player_size AND
                           squad_y >= player_y - player_size AND squad_y <= player_y + player_size THEN
                            IF lives_count > 1 THEN
                                lives_count <= lives_count - 1;
                                squad_active <= '0';
                            ELSE
                                lives_count <= 0;
                                current_state <= GAMEOVER;
                            END IF;
                        END IF;
                        -- Collision for Wingman 1 (x-20, y-20)
                        IF (squad_x - 20) >= player_x_pos - player_size AND (squad_x - 20) <= player_x_pos + player_size AND
                           (squad_y - 20) >= player_y - player_size AND (squad_y - 20) <= player_y + player_size THEN
                            IF lives_count > 1 THEN
                                lives_count <= lives_count - 1;
                                squad_active <= '0';
                            ELSE
                                lives_count <= 0;
                                current_state <= GAMEOVER;
                            END IF;
                        END IF;
                         -- Collision for Wingman 2 (x-20, y+20)
                        IF (squad_x - 20) >= player_x_pos - player_size AND (squad_x - 20) <= player_x_pos + player_size AND
                           (squad_y + 20) >= player_y - player_size AND (squad_y + 20) <= player_y + player_size THEN
                            IF lives_count > 1 THEN
                                lives_count <= lives_count - 1;
                                squad_active <= '0';
                            ELSE
                                lives_count <= 0;
                                current_state <= GAMEOVER;
                            END IF;
                        END IF;
                    END IF;
                    
                    -- Move enemies
                    enemy_move_counter <= enemy_move_counter + 1;
                    IF enemy_move_counter = move_threshold THEN 
                        enemy_move_counter <= (OTHERS => '0');
                        
                        IF enemy_direction = '0' THEN -- moving right
                            IF enemy_x_pos + CONV_STD_LOGIC_VECTOR((NUM_ENEMY_COLS-1) * ENEMY_SPACING_X + enemy_size, 11) >= CONV_STD_LOGIC_VECTOR(780, 11) THEN
                                enemy_direction <= '1';
                                -- Breathing Logic
                                IF formation_move_dir = '0' THEN -- Moving Down
                                    enemy_y_offset <= enemy_y_offset + CONV_STD_LOGIC_VECTOR(10, 11);
                                    IF enemy_y_offset >= CONV_STD_LOGIC_VECTOR(100, 11) THEN
                                        formation_move_dir <= '1'; -- Switch to Up
                                    END IF;
                                ELSE -- Moving Up
                                    IF enemy_y_offset >= CONV_STD_LOGIC_VECTOR(10, 11) THEN
                                        enemy_y_offset <= enemy_y_offset - CONV_STD_LOGIC_VECTOR(10, 11);
                                    ELSE
                                        enemy_y_offset <= (OTHERS => '0');
                                        formation_move_dir <= '0'; -- Switch to Down
                                    END IF;
                                END IF;
                                
                                -- Check bottom
                                FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                                    FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                                        IF enemy_alive(row, col) = '1' THEN
                                            IF current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11) + enemy_size >= player_y - player_size THEN
                                                IF lives_count > 1 THEN
                                                    lives_count <= lives_count - 1;
                                                    current_state <= NEXT_WAVE;
                                                ELSE
                                                    lives_count <= 0;
                                                    current_state <= GAMEOVER;
                                                END IF;
                                            END IF;
                                        END IF;
                                    END LOOP;
                                END LOOP;
                            ELSE
                                enemy_x_pos <= enemy_x_pos + enemy_speed;
                            END IF;
                        ELSE -- moving left
                            IF enemy_x_pos <= CONV_STD_LOGIC_VECTOR(20, 11) THEN
                                enemy_direction <= '0';
                                -- Breathing Logic
                                IF formation_move_dir = '0' THEN -- Moving Down
                                    enemy_y_offset <= enemy_y_offset + CONV_STD_LOGIC_VECTOR(10, 11);
                                    IF enemy_y_offset >= CONV_STD_LOGIC_VECTOR(100, 11) THEN
                                        formation_move_dir <= '1'; -- Switch to Up
                                    END IF;
                                ELSE -- Moving Up
                                    IF enemy_y_offset >= CONV_STD_LOGIC_VECTOR(10, 11) THEN
                                        enemy_y_offset <= enemy_y_offset - CONV_STD_LOGIC_VECTOR(10, 11);
                                    ELSE
                                        enemy_y_offset <= (OTHERS => '0');
                                        formation_move_dir <= '0'; -- Switch to Down
                                    END IF;
                                END IF;
                                
                                -- Check bottom
                                FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                                    FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                                        IF enemy_alive(row, col) = '1' THEN
                                            IF current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11) + enemy_size >= player_y - player_size THEN
                                                IF lives_count > 1 THEN
                                                    lives_count <= lives_count - 1;
                                                    current_state <= NEXT_WAVE;
                                                ELSE
                                                    lives_count <= 0;
                                                    current_state <= GAMEOVER;
                                                END IF;
                                            END IF;
                                        END IF;
                                    END LOOP;
                                END LOOP;
                            ELSE
                                enemy_x_pos <= enemy_x_pos - enemy_speed;
                            END IF;
                        END IF;
                    END IF;
                    
                    -- Check bullet-enemy collisions
                    IF bullet_active = '1' THEN
                        collision_found := '0';
                        
                        -- Check Diver Collision
                        IF diver_active = '1' THEN
                            IF bullet_x >= diver_x - enemy_size AND
                               bullet_x <= diver_x + enemy_size AND
                               bullet_y >= diver_y - enemy_size AND
                               bullet_y <= diver_y + enemy_size THEN
                                diver_active <= '0';
                                enemy_alive(diver_row, diver_col) <= '0'; -- Kill the bee
                                enemy_is_diving(diver_row, diver_col) <= '0';
                                bullet_active <= '0';
                                bullet_y <= CONV_STD_LOGIC_VECTOR(600, 11);
                                score_i <= score_i + 50; -- Bonus for diver
                                hits_count <= hits_count + 1;
                                collision_found := '1';
                            END IF;
                        END IF;
                        
                        -- Check Formation Collision
                        FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                            FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                                IF enemy_alive(row, col) = '1' AND enemy_is_diving(row, col) = '0' AND collision_found = '0' THEN
                                    enemy_x := enemy_x_pos + CONV_STD_LOGIC_VECTOR(col * ENEMY_SPACING_X, 11);
                                    enemy_y := current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11);
                                    
                                    IF bullet_x >= enemy_x - enemy_size AND
                                       bullet_x <= enemy_x + enemy_size AND
                                       bullet_y >= enemy_y - enemy_size AND
                                       bullet_y <= enemy_y + enemy_size THEN
                                        enemy_alive(row, col) <= '0';
                                        bullet_active <= '0';
                                        bullet_y <= CONV_STD_LOGIC_VECTOR(600, 11);
                                        score_i <= score_i + 10;
                                        hits_count <= hits_count + 1;
                                        collision_found := '1';
                                    END IF;
                                END IF;
                            END LOOP;
                        END LOOP;
                    END IF;
                    
                    -- Check enemy-player collisions
                    collision_found := '0';
                    FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                        FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                            IF enemy_alive(row, col) = '1' AND collision_found = '0' THEN
                                enemy_x := enemy_x_pos + CONV_STD_LOGIC_VECTOR(col * ENEMY_SPACING_X, 11);
                                enemy_y := current_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11);
                                
                                IF player_x_pos >= enemy_x - enemy_size - player_size AND
                                   player_x_pos <= enemy_x + enemy_size + player_size AND
                                   player_y >= enemy_y - enemy_size AND
                                   player_y <= enemy_y + enemy_size THEN
                                    IF lives_count > 1 THEN
                                        lives_count <= lives_count - 1;
                                        diver_active <= '0';
                                        enemy_is_diving(diver_row, diver_col) <= '0'; -- Return to formation
                                        eb_L_active <= '0'; eb_C_active <= '0'; eb_R_active <= '0';
                                        bullet_active <= '0';
                                    ELSE
                                        lives_count <= 0;
                                        current_state <= GAMEOVER;
                                    END IF;
                                    collision_found := '1';
                                END IF;
                            END IF;
                        END LOOP;
                    END LOOP;
                    
                    -- Check if all enemies destroyed
                    enemies_remaining := 0;
                    FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                        FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                            IF enemy_alive(row, col) = '1' THEN
                                enemies_remaining := enemies_remaining + 1;
                            END IF;
                        END LOOP;
                    END LOOP;
                    
                    IF enemies_remaining = 0 THEN
                        wave_number <= wave_number + 1;
                        current_state <= NEXT_WAVE;
                    END IF;
                    
                WHEN GAMEOVER =>
                    -- Wait for a few seconds then go to results
                    game_over_timer := game_over_timer + 1;
                    IF game_over_timer > 180 THEN -- 3 seconds at 60Hz
                        game_over_timer := 0;
                        current_state <= RESULTS_SCREEN;
                    END IF;
                    
                WHEN RESULTS_SCREEN =>
                    -- Calculate Ratio once
                    IF shots_fired_count > 0 THEN
                         hit_miss_ratio <= (hits_count * 100) / shots_fired_count;
                    ELSE
                         hit_miss_ratio <= 0;
                    END IF;
                    -- Wait for reset
                    NULL;
            END CASE;
        END IF;
    END PROCESS;
END Behavioral;

