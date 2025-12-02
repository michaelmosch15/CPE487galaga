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
        game_over : OUT STD_LOGIC -- game over indicator
    );
END galaga_game;

ARCHITECTURE Behavioral OF galaga_game IS
    -- Constants
    CONSTANT player_size : INTEGER := 8; -- player ship size
    CONSTANT enemy_size : INTEGER := 6; -- enemy ship size
    CONSTANT bullet_size : INTEGER := 2; -- bullet size
    CONSTANT player_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(550, 11); -- player y position (bottom)
    CONSTANT enemy_start_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(50, 11); -- top enemy row
    CONSTANT bullet_speed : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(8, 11); -- bullet speed
    CONSTANT enemy_speed : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(2, 11); -- enemy movement speed
    CONSTANT enemy_bullet_speed : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(4, 11); -- enemy bullet speed
    
    -- Enemy formation: 5 rows x 8 columns
    CONSTANT NUM_ENEMY_ROWS : INTEGER := 5;
    CONSTANT NUM_ENEMY_COLS : INTEGER := 8;
    CONSTANT ENEMY_SPACING_X : INTEGER := 80;
    CONSTANT ENEMY_SPACING_Y : INTEGER := 50;
    
    -- Signals
    SIGNAL player_on : STD_LOGIC;
    SIGNAL enemy_on : STD_LOGIC;
    SIGNAL bullet_on : STD_LOGIC;
    SIGNAL enemy_bullet_on : STD_LOGIC;
    SIGNAL game_active : STD_LOGIC := '1';
    
    -- Game State
    TYPE game_state_type IS (START, PLAY, GAMEOVER, NEXT_WAVE);
    SIGNAL current_state : game_state_type := START;
    SIGNAL wave_number : INTEGER RANGE 1 TO 3 := 1;
    SIGNAL shoot_delay : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(60, 11);
    
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
    SIGNAL random_col : STD_LOGIC_VECTOR(2 DOWNTO 0) := "000";
    
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
    
    -- Enemy positions and states
    TYPE enemy_array IS ARRAY(0 TO NUM_ENEMY_ROWS-1, 0 TO NUM_ENEMY_COLS-1) OF STD_LOGIC;
    SIGNAL enemy_alive : enemy_array := (OTHERS => (OTHERS => '1'));
    SIGNAL enemy_is_diving : enemy_array := (OTHERS => (OTHERS => '0'));
    SIGNAL enemy_x_pos : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(100, 11);
    SIGNAL enemy_y_offset : STD_LOGIC_VECTOR(10 DOWNTO 0) := (OTHERS => '0'); -- vertical offset for moving down
    SIGNAL enemy_direction : STD_LOGIC := '0'; -- 0 = right, 1 = left
    SIGNAL enemy_move_counter : STD_LOGIC_VECTOR(20 DOWNTO 0) := (OTHERS => '0');
    
    -- Score
    SIGNAL score_i : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    
    -- Collision detection signals
    SIGNAL bullet_enemy_collision : STD_LOGIC := '0';
    SIGNAL enemy_player_collision : STD_LOGIC := '0';
    
