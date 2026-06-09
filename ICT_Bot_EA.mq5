//+------------------------------------------------------------------+
//|                                                  ICT_Bot_EA.mq5  |
//|        ICT 2022 Confluence Model - Professional EA                |
//|        Kill Zones + Liquidity Sweep + MSS/CISD + FVG/IFVG/OB    |
//|        + CRT Model + SMT Divergence + OTE Zone                   |
//+------------------------------------------------------------------+
#property copyright "ICT Bot v2.0"
#property version   "2.00"
#property strict
#property description "ICT 2022 Confluence Model: Sweep → MSS → FVG/OB Entry"
#property description "CRT + SMT as confirmation filters"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- General Settings
input ENUM_TIMEFRAMES InpHTF         = PERIOD_H4;     // HTF: Bias & Liquidity Levels
input ENUM_TIMEFRAMES InpLTF         = PERIOD_M15;    // LTF: Entry & MSS Detection
input ENUM_TIMEFRAMES InpCRT_TF      = PERIOD_H1;     // CRT: Candle Range Timeframe

//--- Kill Zone Settings (Server Time - Adjust for your broker)
input int      InpLondonStart        = 2;    // London Kill Zone Start (Server Hour)
input int      InpLondonEnd          = 5;    // London Kill Zone End (Server Hour)
input int      InpNYStart            = 8;    // NY Kill Zone Start (Server Hour)
input int      InpNYEnd              = 11;   // NY Kill Zone End (Server Hour)
input bool     InpAsianFilter        = true; // Use Asian Range as liquidity reference

//--- Liquidity Settings (HTF)
input int      InpLiq_Lookback       = 20;   // Swing High/Low Lookback (HTF candles)
input bool     InpUsePDHL            = true; // Use Previous Day High/Low
input bool     InpUsePWHL            = true; // Use Previous Week High/Low
input double   InpLiq_Threshold      = 2.0;  // Sweep Threshold (points beyond level)

//--- MSS / CISD Settings (LTF)
input int      InpMSS_Lookback       = 5;    // MSS Detection Window (LTF candles after sweep)
input double   InpMSS_MinDisplacement = 10.0; // Min Displacement Size (points)

//--- FVG / IFVG Settings (LTF)
input int      InpFVG_Lookback       = 20;   // FVG Scan Window after MSS
input double   InpFVG_MinSize        = 3.0;  // Minimum FVG Size (points)

//--- Order Block Settings (LTF)
input int      InpOB_Lookback        = 15;   // OB Scan Window
input bool     InpUseOB              = true; // Include Order Block entries
input double   InpOB_MinBody         = 5.0;  // Min OB candle body (points)

//--- ADAPTIVE ENGINE (ATR) - auto-scales to each instrument
input bool     InpUseATR             = true; // Use ATR-adaptive sizing (RECOMMENDED)
input int      InpATR_Period         = 14;   // ATR Period
input double   InpSL_ATR_Mult        = 0.5;  // SL buffer beyond structure (x ATR)
input double   InpMinSL_ATR_Mult     = 1.2;  // Minimum SL distance (x ATR) - avoids noise stop-outs
input double   InpMaxSL_ATR_Mult     = 6.0;  // Maximum SL distance (x ATR) - skip oversized stops
input double   InpMSS_Disp_ATR       = 0.5;  // Min displacement size (x ATR)
input double   InpFVG_ATR_Mult       = 0.10; // Min FVG size (x ATR)

//--- HTF BIAS FILTER (trade only with higher-timeframe direction)
input bool     InpUseHTFBias         = true; // Require entry aligned with HTF bias
input int      InpHTF_EMA_Period     = 50;   // HTF EMA period for bias

//--- OTE (Optimal Trade Entry) Zone
input double   InpOTE_FibStart       = 0.62; // OTE Zone Start (Fib)
input double   InpOTE_FibEnd         = 0.79; // OTE Zone End (Fib)
input bool     InpRequireOTE         = true; // Require entry in OTE Zone

//--- CRT Model (Confirmation)
input bool     InpUseCRT             = true;  // Use CRT as confirmation
input double   InpCRT_SweepBuffer    = 2.0;  // CRT Sweep tolerance (points)

//--- SMT Divergence (Confirmation)
input bool     InpUseSMT             = true;  // Use SMT Divergence confirmation
input string   InpSMT_EURUSD        = "USDX"; // SMT pair for EURUSD (inverse)
input string   InpSMT_XAUUSD        = "USDX"; // SMT pair for XAUUSD (inverse)
input string   InpSMT_NAS100        = "US500"; // SMT pair for NAS100 (positive)
input int      InpSMT_Lookback       = 10;    // SMT Lookback candles

//--- SMC CONFIRMATION (Market Structure + Premium/Discount)
input bool     InpUseSMC             = true; // Use SMC confirmation
input int      InpSMC_StructLookback = 30;   // Structure lookback (LTF candles)

//--- ORDER FLOW CONFIRMATION (momentum / delivery)
input bool     InpUseOrderFlow       = true; // Use Order Flow confirmation
input int      InpOF_Lookback        = 3;    // Consecutive delivery candles to confirm
input double   InpOF_BodyRatio       = 0.55; // Min body/range ratio for a "strong" candle

//--- PRICE ACTION CONFIRMATION (entry candle quality)
input bool     InpUsePriceAction     = true; // Use Price Action confirmation
input double   InpPA_RejWickRatio    = 0.50; // Min rejection-wick ratio at entry

//--- CONFLUENCE GATE (quality filter)
input bool     InpUseConfluenceGate  = true; // Require minimum confluence score
input int      InpMinConfluenceScore = 6;    // Min score to take a trade (higher = stricter)

//--- Risk Management
input double   InpRiskPercent        = 1.0;  // Risk Per Trade (%)
input double   InpRR_Ratio           = 3.0;  // Minimum Risk:Reward Ratio
input int      InpMaxTradesPerDay    = 2;    // Max Trades Per Day
input int      InpMagicNumber        = 202200; // Magic Number
input double   InpMaxSpread          = 25.0; // Max Spread (points)

//--- Symbol Toggles
input bool     InpTradeEURUSD        = true; // Trade EURUSD
input bool     InpTradeXAUUSD        = true; // Trade XAUUSD
input bool     InpTradeNAS100        = true; // Trade NAS100

//--- PROP FIRM PROTECTION (FundedNext / FTMO / etc.)
input bool     InpPropFirmMode       = true;   // Enable Prop Firm Protection
input double   InpAccountSize        = 15000;  // Account Size ($)
input double   InpDailyLossLimit     = 750;    // Daily Loss Limit ($)
input double   InpMaxLossLimit       = 1500;   // Max Overall Loss Limit ($)
input double   InpDailySafetyBuffer  = 0.80;   // Stop trading at % of daily limit (0.80 = 80%)
input double   InpMaxSafetyBuffer    = 0.85;   // Stop trading at % of max limit (0.85 = 85%)
input bool     InpCloseAllOnDaily    = true;   // Close all trades if daily limit hit
input double   InpMaxRiskCapPercent  = 1.0;    // Hard cap risk per trade (% of account)

//+------------------------------------------------------------------+
//| STRUCTURES                                                         |
//+------------------------------------------------------------------+

// Kill Zone state
struct KillZone
{
   bool     isActive;
   string   session;
};

// HTF Liquidity Level (target for sweeps)
struct LiquidityLevel
{
   double   price;
   string   source;      // "PDH","PDL","PWH","PWL","SwingH","SwingL"
   bool     isBuySide;   // true = BSL (highs), false = SSL (lows)
};

