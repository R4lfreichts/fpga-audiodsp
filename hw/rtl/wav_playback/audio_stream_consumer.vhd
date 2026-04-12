library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity audio_stream_consumer is
    generic (
        d_width : integer := 24
    );
    port (
        clk           : in  std_logic;  -- Audiotaktbereich, z. B. master_clk = 12.288 MHz
        reset_n       : in  std_logic;

        -- AXI4-Stream Slave
        s_axis_tdata  : in  std_logic_vector(63 downto 0);
        s_axis_tvalid : in  std_logic;
        s_axis_tready : out std_logic;

        -- vom I2S-Pfad
        ws            : in  std_logic;

        -- an i2s_transceiver
        l_data_tx     : out std_logic_vector(d_width-1 downto 0);
        r_data_tx     : out std_logic_vector(d_width-1 downto 0);

        -- optionales Debug-Signal
        underrun      : out std_logic
    );
end entity;

architecture rtl of audio_stream_consumer is

    signal ws_prev         : std_logic := '0';

    signal frame_buf       : std_logic_vector(63 downto 0) := (others => '0');
    signal frame_buf_valid : std_logic := '0';

    signal l_data_tx_reg   : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal r_data_tx_reg   : std_logic_vector(d_width-1 downto 0) := (others => '0');
    signal underrun_reg    : std_logic := '0';

begin

    -- Immer genau ein Frame vorpuffern
    -- Sobald der Puffer leer ist, darf das nächste AXIS-Wort übernommen werden.
    s_axis_tready <= not frame_buf_valid;

    l_data_tx <= l_data_tx_reg;
    r_data_tx <= r_data_tx_reg;
    underrun  <= underrun_reg;

    process(clk)
    begin
        if rising_edge(clk) then
            if reset_n = '0' then
                ws_prev         <= '0';
                frame_buf       <= (others => '0');
                frame_buf_valid <= '0';
                l_data_tx_reg   <= (others => '0');
                r_data_tx_reg   <= (others => '0');
                underrun_reg    <= '0';
            else
                underrun_reg <= '0';

                -- AXI-Stream-Handshake:
                -- wenn Puffer leer ist und Daten anliegen, ein komplettes Stereo-Frame puffern
                if (s_axis_tvalid = '1') and (frame_buf_valid = '0') then
                    frame_buf       <= s_axis_tdata;
                    frame_buf_valid <= '1';
                end if;

                -- Pro Stereo-Frame genau ein neues Samplepaar an den I2S-Pfad übergeben
                -- wie bisher beim Übergang ws: '1' -> '0'
                if (ws_prev = '1') and (ws = '0') then
                    if frame_buf_valid = '1' then
                        -- linkes Sample:  untere 24 Bit von lane 0
                        -- rechtes Sample: untere 24 Bit von lane 1
                        l_data_tx_reg <= frame_buf(23 downto 0);
                        r_data_tx_reg <= frame_buf(55 downto 32);

                        frame_buf_valid <= '0';
                    else
                        -- keine Daten vorhanden -> Stille
                        l_data_tx_reg <= (others => '0');
                        r_data_tx_reg <= (others => '0');
                        underrun_reg  <= '1';
                    end if;
                end if;

                ws_prev <= ws;
            end if;
        end if;
    end process;

end architecture;