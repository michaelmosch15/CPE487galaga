LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY galaga IS
    PORT (
        clk_in : IN STD_LOGIC; -- system clock
        VGA_red : OUT STD_LOGIC_VECTOR (3 DOWNTO 0); -- VGA outputs
        VGA_green : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_blue : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_hsync : OUT STD_LOGIC;
        VGA_vsync : OUT STD_LOGIC;
        btnl : IN STD_LOGIC; -- move left
        btnr : IN STD_LOGIC; -- move right
        btn0 : IN STD_LOGIC; -- shoot
        SEG7_anode : OUT STD_LOGIC_VECTOR (7 DOWNTO 0); -- anodes of four 7-seg displays
        SEG7_seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0)
    ); 
END galaga;

ARCHITECTURE Behavioral OF galaga IS
    SIGNAL pxl_clk : STD_LOGIC := '0'; -- 25 MHz clock to VGA sync module
    -- internal signals to connect modules
    SIGNAL S_red, S_green, S_blue : STD_LOGIC;
    SIGNAL S_red_vec, S_green_vec, S_blue_vec : STD_LOGIC_VECTOR (3 DOWNTO 0);
    SIGNAL S_vsync : STD_LOGIC;
    SIGNAL S_pixel_row, S_pixel_col : STD_LOGIC_VECTOR (10 DOWNTO 0);
    SIGNAL player_pos : STD_LOGIC_VECTOR (10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(400, 11);
    SIGNAL count : STD_LOGIC_VECTOR (20 DOWNTO 0);
    SIGNAL display : STD_LOGIC_VECTOR (15 DOWNTO 0); -- value to be displayed
    SIGNAL led_mpx : STD_LOGIC_VECTOR (2 DOWNTO 0); -- 7-seg multiplexing clock
    SIGNAL shoot_signal : STD_LOGIC;
    SIGNAL shoot_prev : STD_LOGIC := '0';
    
    COMPONENT galaga_game IS
        PORT (
            v_sync : IN STD_LOGIC;
            pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            player_x : IN STD_LOGIC_VECTOR (10 DOWNTO 0);
            shoot : IN STD_LOGIC;
            red : OUT STD_LOGIC;
            green : OUT STD_LOGIC;
            blue : OUT STD_LOGIC;
            score : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            game_over : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT vga_sync IS
        PORT (
            pixel_clk : IN STD_LOGIC;
            red_in    : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            green_in  : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            blue_in   : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            red_out   : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            green_out : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            blue_out  : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            hsync : OUT STD_LOGIC;
            vsync : OUT STD_LOGIC;
            pixel_row : OUT STD_LOGIC_VECTOR (10 DOWNTO 0);
            pixel_col : OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
        );
    END COMPONENT;
    
    COMPONENT clk_wiz_0 IS
        PORT (
            clk_in1  : IN STD_LOGIC;
            clk_out1 : OUT STD_LOGIC
        );
    END COMPONENT;
    
    COMPONENT leddec16 IS
        PORT (
            dig : IN STD_LOGIC_VECTOR (2 DOWNTO 0);
            data : IN STD_LOGIC_VECTOR (15 DOWNTO 0);
            anode : OUT STD_LOGIC_VECTOR (7 DOWNTO 0);
            seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0)
        );
    END COMPONENT; 
    
BEGIN
    -- Player movement process
    player_movement : PROCESS (clk_in) IS
    BEGIN
        IF rising_edge(clk_in) THEN
            count <= count + 1;
            IF (btnl = '1' AND count = 0 AND player_pos > 20) THEN
                player_pos <= player_pos - 5;
            ELSIF (btnr = '1' AND count = 0 AND player_pos < 780) THEN
                player_pos <= player_pos + 5;
            END IF;
        END IF;
    END PROCESS;
    
    -- Shoot button edge detection
    shoot_detect : PROCESS (clk_in) IS
    BEGIN
        IF rising_edge(clk_in) THEN
            shoot_prev <= btn0;
            IF btn0 = '1' AND shoot_prev = '0' THEN
                shoot_signal <= '1';
            ELSE
                shoot_signal <= '0';
            END IF;
        END IF;
    END PROCESS;
    
    led_mpx <= count(19 DOWNTO 17); -- 7-seg multiplexing clock
    
    -- Convert single-bit color signals to 4-bit vectors
    S_red_vec <= S_red & "000";
    S_green_vec <= S_green & "000";
    S_blue_vec <= S_blue & "000";
    
    -- Instantiate galaga game component
    game_inst : galaga_game
    PORT MAP(
        v_sync => S_vsync, 
        pixel_row => S_pixel_row, 
        pixel_col => S_pixel_col, 
        player_x => player_pos, 
        shoot => shoot_signal, 
        red => S_red, 
        green => S_green, 
        blue => S_blue,
        score => display,
        game_over => OPEN
    );
    
    -- Instantiate VGA sync component
    vga_driver : vga_sync
    PORT MAP(
        pixel_clk => pxl_clk, 
        red_in => S_red_vec, 
        green_in => S_green_vec, 
        blue_in => S_blue_vec, 
        red_out => VGA_red, 
        green_out => VGA_green, 
        blue_out => VGA_blue, 
        pixel_row => S_pixel_row, 
        pixel_col => S_pixel_col, 
        hsync => VGA_hsync, 
        vsync => S_vsync
    );
    VGA_vsync <= S_vsync;
        
    -- Instantiate clock wizard
    clk_wiz_0_inst : clk_wiz_0
    PORT MAP (
        clk_in1 => clk_in,
        clk_out1 => pxl_clk
    );
    
    -- Instantiate 7-segment display
    led1 : leddec16
    PORT MAP(
        dig => led_mpx, 
        data => display, 
        anode => SEG7_anode, 
        seg => SEG7_seg
    );
END Behavioral;

