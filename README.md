# Final Project: Video Game Galaga

* This project implements a simplified version of the classic arcade game **Galaga** on the Digilent Nexys A7-100T FPGA board using VHDL.
  * The project utilizes the VGA interface to display the game state on a monitor

## Project Description & Behavior

The **Galaga** game consists of a player-controlled ship, a formation of enemy ships, and projectiles.

*   **Player Ship:** Represented by a triangle at the bottom of the screen.
    *   **Movement:** Controlled by `BTNL` (Left) and `BTNR` (Right).
    *   **Shooting:** `BTN0` fires a projectile upwards.
*   **Enemies:** A grid (5 rows x 8 columns) of red blocks starting at the top.
    *   **Movement:** The formation moves horizontally until it hits the screen edge, then drops down and reverses direction.
*   **Game Logic (`galaga_game.vhd`):**
    *   **Collision Detection:**
        *   **Bullet vs Enemy:** If a bullet intersects with an enemy's coordinates, the enemy is disabled (disappears), the bullet resets, and the score increases by 10.
        *   **Enemy vs Player:** If an enemy touches the player, the game ends.
        *   **Enemy vs Bottom:** If the enemy formation reaches the player's vertical level, the game ends.
    *   **Score:** The current score is output to the 7-segment display.
    *   **Win Condition:** If all enemies are destroyed, the level resets (enemies respawn).

### System Block Diagram

The system is composed of several VHDL modules working together:

`mermaid
graph TD
    Input[Buttons & Clock] --> Top[galaga.vhd (Top Level)]
    Top --> ClockWiz[clk_wiz_0 (100MHz -> 25MHz)]
    Top --> GameLogic[galaga_game.vhd (Game State & Physics)]
    Top --> VGA[vga_sync.vhd (VGA Timing)]
    Top --> SevenSeg[leddec16.vhd (Score Display)]
    
    GameLogic -- RGB Signals --> Top
    GameLogic -- Score --> Top
    ClockWiz -- Pixel Clock --> VGA
    VGA -- Sync Signals --> Top
` 

*   **_galaga_game_**: The core logic engine. It maintains the state of the player, all 40 enemies, and the bullet. It calculates positions based on the frame refresh (Vsync) and handles all collision logic.
*   **_vga_sync_**: Generates the standard VGA timing signals (HSync, VSync) and pixel coordinates (Row, Col) for an 800x600 resolution.
*   **_galaga_**: The top-level wrapper that connects the physical inputs (Buttons, Clock) to the internal modules and maps the outputs to the VGA port and 7-segment display.

## Required Hardware
*   Digilent Nexys A7-100T FPGA Board
*   VGA Monitor
*   VGA Cable (or HDMI with active VGA adapter)
*   Micro-USB cable for programming/power

## Instructions to Run the Project

### 1. Create a new RTL project _galaga_ in Vivado

*   Create six source files of file type VHDL:
    *   **_clk_wiz_0.vhd_** & **_clk_wiz_0_clk_wiz.vhd_**: Clock generation (same as Lab 3).
    *   **_leddec16.vhd_**: 7-segment decoder (same as Lab 5).
    *   **_vga_sync.vhd_**: VGA timing generator.
    *   **_galaga_game.vhd_**: The main game logic and rendering.
    *   **_galaga.vhd_**: The top-level module.

*   Create a new constraint file of file type XDC called **_galaga.xdc_**.

*   Select the **Nexys A7-100T** board when prompted.

*   Copy the provided VHDL code into the respective source files and the constraints into `galaga.xdc`.

### 2. Run Synthesis and Implementation

*   Click **Run Synthesis** in the Flow Navigator.
*   Once complete, click **Run Implementation**.

### 3. Generate Bitstream and Program Device

*   Click **Generate Bitstream**.
*   Connect your Nexys A7 board via USB and turn it on.
*   Open **Hardware Manager** -> **Open Target** -> **Auto Connect**.
*   Click **Program Device** and select the generated `.bit` file.

### 4. How to Play

1.  **Start:** The game starts immediately upon programming.
2.  **Move:** Use **BTNL** to move Left and **BTNR** to move Right.
3.  **Fire:** Press **BTN0** (Center Button) to shoot.
4.  **Goal:** Destroy all red enemy blocks before they touch you or reach the bottom of the screen.
5.  **Score:** Watch your score increase on the 7-segment display!
