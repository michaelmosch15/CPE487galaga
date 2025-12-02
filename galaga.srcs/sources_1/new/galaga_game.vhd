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
    
    -- Enemy positions and states
    TYPE enemy_array IS ARRAY(0 TO NUM_ENEMY_ROWS-1, 0 TO NUM_ENEMY_COLS-1) OF STD_LOGIC;
    SIGNAL enemy_alive : enemy_array := (OTHERS => (OTHERS => '1'));
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
    green <= NOT (enemy_on OR enemy_bullet_on);
    blue <= NOT (player_on OR enemy_on OR bullet_on OR enemy_bullet_on);
    score <= score_i;
    game_over <= NOT game_active;
    
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
    enemy_draw : PROCESS (enemy_x_pos, pixel_row, pixel_col, enemy_alive) IS
        VARIABLE enemy_x, enemy_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE found : STD_LOGIC := '0';
    BEGIN
        found := '0';
        enemy_on <= '0';
        
        FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
            FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                IF enemy_alive(row, col) = '1' THEN
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

    -- Process to draw enemy bullet
    enemy_bullet_draw : PROCESS (enemy_bullet_x, enemy_bullet_y, pixel_row, pixel_col, enemy_bullet_active) IS
        VARIABLE dx, dy : STD_LOGIC_VECTOR(10 DOWNTO 0);
    BEGIN
        IF enemy_bullet_active = '1' THEN
            IF pixel_col >= enemy_bullet_x - bullet_size AND
               pixel_col <= enemy_bullet_x + bullet_size AND
               pixel_row >= enemy_bullet_y - bullet_size AND
               pixel_row <= enemy_bullet_y + bullet_size THEN
                dx := pixel_col - enemy_bullet_x;
                IF dx(10) = '1' THEN
                    dx := (NOT dx) + 1;
                END IF;
                dy := pixel_row - enemy_bullet_y;
                IF dy(10) = '1' THEN
                    dy := (NOT dy) + 1;
                END IF;
                IF (dx * dx + dy * dy) < (bullet_size * bullet_size) THEN
                    enemy_bullet_on <= '1';
                ELSE
                    enemy_bullet_on <= '0';
                END IF;
            ELSE
                enemy_bullet_on <= '0';
            END IF;
        ELSE
            enemy_bullet_on <= '0';
        END IF;
    END PROCESS;

    
    -- Main game logic process
    game_logic : PROCESS
        VARIABLE temp : STD_LOGIC_VECTOR(11 DOWNTO 0);
        VARIABLE enemy_x, enemy_y : STD_LOGIC_VECTOR(10 DOWNTO 0);
        VARIABLE enemies_remaining : INTEGER;
        VARIABLE collision_found : STD_LOGIC;
    BEGIN
        WAIT UNTIL rising_edge(v_sync);
        
        IF game_active = '1' THEN
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
            
            -- Handle Enemy Shooting
            random_col <= random_col + 1; -- Simple counter for randomness
            enemy_shoot_timer <= enemy_shoot_timer + 1;
            
            IF enemy_bullet_active = '0' AND enemy_shoot_timer > CONV_STD_LOGIC_VECTOR(60, 11) THEN -- Shoot roughly once per second
                enemy_shoot_timer <= (OTHERS => '0');
                -- Try to find an enemy in the random column to shoot
                FOR row IN NUM_ENEMY_ROWS-1 DOWNTO 0 LOOP
                    IF enemy_alive(row, CONV_INTEGER(random_col)) = '1' THEN
                        enemy_bullet_active <= '1';
                        enemy_bullet_x <= enemy_x_pos + CONV_STD_LOGIC_VECTOR(CONV_INTEGER(random_col) * ENEMY_SPACING_X, 11);
                        enemy_bullet_y <= enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11) + enemy_size;
                        EXIT; -- Only one bullet
                    END IF;
                END LOOP;
            END IF;
            
            -- Move Enemy Bullet
            IF enemy_bullet_active = '1' THEN
                IF enemy_bullet_y > CONV_STD_LOGIC_VECTOR(600, 11) THEN
                    enemy_bullet_active <= '0';
                ELSE
                    enemy_bullet_y <= enemy_bullet_y + enemy_bullet_speed;
                END IF;
                
                -- Check collision with player
                IF enemy_bullet_x >= player_x_pos - player_size AND
                   enemy_bullet_x <= player_x_pos + player_size AND
                   enemy_bullet_y >= player_y - player_size AND
                   enemy_bullet_y <= player_y + player_size THEN
                    game_active <= '0';
                END IF;
            END IF;
            
            -- Move enemies (side to side, then down)
            enemy_move_counter <= enemy_move_counter + 1;
            IF enemy_move_counter = CONV_STD_LOGIC_VECTOR(5, 21) THEN -- Faster movement (every 5 frames)
                enemy_move_counter <= (OTHERS => '0');
                
                -- Check if enemies hit edge
                IF enemy_direction = '0' THEN -- moving right
                    IF enemy_x_pos + CONV_STD_LOGIC_VECTOR((NUM_ENEMY_COLS-1) * ENEMY_SPACING_X + enemy_size, 11) >= CONV_STD_LOGIC_VECTOR(780, 11) THEN
                        enemy_direction <= '1';
                        -- Move down
                        enemy_y_offset <= enemy_y_offset + CONV_STD_LOGIC_VECTOR(10, 11);
                        -- Check if enemy reached bottom
                        FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                            FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                                IF enemy_alive(row, col) = '1' THEN
                                    IF enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11) + enemy_size >= player_y - player_size THEN
                                        game_active <= '0'; -- game over
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
                        -- Move down
                        enemy_y_offset <= enemy_y_offset + CONV_STD_LOGIC_VECTOR(10, 11);
                        -- Check if enemy reached bottom
                        FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                            FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                                IF enemy_alive(row, col) = '1' THEN
                                    IF enemy_start_y + enemy_y_offset + CONV_STD_LOGIC_VECTOR(row * ENEMY_SPACING_Y, 11) + enemy_size >= player_y - player_size THEN
                                        game_active <= '0';
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
                FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                    FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                        IF enemy_alive(row, col) = '1' AND collision_found = '0' THEN
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
                            game_active <= '0';
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
                -- Level complete - reset enemies
                FOR row IN 0 TO NUM_ENEMY_ROWS-1 LOOP
                    FOR col IN 0 TO NUM_ENEMY_COLS-1 LOOP
                        enemy_alive(row, col) <= '1';
                    END LOOP;
                END LOOP;
                enemy_x_pos <= CONV_STD_LOGIC_VECTOR(100, 11);
                enemy_y_offset <= (OTHERS => '0');
                enemy_direction <= '0';
            END IF;
        END IF;
    END PROCESS;
END Behavioral;

