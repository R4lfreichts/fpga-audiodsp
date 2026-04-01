library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_audio_stream_consumer is
end entity;

architecture sim of tb_audio_stream_consumer is

    constant d_width : integer := 24;

    signal clk           : std_logic := '0';
    signal reset_n       : std_logic := '0';

    signal s_axis_tdata  : std_logic_vector(63 downto 0) := (others => '0');
    signal s_axis_tvalid : std_logic := '0';
    signal s_axis_tready : std_logic;

    signal ws            : std_logic := '0';

    signal l_data_tx     : std_logic_vector(d_width-1 downto 0);
    signal r_data_tx     : std_logic_vector(d_width-1 downto 0);
    signal underrun      : std_logic;

begin

    uut : entity work.audio_stream_consumer
        generic map (
            d_width => d_width
        )
        port map (
            clk           => clk,
            reset_n       => reset_n,
            s_axis_tdata  => s_axis_tdata,
            s_axis_tvalid => s_axis_tvalid,
            s_axis_tready => s_axis_tready,
            ws            => ws,
            l_data_tx     => l_data_tx,
            r_data_tx     => r_data_tx,
            underrun      => underrun
        );

    -- einfacher Simulationstakt
    clk <= not clk after 10 ns;

    stim_proc : process
    begin
        -- Reset
        reset_n <= '0';
        s_axis_tvalid <= '0';
        ws <= '0';
        wait for 100 ns;

        reset_n <= '1';
        wait for 40 ns;

        -- 1. Stereo-Frame:
        -- left  = 0x000001
        -- right = 0x000002
        s_axis_tdata  <= x"00000002_00000001";
        s_axis_tvalid <= '1';
        wait for 20 ns;  -- ein Takt
        s_axis_tvalid <= '0';

        -- etwas warten
        wait for 100 ns;

        -- ws-Flanke 1 -> 0 erzeugen
        ws <= '1';
        wait for 80 ns;
        ws <= '0';
        wait for 100 ns;

        -- 2. Stereo-Frame:
        -- left  = 0x0000AA
        -- right = 0x0000BB
        s_axis_tdata  <= x"000000BB_000000AA";
        s_axis_tvalid <= '1';
        wait for 20 ns;
        s_axis_tvalid <= '0';

        wait for 100 ns;

        -- nächste ws-Flanke
        ws <= '1';
        wait for 80 ns;
        ws <= '0';
        wait for 100 ns;

        -- absichtlich kein neues Frame -> underrun testen
        ws <= '1';
        wait for 80 ns;
        ws <= '0';
        wait for 100 ns;

        wait;
    end process;

end architecture;