library ieee;
use ieee.std_logic_1164.all;

entity i2s_transceiver is
  generic(
    mclk_sclk_ratio  : integer := 4;
    sclk_ws_ratio    : integer := 64;
    d_width          : integer := 24
  );
  port(
    reset_n     : in  std_logic;
    mclk        : in  std_logic;
    sclk        : out std_logic;
    ws          : out std_logic;
    sample_tick : out std_logic;
    sd_tx       : out std_logic;
    sd_rx       : in  std_logic;
    l_data_tx   : in  std_logic_vector(d_width-1 downto 0);
    r_data_tx   : in  std_logic_vector(d_width-1 downto 0);
    l_data_rx   : out std_logic_vector(d_width-1 downto 0);
    r_data_rx   : out std_logic_vector(d_width-1 downto 0)
  );
end i2s_transceiver;

architecture logic of i2s_transceiver is
  signal sclk_int      : std_logic := '0';
  signal ws_int        : std_logic := '0';
  signal l_data_rx_int : std_logic_vector(d_width-1 downto 0) := (others => '0');
  signal r_data_rx_int : std_logic_vector(d_width-1 downto 0) := (others => '0');
  signal l_data_tx_int : std_logic_vector(d_width-1 downto 0) := (others => '0');
  signal r_data_tx_int : std_logic_vector(d_width-1 downto 0) := (others => '0');
begin

  process(mclk, reset_n)
    variable sclk_cnt : integer := 0;
    variable ws_cnt   : integer := 0;
  begin
    if reset_n = '0' then
      sclk_cnt      := 0;
      ws_cnt        := 0;
      sclk_int      <= '0';
      ws_int        <= '0';
      sample_tick   <= '0';
      l_data_rx_int <= (others => '0');
      r_data_rx_int <= (others => '0');
      l_data_tx_int <= (others => '0');
      r_data_tx_int <= (others => '0');
      sd_tx         <= '0';
      l_data_rx     <= (others => '0');
      r_data_rx     <= (others => '0');

    elsif rising_edge(mclk) then
      sample_tick <= '0';

      if sclk_cnt < mclk_sclk_ratio/2 - 1 then
        sclk_cnt := sclk_cnt + 1;
      else
        sclk_cnt := 0;
        sclk_int <= not sclk_int;

        if ws_cnt < sclk_ws_ratio - 1 then
          ws_cnt := ws_cnt + 1;

          if (sclk_int = '0') and (ws_cnt > 1) and (ws_cnt < d_width*2 + 2) then
            if ws_int = '1' then
              r_data_rx_int <= r_data_rx_int(d_width-2 downto 0) & sd_rx;
            else
              l_data_rx_int <= l_data_rx_int(d_width-2 downto 0) & sd_rx;
            end if;
          end if;

          if (sclk_int = '1') and (ws_cnt < d_width*2 + 3) then
            if ws_int = '1' then
              sd_tx         <= r_data_tx_int(d_width-1);
              r_data_tx_int <= r_data_tx_int(d_width-2 downto 0) & '0';
            else
              sd_tx         <= l_data_tx_int(d_width-1);
              l_data_tx_int <= l_data_tx_int(d_width-2 downto 0) & '0';
            end if;
          end if;

        else
          ws_cnt := 0;

          if ws_int = '1' then
            l_data_rx     <= l_data_rx_int;
            r_data_rx     <= r_data_rx_int;
            l_data_tx_int <= l_data_tx;
            r_data_tx_int <= r_data_tx;
            sample_tick   <= '1';
          end if;

          ws_int <= not ws_int;
        end if;
      end if;
    end if;
  end process;

  sclk <= sclk_int;
  ws   <= ws_int;

end logic;