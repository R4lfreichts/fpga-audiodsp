library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fx_soft_clipping is
    generic (
        d_width    : integer := 24;
        clip_shift : integer := 2
    );
    port (
        clk         : in  std_logic;
        reset_n     : in  std_logic;
        sample_tick : in  std_logic;
        l_in        : in  std_logic_vector(d_width-1 downto 0);
        r_in        : in  std_logic_vector(d_width-1 downto 0);
        l_out       : out std_logic_vector(d_width-1 downto 0);
        r_out       : out std_logic_vector(d_width-1 downto 0)
    );
end entity fx_soft_clipping;

architecture rtl of fx_soft_clipping is

    function soft_clip_sample(
        x         : signed;
        shift_val : integer;
        out_width : positive
    ) return signed is
        variable x_ext      : signed(out_width downto 0);
        variable mag        : signed(out_width downto 0);
        variable y_mag      : signed(out_width downto 0);
        variable threshold  : signed(out_width downto 0);
        variable limit_2t   : signed(out_width downto 0);
        variable shift_eff  : integer;
        variable y          : signed(out_width-1 downto 0);
    begin
        -- Keep threshold in a sane range.
        -- shift=1 means about 50% full scale.
        if shift_val < 1 then
            shift_eff := 1;
        elsif shift_val > out_width - 2 then
            shift_eff := out_width - 2;
        else
            shift_eff := shift_val;
        end if;

        x_ext := resize(x, out_width + 1);

        if x_ext < 0 then
            mag := -x_ext;
        else
            mag := x_ext;
        end if;

        threshold := to_signed((2**(out_width - 1 - shift_eff)) - 1, out_width + 1);
        limit_2t  := shift_left(threshold, 1);

        if mag <= threshold then
            y_mag := mag;
        elsif mag <= limit_2t then
            -- Compressed knee region, slope 0.5
            y_mag := threshold + shift_right(mag - threshold, 1);
        else
            -- Gentle saturation
            y_mag := threshold + shift_right(threshold, 1);
        end if;

        if x_ext < 0 then
            y := resize(-y_mag, out_width);
        else
            y := resize(y_mag, out_width);
        end if;

        return y;
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
                l_tmp := soft_clip_sample(signed(l_in), clip_shift, d_width);
                r_tmp := soft_clip_sample(signed(r_in), clip_shift, d_width);

                l_reg <= std_logic_vector(l_tmp);
                r_reg <= std_logic_vector(r_tmp);
            end if;
        end if;
    end process;

    l_out <= l_reg;
    r_out <= r_reg;

end architecture rtl;