// Liquidity Sweep event
struct SweepEvent
{
   bool     occurred;
   double   levelPrice;
   string   levelSource;
   int      direction;   // 1 = swept SSL (bullish setup), -1 = swept BSL (bearish setup)
   datetime time;
   int      candleIndex; // LTF candle where sweep happened
};

// Market Structure Shift / CISD
struct MSS_Event
{
   bool     occurred;
   int      direction;   // 1 = bullish MSS, -1 = bearish MSS
   double   swingBreakPrice; // price level that was broken
   double   displacementHigh;
   double   displacementLow;
   int      candleIndex;
};

// Fair Value Gap zone
struct FVG_Zone
{
   double   high;
   double   low;
   datetime time;
   bool     isBullish;
   bool     isInverse;   // IFVG
   int      candleIndex;
};

// Order Block zone  
struct OrderBlock
{
   double   high;
   double   low;
   datetime time;
   bool     isBullish;
   int      candleIndex;
};

// OTE zone (Fibonacci)
struct OTE_Zone
{
   double   high;        // 62% retracement level
   double   low;         // 79% retracement level
   bool     valid;
};

// CRT (Candle Range Theory) signal
struct CRT_Signal
{
   bool     confirmed;
   int      direction;
   double   rangeHigh;
   double   rangeLow;
};

// SMT Divergence signal
struct SMT_Signal
{
   bool     confirmed;
   int      direction;
   string   corrSymbol;
};

// Final Trade Setup
struct TradeSetup
{
   bool     valid;
   int      direction;   // 1 = Buy, -1 = Sell
   double   entry;
   double   sl;
   double   tp;
   string   reason;
   int      confluenceScore; // Higher = more confluences aligned
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                   |
//+------------------------------------------------------------------+
CTrade trade;
int todayTrades;
datetime lastTradeDay;
datetime lastProcessedBar[];  // Track last processed bar per symbol

//--- Prop Firm tracking
double dayStartBalance;       // Balance at start of trading day (for daily loss calc)
double initialBalance;        // Initial account balance (for max loss / floor calc)
double maxLossFloor;          // Equity floor = initialBalance - MaxLossLimit
bool   dailyHalt;             // True = halted for the rest of today (daily limit reached)
bool   accountBlown;          // True = max loss reached, stop completely

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   todayTrades = 0;
   lastTradeDay = 0;
   
   //--- Initialize Prop Firm tracking
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dayStartBalance = initialBalance;
   maxLossFloor = initialBalance - InpMaxLossLimit;
   dailyHalt = false;
   accountBlown = false;
   
   Print("╔══════════════════════════════════════════╗");
   Print("║   ICT 2022 CONFLUENCE MODEL EA v2.0     ║");
   Print("╠══════════════════════════════════════════╣");
   Print("║ Strategy: Sweep → MSS → FVG/OB Entry   ║");
   Print("║ Confirmations: CRT + SMT                ║");
   Print("╚══════════════════════════════════════════╝");
   Print("HTF: ", EnumToString(InpHTF), " | LTF: ", EnumToString(InpLTF));
   Print("Risk: ", InpRiskPercent, "% | RR: 1:", InpRR_Ratio);
   Print("CRT: ", InpUseCRT ? "ON" : "OFF", " | SMT: ", InpUseSMT ? "ON" : "OFF");
   Print("OTE Zone: ", InpOTE_FibStart*100, "% - ", InpOTE_FibEnd*100, "%");
   
   if(InpPropFirmMode)
   {
      Print("─── PROP FIRM PROTECTION: ON ───");
      Print("Account Size:     $", DoubleToString(InpAccountSize, 2));
      Print("Daily Loss Limit: $", DoubleToString(InpDailyLossLimit, 2), 
            " (stop at ", InpDailySafetyBuffer*100, "% = $", 
            DoubleToString(InpDailyLossLimit*InpDailySafetyBuffer, 2), ")");
      Print("Max Loss Limit:   $", DoubleToString(InpMaxLossLimit, 2),
            " (floor = $", DoubleToString(maxLossFloor, 2), ")");
      Print("Initial Balance:  $", DoubleToString(initialBalance, 2));
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== ICT Bot EA Removed ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Reset daily trade counter & daily balance on new day
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." + 
                    IntegerToString(dt.mon) + "." + IntegerToString(dt.day));
   if(today != lastTradeDay)
   {
      todayTrades = 0;
      lastTradeDay = today;
      // New trading day → reset daily baseline and daily halt
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyHalt = false;
      if(InpPropFirmMode)
         Print("─── NEW DAY ─── Day Start Balance: $", DoubleToString(dayStartBalance, 2),
               " | Daily room: $", DoubleToString(InpDailyLossLimit, 2));
   }
   
   //--- PROP FIRM PROTECTION: Check loss limits FIRST
   if(InpPropFirmMode)
   {
      if(!CheckPropFirmLimits()) return; // Halted → no trading
   }
   
   //--- Check max trades per day
   if(todayTrades >= InpMaxTradesPerDay) return;
   
   //--- Process each symbol
   if(InpTradeEURUSD) ProcessSymbol("EURUSD");
   if(InpTradeXAUUSD) ProcessSymbol("XAUUSD");
   if(InpTradeNAS100) ProcessSymbol("NAS100");
}

//+------------------------------------------------------------------+
//| PROP FIRM PROTECTION - Daily & Max Loss Limits                     |
//| Returns false if trading should be halted                          |
//+------------------------------------------------------------------+
bool CheckPropFirmLimits()
{
   //--- If account already blown (max loss reached), never trade again
   if(accountBlown)
      return false;
   
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   //========================================================
   // 1. MAX OVERALL LOSS CHECK (account-ending breach)
   //    Floor = initialBalance - MaxLossLimit
   //========================================================
   double maxLossUsed = initialBalance - equity;        // how much lost overall
   double maxLossThreshold = InpMaxLossLimit * InpMaxSafetyBuffer;
   
   if(maxLossUsed >= maxLossThreshold)
   {
      if(!accountBlown)
      {
         Print("🛑 MAX LOSS LIMIT REACHED! Lost: $", DoubleToString(maxLossUsed, 2),
               " / $", DoubleToString(InpMaxLossLimit, 2), " — CLOSING ALL & STOPPING");
         CloseAllPositions();
         accountBlown = true;
      }
      return false;
   }
   
   //========================================================
   // 2. DAILY LOSS CHECK
   //    Daily loss = dayStartBalance - current equity
   //========================================================
   double dailyLossUsed = dayStartBalance - equity;     // loss today (uses equity incl. floating)
   double dailyLossThreshold = InpDailyLossLimit * InpDailySafetyBuffer;
   
   if(dailyLossUsed >= dailyLossThreshold)
   {
      if(!dailyHalt)
      {
         Print("⛔ DAILY LOSS LIMIT REACHED! Today's loss: $", DoubleToString(dailyLossUsed, 2),
               " / $", DoubleToString(InpDailyLossLimit, 2), " — HALTING FOR TODAY");
         if(InpCloseAllOnDaily)
            CloseAllPositions();
         dailyHalt = true;
      }
      return false;
   }
   
   //--- Still within limits
   if(dailyHalt) return false; // already halted today
   
   return true;
}

//+------------------------------------------------------------------+
//| Close all positions opened by this EA                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            string sym = PositionGetString(POSITION_SYMBOL);
            trade.PositionClose(ticket);
            Print("Closed position on ", sym, " (prop firm protection)");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get remaining daily loss allowance (in $)                          |
