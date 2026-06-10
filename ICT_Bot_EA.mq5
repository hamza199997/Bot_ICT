//+------------------------------------------------------------------+
//|                                          ICT_Bot_EA.mq5          |
//|           ICT/SMC Strategy - v4.0 UPGRADED                        |
//|           OB + FVG + Sweep + CHoCH/BOS + OTE + RSI Divergence    |
//|           Kill Zones + Trailing + Prop Firm Protection            |
//+------------------------------------------------------------------+
#property copyright "ICT Bot v4.0 - CHoCH/OTE/RSI Upgrade"
#property version   "4.00"
#property strict
#property description "ICT/SMC v4: Sweep + CHoCH/BOS + OTE Fib + RSI Div | Kill Zones"
#property description "Quality entries over quantity — institutional precision"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- Symbol & Timeframe
input ENUM_TIMEFRAMES InpHTF         = PERIOD_H4;     // HTF: Bias (EMA direction)
input ENUM_TIMEFRAMES InpLTF         = PERIOD_M15;    // LTF: Entry detection (match chart TF!)

//--- [NEW] Kill Zone Filter (ICT precise windows — EST-based)
input bool     InpKillZoneOn         = true;  // Enable Kill Zone Filter
input int      InpServerUTCOffset    = 3;     // Server UTC Offset (3 for summer DST)
input int      InpLondonKZStart      = 2;     // London Kill Zone Start (EST hour)
input int      InpLondonKZEnd        = 5;     // London Kill Zone End (EST hour)
input int      InpNYKZStart          = 7;     // New York Kill Zone Start (EST hour)
input int      InpNYKZEnd            = 11;    // New York Kill Zone End (EST hour)
input bool     InpAllowLondonClose   = true;  // Allow London Close KZ (10-12 EST)
input int      InpLondonCloseStart   = 10;    // London Close KZ Start (EST)
input int      InpLondonCloseEnd     = 13;    // London Close KZ End (EST)

// Day Filter
input bool     InpDayFilterOn        = true;  // Enable Day Filter
input bool     InpBlockMonday        = false; // Block Monday
input bool     InpBlockTuesday       = false; // Block Tuesday
input bool     InpBlockWednesday     = false; // Block Wednesday
input bool     InpBlockThursday      = false; // Block Thursday
input bool     InpBlockFriday        = true;  // Block Friday (news heavy + manipulation)

//--- HTF Bias
input int      InpEMA_Fast           = 21;    // Fast EMA (HTF)
input int      InpEMA_Slow           = 50;    // Slow EMA (HTF)

//--- Order Block Detection
input int      InpOB_Lookback        = 30;    // OB scan range (LTF candles)
input double   InpOB_ATR_MinBody     = 0.3;   // OB min body size (x ATR)
input double   InpOB_ATR_Displacement= 1.5;   // Displacement strength (x ATR)

//--- FVG Detection
input int      InpFVG_Lookback       = 20;    // FVG scan range (LTF candles)
input double   InpFVG_ATR_MinSize    = 0.15;  // Min FVG size (x ATR)

//--- Liquidity Sweep
input int      InpSweep_Lookback     = 30;    // Swing H/L lookback
input double   InpSweep_ATR_Thresh   = 0.1;   // Sweep threshold (x ATR)

//--- [NEW] CHoCH / BOS (Market Structure Shift) Detection
input bool     InpUseCHoCH           = true;  // Enable CHoCH/BOS Confirmation
input int      InpCHoCH_Lookback     = 30;    // CHoCH detection lookback (LTF candles)
input int      InpSwingStrength      = 2;     // Swing point strength (bars each side)

//--- [NEW] OTE (Optimal Trade Entry) Fibonacci Zone
input bool     InpUseOTE             = true;  // Enable OTE Fibonacci Filter
input double   InpOTE_FibLow         = 0.50;  // OTE Zone Start (Fib level) — wider for M15
input double   InpOTE_FibHigh        = 0.79;  // OTE Zone End (Fib level)
input int      InpOTE_SwingLookback  = 25;    // Swing lookback for Fib calculation

//--- [NEW] RSI Divergence Filter (SOFT — won't block trade alone)
input bool     InpUseRSIDivergence   = false; // RSI Divergence (disable if too strict)
input int      InpRSI_Period         = 14;    // RSI Period
input int      InpRSI_DivLookback    = 15;    // RSI Divergence lookback (bars)

//--- Stop Loss
input int      InpATR_Period         = 14;    // ATR Period
input double   InpSL_ATR_Mult       = 0.3;   // SL buffer beyond zone (x ATR)
input double   InpSL_Min_ATR        = 0.4;   // Min SL distance (x ATR)
input double   InpSL_Max_ATR        = 1.2;   // Max SL (x ATR)

//--- Take Profit & Breakeven
input double   InpTP1_RR            = 1.5;   // TP1: Move to BREAKEVEN only (no close!)
input double   InpTP2_RR            = 3.0;   // TP2: FULL CLOSE here (actual TP = 3x Risk!)
input double   InpTP3_RR            = 5.0;   // TP3: Used for trailing / logging only
input double   InpMinRR             = 2.0;   // Minimum RR to accept ANY trade
input bool     InpMoveToBreakeven   = true;  // Move SL to breakeven at TP1 level

