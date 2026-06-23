library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fx_gain is
    generic (
        d_width : integer := 24
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        sample_tick : in  std_logic;
        gain_shift  : in  integer range -3 to 3;
        l_in        : in  std_logic_vector(d_width-1 downto 0);
        r_in        : in  std_logic_vector(d_width-1 downto 0);
        l_out       : out std_logic_vector(d_width-1 downto 0);
        r_out       : out std_logic_vector(d_width-1 downto 0)
    );
end entity;

architecture rtl of fx_gain is

    function sat_resize(x : signed; out_width : positive) return signed is
        variable y     : signed(out_width-1 downto 0);
        variable xmax  : signed(x'length-1 downto 0);
        variable xmin  : signed(x'length-1 downto 0);
    begin
        xmax := to_signed((2**(out_width-1)) - 1, x'length);
        xmin := to_signed(-(2**(out_width-1)),    x'length);

        if x > xmax then
            y := to_signed((2**(out_width-1)) - 1, out_width);
        elsif x < xmin then
            y := to_signed(-(2**(out_width-1)), out_width);
        else
            y := resize(x, out_width);
        end if;

        return y;
    end function;

    function apply_gain(x : signed; shift_val : integer; out_width : positive) return signed is
        variable x_ext : signed(x'length + 8 - 1 downto 0);
        variable y_ext : signed(x'length + 8 - 1 downto 0);
    begin
        x_ext := resize(x, x'length + 8);

        if shift_val > 0 then
            y_ext := shift_left(x_ext, shift_val);
        elsif shift_val < 0 then
            y_ext := shift_right(x_ext, -shift_val);
        else
            y_ext := x_ext;
        end if;

        return sat_resize(y_ext, out_width);
    end function;

    signal l_reg : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal r_reg : std_logic_vector(d_width-1 downto 0) := (others => '0');

begin

    process(clk)
        variable l_tmp : signed(d_width-1 downto 0);
        variable r_tmp : signed(d_width-1 downto 0);
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                l_reg <= (others => '0');
                r_reg <= (others => '0');
            elsif sample_tick = '1' then
                l_tmp := apply_gain(signed(l_in), gain_shift, d_width);
                r_tmp := apply_gain(signed(r_in), gain_shift, d_width);

                l_reg <= std_logic_vector(l_tmp);
                r_reg <= std_logic_vector(r_tmp);
            end if;
        end if;
    end process;

    l_out <= l_reg;
    r_out <= r_reg;

end architecture rtl;