//+------------------------------------------------------------------+
double GetRemainingDailyAllowance()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyLossUsed = dayStartBalance - equity;
   double dailyThreshold = InpDailyLossLimit * InpDailySafetyBuffer;
   double remaining = dailyThreshold - dailyLossUsed;
   return MathMax(0, remaining);
}

//+------------------------------------------------------------------+
//| Get remaining max loss allowance (in $)                            |
//+------------------------------------------------------------------+
double GetRemainingMaxAllowance()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double maxLossUsed = initialBalance - equity;
   double maxThreshold = InpMaxLossLimit * InpMaxSafetyBuffer;
   double remaining = maxThreshold - maxLossUsed;
   return MathMax(0, remaining);
}

//+------------------------------------------------------------------+
//|                 MAIN PROCESS - ICT 2022 MODEL                      |
//|                                                                    |
//| PHASE 1: Kill Zone Active?                                         |
//| PHASE 2: Identify HTF Liquidity Levels                             |
//| PHASE 3: Detect Liquidity Sweep on LTF                            |
//| PHASE 4: Detect MSS / CISD after sweep (displacement)             |
//| PHASE 5: Find FVG or OB in OTE zone (entry)                       |
//| PHASE 6: CRT + SMT confirmation                                   |
//| PHASE 7: Execute with proper risk                                  |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol)
{
   //--- Basic checks
   if(!SymbolSelect(symbol, true)) return;
   if(SymbolInfoInteger(symbol, SYMBOL_SPREAD) > InpMaxSpread) return;
   if(HasOpenPosition(symbol)) return;
   
   //--- Only process on new LTF bar (PER-SYMBOL, avoid multiple signals per candle)
   if(!IsNewBar(symbol)) return;
   
   //====================================================================
   // PHASE 1: KILL ZONE CHECK
   //====================================================================
   KillZone kz = CheckKillZone();
   if(!kz.isActive) return;
   
   //====================================================================
   // PHASE 2: IDENTIFY HTF LIQUIDITY LEVELS
   //====================================================================
   LiquidityLevel levels[];
   GetHTFLiquidityLevels(symbol, levels);
   if(ArraySize(levels) == 0) return;
   
   //====================================================================
   // PHASE 3: DETECT LIQUIDITY SWEEP
   // Price must sweep an HTF level (go beyond it) then reject
   //====================================================================
   SweepEvent sweep = DetectLiquiditySweep(symbol, levels);
   if(!sweep.occurred) return;
   
   Print("[", symbol, "] ✓ PHASE 3: Liquidity Sweep at ", sweep.levelPrice, 
         " (", sweep.levelSource, ") | Direction: ", sweep.direction == 1 ? "BULLISH" : "BEARISH");
   
   //====================================================================
   // PHASE 4: DETECT MSS / CISD (Market Structure Shift after sweep)
   // Must see displacement (strong candle breaking structure)
   //====================================================================
   MSS_Event mss = DetectMSS(symbol, sweep);
   if(!mss.occurred) return;
   
   Print("[", symbol, "] ✓ PHASE 4: MSS/CISD confirmed at ", mss.swingBreakPrice,
         " | Displacement: ", mss.displacementLow, " - ", mss.displacementHigh);
   
   //====================================================================
   // PHASE 5: FIND ENTRY - FVG/IFVG or OB in OTE Zone
   // FVG created by the displacement candle is the ideal entry
   //====================================================================
   TradeSetup setup = FindEntry(symbol, sweep, mss);
   if(!setup.valid) return;
   
   Print("[", symbol, "] ✓ PHASE 5: Entry found at ", setup.entry, " | ", setup.reason);
   
   //====================================================================
   // PHASE 6: CRT + SMT CONFIRMATION
   // These add confluence but aren't required (boost score)
   //====================================================================
   int confluenceBonus = 0;
   
   if(InpUseCRT)
   {
      CRT_Signal crt = CheckCRT(symbol, sweep.direction);
      if(crt.confirmed)
      {
         confluenceBonus++;
         setup.reason = setup.reason + " +CRT";
         Print("[", symbol, "] ✓ CRT Confirmed: Range ", crt.rangeLow, " - ", crt.rangeHigh);
      }
   }
   
   if(InpUseSMT)
   {
      SMT_Signal smt = CheckSMT(symbol, sweep.direction);
      if(smt.confirmed)
      {
         confluenceBonus++;
         setup.reason = setup.reason + " +SMT(" + smt.corrSymbol + ")";
         Print("[", symbol, "] ✓ SMT Divergence vs ", smt.corrSymbol);
      }
   }
   
   //--- SMC confirmation (market structure + premium/discount)
   if(InpUseSMC)
   {
      if(CheckSMC(symbol, sweep.direction))
      {
         confluenceBonus++;
         setup.reason = setup.reason + " +SMC";
         Print("[", symbol, "] ✓ SMC: in discount/premium zone");
      }
   }
   
   //--- Order Flow confirmation (institutional delivery)
   if(InpUseOrderFlow)
   {
      if(CheckOrderFlow(symbol, sweep.direction))
      {
         confluenceBonus++;
         setup.reason = setup.reason + " +OF";
         Print("[", symbol, "] ✓ Order Flow: delivery aligned");
      }
   }
   
   //--- Price Action confirmation (rejection at entry)
   if(InpUsePriceAction)
   {
      if(CheckPriceAction(symbol, sweep.direction))
      {
         confluenceBonus++;
         setup.reason = setup.reason + " +PA";
         Print("[", symbol, "] ✓ Price Action: rejection candle");
      }
   }
   
   setup.confluenceScore += confluenceBonus;
   
   //====================================================================
   // CONFLUENCE GATE - quality filter (skip low-confluence setups)
   //====================================================================
   if(InpUseConfluenceGate && setup.confluenceScore < InpMinConfluenceScore)
   {
      Print("[", symbol, "] ✗ Skipped: confluence score ", setup.confluenceScore,
            " < required ", InpMinConfluenceScore, " | ", setup.reason);
      return;
   }
   
   //====================================================================
   // PHASE 7: EXECUTE TRADE
   //====================================================================
   Print("[", symbol, "] ★ SETUP COMPLETE | Score: ", setup.confluenceScore, 
         " | ", setup.reason);
   ExecuteTrade(symbol, setup);
}

//+------------------------------------------------------------------+
//| PHASE 1: KILL ZONE CHECK                                           |
//+------------------------------------------------------------------+
KillZone CheckKillZone()
{
   KillZone kz;
   kz.isActive = false;
   kz.session = "";
   
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour;
   
   if(hour >= InpLondonStart && hour < InpLondonEnd)
   {
      kz.isActive = true;
      kz.session = "London";
   }
   else if(hour >= InpNYStart && hour < InpNYEnd)
   {
      kz.isActive = true;
      kz.session = "NY";
   }
   
   return kz;
}