//--- Trailing Stop
input bool     InpUseTrailing        = true;  // Enable Trailing Stop
input double   InpTrailATRMult       = 1.0;   // Trailing distance (x ATR)
input double   InpTrailActivateRR    = 1.5;   // Activate trailing after X times risk in profit

//--- Position Sizing & Risk
input double   InpRiskPercent        = 1.0;   // Risk Per Trade (% of balance)
input int      InpMaxTradesPerDay    = 2;     // Max Trades Per Day TOTAL
input int      InpMaxTradesPerSymbol = 1;     // Max Trades Per Symbol Per Day
input int      InpMagicNumber        = 400100; // Magic Number
input double   InpMaxSpread_ATR     = 0.5;   // Max Spread (x ATR)

//--- Consecutive Loss Protection
input bool     InpUseConsLossBreaker = true;  // Enable Consecutive Loss Breaker
input int      InpMaxConsLosses      = 3;     // Max consecutive losses before pause

//--- Prop Firm Protection
input bool     InpPropFirmMode       = true;  // Enable Prop Firm Protection
input double   InpAccountSize        = 15000; // Account Size ($)
input double   InpDailyLossLimit     = 750;   // Daily Loss Limit ($)
input double   InpMaxLossLimit       = 1500;  // Max Overall Loss Limit ($)
input double   InpDailySafetyPct    = 0.75;  // Stop at % of daily limit
input double   InpMaxSafetyPct      = 0.80;  // Stop at % of max limit

//--- Symbol Toggles
input bool     InpTradeEURUSD        = true;  // Trade EURUSD
input bool     InpTradeXAUUSD        = true;  // Trade XAUUSD
input bool     InpTradeNAS100        = true;  // Trade NAS100

//+------------------------------------------------------------------+
//| STRUCTURES                                                         |
//+------------------------------------------------------------------+
struct OrderBlock { double high, low, midpoint; bool isBullish, valid; int barIndex; };
struct FairValueGap { double high, low; bool isBullish, valid; int barIndex; };
struct TradeSetup { bool valid; int direction; double entry, sl, tp1, tp2, tp3; string reason; };

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                   |
//+------------------------------------------------------------------+
CTrade trade;
int    todayTrades;
datetime lastTradeDay;
double dayStartBalance;
double initialBalance;
bool   dailyHalt;
bool   maxLossHalt;

// Consecutive loss tracking
int    consecutiveLosses;
bool   consLossHalt;

// Per-symbol daily trade counter
struct SymbolDayTrades { string symbol; int count; };
SymbolDayTrades symDayTrades[];

// Indicator handles
struct SymbolHandles { string symbol; int atrHandle, emaFastHandle, emaSlowHandle, rsiHandle; };
SymbolHandles handles[];

