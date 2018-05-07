library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity digits is
   port (
      clk_i     : in  std_logic;

      pix_x_i   : in  std_logic_vector(9 downto 0);
      pix_y_i   : in  std_logic_vector(9 downto 0);
      digits_i  : in  std_logic_vector(7 downto 0);

      vga_hs_o  : out std_logic;
      vga_vs_o  : out std_logic;
      vga_col_o : out std_logic_vector(7 downto 0)
   );
end digits;

architecture Structural of digits is

   -- Define pixel counter range
   constant H_TOTAL  : integer := 800;
   constant V_TOTAL  : integer := 525;

   -- Define visible screen size
   constant H_PIXELS : integer := 640;
   constant V_PIXELS : integer := 480;

   -- Define VGA timing constants
   constant HS_START : integer := 656;
   constant HS_TIME  : integer := 96;
   constant VS_START : integer := 490;
   constant VS_TIME  : integer := 2;

   -- Each character is 16x16 pixels, so the screen contains 40x30 characters.

   -- Define positioning of first digit
   constant DIGITS_CHAR_X : integer := 10;
   constant DIGITS_CHAR_Y : integer := 15;

   -- A single character bitmap is defined by 8x8 = 64 bits.
   subtype bitmap_t is std_logic_vector(63 downto 0);

   -- The entire font is defined by an array bitmaps, one for each character.
   type bitmap_vector_t is array (natural range <>) of bitmap_t;

   -- Define bitmaps
   -- Taken from https://github.com/dhepper/font8x8/blob/master/font8x8_basic.h
   constant bitmaps : bitmap_vector_t := (
      -- Digit 0
      "01111100" &
      "11000110" &
      "11001110" &
      "11011110" &
      "11110110" &
      "11100110" &
      "01111100" &
      "00000000",

      -- Digit 1
      "00110000" &
      "01110000" &
      "00110000" &
      "00110000" &
      "00110000" &
      "00110000" &
      "11111100" &
      "00000000");

   -- Define colours
   constant COL_BLACK : std_logic_vector(7 downto 0) := B"000_000_00";
   constant COL_DARK  : std_logic_vector(7 downto 0) := B"001_001_01";
   constant COL_GREY  : std_logic_vector(7 downto 0) := B"010_010_01";
   constant COL_WHITE : std_logic_vector(7 downto 0) := B"111_111_11";
   constant COL_RED   : std_logic_vector(7 downto 0) := B"111_000_00";
   constant COL_GREEN : std_logic_vector(7 downto 0) := B"000_111_00";
   constant COL_BLUE  : std_logic_vector(7 downto 0) := B"000_000_11";


   -- Character coordinates
   signal char_col : integer range 0 to H_TOTAL/16-1;
   signal char_row : integer range 0 to V_TOTAL/16-1;

   -- Value of digit at current position
   signal digits_offset : integer range 0 to 7;
   signal digits_index  : integer range 0 to 7;
   signal digit         : std_logic;

   -- Bitmap of digit at current position
   signal bitmaps_index : integer range 0 to 1;
   signal bitmap        : bitmap_t;

   -- Pixel at current position
   signal pix_col       : integer range 0 to 7;
   signal pix_row       : integer range 0 to 7;
   signal bitmap_index  : integer range 0 to 63;
   signal pix           : std_logic;

   -- Pixel colour
   signal vga_col : std_logic_vector(7 downto 0);

   -- Synchronization
   signal vga_hs  : std_logic;
   signal vga_vs  : std_logic;

begin

   --------------------------------------------------
   -- Calculate character coordinates, within 40x30
   --------------------------------------------------

   char_col <= conv_integer(pix_x_i(9 downto 4));
   char_row <= conv_integer(pix_y_i(9 downto 4));

   --------------------------------------------------
   -- Calculate value of digit at current position ('0' or '1')
   --------------------------------------------------

   digits_offset <= char_col - DIGITS_CHAR_X;
   digits_index  <= 7 - digits_offset;
   digit         <= digits_i(digits_index);

   --------------------------------------------------
   -- Calculate bitmap (64 bits) of digit at current position
   --------------------------------------------------

   bitmaps_index <= conv_integer((0 => digit));
   bitmap        <= bitmaps(bitmaps_index);

   --------------------------------------------------
   -- Calculate pixel at current position ('0' or '1')
   --------------------------------------------------

   pix_col       <= 7 - conv_integer(pix_x_i(3 downto 1));
   pix_row       <= 7 - conv_integer(pix_y_i(3 downto 1));
   bitmap_index  <= pix_row*8 + pix_col;
   pix           <= bitmap(bitmap_index);


   --------------------------------------------------
   -- Generate pixel colour
   --------------------------------------------------

   p_vga_col : process (clk_i)
   begin
      if rising_edge(clk_i) then

         -- Set the default screen background colour
         vga_col <= COL_GREY;

         -- Are we within the borders of the text?
         if char_row = DIGITS_CHAR_Y and
            char_col >= DIGITS_CHAR_X and char_col < DIGITS_CHAR_X+8 then

            if pix = '1' then
               vga_col <= COL_WHITE;
            else
               vga_col <= COL_DARK; -- Text background colour.
            end if;
         end if;

         -- Make sure colour is black outside visible screen
         if pix_x_i >= H_PIXELS or pix_y_i >= V_PIXELS then
            vga_col <= COL_BLACK;
         end if;

      end if;
   end process p_vga_col;


   --------------------------------------------------
   -- Generate horizontal and vertical sync signals
   --------------------------------------------------

   p_vga_hs : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_x_i >= HS_START and pix_x_i < HS_START+HS_TIME then
            vga_hs <= '0';
         else
            vga_hs <= '1';
         end if;
      end if;
   end process p_vga_hs;

   p_vga_vs : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if pix_y_i >= VS_START and pix_y_i < VS_START+VS_TIME then
            vga_vs <= '0';
         else
            vga_vs <= '1';
         end if;
      end if;
   end process p_vga_vs;


   --------------------------------------------------
   -- Drive output signals
   --------------------------------------------------

   vga_col_o <= vga_col;
   vga_hs_o  <= vga_hs;
   vga_vs_o  <= vga_vs;

end architecture Structural;