//+------------------------------------------------------------------+
//| PHASE 2: GET HTF LIQUIDITY LEVELS                                  |
//| Sources: Previous Day H/L, Previous Week H/L, Swing H/L          |
//+------------------------------------------------------------------+
void GetHTFLiquidityLevels(string symbol, LiquidityLevel &levels[])
{
   ArrayResize(levels, 0);
   int count = 0;
   
   //--- Previous Day High/Low
   if(InpUsePDHL)
   {
      double pdh = iHigh(symbol, PERIOD_D1, 1);
      double pdl = iLow(symbol, PERIOD_D1, 1);
      
      ArrayResize(levels, count + 2);
      levels[count].price = pdh;
      levels[count].source = "PDH";
      levels[count].isBuySide = true;
      count++;
      levels[count].price = pdl;
      levels[count].source = "PDL";
      levels[count].isBuySide = false;
      count++;
   }
   
   //--- Previous Week High/Low
   if(InpUsePWHL)
   {
      double pwh = iHigh(symbol, PERIOD_W1, 1);
      double pwl = iLow(symbol, PERIOD_W1, 1);
      
      ArrayResize(levels, count + 2);
      levels[count].price = pwh;
      levels[count].source = "PWH";
      levels[count].isBuySide = true;
      count++;
      levels[count].price = pwl;
      levels[count].source = "PWL";
      levels[count].isBuySide = false;
      count++;
   }
   
   //--- HTF Swing High/Low
   double swHigh = 0, swLow = DBL_MAX;
   for(int i = 1; i <= InpLiq_Lookback; i++)
   {
      double h = iHigh(symbol, InpHTF, i);
      double l = iLow(symbol, InpHTF, i);
      if(h > swHigh) swHigh = h;
      if(l < swLow)  swLow = l;
   }
   
   ArrayResize(levels, count + 2);
   levels[count].price = swHigh;
   levels[count].source = "SwingH";
   levels[count].isBuySide = true;
   count++;
   levels[count].price = swLow;
   levels[count].source = "SwingL";
   levels[count].isBuySide = false;
   count++;
   
   //--- Asian Session Range (if enabled)
   if(InpAsianFilter)
   {
      double asianHigh = 0, asianLow = DBL_MAX;
      MqlDateTime dt;
      
      for(int i = 1; i < 100; i++)
      {
         datetime barTime = iTime(symbol, InpLTF, i);
         TimeToStruct(barTime, dt);
         // Asian session: roughly 0:00 - 2:00 server time (adjust per broker)
         if(dt.hour >= 0 && dt.hour < 2 && dt.day == dt.day)
         {
            double h = iHigh(symbol, InpLTF, i);
            double l = iLow(symbol, InpLTF, i);
            if(h > asianHigh) asianHigh = h;
            if(l < asianLow)  asianLow = l;
         }
      }
      
      if(asianHigh > 0 && asianLow < DBL_MAX)
      {
         ArrayResize(levels, count + 2);
         levels[count].price = asianHigh;
         levels[count].source = "AsianH";
         levels[count].isBuySide = true;
         count++;
         levels[count].price = asianLow;
         levels[count].source = "AsianL";
         levels[count].isBuySide = false;
         count++;
      }
   }
}

//+------------------------------------------------------------------+
//| PHASE 3: DETECT LIQUIDITY SWEEP                                    |
//| Price sweeps beyond a level then closes back inside                |
//| This is the "stop hunt" / liquidity grab                           |
//+------------------------------------------------------------------+
SweepEvent DetectLiquiditySweep(string symbol, LiquidityLevel &levels[])
{
   SweepEvent sweep;
   sweep.occurred = false;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double threshold = InpLiq_Threshold * point;
   
   //--- Check last few LTF candles for a sweep
   for(int bar = 1; bar <= 3; bar++)
   {
      double high = iHigh(symbol, InpLTF, bar);
      double low  = iLow(symbol, InpLTF, bar);
      double close = iClose(symbol, InpLTF, bar);
      
      for(int lev = 0; lev < ArraySize(levels); lev++)
      {
         double level = levels[lev].price;
         
         //--- Sweep of BSL (Buy Side Liquidity) → Bearish setup
         if(levels[lev].isBuySide)
         {
            // Wick went above the level but close came back below
            if(high > level + threshold && close < level)
            {
               sweep.occurred = true;
               sweep.levelPrice = level;
               sweep.levelSource = levels[lev].source;
               sweep.direction = -1; // Bearish after BSL sweep
               sweep.time = iTime(symbol, InpLTF, bar);
               sweep.candleIndex = bar;
               return sweep;
            }
         }
         //--- Sweep of SSL (Sell Side Liquidity) → Bullish setup
         else
         {
            // Wick went below the level but close came back above
            if(low < level - threshold && close > level)
            {
               sweep.occurred = true;
               sweep.levelPrice = level;
               sweep.levelSource = levels[lev].source;
               sweep.direction = 1; // Bullish after SSL sweep
               sweep.time = iTime(symbol, InpLTF, bar);
               sweep.candleIndex = bar;
               return sweep;
            }
         }
      }
   }
   
   return sweep;
}

//+------------------------------------------------------------------+
//| PHASE 4: DETECT MSS / CISD                                        |
//| After the sweep, look for Market Structure Shift:                  |
//| - Bullish MSS: breaks above most recent swing high (after SSL)    |
//| - Bearish MSS: breaks below most recent swing low (after BSL)     |
//| The candle that breaks must show displacement (strong body)        |
//+------------------------------------------------------------------+
MSS_Event DetectMSS(string symbol, SweepEvent &sweep)
{
   MSS_Event mss;
   mss.occurred = false;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double atr = InpUseATR ? GetATR(symbol, InpLTF, InpATR_Period) : 0;
   double minDisp = (atr > 0) ? InpMSS_Disp_ATR * atr : InpMSS_MinDisplacement * point;
   
   //--- Find the swing to break (opposite side of sweep)
   double swingToBreak = 0;
   
   // Look at candles BEFORE the sweep to find the swing
   int startBar = sweep.candleIndex + 1;
   int endBar = startBar + InpMSS_Lookback;
   
   if(sweep.direction == 1) // Bullish — need to break swing HIGH
   {
      for(int i = startBar; i <= endBar && i < 50; i++)
      {
         double h = iHigh(symbol, InpLTF, i);
         // Find a local swing high (higher than neighbors)
         if(i > startBar)
         {
            double prevH = iHigh(symbol, InpLTF, i+1);
            double nextH = iHigh(symbol, InpLTF, i-1);
            if(h > prevH && h > nextH)
            {
               swingToBreak = h;
               break;
            }
         }
         if(swingToBreak == 0) swingToBreak = h; // fallback: highest
         else if(h > swingToBreak) swingToBreak = h;
      }
   }
   else // Bearish — need to break swing LOW
   {
      swingToBreak = DBL_MAX;
      for(int i = startBar; i <= endBar && i < 50; i++)
      {
         double l = iLow(symbol, InpLTF, i);
         if(i > startBar)
         {
            double prevL = iLow(symbol, InpLTF, i+1);
            double nextL = iLow(symbol, InpLTF, i-1);
            if(l < prevL && l < nextL)
            {
               swingToBreak = l;
               break;
            }
         }
         if(swingToBreak == DBL_MAX) swingToBreak = l;
         else if(l < swingToBreak) swingToBreak = l;
      }
   }
   
   if(swingToBreak == 0 || swingToBreak == DBL_MAX) return mss;
   
   //--- Look at candles AFTER the sweep for the break (MSS)
   for(int i = sweep.candleIndex - 1; i >= 0; i--)
   {
      double open_i  = iOpen(symbol, InpLTF, i);
      double close_i = iClose(symbol, InpLTF, i);
      double high_i  = iHigh(symbol, InpLTF, i);
      double low_i   = iLow(symbol, InpLTF, i);
      double body    = MathAbs(close_i - open_i);
      
      if(sweep.direction == 1) // Bullish MSS: close above swing high with displacement
      {
         if(close_i > swingToBreak && body >= minDisp && close_i > open_i)
         {
            mss.occurred = true;
            mss.direction = 1;
            mss.swingBreakPrice = swingToBreak;
            mss.displacementHigh = high_i;
            mss.displacementLow = low_i;
            mss.candleIndex = i;
            return mss;
         }
      }
      else // Bearish MSS: close below swing low with displacement
      {
         if(close_i < swingToBreak && body >= minDisp && close_i < open_i)
         {
            mss.occurred = true;
            mss.direction = -1;
            mss.swingBreakPrice = swingToBreak;
            mss.displacementHigh = high_i;
            mss.displacementLow = low_i;
            mss.candleIndex = i;
            return mss;
         }
      }
   }
   
   return mss;
}