//+------------------------------------------------------------------+
//| Expert initialization                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   
   todayTrades = 0;
   lastTradeDay = 0;
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dayStartBalance = initialBalance;
   dailyHalt = false;
   maxLossHalt = false;
   consecutiveLosses = 0;
   consLossHalt = false;
   
   string symbols[] = {"EURUSD", "XAUUSD", "NAS100"};
   for(int i = 0; i < 3; i++)
   {
      if(!SymbolSelect(symbols[i], true)) continue;
      int idx = ArraySize(handles);
      ArrayResize(handles, idx + 1);
      handles[idx].symbol = symbols[i];
      handles[idx].atrHandle = iATR(symbols[i], InpLTF, InpATR_Period);
      handles[idx].emaFastHandle = iMA(symbols[i], InpHTF, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      handles[idx].emaSlowHandle = iMA(symbols[i], InpHTF, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      handles[idx].rsiHandle = iRSI(symbols[i], InpLTF, InpRSI_Period, PRICE_CLOSE);
   }
   
   Print("=== ICT/SMC BOT v4.0 — CHoCH + OTE + RSI + Kill Zones ===");
   Print("CHoCH: ", InpUseCHoCH?"ON":"OFF", " | OTE: ", InpUseOTE?"ON":"OFF");
   Print("RSI Div: ", InpUseRSIDivergence?"ON":"OFF", " | Kill Zones: ", InpKillZoneOn?"ON":"OFF");
   Print("SL: max ", InpSL_Max_ATR, "xATR | TP: ", InpTP2_RR, "RR | Trailing: ", InpUseTrailing?"ON":"OFF");
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { Print("ICT Bot v4.0 removed."); }

//+------------------------------------------------------------------+
//| Expert tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                    IntegerToString(dt.mon) + "." + IntegerToString(dt.day));
   
   // Daily reset
   if(today != lastTradeDay)
   {
      todayTrades = 0;
      lastTradeDay = today;
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyHalt = false;
      consLossHalt = false;
      ArrayResize(symDayTrades, 0);
   }
   
   if(InpPropFirmMode && !CheckPropFirmSafe()) return;
   if(todayTrades >= InpMaxTradesPerDay) return;
   if(InpUseConsLossBreaker && consLossHalt) return;
   
   // Trailing stop & position management
   ManageOpenPositions();
   
   // Day filter
   if(InpDayFilterOn && IsDayBlocked(dt.day_of_week)) return;
   
   // [NEW] Kill Zone check
   if(InpKillZoneOn && !IsInKillZone(dt.hour)) return;
   
   if(InpTradeEURUSD) ProcessSymbol("EURUSD");
   if(InpTradeXAUUSD) ProcessSymbol("XAUUSD");
   if(InpTradeNAS100) ProcessSymbol("NAS100");
}

//+------------------------------------------------------------------+
//| Day filter                                                         |
//+------------------------------------------------------------------+
bool IsDayBlocked(int dayOfWeek)
{
   if(dayOfWeek == 1 && InpBlockMonday) return true;
   if(dayOfWeek == 2 && InpBlockTuesday) return true;
   if(dayOfWeek == 3 && InpBlockWednesday) return true;
   if(dayOfWeek == 4 && InpBlockThursday) return true;
   if(dayOfWeek == 5 && InpBlockFriday) return true;
   return false;
}

//+------------------------------------------------------------------+
//| [NEW] Kill Zone Filter — Precise ICT time windows                  |
//| Converts server hour to EST and checks Kill Zones                  |
//+------------------------------------------------------------------+
bool IsInKillZone(int serverHour)
{
   // Convert server time to EST (UTC-5)
   int estHour = serverHour - InpServerUTCOffset - 5;
   if(estHour < 0) estHour += 24;
   if(estHour >= 24) estHour -= 24;
   
   // London Kill Zone: 2:00 - 5:00 AM EST
   if(estHour >= InpLondonKZStart && estHour < InpLondonKZEnd) return true;
   
   // New York Kill Zone: 7:00 - 10:00 AM EST
   if(estHour >= InpNYKZStart && estHour < InpNYKZEnd) return true;
   
   // London Close Kill Zone: 10:00 - 12:00 PM EST (optional)
   if(InpAllowLondonClose && estHour >= InpLondonCloseStart && estHour < InpLondonCloseEnd) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| MAIN PROCESSING LOGIC                                              |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol)
{
   if(!SymbolSelect(symbol, true)) return;
   if(HasOpenPosition(symbol)) return;
   if(!IsNewBar(symbol)) return;
   if(GetSymbolDayTrades(symbol) >= InpMaxTradesPerSymbol) return;
   
   double atr = GetATR(symbol);
   if(atr <= 0) return;
   
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(spread > atr * InpMaxSpread_ATR) return;
   
   // Step 1: HTF Bias
   int bias = GetHTFBias(symbol);
   if(bias == 0) return;
   
   // Step 2: Liquidity Sweep
   bool swept = DetectSweep(symbol, bias, atr);
   if(!swept) return;
   
   // Step 3: [NEW] CHoCH/BOS Confirmation on LTF
   if(InpUseCHoCH && !DetectCHoCH(symbol, bias))
      return;
   
   // Step 4: Order Block or FVG presence
   OrderBlock ob;
   FairValueGap fvg;
   bool obFound = FindOrderBlock(symbol, bias, atr, ob);
   bool fvgFound = FindFVG(symbol, bias, atr, fvg);
   if(!obFound && !fvgFound) return;
   
   // Step 5: [NEW] OTE Fibonacci Zone check
   if(InpUseOTE && !IsInOTEZone(symbol, bias, atr))
      return;
   
   // Step 6: [NEW] RSI Divergence confirmation (optional — soft filter)
   if(InpUseRSIDivergence && !DetectRSIDivergence(symbol, bias))
      return;
   
   // Step 7: Build & Execute Setup
   TradeSetup setup;
   setup.valid = false;
   if(obFound)
      setup = BuildSetup(symbol, bias, ob.low, ob.high, atr, "CHoCH+OB");
   else if(fvgFound)
      setup = BuildSetup(symbol, bias, fvg.low, fvg.high, atr, "CHoCH+FVG");
   
   if(!setup.valid) return;
   
   ExecuteTrade(symbol, setup);
}

//+------------------------------------------------------------------+
//| HTF BIAS                                                           |
//+------------------------------------------------------------------+
int GetHTFBias(string symbol)
{
   double emaFast = GetEMAFast(symbol);
   double emaSlow = GetEMASlow(symbol);
   if(emaFast <= 0 || emaSlow <= 0) return 0;
   if(emaFast > emaSlow) return 1;
   if(emaFast < emaSlow) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| LIQUIDITY SWEEP                                                    |
//+------------------------------------------------------------------+
bool DetectSweep(string symbol, int bias, double atr)
{
   double threshold = InpSweep_ATR_Thresh * atr;
   double swHigh = 0, swLow = DBL_MAX;
   for(int i = 3; i <= InpSweep_Lookback; i++)
   {
      double h = iHigh(symbol, InpLTF, i);
      double l = iLow(symbol, InpLTF, i);
      if(h > swHigh) swHigh = h;
      if(l < swLow)  swLow = l;
   }
   for(int i = 1; i <= 10; i++)
   {
      double high = iHigh(symbol, InpLTF, i);
      double low  = iLow(symbol, InpLTF, i);
      double close = iClose(symbol, InpLTF, i);
      if(bias == 1 && low < swLow - threshold && close > swLow) return true;
      if(bias == -1 && high > swHigh + threshold && close < swHigh) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| [NEW] CHoCH / BOS DETECTION (Market Structure Shift on LTF)        |
//| CHoCH = first break against previous structure                     |
//| BOS = continuation break confirming new structure                   |
//+------------------------------------------------------------------+
bool DetectCHoCH(string symbol, int bias)
{
   // Find swing highs and swing lows on LTF
   double swingHighs[];
   double swingLows[];
   int swingHighBars[];
   int swingLowBars[];
   ArrayResize(swingHighs, 0);
   ArrayResize(swingLows, 0);
   ArrayResize(swingHighBars, 0);
   ArrayResize(swingLowBars, 0);
   
   // Identify swing points using N-bar method
   for(int i = InpSwingStrength; i < InpCHoCH_Lookback; i++)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      double high_i = iHigh(symbol, InpLTF, i);
      double low_i = iLow(symbol, InpLTF, i);
      
      for(int j = 1; j <= InpSwingStrength; j++)
      {
         if(iHigh(symbol, InpLTF, i-j) >= high_i || iHigh(symbol, InpLTF, i+j) >= high_i)
            isSwingHigh = false;
         if(iLow(symbol, InpLTF, i-j) <= low_i || iLow(symbol, InpLTF, i+j) <= low_i)
            isSwingLow = false;
      }
      
      if(isSwingHigh)
      {
         int sz = ArraySize(swingHighs);
         ArrayResize(swingHighs, sz+1);
         ArrayResize(swingHighBars, sz+1);
         swingHighs[sz] = high_i;
         swingHighBars[sz] = i;
      }
      if(isSwingLow)
      {
         int sz = ArraySize(swingLows);
         ArrayResize(swingLows, sz+1);
         ArrayResize(swingLowBars, sz+1);
         swingLows[sz] = low_i;
         swingLowBars[sz] = i;
      }
   }
   
   // Need at least 2 swing points each to detect structure shift
   if(ArraySize(swingHighs) < 2 || ArraySize(swingLows) < 2) return false;
   
   double currentClose = iClose(symbol, InpLTF, 1);
   
   if(bias == 1) // Looking for BULLISH CHoCH (break above recent lower high)
   {
      // In a downtrend: price was making lower highs, lower lows
      // CHoCH = price breaks above the most recent swing high (lower high)
      // This signals the downtrend is over, bulls are in control
      
      // Check if recent structure was bearish (lower highs)
      if(ArraySize(swingHighs) >= 2 && swingHighs[0] < swingHighs[1])
      {
         // Most recent swing high was a lower high — bearish structure existed
         // Now check if current price has broken above it = CHoCH!
         if(currentClose > swingHighs[0])
            return true;
      }
      
      // Also accept BOS: price breaking above a previous high in an existing uptrend
      if(ArraySize(swingHighs) >= 2 && swingHighs[0] > swingHighs[1])
      {
         // Already bullish structure (higher highs) — BOS confirms continuation
         if(currentClose > swingHighs[0])
            return true;
      }
      
      // Also check: price broke above the last swing high (any)
      if(currentClose > swingHighs[0])
         return true;
   }
   else if(bias == -1) // Looking for BEARISH CHoCH (break below recent higher low)
   {
      // In an uptrend: price was making higher highs, higher lows
      // CHoCH = price breaks below the most recent swing low (higher low)
      // This signals the uptrend is over, bears are in control
      
      // Check if recent structure was bullish (higher lows)
      if(ArraySize(swingLows) >= 2 && swingLows[0] > swingLows[1])
      {
         // Most recent swing low was a higher low — bullish structure existed
         // Now check if current price has broken below it = CHoCH!
         if(currentClose < swingLows[0])
            return true;
      }
      
      // Also accept BOS: price breaking below a previous low in existing downtrend
      if(ArraySize(swingLows) >= 2 && swingLows[0] < swingLows[1])
      {
         // Already bearish structure (lower lows) — BOS confirms continuation
         if(currentClose < swingLows[0])
            return true;
      }
      
      // Also check: price broke below the last swing low (any)
      if(currentClose < swingLows[0])
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| [NEW] OTE ZONE CHECK — Fibonacci 62%-79% retracement               |
//| Price must be in the "sweet spot" retracement for optimal entry     |
//+------------------------------------------------------------------+
bool IsInOTEZone(string symbol, int bias, double atr)
{
   // Find the most recent impulsive move (swing high to swing low or vice versa)
   double swingHigh = 0, swingLow = DBL_MAX;
   int swingHighBar = 0, swingLowBar = 0;
   
   // Find highest high and lowest low in lookback
   for(int i = 1; i <= InpOTE_SwingLookback; i++)
   {
      double h = iHigh(symbol, InpLTF, i);
      double l = iLow(symbol, InpLTF, i);
      if(h > swingHigh) { swingHigh = h; swingHighBar = i; }
      if(l < swingLow)  { swingLow = l; swingLowBar = i; }
   }
   
   if(swingHigh <= swingLow) return true; // Can't calculate, allow trade
   
   double price = iClose(symbol, InpLTF, 1);
   double range = swingHigh - swingLow;
   
   if(bias == 1) // Bullish: looking for retracement DOWN into OTE zone
   {
      // After a swing low → swing high move, price retraces down
      // OTE buy zone = swing low + (1 - 0.79)*range to swing low + (1 - 0.62)*range
      // Which is: swingHigh - 0.79*range to swingHigh - 0.62*range
      if(swingHighBar < swingLowBar) // Swing high is more recent = retracing from top
      {
         double oteHigh = swingHigh - InpOTE_FibLow * range;  // 62% level
         double oteLow  = swingHigh - InpOTE_FibHigh * range; // 79% level
         
         // Allow small buffer (0.2x ATR) around OTE zone
         double buffer = 0.2 * atr;
         if(price >= (oteLow - buffer) && price <= (oteHigh + buffer))
            return true;
      }
      else
      {
         // Swing low is more recent — price might be starting new impulse up
         // Still check OTE from the recent drop
         double oteHigh = swingHigh - InpOTE_FibLow * range;
         double oteLow  = swingHigh - InpOTE_FibHigh * range;
         double buffer = 0.2 * atr;
         if(price >= (oteLow - buffer) && price <= (oteHigh + buffer))
            return true;
      }
   }
   else if(bias == -1) // Bearish: looking for retracement UP into OTE zone
   {
      // After a swing high → swing low move, price retraces up
      // OTE sell zone = swingLow + 0.62*range to swingLow + 0.79*range
      if(swingLowBar < swingHighBar) // Swing low is more recent = retracing from bottom
      {
         double oteLow  = swingLow + InpOTE_FibLow * range;   // 62% level
         double oteHigh = swingLow + InpOTE_FibHigh * range;  // 79% level
         
         double buffer = 0.2 * atr;
         if(price >= (oteLow - buffer) && price <= (oteHigh + buffer))
            return true;
      }
      else
      {
         double oteLow  = swingLow + InpOTE_FibLow * range;
         double oteHigh = swingLow + InpOTE_FibHigh * range;
         double buffer = 0.2 * atr;
         if(price >= (oteLow - buffer) && price <= (oteHigh + buffer))
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| [NEW] RSI DIVERGENCE DETECTION                                     |
//| Bullish div: price lower low, RSI higher low                       |
//| Bearish div: price higher high, RSI lower high                     |
//+------------------------------------------------------------------+
bool DetectRSIDivergence(string symbol, int bias)
{
   double rsiValues[];
   ArrayResize(rsiValues, InpRSI_DivLookback + 1);
   
   int rsiHandle = GetRSIHandle(symbol);
   if(rsiHandle == INVALID_HANDLE) return true; // No RSI = allow trade (don't block)
   
   if(CopyBuffer(rsiHandle, 0, 1, InpRSI_DivLookback, rsiValues) < InpRSI_DivLookback)
      return true; // Can't get data = allow trade
   
   // ArrayReverse to make [0] = oldest, [N-1] = most recent
   ArrayReverse(rsiValues);
   int size = ArraySize(rsiValues);
   
   if(bias == 1) // Looking for BULLISH divergence
   {
      // Find two recent swing lows in price
      double priceLow1 = DBL_MAX, priceLow2 = DBL_MAX;
      int priceLowBar1 = -1, priceLowBar2 = -1;
      
      // Most recent low
      for(int i = size - 2; i >= size/2; i--)
      {
         double low = iLow(symbol, InpLTF, size - i);
         if(low < priceLow1) { priceLow1 = low; priceLowBar1 = i; }
      }
      // Earlier low
      for(int i = size/2 - 1; i >= 1; i--)
      {
         double low = iLow(symbol, InpLTF, size - i);
         if(low < priceLow2) { priceLow2 = low; priceLowBar2 = i; }
      }
      
      if(priceLowBar1 < 0 || priceLowBar2 < 0) return false;
      
      // Bullish divergence: price made LOWER low, RSI made HIGHER low
      if(priceLow1 <= priceLow2)
      {
         double rsiAtLow1 = (priceLowBar1 < size) ? rsiValues[priceLowBar1] : 0;
         double rsiAtLow2 = (priceLowBar2 < size) ? rsiValues[priceLowBar2] : 0;
         if(rsiAtLow1 > rsiAtLow2) // RSI higher low = BULLISH DIVERGENCE!
            return true;
      }
      
      // Also accept: RSI oversold (< 35) as confluence even without perfect divergence
      if(rsiValues[size-1] < 35)
         return true;
   }
   else if(bias == -1) // Looking for BEARISH divergence
   {
      // Find two recent swing highs in price
      double priceHigh1 = 0, priceHigh2 = 0;
      int priceHighBar1 = -1, priceHighBar2 = -1;
      
      // Most recent high
      for(int i = size - 2; i >= size/2; i--)
      {
         double high = iHigh(symbol, InpLTF, size - i);
         if(high > priceHigh1) { priceHigh1 = high; priceHighBar1 = i; }
      }
      // Earlier high
      for(int i = size/2 - 1; i >= 1; i--)
      {
         double high = iHigh(symbol, InpLTF, size - i);
         if(high > priceHigh2) { priceHigh2 = high; priceHighBar2 = i; }
      }
      
      if(priceHighBar1 < 0 || priceHighBar2 < 0) return false;
      
      // Bearish divergence: price made HIGHER high, RSI made LOWER high
      if(priceHigh1 >= priceHigh2)
      {
         double rsiAtHigh1 = (priceHighBar1 < size) ? rsiValues[priceHighBar1] : 0;
         double rsiAtHigh2 = (priceHighBar2 < size) ? rsiValues[priceHighBar2] : 0;
         if(rsiAtHigh1 < rsiAtHigh2) // RSI lower high = BEARISH DIVERGENCE!
            return true;
      }
      
      // Also accept: RSI overbought (> 65) as confluence
      if(rsiValues[size-1] > 65)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| ORDER BLOCK                                                        |
//+------------------------------------------------------------------+
bool FindOrderBlock(string symbol, int bias, double atr, OrderBlock &ob)
{
   ob.valid = false;
   double minBody = InpOB_ATR_MinBody * atr;
   double minDisp = InpOB_ATR_Displacement * atr;
   double price = (bias == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   double zoneBuffer = 0.3 * atr;
   
   for(int i = 3; i < InpOB_Lookback; i++)
   {
      double o_i = iOpen(symbol, InpLTF, i), c_i = iClose(symbol, InpLTF, i);
      double h_i = iHigh(symbol, InpLTF, i), l_i = iLow(symbol, InpLTF, i);
      if(MathAbs(c_i - o_i) < minBody) continue;
      
      if(bias == 1 && c_i < o_i) // Bearish candle (potential bullish OB)
      {
         double maxH = 0;
         for(int j = i-1; j >= 1; j--) { double hj = iHigh(symbol, InpLTF, j); if(hj > maxH) maxH = hj; }
         if(maxH - h_i >= minDisp && price >= (l_i - zoneBuffer) && price <= (h_i + zoneBuffer))
         { ob.high=h_i; ob.low=l_i; ob.isBullish=true; ob.valid=true; return true; }
      }
      if(bias == -1 && c_i > o_i) // Bullish candle (potential bearish OB)
      {
         double minL = DBL_MAX;
         for(int j = i-1; j >= 1; j--) { double lj = iLow(symbol, InpLTF, j); if(lj < minL) minL = lj; }
         if(l_i - minL >= minDisp && price <= (h_i + zoneBuffer) && price >= (l_i - zoneBuffer))
         { ob.high=h_i; ob.low=l_i; ob.isBullish=false; ob.valid=true; return true; }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| FVG                                                                |
//+------------------------------------------------------------------+
bool FindFVG(string symbol, int bias, double atr, FairValueGap &fvg)
{
   fvg.valid = false;
   double minSize = InpFVG_ATR_MinSize * atr;
   double price = (bias == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   double zoneBuffer = 0.3 * atr;
   
   for(int i = 2; i < InpFVG_Lookback; i++)
   {
      double h1 = iHigh(symbol, InpLTF, i+1), l3 = iLow(symbol, InpLTF, i-1);
      double l1 = iLow(symbol, InpLTF, i+1), h3 = iHigh(symbol, InpLTF, i-1);
      
      if(bias == 1)
      {
         double gH=l3, gL=h1;
         if(gH>gL && gH-gL>=minSize && price>=(gL-zoneBuffer) && price<=(gH+zoneBuffer))
         { fvg.high=gH; fvg.low=gL; fvg.isBullish=true; fvg.valid=true; return true; }
      }
      if(bias == -1)
      {
         double gH=l1, gL=h3;
         if(gH>gL && gH-gL>=minSize && price<=(gH+zoneBuffer) && price>=(gL-zoneBuffer))
         { fvg.high=gH; fvg.low=gL; fvg.isBullish=false; fvg.valid=true; return true; }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| BUILD SETUP                                                        |
//+------------------------------------------------------------------+
TradeSetup BuildSetup(string symbol, int bias, double zoneLow, double zoneHigh, double atr, string reason)
{
   TradeSetup setup;
   setup.valid = false;
   
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double slBuffer = InpSL_ATR_Mult * atr;
   double minSL = InpSL_Min_ATR * atr;
   double maxSL = InpSL_Max_ATR * atr;
   
   if(bias == 1)
   {
      setup.entry = ask;
      setup.sl = zoneLow - slBuffer;
      double risk = setup.entry - setup.sl;
      if(risk < minSL) { setup.sl = setup.entry - minSL; risk = minSL; }
      if(risk > maxSL) return setup;
      if(InpTP2_RR < InpMinRR) return setup;
      
      setup.tp1 = setup.entry + risk * InpTP1_RR;
      setup.tp2 = setup.entry + risk * InpTP2_RR;
      setup.tp3 = setup.entry + risk * InpTP3_RR;
      setup.direction = 1;
      setup.reason = reason + " Buy";
      setup.valid = true;
   }
   else if(bias == -1)
   {
      setup.entry = bid;
      setup.sl = zoneHigh + slBuffer;
      double risk = setup.sl - setup.entry;
      if(risk < minSL) { setup.sl = setup.entry + minSL; risk = minSL; }
      if(risk > maxSL) return setup;
      if(InpTP2_RR < InpMinRR) return setup;
      
      setup.tp1 = setup.entry - risk * InpTP1_RR;
      setup.tp2 = setup.entry - risk * InpTP2_RR;
      setup.tp3 = setup.entry - risk * InpTP3_RR;
      setup.direction = -1;
      setup.reason = reason + " Sell";
      setup.valid = true;
   }
   return setup;
}

//+------------------------------------------------------------------+
//| EXECUTE TRADE                                                      |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, TradeSetup &setup)
{
   double lotSize = CalculateLotSize(symbol, MathAbs(setup.entry - setup.sl));
   if(lotSize <= 0) return;
   
   SetFilling(symbol);
   
   double risk = MathAbs(setup.entry - setup.sl);
   double tp = (setup.direction == 1) ? setup.entry + risk * InpTP2_RR : setup.entry - risk * InpTP2_RR;
   
   bool result = false;
   if(setup.direction == 1)
      result = trade.Buy(lotSize, symbol, setup.entry, setup.sl, tp, setup.reason);
   else
      result = trade.Sell(lotSize, symbol, setup.entry, setup.sl, tp, setup.reason);
   
   if(result)
   {
      todayTrades++;
      IncrementSymbolDayTrades(symbol);
      Print(">>> TRADE: ", symbol, " ", setup.reason, " | Lot:", lotSize,
            " | Entry:", setup.entry, " | SL:", setup.sl, " | TP:", tp,
            " | RR:", InpTP2_RR);
   }
   else
      Print("!!! FAILED: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| MANAGE POSITIONS — Breakeven + Trailing                            |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string sym = PositionGetString(POSITION_SYMBOL);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double volume = PositionGetDouble(POSITION_VOLUME);
      long type = PositionGetInteger(POSITION_TYPE);
      
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double risk = MathAbs(openPrice - currentSL);
      if(risk <= 0) continue;
      
      double atr = GetATR(sym);
      if(atr <= 0) atr = risk;
      
      if(type == POSITION_TYPE_BUY)
      {
         double tp1Level = openPrice + risk * InpTP1_RR;
         double profit = bid - openPrice;
         
         // Move to breakeven at TP1
         if(InpMoveToBreakeven && bid >= tp1Level && currentSL < openPrice)
         {
            double beSL = openPrice + SymbolInfoInteger(sym, SYMBOL_SPREAD) * SymbolInfoDouble(sym, SYMBOL_POINT);
            trade.PositionModify(ticket, beSL, currentTP);
            Print("   BE: ", sym, " SL -> breakeven at ", beSL);
         }
         
         // Trailing Stop
         if(InpUseTrailing && profit >= risk * InpTrailActivateRR && currentSL >= openPrice)
         {
            double trailDist = InpTrailATRMult * atr;
            double newSL = bid - trailDist;
            if(newSL > currentSL)
               trade.PositionModify(ticket, newSL, currentTP);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double tp1Level = openPrice - risk * InpTP1_RR;
         double profit = openPrice - ask;
         
         if(InpMoveToBreakeven && ask <= tp1Level && currentSL > openPrice)
         {
            double beSL = openPrice - SymbolInfoInteger(sym, SYMBOL_SPREAD) * SymbolInfoDouble(sym, SYMBOL_POINT);
            trade.PositionModify(ticket, beSL, currentTP);
            Print("   BE: ", sym, " SL -> breakeven at ", beSL);
         }
         
         if(InpUseTrailing && profit >= risk * InpTrailActivateRR && currentSL <= openPrice)
         {
            double trailDist = InpTrailATRMult * atr;
            double newSL = ask + trailDist;
            if(newSL < currentSL)
               trade.PositionModify(ticket, newSL, currentTP);
         }
      }
   }
   
   TrackConsecutiveLosses();
}

//+------------------------------------------------------------------+
//| CONSECUTIVE LOSS TRACKING                                          |
//+------------------------------------------------------------------+
void TrackConsecutiveLosses()
{
   static int lastDealCount = 0;
   int totalDeals = HistoryDealsTotal();
   
   if(totalDeals <= lastDealCount) return;
   
   HistorySelect(0, TimeCurrent());
   int deals = HistoryDealsTotal();
   if(deals <= 0) return;
   
   ulong lastTicket = HistoryDealGetTicket(deals - 1);
   if(lastTicket <= 0) return;
   if(HistoryDealGetInteger(lastTicket, DEAL_MAGIC) != InpMagicNumber) return;
   if(HistoryDealGetInteger(lastTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;
   
   double profit = HistoryDealGetDouble(lastTicket, DEAL_PROFIT) + 
                   HistoryDealGetDouble(lastTicket, DEAL_SWAP) +
                   HistoryDealGetDouble(lastTicket, DEAL_COMMISSION);
   
   if(profit < 0)
   {
      consecutiveLosses++;
      if(consecutiveLosses >= InpMaxConsLosses)
      {
         consLossHalt = true;
         Print("!!! CONSECUTIVE LOSS BREAKER: ", consecutiveLosses, " losses. Halting.");
      }
   }
   else if(profit > 0)
   {
      consecutiveLosses = 0;
   }
   
   lastDealCount = totalDeals;
}

//+------------------------------------------------------------------+
//| PROP FIRM PROTECTION                                               |
//+------------------------------------------------------------------+
bool CheckPropFirmSafe()
{
   if(maxLossHalt || dailyHalt) return false;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(initialBalance - equity >= InpMaxLossLimit * InpMaxSafetyPct)
   { CloseAll(); maxLossHalt = true; return false; }
   
   if(dayStartBalance - equity >= InpDailyLossLimit * InpDailySafetyPct)
   { CloseAll(); dailyHalt = true; return false; }
   
   return true;
}

void CloseAll()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) trade.PositionClose(t);
   }
}

//+------------------------------------------------------------------+
//| DYNAMIC LOT SIZE                                                   |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double slDistance)
{
   if(slDistance <= 0) return 0;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   
   if(InpPropFirmMode)
   {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double dailyRoom = (InpDailyLossLimit * InpDailySafetyPct) - (dayStartBalance - equity);
      double maxRoom = (InpMaxLossLimit * InpMaxSafetyPct) - (initialBalance - equity);
      riskAmount = MathMin(riskAmount, MathMax(0, dailyRoom));
      riskAmount = MathMin(riskAmount, MathMax(0, maxRoom));
      if(riskAmount <= 0) return 0;
   }
   
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0 || tickSize <= 0) return 0;
   
   double lot = riskAmount / ((slDistance / tickSize) * tickValue);
   
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                   |
//+------------------------------------------------------------------+
bool IsNewBar(string symbol)
{
   static string syms[]; static datetime times[];
   int idx = -1;
   for(int i = 0; i < ArraySize(syms); i++) if(syms[i] == symbol) { idx = i; break; }
   if(idx == -1) { idx = ArraySize(syms); ArrayResize(syms, idx+1); ArrayResize(times, idx+1); syms[idx]=symbol; times[idx]=0; }
   datetime cur = iTime(symbol, InpLTF, 0);
   if(cur == times[idx]) return false;
   times[idx] = cur; return true;
}

double GetATR(string symbol)
{ for(int i=0;i<ArraySize(handles);i++) if(handles[i].symbol==symbol) { double b[]; if(CopyBuffer(handles[i].atrHandle,0,1,1,b)>0) return b[0]; } return 0; }

double GetEMAFast(string symbol)
{ for(int i=0;i<ArraySize(handles);i++) if(handles[i].symbol==symbol) { double b[]; if(CopyBuffer(handles[i].emaFastHandle,0,1,1,b)>0) return b[0]; } return 0; }

double GetEMASlow(string symbol)
{ for(int i=0;i<ArraySize(handles);i++) if(handles[i].symbol==symbol) { double b[]; if(CopyBuffer(handles[i].emaSlowHandle,0,1,1,b)>0) return b[0]; } return 0; }

int GetRSIHandle(string symbol)
{ for(int i=0;i<ArraySize(handles);i++) if(handles[i].symbol==symbol) return handles[i].rsiHandle; return INVALID_HANDLE; }

bool HasOpenPosition(string symbol)
{ for(int i=PositionsTotal()-1;i>=0;i--) if(PositionGetSymbol(i)==symbol && PositionGetInteger(POSITION_MAGIC)==InpMagicNumber) return true; return false; }

void SetFilling(string symbol)
{ long f=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE); if((f&SYMBOL_FILLING_FOK)!=0) trade.SetTypeFilling(ORDER_FILLING_FOK); else if((f&SYMBOL_FILLING_IOC)!=0) trade.SetTypeFilling(ORDER_FILLING_IOC); else trade.SetTypeFilling(ORDER_FILLING_RETURN); }

// Per-symbol daily trade count
int GetSymbolDayTrades(string symbol)
{
   for(int i = 0; i < ArraySize(symDayTrades); i++)
      if(symDayTrades[i].symbol == symbol) return symDayTrades[i].count;
   return 0;
}

void IncrementSymbolDayTrades(string symbol)
{
   for(int i = 0; i < ArraySize(symDayTrades); i++)
   {
      if(symDayTrades[i].symbol == symbol) { symDayTrades[i].count++; return; }
   }
   int idx = ArraySize(symDayTrades);
   ArrayResize(symDayTrades, idx + 1);
   symDayTrades[idx].symbol = symbol;
   symDayTrades[idx].count = 1;
}
//+------------------------------------------------------------------+
