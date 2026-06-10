"""
SMC/ICT 2022 Model Strategy Backtester
=======================================
Validates the trading strategy on historical data before deploying to MT5.

Usage:
    python backtester.py

Requirements:
    pip install pandas numpy matplotlib
    
For MT5 data:
    pip install MetaTrader5
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json
import os

# ============================================================
# CONFIGURATION
# ============================================================
class Config:
    # Strategy Parameters
    STRUCTURE_LOOKBACK = 20
    HTF_LOOKBACK = 50
    FVG_MIN_SIZE_PCT = 0.0005   # Min FVG size as % of price
    OB_MIN_DISPLACEMENT_ATR = 0.8
    OTE_LEVEL_LOW = 0.62
    OTE_LEVEL_HIGH = 0.79
    
    # Risk Management
    RISK_PER_TRADE = 1.0  # %
    MAX_DAILY_LOSS = 3.0  # %
    MAX_TOTAL_DD = 6.0    # %
    MAX_TRADES_PER_DAY = 3
    MIN_RR = 2.0
    
    # Kill Zones (GMT)
    LONDON_START = 7
    LONDON_END = 10
    NY_START = 13
    NY_END = 16
    
    # Backtest Settings
    INITIAL_BALANCE = 100000
    SPREAD_POINTS = 20  # Average spread in points


# ============================================================
# DATA LOADER
# ============================================================
class DataLoader:
    """Load historical price data"""
    
    @staticmethod
    def generate_sample_data(symbol="XAUUSD", timeframe="M15", 
                             start_date="2023-01-01", end_date="2024-12-31"):
        """
        Generate sample OHLCV data for backtesting.
        In production, replace with real data from MT5 or CSV files.
        """
        print(f"Generating sample data for {symbol} ({timeframe})...")
        print(f"Period: {start_date} to {end_date}")
        
        # Generate dates
        start = pd.Timestamp(start_date)
        end = pd.Timestamp(end_date)
        
        if timeframe == "M15":
            freq = "15min"
        elif timeframe == "H1":
            freq = "1h"
        elif timeframe == "H4":
            freq = "4h"
        elif timeframe == "D1":
            freq = "1D"
        else:
            freq = "15min"
        
        dates = pd.date_range(start=start, end=end, freq=freq)
        
        # Filter out weekends
        dates = dates[dates.dayofweek < 5]
        
        # Generate realistic price data using random walk
        np.random.seed(42)
        n = len(dates)
        
        if symbol == "XAUUSD":
            base_price = 1950.0
            volatility = 0.0015
            point = 0.01
        elif symbol == "EURUSD":
            base_price = 1.0850
            volatility = 0.0004
            point = 0.00001
        elif symbol == "NAS100":
            base_price = 15000.0
            volatility = 0.003
            point = 0.01
        else:
            base_price = 1.0
            volatility = 0.001
            point = 0.00001
        
        # Generate returns with regime switching (trending + ranging)
        returns = np.zeros(n)
        regime = 0  # 0=trending up, 1=trending down, 2=ranging
        regime_length = 0
        
        for i in range(n):
            regime_length += 1
            # Switch regime randomly
            if regime_length > np.random.randint(50, 200):
                regime = np.random.choice([0, 1, 2], p=[0.35, 0.35, 0.3])
                regime_length = 0
            
            if regime == 0:  # Trending up
                returns[i] = np.random.normal(volatility * 0.3, volatility)
            elif regime == 1:  # Trending down
                returns[i] = np.random.normal(-volatility * 0.3, volatility)
            else:  # Ranging
                returns[i] = np.random.normal(0, volatility * 0.7)
        
        # Generate prices
        prices = base_price * np.exp(np.cumsum(returns))
        
        # Generate OHLC with realistic candle bodies and wicks
        df = pd.DataFrame(index=dates[:n])
        df['close'] = prices
        
        # More realistic open/high/low generation
        opens = np.roll(prices, 1)
        opens[0] = base_price
        df['open'] = opens
        
        # Generate wicks - larger during sessions, smaller outside
        atr_base = np.abs(prices - opens) + volatility * base_price * 0.3
        
        # Add wicks that occasionally sweep levels (important for liquidity sweeps)
        upper_wicks = np.abs(np.random.exponential(0.5, n)) * atr_base
        lower_wicks = np.abs(np.random.exponential(0.5, n)) * atr_base
        
        # Occasionally add large wicks (stop hunts/sweeps)
        spike_mask = np.random.random(n) < 0.05  # 5% of bars have large wicks
        upper_wicks[spike_mask] *= 3
        lower_wicks[spike_mask] *= 3
        
        df['high'] = np.maximum(df['open'], df['close']) + upper_wicks
        df['low'] = np.minimum(df['open'], df['close']) - lower_wicks
        
        # Volume (higher during kill zones)
        df['volume'] = np.random.randint(100, 10000, n)
        
        df['symbol'] = symbol
        df['point'] = point
        
        print(f"Generated {len(df)} bars")
        return df
    
    @staticmethod
    def load_csv(filepath):
        """Load data from CSV file (MT5 export format)"""
        df = pd.read_csv(filepath, parse_dates=['time'])
        df.set_index('time', inplace=True)
        return df
    
    @staticmethod
    def load_from_mt5(symbol, timeframe, start_date, end_date):
        """
        Load data directly from MetaTrader 5.
        Requires MetaTrader5 package and MT5 terminal running.
        """
        try:
            import MetaTrader5 as mt5
            
            if not mt5.initialize():
                print("MT5 initialization failed")
                return None
            
            tf_map = {
                "M1": mt5.TIMEFRAME_M1,
                "M5": mt5.TIMEFRAME_M5,
                "M15": mt5.TIMEFRAME_M15,
                "H1": mt5.TIMEFRAME_H1,
                "H4": mt5.TIMEFRAME_H4,
                "D1": mt5.TIMEFRAME_D1,
            }
            
            rates = mt5.copy_rates_range(symbol, tf_map[timeframe], 
                                          pd.Timestamp(start_date),
                                          pd.Timestamp(end_date))
            mt5.shutdown()
            
            if rates is None:
                return None
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            df.rename(columns={'tick_volume': 'volume'}, inplace=True)
            
            return df
            
        except ImportError:
            print("MetaTrader5 package not installed. Use: pip install MetaTrader5")
            return None


# ============================================================
# MARKET STRUCTURE MODULE
# ============================================================
class MarketStructure:
    """Detect BOS, CHoCH, Market Structure Shift"""
    
    @staticmethod
    def find_swing_highs(df, lookback=3):
        """Find swing highs in price data"""
        highs = df['high'].values
        swing_highs = []
        
        for i in range(lookback, len(highs) - lookback):
            is_high = True
            for j in range(1, lookback + 1):
                if highs[i] <= highs[i-j] or highs[i] <= highs[i+j]:
                    is_high = False
                    break
            if is_high:
                swing_highs.append({
                    'price': highs[i],
                    'index': i,
                    'time': df.index[i]
                })
        
        return swing_highs
    
    @staticmethod
    def find_swing_lows(df, lookback=3):
        """Find swing lows in price data"""
        lows = df['low'].values
        swing_lows = []
        
        for i in range(lookback, len(lows) - lookback):
            is_low = True
            for j in range(1, lookback + 1):
                if lows[i] >= lows[i-j] or lows[i] >= lows[i+j]:
                    is_low = False
                    break
            if is_low:
                swing_lows.append({
                    'price': lows[i],
                    'index': i,
                    'time': df.index[i]
                })
        
        return swing_lows
    
    @staticmethod
    def get_bias(swing_highs, swing_lows):
        """
        Determine market bias based on structure.
        Returns: 'bullish', 'bearish', or 'neutral'
        """
        if len(swing_highs) < 2 or len(swing_lows) < 2:
            return 'neutral'
        
        # Check last two swing points
        hh = swing_highs[-1]['price'] > swing_highs[-2]['price']  # Higher High
        hl = swing_lows[-1]['price'] > swing_lows[-2]['price']    # Higher Low
        lh = swing_highs[-1]['price'] < swing_highs[-2]['price']  # Lower High
        ll = swing_lows[-1]['price'] < swing_lows[-2]['price']    # Lower Low
        
        if hh and hl:
            return 'bullish'
        elif lh and ll:
            return 'bearish'
        else:
            return 'neutral'
    
    @staticmethod
    def detect_choch(df, swing_highs, swing_lows, bias):
        """
        Detect Change of Character (CHoCH) / Market Structure Shift.
        Returns True if MSS detected in alignment with expected bias.
        """
        if len(swing_highs) < 2 or len(swing_lows) < 2:
            return False, 0
        
        current_price = df['close'].iloc[-1]
        
        if bias == 'bullish':
            # For bullish CHoCH: price breaks above a recent swing high
            # after being in bearish structure
            recent_sh = swing_highs[-1]['price']
            prev_sl = swing_lows[-1]['price']
            prev_prev_sl = swing_lows[-2]['price'] if len(swing_lows) >= 2 else prev_sl
            
            was_bearish = prev_sl < prev_prev_sl
            break_above = current_price > recent_sh
            
            if was_bearish and break_above:
                return True, recent_sh
        
        elif bias == 'bearish':
            recent_sl = swing_lows[-1]['price']
            prev_sh = swing_highs[-1]['price']
            prev_prev_sh = swing_highs[-2]['price'] if len(swing_highs) >= 2 else prev_sh
            
            was_bullish = prev_sh > prev_prev_sh
            break_below = current_price < recent_sl
            
            if was_bullish and break_below:
                return True, recent_sl
        
        return False, 0
    
    @staticmethod
    def get_premium_discount_zone(swing_highs, swing_lows, current_price):
        """
        Determine if price is in Premium (above 50%) or Discount (below 50%) zone.
        Returns: 'premium', 'discount', or 'equilibrium'
        """
        if not swing_highs or not swing_lows:
            return 'equilibrium', 0.5
        
        high = swing_highs[-1]['price']
        low = swing_lows[-1]['price']
        
        if high == low:
            return 'equilibrium', 0.5
        
        position = (current_price - low) / (high - low)
        
        if position <= 0.5:
            return 'discount', position
        else:
            return 'premium', position


# ============================================================
# LIQUIDITY MODULE
# ============================================================
class Liquidity:
    """Detect liquidity pools and sweeps"""
    
    @staticmethod
    def find_equal_highs(swing_highs, tolerance_pct=0.001):
        """Find equal highs (buy-side liquidity pools)"""
        pools = []
        used = set()
        
        for i in range(len(swing_highs)):
            if i in used:
                continue
            cluster = [swing_highs[i]]
            
            for j in range(i+1, len(swing_highs)):
                if j in used:
                    continue
                diff = abs(swing_highs[i]['price'] - swing_highs[j]['price'])
                tolerance = swing_highs[i]['price'] * tolerance_pct
                
                if diff <= tolerance:
                    cluster.append(swing_highs[j])
                    used.add(j)
            
            if len(cluster) >= 2:
                avg_price = np.mean([p['price'] for p in cluster])
                pools.append({
                    'level': avg_price,
                    'touches': len(cluster),
                    'type': 'buy_side',
                    'swept': False
                })
        
        return pools
    
    @staticmethod
    def find_equal_lows(swing_lows, tolerance_pct=0.001):
        """Find equal lows (sell-side liquidity pools)"""
        pools = []
        used = set()
        
        for i in range(len(swing_lows)):
            if i in used:
                continue
            cluster = [swing_lows[i]]
            
            for j in range(i+1, len(swing_lows)):
                if j in used:
                    continue
                diff = abs(swing_lows[i]['price'] - swing_lows[j]['price'])
                tolerance = swing_lows[i]['price'] * tolerance_pct
                
                if diff <= tolerance:
                    cluster.append(swing_lows[j])
                    used.add(j)
            
            if len(cluster) >= 2:
                avg_price = np.mean([p['price'] for p in cluster])
                pools.append({
                    'level': avg_price,
                    'touches': len(cluster),
                    'type': 'sell_side',
                    'swept': False
                })
        
        return pools
    
    @staticmethod
    def detect_sweep(df, pools, bias, lookback=5):
        """
        Detect if liquidity has been swept recently.
        For bullish: sell-side liquidity swept (price went below then closed above)
        For bearish: buy-side liquidity swept (price went above then closed below)
        """
        if not pools:
            return False, 0
        
        recent_data = df.iloc[-lookback:]
        
        for pool in pools:
            if pool['swept']:
                continue
            
            if bias == 'bullish' and pool['type'] == 'sell_side':
                # Check if price wicked below but closed above
                for idx in range(len(recent_data)):
                    bar = recent_data.iloc[idx]
                    if bar['low'] < pool['level'] and bar['close'] > pool['level']:
                        pool['swept'] = True
                        return True, pool['level']
            
            elif bias == 'bearish' and pool['type'] == 'buy_side':
                for idx in range(len(recent_data)):
                    bar = recent_data.iloc[idx]
                    if bar['high'] > pool['level'] and bar['close'] < pool['level']:
                        pool['swept'] = True
                        return True, pool['level']
        
        return False, 0
    
    @staticmethod
    def find_next_liquidity(pools, current_price, direction='above'):
        """Find next untouched liquidity level"""
        candidates = []
        
        for pool in pools:
            if pool['swept']:
                continue
            
            if direction == 'above' and pool['level'] > current_price:
                candidates.append(pool['level'])
            elif direction == 'below' and pool['level'] < current_price:
                candidates.append(pool['level'])
        
        if not candidates:
            return 0
        
        if direction == 'above':
            return min(candidates)
        else:
            return max(candidates)


# ============================================================
# ORDER BLOCK MODULE
# ============================================================
class OrderBlocks:
    """Detect Order Blocks"""
    
    @staticmethod
    def detect_order_blocks(df, atr_multiplier=1.5, lookback=50):
        """
        Find valid Order Blocks.
        Bullish OB: Last bearish candle before strong bullish displacement.
        Bearish OB: Last bullish candle before strong bearish displacement.
        """
        blocks = []
        
        # Calculate ATR
        high = df['high'].values
        low = df['low'].values
        close = df['close'].values
        open_p = df['open'].values
        
        tr = np.maximum(high - low, 
                        np.maximum(np.abs(high - np.roll(close, 1)),
                                   np.abs(low - np.roll(close, 1))))
        atr = pd.Series(tr).rolling(14).mean().values
        
        n = len(df)
        start_idx = max(2, n - lookback)
        
        for i in range(start_idx, n - 1):
            if np.isnan(atr[i]) or atr[i] == 0:
                continue
            
            # Bullish Order Block
            # Candle i is bearish, candle i+1 is strong bullish displacement
            if close[i] < open_p[i] and i + 1 < n:  # Bearish candle (potential OB)
                if close[i+1] > open_p[i+1]:  # Next candle is bullish
                    body = close[i+1] - open_p[i+1]
                    if body >= atr[i] * atr_multiplier:
                        # Displacement confirmed
                        ob = {
                            'top': high[i],
                            'bottom': low[i],
                            'time': df.index[i],
                            'index': i,
                            'type': 'bullish',
                            'mitigated': False,
                            'strength': body / atr[i]
                        }
                        
                        # Check if mitigated (price came back to it after)
                        for j in range(i + 2, n):
                            if low[j] <= ob['top']:
                                ob['mitigated'] = True
                                break
                        
                        blocks.append(ob)
            
            # Bearish Order Block
            if close[i] > open_p[i] and i + 1 < n:  # Bullish candle (potential OB)
                if close[i+1] < open_p[i+1]:  # Next candle is bearish
                    body = open_p[i+1] - close[i+1]
                    if body >= atr[i] * atr_multiplier:
                        ob = {
                            'top': high[i],
                            'bottom': low[i],
                            'time': df.index[i],
                            'index': i,
                            'type': 'bearish',
                            'mitigated': False,
                            'strength': body / atr[i]
                        }
                        
                        for j in range(i + 2, n):
                            if high[j] >= ob['bottom']:
                                ob['mitigated'] = True
                                break
                        
                        blocks.append(ob)
        
        return blocks
    
    @staticmethod
    def find_valid_ob(blocks, current_price, bias):
        """Find nearest valid (un-mitigated) Order Block"""
        valid_blocks = [b for b in blocks if not b['mitigated']]
        
        if not valid_blocks:
            return None
        
        best = None
        best_dist = float('inf')
        
        for ob in valid_blocks:
            if bias == 'bullish' and ob['type'] == 'bullish':
                # Price is IN the OB or above it (already got support from it)
                if current_price >= ob['bottom'] and current_price <= ob['top'] * 1.02:
                    return ob
                # OB is below current price (potential support)
                if ob['top'] <= current_price:
                    dist = current_price - ob['top']
                    ob_size = ob['top'] - ob['bottom']
                    if dist < best_dist and dist <= ob_size * 5:
                        best_dist = dist
                        best = ob
                    
            elif bias == 'bearish' and ob['type'] == 'bearish':
                if current_price >= ob['bottom'] * 0.98 and current_price <= ob['top']:
                    return ob
                if ob['bottom'] >= current_price:
                    dist = ob['bottom'] - current_price
                    ob_size = ob['top'] - ob['bottom']
                    if dist < best_dist and dist <= ob_size * 5:
                        best_dist = dist
                        best = ob
        
        return best


# ============================================================
# FAIR VALUE GAP MODULE
# ============================================================
class FairValueGap:
    """Detect Fair Value Gaps"""
    
    @staticmethod
    def detect_fvgs(df, min_size_pct=0.0005, lookback=30):
        """
        Detect Fair Value Gaps (3-candle imbalance).
        Bullish FVG: Candle 3 low > Candle 1 high
        Bearish FVG: Candle 1 low > Candle 3 high
        """
        gaps = []
        high = df['high'].values
        low = df['low'].values
        
        end_idx = min(len(df) - 2, lookback)
        
        for i in range(1, end_idx):
            # Bullish FVG: gap between candle 1 (i+2) high and candle 3 (i) low
            bull_gap_bottom = high[i+1]  # Middle of the 3 candles back
            # Actually: candle1=i+2, candle2=i+1, candle3=i
            # Wait, with reversed indexing for our loop:
            # candle 1 = i+1 (oldest), candle 2 = i (middle), candle 3 = i-1 (newest)
            
            if i >= 1 and i + 1 < len(high):
                # Bullish FVG
                candle1_high = high[i+1]
                candle3_low = low[i-1] if i-1 >= 0 else low[i]
                
                if candle3_low > candle1_high:
                    gap_size = candle3_low - candle1_high
                    min_size = df['close'].iloc[i] * min_size_pct
                    
                    if gap_size >= min_size:
                        fvg = {
                            'top': candle3_low,
                            'bottom': candle1_high,
                            'mid': (candle3_low + candle1_high) / 2,
                            'time': df.index[i],
                            'index': i,
                            'type': 'bullish',
                            'filled': False,
                            'size': gap_size
                        }
                        
                        # Check if filled
                        for j in range(0, i-1):
                            if low[j] <= fvg['bottom']:
                                fvg['filled'] = True
                                break
                        
                        gaps.append(fvg)
                
                # Bearish FVG
                candle1_low = low[i+1]
                candle3_high = high[i-1] if i-1 >= 0 else high[i]
                
                if candle1_low > candle3_high:
                    gap_size = candle1_low - candle3_high
                    min_size = df['close'].iloc[i] * min_size_pct
                    
                    if gap_size >= min_size:
                        fvg = {
                            'top': candle1_low,
                            'bottom': candle3_high,
                            'mid': (candle1_low + candle3_high) / 2,
                            'time': df.index[i],
                            'index': i,
                            'type': 'bearish',
                            'filled': False,
                            'size': gap_size
                        }
                        
                        for j in range(0, i-1):
                            if high[j] >= fvg['top']:
                                fvg['filled'] = True
                                break
                        
                        gaps.append(fvg)
        
        return gaps
    
    @staticmethod
    def find_valid_fvg(gaps, current_price, bias):
        """Find nearest valid (unfilled) FVG"""
        valid_gaps = [g for g in gaps if not g['filled']]
        
        if not valid_gaps:
            return None
        
        for fvg in valid_gaps:
            if bias == 'bullish' and fvg['type'] == 'bullish':
                # Price should be at or approaching the FVG
                if current_price >= fvg['bottom'] and current_price <= fvg['top']:
                    return fvg  # Price is IN the FVG
                elif fvg['top'] <= current_price:
                    dist = current_price - fvg['top']
                    if dist <= fvg['size'] * 2:
                        return fvg
            
            elif bias == 'bearish' and fvg['type'] == 'bearish':
                if current_price >= fvg['bottom'] and current_price <= fvg['top']:
                    return fvg
                elif fvg['bottom'] >= current_price:
                    dist = fvg['bottom'] - current_price
                    if dist <= fvg['size'] * 2:
                        return fvg
        
        return None


# ============================================================
# KILL ZONE FILTER
# ============================================================
class KillZones:
    """Session time filter"""
    
    @staticmethod
    def is_kill_zone(timestamp, config=Config):
        """Check if timestamp is in a Kill Zone"""
        hour = timestamp.hour
        
        # London Kill Zone
        if config.LONDON_START <= hour < config.LONDON_END:
            return True, 'London'
        
        # New York Kill Zone
        if config.NY_START <= hour < config.NY_END:
            return True, 'New York'
        
        return False, 'None'


# ============================================================
# BACKTESTER ENGINE
# ============================================================
class Backtester:
    """Main backtesting engine"""
    
    def __init__(self, config=Config):
        self.config = config
        self.trades = []
        self.balance = config.INITIAL_BALANCE
        self.equity = config.INITIAL_BALANCE
        self.high_water_mark = config.INITIAL_BALANCE
        self.daily_pnl = 0
        self.today_trades = 0
        self.current_date = None
        self.consec_losses = 0
        
        # Stats
        self.equity_curve = []
        self.max_drawdown = 0
        self.total_trades = 0
        self.winning_trades = 0
        self.losing_trades = 0
        self.total_profit = 0
        self.total_loss = 0
    
    def run(self, htf_data, ltf_data, symbol="XAUUSD"):
        """
        Run the backtest.
        
        Args:
            htf_data: Higher timeframe DataFrame (H4)
            ltf_data: Lower timeframe DataFrame (M15)
            symbol: Trading symbol
        """
        print("\n" + "="*60)
        print(f"  BACKTESTING SMC/ICT Strategy on {symbol}")
        print("="*60)
        print(f"  Period: {ltf_data.index[0]} to {ltf_data.index[-1]}")
        print(f"  Initial Balance: ${self.config.INITIAL_BALANCE:,.2f}")
        print(f"  Risk per trade: {self.config.RISK_PER_TRADE}%")
        print(f"  Min R:R: {self.config.MIN_RR}")
        print("="*60 + "\n")
        
        # Minimum bars needed
        min_bars = max(self.config.HTF_LOOKBACK, self.config.STRUCTURE_LOOKBACK) + 10
        
        # Debug counters
        filter_counts = {'kill_zone': 0, 'bias': 0, 'zone': 0, 'sweep': 0, 
                        'mss': 0, 'ob': 0, 'fvg': 0, 'rr': 0, 'traded': 0}
        
        # Iterate through LTF bars
        for i in range(min_bars, len(ltf_data)):
            current_time = ltf_data.index[i]
            
            # New day reset
            current_day = current_time.date()
            if current_day != self.current_date:
                self.current_date = current_day
                self.today_trades = 0
                self.daily_pnl = 0
            
            # Record equity
            self.equity_curve.append({
                'time': current_time,
                'equity': self.equity,
                'balance': self.balance
            })
            
            # === Safety Checks ===
            # Daily drawdown check
            if self.daily_pnl <= -(self.equity * self.config.MAX_DAILY_LOSS / 100):
                continue
            
            # Total drawdown check
            dd = (self.high_water_mark - self.equity) / self.high_water_mark * 100
            if dd >= self.config.MAX_TOTAL_DD:
                continue
            
            # Max trades per day
            if self.today_trades >= self.config.MAX_TRADES_PER_DAY:
                continue
            
            # Kill Zone check
            in_kz, session = KillZones.is_kill_zone(current_time)
            if not in_kz:
                continue
            filter_counts['kill_zone'] += 1
            
            # === STRATEGY LOGIC ===
            
            # Get HTF data up to current time
            htf_slice = htf_data[htf_data.index <= current_time].iloc[-self.config.HTF_LOOKBACK:]
            ltf_slice = ltf_data.iloc[max(0, i-50):i+1]
            
            if len(htf_slice) < 10 or len(ltf_slice) < 10:
                continue
            
            # Step 1: HTF Bias
            htf_swing_highs = MarketStructure.find_swing_highs(htf_slice, lookback=2)
            htf_swing_lows = MarketStructure.find_swing_lows(htf_slice, lookback=2)
            bias = MarketStructure.get_bias(htf_swing_highs, htf_swing_lows)
            
            if bias == 'neutral':
                continue
            filter_counts['bias'] += 1
            
            # Step 2: Premium/Discount Zone
            current_price = ltf_slice['close'].iloc[-1]
            zone, position = MarketStructure.get_premium_discount_zone(
                htf_swing_highs, htf_swing_lows, current_price)
            
            if bias == 'bullish' and zone != 'discount':
                continue
            if bias == 'bearish' and zone != 'premium':
                continue
            filter_counts['zone'] += 1
            
            # Step 3: Liquidity Detection & Sweep
            ltf_swing_highs = MarketStructure.find_swing_highs(ltf_slice, lookback=2)
            ltf_swing_lows = MarketStructure.find_swing_lows(ltf_slice, lookback=2)
            
            buy_pools = Liquidity.find_equal_highs(ltf_swing_highs, tolerance_pct=0.002)
            sell_pools = Liquidity.find_equal_lows(ltf_swing_lows, tolerance_pct=0.002)
            all_pools = buy_pools + sell_pools
            
            # Also add swing points as liquidity
            for sh in ltf_swing_highs[-5:]:
                all_pools.append({'level': sh['price'], 'touches': 1, 'type': 'buy_side', 'swept': False})
            for sl_point in ltf_swing_lows[-5:]:
                all_pools.append({'level': sl_point['price'], 'touches': 1, 'type': 'sell_side', 'swept': False})
            
            swept, sweep_level = Liquidity.detect_sweep(ltf_slice, all_pools, bias, lookback=8)
            if not swept:
                continue
            filter_counts['sweep'] += 1
            
            # Step 4: Market Structure Shift (CHoCH)
            mss_detected, mss_level = MarketStructure.detect_choch(
                ltf_slice, ltf_swing_highs, ltf_swing_lows, bias)
            if not mss_detected:
                continue
            filter_counts['mss'] += 1
            
            # Step 5: Order Block
            order_blocks = OrderBlocks.detect_order_blocks(ltf_slice, 
                                                           self.config.OB_MIN_DISPLACEMENT_ATR,
                                                           lookback=30)
            valid_ob = OrderBlocks.find_valid_ob(order_blocks, current_price, bias)
            if valid_ob is None:
                continue
            filter_counts['ob'] += 1
            
            # Step 6: Fair Value Gap (use OB as fallback if no FVG)
            fvgs = FairValueGap.detect_fvgs(ltf_slice, min_size_pct=self.config.FVG_MIN_SIZE_PCT)
            valid_fvg = FairValueGap.find_valid_fvg(fvgs, current_price, bias)
            if valid_fvg is None:
                valid_fvg = {'top': valid_ob['top'], 'bottom': valid_ob['bottom'],
                             'mid': (valid_ob['top'] + valid_ob['bottom'])/2}
            
            # === ALL CONDITIONS MET - CALCULATE TRADE ===
            entry, sl, tp = self._calculate_trade_levels(
                bias, valid_ob, valid_fvg, current_price, 
                sweep_level, all_pools, ltf_slice)
            
            if entry == 0 or sl == 0 or tp == 0:
                continue
            
            # Check R:R
            if bias == 'bullish':
                rr = (tp - entry) / (entry - sl)
            else:
                rr = (entry - tp) / (sl - entry)
            
            if rr < self.config.MIN_RR:
                continue
            
            # === SIMULATE TRADE ===
            self._execute_trade(bias, entry, sl, tp, rr, current_time, session, i, ltf_data)
        
        # Print filter diagnostics
        print("\n  🔍 Filter Diagnostics:")
        print(f"  {'─'*50}")
        print(f"  Passed Kill Zone:       {filter_counts['kill_zone']}")
        print(f"  Passed HTF Bias:        {filter_counts['bias']}")
        print(f"  Passed P/D Zone:        {filter_counts['zone']}")
        print(f"  Passed Liq Sweep:       {filter_counts['sweep']}")
        print(f"  Passed MSS/CHoCH:       {filter_counts['mss']}")
        print(f"  Passed Order Block:     {filter_counts['ob']}")
        print(f"  Trades Executed:        {self.total_trades}")
        
        # Print results
        self._print_results()
        return self.trades
    
    def _calculate_trade_levels(self, bias, ob, fvg, current_price, 
                                sweep_level, pools, ltf_slice):
        """Calculate entry, SL, and TP levels"""
        
        # Entry: OTE level within FVG or OB
        if fvg:
            zone_top = fvg['top']
            zone_bottom = fvg['bottom']
        else:
            zone_top = ob['top']
            zone_bottom = ob['bottom']
        
        if bias == 'bullish':
            entry = zone_top - (zone_top - zone_bottom) * self.config.OTE_LEVEL_LOW
            sl = min(ob['bottom'], sweep_level) if sweep_level > 0 else ob['bottom']
            
            # ATR buffer
            atr = ltf_slice['high'].rolling(14).mean().iloc[-1] - ltf_slice['low'].rolling(14).mean().iloc[-1]
            sl -= atr * 0.2
            
            # TP: next liquidity above
            tp = Liquidity.find_next_liquidity(pools, entry, 'above')
            if tp == 0:
                tp = entry + (entry - sl) * self.config.MIN_RR
        else:
            entry = zone_bottom + (zone_top - zone_bottom) * self.config.OTE_LEVEL_LOW
            sl = max(ob['top'], sweep_level) if sweep_level > 0 else ob['top']
            
            atr = ltf_slice['high'].rolling(14).mean().iloc[-1] - ltf_slice['low'].rolling(14).mean().iloc[-1]
            sl += atr * 0.2
            
            tp = Liquidity.find_next_liquidity(pools, entry, 'below')
            if tp == 0:
                tp = entry - (sl - entry) * self.config.MIN_RR
        
        return entry, sl, tp
    
    def _execute_trade(self, bias, entry, sl, tp, rr, time, session, bar_idx, ltf_data):
        """Simulate trade execution and outcome"""
        
        # Calculate risk amount
        risk_amount = self.equity * (self.config.RISK_PER_TRADE / 100)
        
        # Simulate: check if price hits SL or TP first in subsequent bars
        max_bars = min(bar_idx + 96, len(ltf_data))  # Max 96 bars hold time
        
        outcome = 'timeout'
        close_price = entry
        close_time = time
        
        for j in range(bar_idx + 1, max_bars):
            bar = ltf_data.iloc[j]
            
            if bias == 'bullish':
                # Check SL hit (low touches SL)
                if bar['low'] <= sl:
                    outcome = 'loss'
                    close_price = sl
                    close_time = ltf_data.index[j]
                    break
                # Check TP hit (high touches TP)
                if bar['high'] >= tp:
                    outcome = 'win'
                    close_price = tp
                    close_time = ltf_data.index[j]
                    break
            else:
                if bar['high'] >= sl:
                    outcome = 'loss'
                    close_price = sl
                    close_time = ltf_data.index[j]
                    break
                if bar['low'] <= tp:
                    outcome = 'win'
                    close_price = tp
                    close_time = ltf_data.index[j]
                    break
        
        # Calculate P&L
        if outcome == 'win':
            pnl = risk_amount * rr
            self.winning_trades += 1
            self.total_profit += pnl
            self.consec_losses = 0
        elif outcome == 'loss':
            pnl = -risk_amount
            self.losing_trades += 1
            self.total_loss += abs(pnl)
            self.consec_losses += 1
        else:
            # Timeout - close at current price (small loss/gain)
            if bias == 'bullish':
                pnl_ratio = (close_price - entry) / (entry - sl)
            else:
                pnl_ratio = (entry - close_price) / (sl - entry)
            pnl = risk_amount * pnl_ratio
            if pnl > 0:
                self.winning_trades += 1
                self.total_profit += pnl
            else:
                self.losing_trades += 1
                self.total_loss += abs(pnl)
        
        # Update account
        self.balance += pnl
        self.equity += pnl
        self.daily_pnl += pnl
        self.today_trades += 1
        self.total_trades += 1
        
        # Update high water mark
        if self.balance > self.high_water_mark:
            self.high_water_mark = self.balance
        
        # Update max drawdown
        current_dd = (self.high_water_mark - self.equity) / self.high_water_mark * 100
        self.max_drawdown = max(self.max_drawdown, current_dd)
        
        # Record trade
        trade_record = {
            'entry_time': time,
            'close_time': close_time,
            'bias': bias,
            'entry': entry,
            'sl': sl,
            'tp': tp,
            'close_price': close_price,
            'rr': rr,
            'outcome': outcome,
            'pnl': pnl,
            'balance': self.balance,
            'session': session,
            'drawdown': current_dd
        }
        self.trades.append(trade_record)
    
    def _print_results(self):
        """Print backtest results"""
        print("\n" + "="*60)
        print("           📊 BACKTEST RESULTS")
        print("="*60)
        
        if self.total_trades == 0:
            print("  No trades executed!")
            return
        
        win_rate = (self.winning_trades / self.total_trades * 100) if self.total_trades > 0 else 0
        avg_win = (self.total_profit / self.winning_trades) if self.winning_trades > 0 else 0
        avg_loss = (self.total_loss / self.losing_trades) if self.losing_trades > 0 else 0
        profit_factor = (self.total_profit / self.total_loss) if self.total_loss > 0 else float('inf')
        net_profit = self.balance - self.config.INITIAL_BALANCE
        roi = (net_profit / self.config.INITIAL_BALANCE) * 100
        
        # Expectancy
        expectancy = (win_rate/100 * avg_win) - ((100-win_rate)/100 * avg_loss)
        
        print(f"\n  📈 Performance Summary:")
        print(f"  {'─'*50}")
        print(f"  Total Trades:        {self.total_trades}")
        print(f"  Winning Trades:      {self.winning_trades}")
        print(f"  Losing Trades:       {self.losing_trades}")
        print(f"  Win Rate:            {win_rate:.1f}%")
        print(f"  {'─'*50}")
        print(f"  Net Profit:          ${net_profit:,.2f}")
        print(f"  ROI:                 {roi:.2f}%")
        print(f"  Profit Factor:       {profit_factor:.2f}")
        print(f"  {'─'*50}")
        print(f"  Average Win:         ${avg_win:,.2f}")
        print(f"  Average Loss:        ${avg_loss:,.2f}")
        print(f"  Avg Win/Loss Ratio:  {(avg_win/avg_loss if avg_loss > 0 else 0):.2f}")
        print(f"  Expectancy:          ${expectancy:,.2f}")
        print(f"  {'─'*50}")
        print(f"  Max Drawdown:        {self.max_drawdown:.2f}%")
        print(f"  Final Balance:       ${self.balance:,.2f}")
        print(f"  High Water Mark:     ${self.high_water_mark:,.2f}")
        
        # Session breakdown
        print(f"\n  📅 Session Breakdown:")
        print(f"  {'─'*50}")
        sessions = {}
        for t in self.trades:
            s = t['session']
            if s not in sessions:
                sessions[s] = {'wins': 0, 'losses': 0, 'pnl': 0}
            if t['outcome'] == 'win':
                sessions[s]['wins'] += 1
            else:
                sessions[s]['losses'] += 1
            sessions[s]['pnl'] += t['pnl']
        
        for session, data in sessions.items():
            total = data['wins'] + data['losses']
            wr = (data['wins'] / total * 100) if total > 0 else 0
            print(f"  {session:15s}: {total} trades, {wr:.0f}% WR, ${data['pnl']:,.2f}")
        
        # Monthly breakdown
        print(f"\n  📆 Monthly Performance:")
        print(f"  {'─'*50}")
        monthly = {}
        for t in self.trades:
            month_key = t['entry_time'].strftime('%Y-%m')
            if month_key not in monthly:
                monthly[month_key] = {'pnl': 0, 'trades': 0, 'wins': 0}
            monthly[month_key]['pnl'] += t['pnl']
            monthly[month_key]['trades'] += 1
            if t['outcome'] == 'win':
                monthly[month_key]['wins'] += 1
        
        for month, data in sorted(monthly.items()):
            wr = (data['wins'] / data['trades'] * 100) if data['trades'] > 0 else 0
            pnl_pct = (data['pnl'] / self.config.INITIAL_BALANCE) * 100
            bar = '█' * int(abs(pnl_pct) * 2)
            sign = '+' if data['pnl'] >= 0 else '-'
            print(f"  {month}: {data['trades']:3d} trades, {wr:5.1f}% WR, "
                  f"{sign}${abs(data['pnl']):8,.2f} ({sign}{abs(pnl_pct):.1f}%) {bar}")
        
        # Funded Account Assessment
        print(f"\n  🏦 Funded Account Assessment:")
        print(f"  {'─'*50}")
        passed = self.max_drawdown < self.config.MAX_TOTAL_DD
        print(f"  Max Drawdown: {self.max_drawdown:.2f}% (Limit: {self.config.MAX_TOTAL_DD}%)")
        print(f"  Status: {'✅ PASSED' if passed else '❌ FAILED'}")
        
        if roi > 0:
            print(f"  Profit Target: ✅ Achieved ({roi:.1f}%)")
        else:
            print(f"  Profit Target: ❌ Not achieved ({roi:.1f}%)")
        
        print("\n" + "="*60)


# ============================================================
# MAIN EXECUTION
# ============================================================
def main():
    print("╔══════════════════════════════════════════════╗")
    print("║  SMC/ICT 2022 Strategy Backtester v1.0      ║")
    print("╚══════════════════════════════════════════════╝\n")
    
    # Configuration
    config = Config()
    
    # Load data (using sample data for demonstration)
    print("Loading data...")
    
    # Generate HTF data (H4)
    htf_data = DataLoader.generate_sample_data(
        symbol="XAUUSD",
        timeframe="H4",
        start_date="2023-01-01",
        end_date="2024-12-31"
    )
    
    # Generate LTF data (M15)
    ltf_data = DataLoader.generate_sample_data(
        symbol="XAUUSD",
        timeframe="M15",
        start_date="2023-01-01",
        end_date="2024-12-31"
    )
    
    # Run backtest
    backtester = Backtester(config)
    trades = backtester.run(htf_data, ltf_data, symbol="XAUUSD")
    
    # Save results to JSON
    results_file = "backtest_results.json"
    results = {
        'total_trades': backtester.total_trades,
        'win_rate': (backtester.winning_trades / backtester.total_trades * 100) if backtester.total_trades > 0 else 0,
        'net_profit': backtester.balance - config.INITIAL_BALANCE,
        'max_drawdown': backtester.max_drawdown,
        'profit_factor': (backtester.total_profit / backtester.total_loss) if backtester.total_loss > 0 else 0,
        'final_balance': backtester.balance,
    }
    
    with open(results_file, 'w') as f:
        json.dump(results, f, indent=2, default=str)
    
    print(f"\nResults saved to: {results_file}")
    print("\n💡 To use with real data:")
    print("   1. Export MT5 data to CSV")
    print("   2. Use DataLoader.load_csv('path/to/data.csv')")
    print("   3. Or connect to MT5: DataLoader.load_from_mt5('XAUUSD', 'M15', ...)")


if __name__ == "__main__":
    main()