//+------------------------------------------------------------------+
//| PHASE 5: FIND ENTRY (FVG/IFVG/OB in OTE Zone)                    |
//| After MSS, the displacement creates a FVG — that's our entry      |
//| If FVG overlaps with OB = highest probability (unicorn setup)     |
//+------------------------------------------------------------------+
TradeSetup FindEntry(string symbol, SweepEvent &sweep, MSS_Event &mss)
{
   TradeSetup setup;
   setup.valid = false;
   setup.confluenceScore = 3; // Base: Sweep + MSS + KZ
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double currentPrice = (mss.direction == 1) ? ask : bid;
   
   //--- ATR-based SL buffer (auto-scales per instrument; avoids noise stop-outs)
   double atr = InpUseATR ? GetATR(symbol, InpLTF, InpATR_Period) : 0;
   double slBuffer = (atr > 0) ? InpSL_ATR_Mult * atr : 10 * point;
   
   //--- Calculate OTE Zone (62%-79% retracement of displacement)
   OTE_Zone ote;
   ote.valid = false;
   
   if(mss.direction == 1) // Bullish: retrace down into OTE
   {
      double range = mss.displacementHigh - mss.displacementLow;
      ote.high = mss.displacementHigh - range * InpOTE_FibStart; // 62%
      ote.low  = mss.displacementHigh - range * InpOTE_FibEnd;   // 79%
      ote.valid = true;
   }
   else // Bearish: retrace up into OTE
   {
      double range = mss.displacementHigh - mss.displacementLow;
      ote.low  = mss.displacementLow + range * InpOTE_FibStart; // 62%
      ote.high = mss.displacementLow + range * InpOTE_FibEnd;   // 79%
      ote.valid = true;
   }
   
   //--- Search for FVG created by displacement
   FVG_Zone fvg;
   bool fvgFound = FindFVGAfterMSS(symbol, mss, fvg);
   
   //--- Search for Order Block before displacement
   OrderBlock ob;
   bool obFound = false;
   if(InpUseOB)
      obFound = FindOBBeforeMSS(symbol, mss, ob);
   
   //--- Determine best entry
   bool entryFound = false;
   double entryPrice = 0, slPrice = 0;
   string entryReason = "";
   
   //--- PRIORITY 1: FVG inside OTE zone (highest probability)
   if(fvgFound)
   {
      bool inOTE = true;
      if(InpRequireOTE && ote.valid)
      {
         if(mss.direction == 1)
            inOTE = (fvg.low <= ote.high && fvg.high >= ote.low);
         else
            inOTE = (fvg.high >= ote.low && fvg.low <= ote.high);
      }
      
      if(inOTE)
      {
         // Check if price is currently at the FVG
         if(mss.direction == 1 && currentPrice >= fvg.low && currentPrice <= fvg.high)
         {
            entryFound = true;
            entryPrice = ask;
            slPrice = fvg.low - slBuffer;
            entryReason = fvg.isInverse ? "IFVG" : "FVG";
            if(InpRequireOTE) entryReason += "+OTE";
            setup.confluenceScore++;
         }
         else if(mss.direction == -1 && currentPrice <= fvg.high && currentPrice >= fvg.low)
         {
            entryFound = true;
            entryPrice = bid;
            slPrice = fvg.high + slBuffer;
            entryReason = fvg.isInverse ? "IFVG" : "FVG";
            if(InpRequireOTE) entryReason += "+OTE";
            setup.confluenceScore++;
         }
      }
   }
   
   //--- PRIORITY 2: Order Block inside OTE zone
   if(!entryFound && obFound)
   {
      bool inOTE = true;
      if(InpRequireOTE && ote.valid)
      {
         if(mss.direction == 1)
            inOTE = (ob.low <= ote.high && ob.high >= ote.low);
         else
            inOTE = (ob.high >= ote.low && ob.low <= ote.high);
      }
      
      if(inOTE)
      {
         if(mss.direction == 1 && currentPrice >= ob.low && currentPrice <= ob.high)
         {
            entryFound = true;
            entryPrice = ask;
            slPrice = ob.low - slBuffer;
            entryReason = "OB";
            if(InpRequireOTE) entryReason += "+OTE";
            setup.confluenceScore++;
         }
         else if(mss.direction == -1 && currentPrice <= ob.high && currentPrice >= ob.low)
         {
            entryFound = true;
            entryPrice = bid;
            slPrice = ob.high + slBuffer;
            entryReason = "OB";
            if(InpRequireOTE) entryReason += "+OTE";
            setup.confluenceScore++;
         }
      }
   }
   
   //--- BONUS: FVG + OB overlap (Unicorn setup)
   if(fvgFound && obFound)
   {
      // Check if FVG and OB overlap
      if(fvg.low <= ob.high && fvg.high >= ob.low)
      {
         setup.confluenceScore += 2; // Unicorn bonus
         entryReason = "UNICORN(FVG+OB)";
         if(InpRequireOTE) entryReason += "+OTE";
      }
   }
   
   if(!entryFound) return setup;
   
   //--- HTF BIAS FILTER: only trade in the higher-timeframe direction
   if(InpUseHTFBias)
   {
      int htfBias = GetHTFBias(symbol);
      if(htfBias != 0 && htfBias != mss.direction)
         return setup; // entry against HTF bias -> skip
   }
   
   //--- Calculate TP based on RR
   double riskDistance = MathAbs(entryPrice - slPrice);
   
   //--- ATR-based SL distance sanity (skip noise-tight & oversized stops)
   if(atr > 0)
   {
      double minSL = InpMinSL_ATR_Mult * atr;
      double maxSL = InpMaxSL_ATR_Mult * atr;
      // Enforce a minimum stop distance so spread/noise can't stop us out instantly
      if(riskDistance < minSL)
      {
         if(mss.direction == 1) slPrice = entryPrice - minSL;
         else                   slPrice = entryPrice + minSL;
         riskDistance = minSL;
      }
      // Skip setups whose structure stop is unreasonably far
      if(riskDistance > maxSL) return setup;
   }
   
   double tpPrice = 0;
   if(mss.direction == 1)
      tpPrice = entryPrice + riskDistance * InpRR_Ratio;
   else
      tpPrice = entryPrice - riskDistance * InpRR_Ratio;
   
   //--- Validate RR
   if(riskDistance <= 0) return setup;
   
   //--- Build final setup
   setup.valid = true;
   setup.direction = mss.direction;
   setup.entry = entryPrice;
   setup.sl = slPrice;
   setup.tp = tpPrice;
   setup.reason = "Sweep(" + sweep.levelSource + ")→MSS→" + entryReason;
   
   return setup;
}

