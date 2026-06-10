# SMC/ICT 2022 Model Trading Bot

## Overview
A complete **Expert Advisor (EA)** for MetaTrader 5 implementing the ICT 2022 Trading Model with Smart Money Concepts (SMC). Designed specifically for **Funded Accounts** (FTMO, MyForexFunds, etc.).

## Strategy Logic

```
HTF Bias (H4/Daily) → Liquidity Sweep → MSS/CHoCH (M15) → OB + FVG Entry → Kill Zone Timing
```

### Entry Conditions (All must be true):
1. ✅ **HTF Trend** - Break of Structure on H4 (bullish/bearish bias)
2. ✅ **Premium/Discount** - Price in correct zone (buy in discount, sell in premium)
3. ✅ **Liquidity Sweep** - Price sweeps equal highs/lows or PDH/PDL
4. ✅ **Market Structure Shift** - CHoCH/MSS on M15 confirms reversal
5. ✅ **Order Block** - Valid un-mitigated OB present
6. ✅ **Fair Value Gap** - FVG formed during displacement
7. ✅ **Kill Zone** - London Open (07:00-10:00) or New York (13:00-16:00)

### Risk Management:
- 1% risk per trade
- Max 3 trades/day
- Daily drawdown limit: 3% (stops before funded account 5% limit)
- Total drawdown limit: 6% (stops before funded account 10% limit)
- Break-even after 1R profit
- Partial close (50%) at 1.5R
- Trailing stop activation at 2R

## File Structure

```
SMC_ICT_Bot/
├── MQL5/
│   ├── SMC_ICT_EA.mq5           # Main EA file
│   └── Modules/
│       ├── MarketStructure.mqh   # BOS, CHoCH, MSS detection
│       ├── Liquidity.mqh         # Liquidity pools & sweeps
│       ├── OrderBlocks.mqh       # Order Block detection
│       ├── FairValueGap.mqh      # FVG detection
│       ├── KillZones.mqh         # Session time filters
│       ├── RiskManager.mqh       # Position sizing & DD protection
│       └── TradeManager.mqh      # Trade execution & management
├── Python/
│   └── backtester.py             # Strategy backtester
└── README.md
```

## Installation (MT5)

1. Copy the `MQL5` folder contents to your MT5 data folder:
   - `SMC_ICT_EA.mq5` → `MQL5/Experts/`
   - `Modules/` → `MQL5/Experts/Modules/`

2. Compile in MetaEditor (F5)

3. Attach to chart (XAUUSD M15 recommended)

4. Configure inputs for your funded account rules

## Python Backtester

```bash
cd Python
pip install pandas numpy matplotlib
python backtester.py
```

For real MT5 data:
```bash
pip install MetaTrader5
```

## Recommended Settings

| Parameter | Funded Account | Personal Account |
|-----------|---------------|-----------------|
| Risk/Trade | 1.0% | 1.5-2.0% |
| Max Daily Loss | 3.0% | 4.0% |
| Max Drawdown | 6.0% | 8.0% |
| Max Trades/Day | 3 | 5 |
| Min R:R | 2.0 | 1.5 |

## Symbols
- **XAUUSD** (Gold) - Primary, best with SMC due to clear structure
- **EURUSD** - Good liquidity, clean levels
- **NAS100** - High volatility, larger moves

## Important Notes

⚠️ **This is an automated trading system. Use at your own risk.**
- Always test on a demo account first
- Past performance does not guarantee future results
- Start with minimum lot sizes
- Monitor the bot regularly