BEGIN
    red <= NOT (player_on OR bullet_on);
    green <= NOT (enemy_on OR enemy_bullet_on OR diver_active OR eb_L_active OR eb_C_active OR eb_R_active);
    blue <= NOT (player_on OR enemy_on OR bullet_on OR enemy_bullet_on OR diver_active OR eb_L_active OR eb_C_active OR eb_R_active);
    score <= score_i;
    game_over <= '1' WHEN current_state = GAMEOVER ELSE '0';
    
    -- Process to draw player ship (triangle shape)
    player_draw : PROCESS (player_x_pos, pixel_row, pixel_col) IS
        VARIABLE dx, dy : STD_LOGIC_VECTOR(10 DOWNTO 0);
    BEGIN
        IF pixel_col >= player_x_pos - player_size AND
           pixel_col <= player_x_pos + player_size AND
           pixel_row >= player_y - player_size AND
           pixel_row <= player_y THEN
            dx := pixel_col - player_x_pos;
            IF dx(10) = '1' THEN
                dx := (NOT dx) + 1; -- absolute value
            END IF;
            dy := player_y - pixel_row;
            -- Draw triangle shape
            IF dy > dx THEN
                player_on <= game_active;
            ELSE
                player_on <= '0';
            END IF;
        ELSE
            player_on <= '0';
        END IF;
    END PROCESS;
    
    -- Process to draw enemies
    enemy_draw : PROCESS (enemy_x_pos, pixel_row, pixel_col, enemy_alive, enemy_is_diving, diver_active, diver_x, diver_y) IS
        VARIABLE enemy_x, enemy_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE found : STD_LOGIC := '0';
    BEGIN
        found := '0';
        enemy_on <= '0';
        
        -- Draw Formation
        FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
            FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                IF enemy_alive(row, col) = '1' AND enemy_is_diving(row, col) = '0' THEN
                    enemy_x := enemy_x_pos + CONV_STD_LOGIC_VECTOR(col * ENEMY_SPACING_X, 11);
                    enemy_y := enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11);
                    
                    IF pixel_col >= enemy_x - enemy_size AND
                       pixel_col <= enemy_x + enemy_size AND
                       pixel_row >= enemy_y - enemy_size AND
                       pixel_row <= enemy_y + enemy_size THEN
                        found := '1';
                    END IF;
                END IF;
            END LOOP;
        END LOOP;
        
        -- Draw Diver
        IF diver_active = '1' THEN
            IF pixel_col >= diver_x - enemy_size AND
               pixel_col <= diver_x + enemy_size AND
               pixel_row >= diver_y - enemy_size AND
               pixel_row <= diver_y + enemy_size THEN
                found := '1';
            END IF;
        END IF;
        
        IF found = '1' THEN
            enemy_on <= game_active;
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

    -- Process to draw enemy bullet (Triple Shot)
    enemy_bullet_draw : PROCESS (eb_L_x, eb_L_y, eb_L_active, eb_C_x, eb_C_y, eb_C_active, eb_R_x, eb_R_y, eb_R_active, pixel_row, pixel_col) IS
        VARIABLE dx, dy : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE found : STD_LOGIC := '0';
    BEGIN
        found := '0';
        
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

    
    -- Main game logic process
    game_logic : PROCESS
        VARIABLE temp : STD_LOGIC_VECTOR(11 DOWNTO 0);
        VARIABLE enemy_x, enemy_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE enemies_remaining : INTEGER;
        VARIABLE collision_found : STD_LOGIC;
    BEGIN
        WAIT UNTIL rising_edge(v_sync);
        
        IF reset = '1' THEN
            current_state <= START;
        ELSE
            CASE current_state IS
                WHEN START =>
                    score_i <= (OTHERS => '0');
                    wave_number <= 1;
                    current_state <= NEXT_WAVE;
                    
                WHEN NEXT_WAVE =>
                    -- Reset positions
                    enemy_x_pos <= CONV_STD_LOGIC_VECTOR(100, 11);
                    enemy_y_offset <= (OTHERS => '0');
                    enemy_direction <= '0';
                    bullet_active <= '0';
                    diver_active <= '0';
                    eb_L_active <= '0';
                    eb_C_active <= '0';
                    eb_R_active <= '0';
                    enemy_is_diving <= (OTHERS => (OTHERS => '0'));
                    
                    -- Set difficulty
                    CASE wave_number IS
                        WHEN 1 => shoot_delay <= CONV_STD_LOGIC_VECTOR(60, 11);
                        WHEN 2 => shoot_delay <= CONV_STD_LOGIC_VECTOR(45, 11);
                        WHEN 3 => shoot_delay <= CONV_STD_LOGIC_VECTOR(30, 11);
                        WHEN OTHERS => shoot_delay <= CONV_STD_LOGIC_VECTOR(20, 11);
                    END CASE;
                    
                    -- Set Formation
                    FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                        FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                            IF wave_number = 1 THEN
                                enemy_alive(row, col) <= '1'; -- Full block
                            ELSIF wave_number = 2 THEN
                                IF (row + col) MOD 2 = 0 THEN -- Checkerboard
                                    enemy_alive(row, col) <= '1';
                                ELSE
                                    enemy_alive(row, col) <= '0';
                                END IF;
                            ELSE -- Wave 3 (V-Shapeish)
                                IF row = 0 OR row = 1 THEN
                                    enemy_alive(row, col) <= '1';
                                ELSIF row = 2 AND (col > 1 AND col < 6) THEN
                                    enemy_alive(row, col) <= '1';
                                ELSIF row = 3 AND (col > 2 AND col < 5) THEN
                                    enemy_alive(row, col) <= '1';
                                ELSE
                                    enemy_alive(row, col) <= '0';
                                END IF;
                            END IF;
                        END LOOP;
                    END LOOP;
                    
                    current_state <= PLAY;
                    
                WHEN PLAY =>
                    -- Update player position
                    player_x_pos <= player_x;
                    
                    -- Handle shooting
                    IF shoot = '1' AND shoot_prev = '0' AND bullet_active = '0' THEN
                        bullet_active <= '1';
                        bullet_x <= player_x_pos;
                        bullet_y <= player_y - CONV_STD_LOGIC_VECTOR(player_size, 11);
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
                    IF diver_active = '0' AND diver_timer > shoot_delay + 100 THEN
                        diver_timer <= (OTHERS => '0');
                        -- Try to find a Bee (Row 4) to dive
                        IF enemy_alive(4, CONV_INTEGER(random_col)) = '1' AND enemy_is_diving(4, CONV_INTEGER(random_col)) = '0' THEN
                            diver_active <= '1';
                            diver_row <= 4;
                            diver_col <= CONV_INTEGER(random_col);
                            enemy_is_diving(4, CONV_INTEGER(random_col)) <= '1';
                            
                            -- Set initial position
                            diver_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                            diver_y <= enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(4 * ENEMY_SPACING_Y, 11);
                            diver_shot_fired <= '0';
                        END IF;
                    END IF;
                    
                    -- Move Diver
                    IF diver_active = '1' THEN
                        diver_y <= diver_y + enemy_bullet_speed; -- Dive speed same as bullet for now
                        
                        -- Homing X (Simple)
                        IF diver_x < player_x_pos THEN
                            diver_x <= diver_x + 1;
                        ELSIF diver_x > player_x_pos THEN
                            diver_x <= diver_x - 1;
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
                            current_state <= GAMEOVER;
                        END IF;
                    END IF;
                    
                    -- Move Triple Bullets
                    IF eb_C_active = '1' THEN
                        eb_C_y <= eb_C_y + enemy_bullet_speed;
                        IF eb_C_y > 600 THEN eb_C_active <= '0'; END IF;
                        -- Collision
                        IF eb_C_x >= player_x_pos - player_size AND eb_C_x <= player_x_pos + player_size AND
                           eb_C_y >= player_y - player_size AND eb_C_y <= player_y + player_size THEN
                            current_state <= GAMEOVER;
                        END IF;
                    END IF;
                    
                    IF eb_L_active = '1' THEN
                        eb_L_y <= eb_L_y + enemy_bullet_speed;
                        eb_L_x <= eb_L_x - 2; -- 45 deg left approx
                        IF eb_L_y > 600 THEN eb_L_active <= '0'; END IF;
                        -- Collision
                        IF eb_L_x >= player_x_pos - player_size AND eb_L_x <= player_x_pos + player_size AND
                           eb_L_y >= player_y - player_size AND eb_L_y <= player_y + player_size THEN
                            current_state <= GAMEOVER;
                        END IF;
                    END IF;
                    
                    IF eb_R_active = '1' THEN
                        eb_R_y <= eb_R_y + enemy_bullet_speed;
                        eb_R_x <= eb_R_x + 2; -- 45 deg right approx
                        IF eb_R_y > 600 THEN eb_R_active <= '0'; END IF;
                        -- Collision
                        IF eb_R_x >= player_x_pos - player_size AND eb_R_x <= player_x_pos + player_size AND
                           eb_R_y >= player_y - player_size AND eb_R_y <= player_y + player_size THEN
                            current_state <= GAMEOVER;
                        END IF;
                    END IF;
                    
                    -- Move enemies
                    enemy_move_counter <= enemy_move_counter + 1;
                    IF enemy_move_counter = CONV_STD_LOGIC_VECTOR(5, 21) THEN 
                        enemy_move_counter <= (OTHERS => '0');
                        
                        IF enemy_direction = '0' THEN -- moving right
                            IF enemy_x_pos + CONV_STD_LOGIC_VECTOR((NUM_ENEMY_COLS-1) * ENEMY_SPACING_X + enemy_size, 11) >= CONV_STD_LOGIC_VECTOR(780, 11) THEN
                                enemy_direction <= '1';
                                enemy_y_offset <= enemy_y_offset + CONV_STD_LOGIC_VECTOR(10, 11);
                                -- Check bottom
                                FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                                    FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                                        IF enemy_alive(row, col) = '1' THEN
                                            IF enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11) + enemy_size >= player_y - player_size THEN
                                                current_state <= GAMEOVER;
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
                                enemy_y_offset <= enemy_y_offset + CONV_STD_LOGIC_VECTOR(10, 11);
                                -- Check bottom
                                FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                                    FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                                        IF enemy_alive(row, col) = '1' THEN
                                            IF enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11) + enemy_size >= player_y - player_size THEN
                                                current_state <= GAMEOVER;
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
                                collision_found := '1';
                            END IF;
                        END IF;
                        
                        -- Check Formation Collision
                        FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                            FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                                IF enemy_alive(row, col) = '1' AND enemy_is_diving(row, col) = '0' AND collision_found = '0' THEN
                                    enemy_x := enemy_x_pos + CONV_STD_LOGIC_VECTOR(col * ENEMY_SPACING_X, 11);
                                    enemy_y := enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11);
                                    
                                    IF bullet_x >= enemy_x - enemy_size AND
                                       bullet_x <= enemy_x + enemy_size AND
                                       bullet_y >= enemy_y - enemy_size AND
                                       bullet_y <= enemy_y + enemy_size THEN
                                        enemy_alive(row, col) <= '0';
                                        bullet_active <= '0';
                                        bullet_y <= CONV_STD_LOGIC_VECTOR(600, 11);
                                        score_i <= score_i + 10;
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
                                enemy_y := enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11);
                                
                                IF player_x_pos >= enemy_x - enemy_size - player_size AND
                                   player_x_pos <= enemy_x + enemy_size + player_size AND
                                   player_y >= enemy_y - enemy_size AND
                                   player_y <= enemy_y + enemy_size THEN
                                    current_state <= GAMEOVER;
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
                        IF wave_number < 3 THEN
                            wave_number <= wave_number + 1;
                        END IF;
                        current_state <= NEXT_WAVE;
                    END IF;
                    
                WHEN GAMEOVER =>
                    -- Wait for reset
                    NULL;
            END CASE;
        END IF;
    END PROCESS;
END Behavioral;