//+------------------------------------------------------------------+
//| Find FVG created by or after MSS displacement                      |
//+------------------------------------------------------------------+
bool FindFVGAfterMSS(string symbol, MSS_Event &mss, FVG_Zone &resultFVG)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double atr = InpUseATR ? GetATR(symbol, InpLTF, InpATR_Period) : 0;
   double minSize = (atr > 0) ? InpFVG_ATR_Mult * atr : InpFVG_MinSize * point;
   
   int startBar = mss.candleIndex;
   int endBar = MathMax(0, startBar - InpFVG_Lookback);
   
   for(int i = startBar; i > endBar && i >= 2; i--)
   {
      double high1 = iHigh(symbol, InpLTF, i + 1);  // Candle before
      double low3  = iLow(symbol, InpLTF, i - 1);   // Candle after
      double high3 = iHigh(symbol, InpLTF, i - 1);
      double low1  = iLow(symbol, InpLTF, i + 1);
      
      if(mss.direction == 1) // Bullish FVG
      {
         double gapHigh = low3;   // Low of candle 3
         double gapLow  = high1;  // High of candle 1
         
         if(gapHigh > gapLow && (gapHigh - gapLow) >= minSize)
         {
            resultFVG.high = gapHigh;
            resultFVG.low = gapLow;
            resultFVG.time = iTime(symbol, InpLTF, i);
            resultFVG.isBullish = true;
            resultFVG.isInverse = false;
            resultFVG.candleIndex = i;
            return true;
         }
      }
      else // Bearish FVG
      {
         double gapHigh = low1;   // Low of candle 1
         double gapLow  = high3;  // High of candle 3
         
         if(gapHigh > gapLow && (gapHigh - gapLow) >= minSize)
         {
            resultFVG.high = gapHigh;
            resultFVG.low = gapLow;
            resultFVG.time = iTime(symbol, InpLTF, i);
            resultFVG.isBullish = false;
            resultFVG.isInverse = false;
            resultFVG.candleIndex = i;
            return true;
         }
      }
   }
   
   //--- Also check for IFVG (previously filled FVG now acting as S/R)
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   for(int i = startBar + 1; i < startBar + InpFVG_Lookback && i < 50; i++)
   {
      double high1 = iHigh(symbol, InpLTF, i + 1);
      double low3  = iLow(symbol, InpLTF, i - 1);
      double high3 = iHigh(symbol, InpLTF, i - 1);
      double low1  = iLow(symbol, InpLTF, i + 1);
      
      if(mss.direction == 1)
      {
         double gapHigh = low3;
         double gapLow  = high1;
         
         if(gapHigh > gapLow && (gapHigh - gapLow) >= minSize)
         {
            // Check if FVG was filled (price went through it) = IFVG
            bool wasFilled = false;
            for(int j = i - 2; j >= 0; j--)
            {
               if(iLow(symbol, InpLTF, j) < gapLow)
               {
                  wasFilled = true;
                  break;
               }
            }
            
            if(wasFilled && ask >= gapLow && ask <= gapHigh)
            {
               resultFVG.high = gapHigh;
               resultFVG.low = gapLow;
               resultFVG.time = iTime(symbol, InpLTF, i);
               resultFVG.isBullish = true;
               resultFVG.isInverse = true; // IFVG!
               resultFVG.candleIndex = i;
               return true;
            }
         }
      }
      else
      {
         double gapHigh = low1;
         double gapLow  = high3;
         
         if(gapHigh > gapLow && (gapHigh - gapLow) >= minSize)
         {
            bool wasFilled = false;
            for(int j = i - 2; j >= 0; j--)
            {
               if(iHigh(symbol, InpLTF, j) > gapHigh)
               {
                  wasFilled = true;
                  break;
               }
            }
            
            if(wasFilled && bid <= gapHigh && bid >= gapLow)
            {
               resultFVG.high = gapHigh;
               resultFVG.low = gapLow;
               resultFVG.time = iTime(symbol, InpLTF, i);
               resultFVG.isBullish = false;
               resultFVG.isInverse = true;
               resultFVG.candleIndex = i;
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Find Order Block before MSS (last opposing candle before move)    |
//+------------------------------------------------------------------+
bool FindOBBeforeMSS(string symbol, MSS_Event &mss, OrderBlock &resultOB)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minBody = InpOB_MinBody * point;
   
   int startBar = mss.candleIndex + 1;
   int endBar = startBar + InpOB_Lookback;
   
   for(int i = startBar; i <= endBar && i < 50; i++)
   {
      double open_i  = iOpen(symbol, InpLTF, i);
      double close_i = iClose(symbol, InpLTF, i);
      double high_i  = iHigh(symbol, InpLTF, i);
      double low_i   = iLow(symbol, InpLTF, i);
      double body    = MathAbs(open_i - close_i);
      
      if(body < minBody) continue;
      
      //--- Bullish OB: Last bearish candle before bullish displacement
      if(mss.direction == 1 && close_i < open_i)
      {
         resultOB.high = high_i;
         resultOB.low = low_i;
         resultOB.time = iTime(symbol, InpLTF, i);
         resultOB.isBullish = true;
         resultOB.candleIndex = i;
         return true;
      }
      //--- Bearish OB: Last bullish candle before bearish displacement
      else if(mss.direction == -1 && close_i > open_i)
      {
         resultOB.high = high_i;
         resultOB.low = low_i;
         resultOB.time = iTime(symbol, InpLTF, i);
         resultOB.isBullish = false;
         resultOB.candleIndex = i;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| PHASE 6A: CRT MODEL (Candle Range Theory)                         |
//| Previous candle (H1) sets range → current candle sweeps one side  |
//| then expands to opposite = confirms direction                      |
//+------------------------------------------------------------------+
CRT_Signal CheckCRT(string symbol, int direction)
{
   CRT_Signal crt;
   crt.confirmed = false;
   crt.direction = 0;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double buffer = InpCRT_SweepBuffer * point;
   
   //--- Previous candle range (the "setup" candle)
   double prevHigh  = iHigh(symbol, InpCRT_TF, 1);
   double prevLow   = iLow(symbol, InpCRT_TF, 1);
   double prevRange = prevHigh - prevLow;
   
   if(prevRange <= 0) return crt;
   
   //--- Current candle
   double currHigh  = iHigh(symbol, InpCRT_TF, 0);
   double currLow   = iLow(symbol, InpCRT_TF, 0);
   double currClose = iClose(symbol, InpCRT_TF, 0);
   double currOpen  = iOpen(symbol, InpCRT_TF, 0);
   
   crt.rangeHigh = prevHigh;
   crt.rangeLow = prevLow;
   
   //--- Bullish CRT: Swept below previous low → expanding up
   if(direction == 1)
   {
      bool sweptLow = (currLow < prevLow - buffer);
      bool closedAboveMid = (currClose > prevLow + prevRange * 0.5);
      
      if(sweptLow && closedAboveMid)
      {
         crt.confirmed = true;
         crt.direction = 1;
      }
   }
   //--- Bearish CRT: Swept above previous high → expanding down
   else if(direction == -1)
   {
      bool sweptHigh = (currHigh > prevHigh + buffer);
      bool closedBelowMid = (currClose < prevHigh - prevRange * 0.5);
      
      if(sweptHigh && closedBelowMid)
      {
         crt.confirmed = true;
         crt.direction = -1;
      }
   }
   
   return crt;
}

//+------------------------------------------------------------------+
//| PHASE 6B: SMT DIVERGENCE                                           |
//| Compare main symbol with correlated pair                           |
//| Divergence = one makes new extreme, other doesn't = reversal      |
//+------------------------------------------------------------------+
SMT_Signal CheckSMT(string symbol, int direction)
{
   SMT_Signal smt;
   smt.confirmed = false;
   smt.direction = 0;
   smt.corrSymbol = "";
   
   //--- Get correlation pair
   string corrSymbol = "";
   bool isInverse = true;
   
   if(StringFind(symbol, "EURUSD") >= 0)
   {  corrSymbol = InpSMT_EURUSD; isInverse = true;  }
   else if(StringFind(symbol, "XAUUSD") >= 0 || StringFind(symbol, "GOLD") >= 0)
   {  corrSymbol = InpSMT_XAUUSD; isInverse = true;  }
   else if(StringFind(symbol, "NAS") >= 0 || StringFind(symbol, "US100") >= 0 || StringFind(symbol, "USTEC") >= 0)
   {  corrSymbol = InpSMT_NAS100; isInverse = false; }
   else
      return smt;
   
   //--- Try to select correlation symbol (multiple name attempts)
   if(!SymbolSelect(corrSymbol, true))
   {
      // Try common alternatives
      string alts[];
      if(corrSymbol == "USDX" || corrSymbol == "DXY")
      {
         string tryNames[] = {"USDX", "DXY", "USDX.", "DXY.", "USDollarIndex"};
         for(int a = 0; a < ArraySize(tryNames); a++)
         {
            if(SymbolSelect(tryNames[a], true)) { corrSymbol = tryNames[a]; break; }
         }
      }
      else if(corrSymbol == "US500" || corrSymbol == "SP500")
      {
         string tryNames[] = {"US500", "SP500", "SPX500", "US500.", "SP500m"};
         for(int a = 0; a < ArraySize(tryNames); a++)
         {
            if(SymbolSelect(tryNames[a], true)) { corrSymbol = tryNames[a]; break; }
         }
      }
      
      if(!SymbolSelect(corrSymbol, true))
         return smt; // Can't find the symbol
   }
   
   smt.corrSymbol = corrSymbol;
   
   //--- Find swing extremes for both symbols
   double mainHigh = 0, mainLow = DBL_MAX;
   double corrHigh = 0, corrLow = DBL_MAX;
   
   for(int i = 1; i <= InpSMT_Lookback; i++)
   {
      double mh = iHigh(symbol, InpLTF, i);
      double ml = iLow(symbol, InpLTF, i);
      double ch = iHigh(corrSymbol, InpLTF, i);
      double cl = iLow(corrSymbol, InpLTF, i);
      
      if(mh > mainHigh) mainHigh = mh;
      if(ml < mainLow)  mainLow = ml;
      if(ch > corrHigh) corrHigh = ch;
      if(cl < corrLow)  corrLow = cl;
   }
   
   //--- Current values
   double mainCurrHigh = iHigh(symbol, InpLTF, 0);
   double mainCurrLow  = iLow(symbol, InpLTF, 0);
   double corrCurrHigh = iHigh(corrSymbol, InpLTF, 0);
   double corrCurrLow  = iLow(corrSymbol, InpLTF, 0);
   
   //--- Bullish SMT: Main makes new low, correlated doesn't confirm
   if(direction == 1)
   {
      bool mainNewLow = (mainCurrLow < mainLow);
      
      if(isInverse)
      {
         // If EURUSD makes new low, DXY should make new high. If not = divergence
         bool corrNoNewHigh = (corrCurrHigh <= corrHigh);
         if(mainNewLow && corrNoNewHigh)
         { smt.confirmed = true; smt.direction = 1; }
      }
      else
      {
         // If NAS100 makes new low, SP500 should too. If not = divergence
         bool corrNoNewLow = (corrCurrLow >= corrLow);
         if(mainNewLow && corrNoNewLow)
         { smt.confirmed = true; smt.direction = 1; }
      }
   }
   //--- Bearish SMT: Main makes new high, correlated doesn't confirm
   else if(direction == -1)
   {
      bool mainNewHigh = (mainCurrHigh > mainHigh);
      
      if(isInverse)
      {
         // If EURUSD makes new high, DXY should make new low. If not = divergence
         bool corrNoNewLow = (corrCurrLow >= corrLow);
         if(mainNewHigh && corrNoNewLow)
         { smt.confirmed = true; smt.direction = -1; }
      }
      else
      {
         // If NAS100 makes new high, SP500 should too. If not = divergence
         bool corrNoNewHigh = (corrCurrHigh <= corrHigh);
         if(mainNewHigh && corrNoNewHigh)
         { smt.confirmed = true; smt.direction = -1; }
      }
   }
   
   return smt;
}

//+------------------------------------------------------------------+
//| PHASE 7: EXECUTE TRADE                                             |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, TradeSetup &setup)
{
   double lotSize = CalculateLotSize(symbol, MathAbs(setup.entry - setup.sl));
   if(lotSize <= 0) return;
   
   //--- Set correct filling mode for this symbol (avoids trade failures)
   SetFillingForSymbol(symbol);
   
   bool result = false;
   
   if(setup.direction == 1)
      result = trade.Buy(lotSize, symbol, setup.entry, setup.sl, setup.tp, setup.reason);
   else
      result = trade.Sell(lotSize, symbol, setup.entry, setup.sl, setup.tp, setup.reason);
   
   if(result)
   {
      todayTrades++;
      Print("╔══════════════════════════════════════╗");
      Print("║         ★ TRADE EXECUTED ★           ║");
      Print("╠══════════════════════════════════════╣");
      Print("║ Symbol: ", symbol);
      Print("║ Dir:    ", setup.direction == 1 ? "BUY ↑" : "SELL ↓");
      Print("║ Entry:  ", setup.entry);
      Print("║ SL:     ", setup.sl);
      Print("║ TP:     ", setup.tp);
      Print("║ Lot:    ", lotSize);
      Print("║ Score:  ", setup.confluenceScore, " confluences");
      Print("║ Reason: ", setup.reason);
      Print("╚══════════════════════════════════════╝");
   }
   else
   {
      Print("✗ Trade FAILED: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| CALCULATE LOT SIZE (Risk-based + Prop Firm aware)                  |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double slDistance)
{
   if(slDistance <= 0) return 0;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
   //--- Base risk amount (normal % risk)
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   
   //========================================================
   // PROP FIRM: Cap the risk so a single SL hit can NEVER
   // breach the daily or max loss limits
   //========================================================
   if(InpPropFirmMode)
   {
      // Hard cap: never risk more than X% of account size
      double hardCap = InpAccountSize * (InpMaxRiskCapPercent / 100.0);
      
      // Remaining room before hitting daily safety threshold
      double dailyRoom = GetRemainingDailyAllowance();
      
      // Remaining room before hitting max-loss safety threshold
      double maxRoom = GetRemainingMaxAllowance();
      
      // Risk must respect ALL constraints (take the smallest)
      riskAmount = MathMin(riskAmount, hardCap);
      riskAmount = MathMin(riskAmount, dailyRoom);
      riskAmount = MathMin(riskAmount, maxRoom);
      
      // If no room left, don't trade
      if(riskAmount <= 0)
      {
         Print("⚠️ No risk room left (daily/max limit). Skipping trade on ", symbol);
         return 0;
      }
   }
   
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickValue <= 0 || tickSize <= 0) return 0;
   
   double lotSize = riskAmount / ((slDistance / tickSize) * tickValue);
   
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   //--- Prop firm: verify the actual $ risk at this lot doesn't exceed room
   if(InpPropFirmMode)
   {
      double actualRisk = (slDistance / tickSize) * tickValue * lotSize;
      double dailyRoom = GetRemainingDailyAllowance();
      
      // If even the minimum lot risks more than our daily room → skip
      if(actualRisk > dailyRoom && lotSize <= minLot)
      {
         Print("⚠️ Min lot risk ($", DoubleToString(actualRisk, 2), 
               ") exceeds daily room ($", DoubleToString(dailyRoom, 2), "). Skipping ", symbol);
         return 0;
      }
   }
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| CHECK IF POSITION EXISTS                                           |
//+------------------------------------------------------------------+
bool HasOpenPosition(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| NEW BAR DETECTION (per-symbol)                                     |
//| Returns true only once per new LTF candle for each symbol          |
//+------------------------------------------------------------------+
bool IsNewBar(string symbol)
{
   static string   syms[];
   static datetime times[];

   int idx = -1;
   for(int i = 0; i < ArraySize(syms); i++)
   {
      if(syms[i] == symbol) { idx = i; break; }
   }
   if(idx == -1)
   {
      idx = ArraySize(syms);
      ArrayResize(syms,  idx + 1);
      ArrayResize(times, idx + 1);
      syms[idx]  = symbol;
      times[idx] = 0;
   }

   datetime cur = iTime(symbol, InpLTF, 0);
   if(cur == times[idx]) return false;
   times[idx] = cur;
   return true;
}

//+------------------------------------------------------------------+
//| SET CORRECT FILLING MODE FOR SYMBOL                                |
//| Avoids "Unsupported filling mode" trade failures                   |
//+------------------------------------------------------------------+
void SetFillingForSymbol(string symbol)
{
   long filling = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) != 0)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((filling & SYMBOL_FILLING_IOC) != 0)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

//+------------------------------------------------------------------+
//| ATR VALUE (with handle caching per symbol/timeframe/period)        |
//| Returns the ATR of the last CLOSED candle. 0 if unavailable.       |
//+------------------------------------------------------------------+
double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   static string keys[];
   static int    handles[];

   string key = symbol + "_" + (string)tf + "_" + (string)period;
   int idx = -1;
   for(int i = 0; i < ArraySize(keys); i++)
   {
      if(keys[i] == key) { idx = i; break; }
   }
   if(idx == -1)
   {
      int h = iATR(symbol, tf, period);
      if(h == INVALID_HANDLE) return 0;
      idx = ArraySize(keys);
      ArrayResize(keys, idx + 1);
      ArrayResize(handles, idx + 1);
      keys[idx] = key;
      handles[idx] = h;
   }

   double buf[];
   if(CopyBuffer(handles[idx], 0, 1, 1, buf) <= 0) return 0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| EMA VALUE (with handle caching per symbol/timeframe/period)        |
//+------------------------------------------------------------------+
double GetEMA(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   static string keys[];
   static int    handles[];

   string key = symbol + "_ema_" + (string)tf + "_" + (string)period;
   int idx = -1;
   for(int i = 0; i < ArraySize(keys); i++)
   {
      if(keys[i] == key) { idx = i; break; }
   }
   if(idx == -1)
   {
      int h = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
      if(h == INVALID_HANDLE) return 0;
      idx = ArraySize(keys);
      ArrayResize(keys, idx + 1);
      ArrayResize(handles, idx + 1);
      keys[idx] = key;
      handles[idx] = h;
   }

   double buf[];
   if(CopyBuffer(handles[idx], 0, 1, 1, buf) <= 0) return 0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| HTF BIAS (higher-timeframe direction filter)                       |
//| 1 = bullish, -1 = bearish, 0 = unclear                             |
//+------------------------------------------------------------------+
int GetHTFBias(string symbol)
{
   double ema = GetEMA(symbol, InpHTF, InpHTF_EMA_Period);
   if(ema <= 0) return 0;

   double close1 = iClose(symbol, InpHTF, 1);
   if(close1 <= 0) return 0;

   if(close1 > ema) return 1;   // price above HTF EMA -> bullish
   if(close1 < ema) return -1;  // price below HTF EMA -> bearish
   return 0;
}

//+------------------------------------------------------------------+
//| SMC CONFIRMATION                                                   |
//| Confirms the entry aligns with Smart Money Concepts:               |
//|  - internal market structure agrees with direction                |
//|  - price is in Discount (for buys) / Premium (for sells) zone      |
//| Returns true if confirmed.                                         |
//+------------------------------------------------------------------+
bool CheckSMC(string symbol, int direction)
{
   //--- Build the recent dealing range (highest high / lowest low)
   double rangeHigh = 0, rangeLow = DBL_MAX;
   for(int i = 1; i <= InpSMC_StructLookback; i++)
   {
      double h = iHigh(symbol, InpLTF, i);
      double l = iLow(symbol, InpLTF, i);
      if(h > rangeHigh) rangeHigh = h;
      if(l < rangeLow)  rangeLow = l;
   }
   if(rangeHigh <= rangeLow) return false;

   double mid = (rangeHigh + rangeLow) / 2.0;   // equilibrium (50%)
   double price = iClose(symbol, InpLTF, 0);

   //--- Premium/Discount logic:
   //    Buys want DISCOUNT (price below equilibrium)
   //    Sells want PREMIUM (price above equilibrium)
   if(direction == 1 && price <= mid) return true;
   if(direction == -1 && price >= mid) return true;

   return false;
}

//+------------------------------------------------------------------+
//| ORDER FLOW CONFIRMATION                                            |
//| Confirms institutional delivery: a run of strong-bodied candles    |
//| in the trade direction (consistent order flow / no churn).         |
//+------------------------------------------------------------------+
bool CheckOrderFlow(string symbol, int direction)
{
   int agree = 0;
   for(int i = 1; i <= InpOF_Lookback; i++)
   {
      double o = iOpen(symbol, InpLTF, i);
      double c = iClose(symbol, InpLTF, i);
      double h = iHigh(symbol, InpLTF, i);
      double l = iLow(symbol, InpLTF, i);
      double range = h - l;
      if(range <= 0) continue;

      double body = MathAbs(c - o);
      double bodyRatio = body / range;

      // Strong candle delivering in the trade direction
      if(direction == 1 && c > o && bodyRatio >= InpOF_BodyRatio) agree++;
      else if(direction == -1 && c < o && bodyRatio >= InpOF_BodyRatio) agree++;
   }
   // Need at least half of the lookback candles delivering in our direction
   return (agree >= (int)MathCeil(InpOF_Lookback / 2.0));
}

//+------------------------------------------------------------------+
//| PRICE ACTION CONFIRMATION                                          |
//| Confirms the last closed candle shows a rejection in our favour    |
//| (long lower wick for buys / long upper wick for sells).            |
//+------------------------------------------------------------------+
bool CheckPriceAction(string symbol, int direction)
{
   double o = iOpen(symbol, InpLTF, 1);
   double c = iClose(symbol, InpLTF, 1);
   double h = iHigh(symbol, InpLTF, 1);
   double l = iLow(symbol, InpLTF, 1);
   double range = h - l;
   if(range <= 0) return false;

   double upperWick = h - MathMax(o, c);
   double lowerWick = MathMin(o, c) - l;

   if(direction == 1)
   {
      // Bullish rejection: long lower wick + close in upper half
      bool rejection = (lowerWick / range) >= InpPA_RejWickRatio;
      bool closesUp  = c >= (l + range * 0.5);
      return (rejection || closesUp);
   }
   else if(direction == -1)
   {
      // Bearish rejection: long upper wick + close in lower half
      bool rejection = (upperWick / range) >= InpPA_RejWickRatio;
      bool closesDown = c <= (h - range * 0.5);
      return (rejection || closesDown);
   }
   return false;
}
//+------------------------------------------------------------------+
