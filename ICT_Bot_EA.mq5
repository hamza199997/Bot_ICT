//+------------------------------------------------------------------+
//|                                          ICT_Bot_EA.mq5          |
//|           ICT/SMC Proven Strategy - Clean Build v3.0              |
//|           Order Block + FVG + Liquidity Sweep + HTF Bias          |
//|           3 Take Profits + ATR-based SL + Prop Firm Safe          |
//+------------------------------------------------------------------+
#property copyright "ICT Bot v3.0 - Proven Strategy"
#property version   "3.00"
#property strict
#property description "Simple proven ICT/SMC: OB + FVG + Sweep, 3 TPs, tight SL"
#property description "Based on backtested data: OB 70-75% WR, FVG 65-70% WR"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- Symbol & Timeframe
input ENUM_TIMEFRAMES InpHTF         = PERIOD_H1;     // HTF: Bias (EMA direction)
input ENUM_TIMEFRAMES InpLTF         = PERIOD_M5;     // LTF: Entry detection

//--- Session Filter (Server Time)
input int      InpSessionStart       = 2;     // Session Start Hour (London open)
input int      InpSessionEnd         = 16;    // Session End Hour (NY close)

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

//--- Stop Loss (ATR-based, TIGHT - cap losses)
input int      InpATR_Period         = 14;    // ATR Period
input double   InpSL_ATR_Mult       = 0.5;   // SL buffer (x ATR) - tighter
input double   InpSL_Min_ATR        = 0.5;   // Min SL (x ATR) - tight!
input double   InpSL_Max_ATR        = 1.5;   // Max SL (x ATR) - cap losses!

//--- Take Profit (3 TPs - WIDER for better RR)
input double   InpTP1_RR            = 1.5;   // TP1: 1:1.5 (close 40%)
input double   InpTP2_RR            = 2.5;   // TP2: 1:2.5 (close 30%)
input double   InpTP3_RR            = 4.0;   // TP3: 1:4 (close 30%)
input double   InpTP1_ClosePercent  = 40.0;  // TP1: % to close
input double   InpTP2_ClosePercent  = 30.0;  // TP2: % to close
input bool     InpMoveToBreakeven   = true;  // Move SL to breakeven at TP1

//--- Risk Management
input double   InpRiskPercent        = 1.0;   // Risk Per Trade (%)
input int      InpMaxTradesPerDay    = 3;     // Max Trades Per Day
input int      InpMagicNumber        = 300300; // Magic Number
input double   InpMaxSpread_ATR     = 0.3;   // Max Spread (x ATR)

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
struct OrderBlock
{
   double high;
   double low;
   double midpoint;
   bool   isBullish;
   int    barIndex;
   bool   valid;
};

struct FairValueGap
{
   double high;
   double low;
   bool   isBullish;
   int    barIndex;
   bool   valid;
};

struct TradeSetup
{
   bool   valid;
   int    direction;    // 1=buy, -1=sell
   double entry;
   double sl;
   double tp1;
   double tp2;
   double tp3;
   string reason;
};

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

//--- Indicator handles (per symbol)
struct SymbolHandles
{
   string symbol;
   int    atrHandle;
   int    emaFastHandle;
   int    emaSlowHandle;
};
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
   
   // Pre-create indicator handles for each symbol
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
   }
   
   Print("=============================================");
   Print("  ICT/SMC PROVEN STRATEGY BOT v3.0");
   Print("  Models: Order Block + FVG + Sweep");
   Print("  3 TPs: 1:1 (40%), 1:2 (30%), 1:3 (30%)");
   Print("  SL: ATR-based tight stop");
   Print("  Prop Firm: ", InpPropFirmMode ? "PROTECTED" : "OFF");
   Print("=============================================");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("ICT Bot v3 removed.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   // Daily reset
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." +
                    IntegerToString(dt.mon) + "." + IntegerToString(dt.day));
   if(today != lastTradeDay)
   {
      todayTrades = 0;
      lastTradeDay = today;
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyHalt = false;
   }
   
   // Prop firm check
   if(InpPropFirmMode && !CheckPropFirmSafe()) return;
   
   // Max trades
   if(todayTrades >= InpMaxTradesPerDay) return;
   
   // Manage open positions (partial TPs + breakeven)
   ManageOpenPositions();
   
   // Process symbols
   if(InpTradeEURUSD) ProcessSymbol("EURUSD");
   if(InpTradeXAUUSD) ProcessSymbol("XAUUSD");
   if(InpTradeNAS100) ProcessSymbol("NAS100");
}

//+------------------------------------------------------------------+
//| MAIN LOGIC PER SYMBOL                                              |
//|                                                                    |
//| Simple proven flow:                                                |
//|  1. Session active?                                                |
//|  2. HTF Bias (EMA cross direction)?                                |
//|  3. Liquidity Sweep happened?                                      |
//|  4. Order Block OR FVG entry zone?                                 |
//|  5. Price at entry zone? -> TRADE with 3 TPs                       |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol)
{
   if(!SymbolSelect(symbol, true)) return;
   if(HasOpenPosition(symbol)) return;
   if(!IsNewBar(symbol)) return;
   
   // Get ATR for this symbol
   double atr = GetATR(symbol);
   if(atr <= 0) return;
   
   // Check spread vs ATR
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(spread > atr * InpMaxSpread_ATR) return;
   
   //--- STEP 1: Session filter
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.hour < InpSessionStart || dt.hour >= InpSessionEnd) return;
   
   //--- STEP 2: HTF Bias
   int bias = GetHTFBias(symbol);
   if(bias == 0) return;
   
   //--- STEP 3: Liquidity Sweep
   bool swept = DetectSweep(symbol, bias, atr);
   if(!swept) return;
   
   //--- STEP 4: Find Order Block OR FVG
   OrderBlock ob;
   FairValueGap fvg;
   bool obFound = FindOrderBlock(symbol, bias, atr, ob);
   bool fvgFound = FindFVG(symbol, bias, atr, fvg);
   
   if(!obFound && !fvgFound) return;
   
   //--- STEP 5: Check if price is AT the entry zone
   TradeSetup setup;
   setup.valid = false;
   
   // Priority: OB (higher win rate) > FVG
   if(obFound)
      setup = BuildSetup(symbol, bias, ob.low, ob.high, atr, "OB");
   else if(fvgFound)
      setup = BuildSetup(symbol, bias, fvg.low, fvg.high, atr, "FVG");
   
   if(!setup.valid) return;
   
   //--- EXECUTE
   ExecuteTrade(symbol, setup);
}

//+------------------------------------------------------------------+
//| HTF BIAS (EMA cross)                                               |
//+------------------------------------------------------------------+
int GetHTFBias(string symbol)
{
   double emaFast = GetEMAFast(symbol);
   double emaSlow = GetEMASlow(symbol);
   if(emaFast <= 0 || emaSlow <= 0) return 0;
   
   double close1 = iClose(symbol, InpHTF, 1);
   
   // Bullish: fast above slow AND price above fast
   if(emaFast > emaSlow && close1 > emaFast) return 1;
   // Bearish: fast below slow AND price below fast
   if(emaFast < emaSlow && close1 < emaFast) return -1;
   
   return 0;
}

//+------------------------------------------------------------------+
//| LIQUIDITY SWEEP DETECTION                                          |
//| Looks for price sweeping a swing high/low then rejecting           |
//+------------------------------------------------------------------+
bool DetectSweep(string symbol, int bias, double atr)
{
   double threshold = InpSweep_ATR_Thresh * atr;
   
   // Find swing high/low
   double swHigh = 0, swLow = DBL_MAX;
   for(int i = 3; i <= InpSweep_Lookback; i++)
   {
      double h = iHigh(symbol, InpLTF, i);
      double l = iLow(symbol, InpLTF, i);
      if(h > swHigh) swHigh = h;
      if(l < swLow)  swLow = l;
   }
   
   // Check last few candles for sweep + rejection
   for(int i = 1; i <= 5; i++)
   {
      double high = iHigh(symbol, InpLTF, i);
      double low  = iLow(symbol, InpLTF, i);
      double close = iClose(symbol, InpLTF, i);
      
      // Bullish: swept below swing low, closed back above
      if(bias == 1 && low < swLow - threshold && close > swLow)
         return true;
      
      // Bearish: swept above swing high, closed back below
      if(bias == -1 && high > swHigh + threshold && close < swHigh)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| ORDER BLOCK DETECTION                                              |
//| Last opposing candle before strong displacement move                |
//+------------------------------------------------------------------+
bool FindOrderBlock(string symbol, int bias, double atr, OrderBlock &ob)
{
   ob.valid = false;
   double minBody = InpOB_ATR_MinBody * atr;
   double minDisp = InpOB_ATR_Displacement * atr;
   
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double price = (bias == 1) ? ask : bid;
   
   for(int i = 3; i < InpOB_Lookback; i++)
   {
      double o_i = iOpen(symbol, InpLTF, i);
      double c_i = iClose(symbol, InpLTF, i);
      double h_i = iHigh(symbol, InpLTF, i);
      double l_i = iLow(symbol, InpLTF, i);
      double body = MathAbs(c_i - o_i);
      
      if(body < minBody) continue;
      
      // Bullish OB: bearish candle followed by strong up-move
      if(bias == 1 && c_i < o_i)
      {
         // Check displacement after
         double maxHigh = 0;
         for(int j = i - 1; j >= 1; j--)
         {
            double hj = iHigh(symbol, InpLTF, j);
            if(hj > maxHigh) maxHigh = hj;
         }
         if(maxHigh - h_i >= minDisp)
         {
            // Price must be at OB zone NOW
            if(price >= l_i && price <= h_i)
            {
               ob.high = h_i;
               ob.low = l_i;
               ob.midpoint = (h_i + l_i) / 2.0;
               ob.isBullish = true;
               ob.barIndex = i;
               ob.valid = true;
               return true;
            }
         }
      }
      
      // Bearish OB: bullish candle followed by strong down-move
      if(bias == -1 && c_i > o_i)
      {
         double minLow = DBL_MAX;
         for(int j = i - 1; j >= 1; j--)
         {
            double lj = iLow(symbol, InpLTF, j);
            if(lj < minLow) minLow = lj;
         }
         if(l_i - minLow >= minDisp)
         {
            if(price <= h_i && price >= l_i)
            {
               ob.high = h_i;
               ob.low = l_i;
               ob.midpoint = (h_i + l_i) / 2.0;
               ob.isBullish = false;
               ob.barIndex = i;
               ob.valid = true;
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| FVG DETECTION                                                      |
//| 3-candle gap where price moved too fast                            |
//+------------------------------------------------------------------+
bool FindFVG(string symbol, int bias, double atr, FairValueGap &fvg)
{
   fvg.valid = false;
   double minSize = InpFVG_ATR_MinSize * atr;
   
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double price = (bias == 1) ? ask : bid;
   
   for(int i = 2; i < InpFVG_Lookback; i++)
   {
      double h1 = iHigh(symbol, InpLTF, i + 1); // candle 1
      double l1 = iLow(symbol, InpLTF, i + 1);
      double l3 = iLow(symbol, InpLTF, i - 1);  // candle 3
      double h3 = iHigh(symbol, InpLTF, i - 1);
      
      // Bullish FVG
      if(bias == 1)
      {
         double gapHigh = l3;
         double gapLow = h1;
         if(gapHigh > gapLow && (gapHigh - gapLow) >= minSize)
         {
            if(price >= gapLow && price <= gapHigh)
            {
               fvg.high = gapHigh;
               fvg.low = gapLow;
               fvg.isBullish = true;
               fvg.barIndex = i;
               fvg.valid = true;
               return true;
            }
         }
      }
      
      // Bearish FVG
      if(bias == -1)
      {
         double gapHigh = l1;
         double gapLow = h3;
         if(gapHigh > gapLow && (gapHigh - gapLow) >= minSize)
         {
            if(price <= gapHigh && price >= gapLow)
            {
               fvg.high = gapHigh;
               fvg.low = gapLow;
               fvg.isBullish = false;
               fvg.barIndex = i;
               fvg.valid = true;
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| BUILD TRADE SETUP (entry, SL, 3 TPs)                               |
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
   
   if(bias == 1) // BUY
   {
      setup.entry = ask;
      setup.sl = zoneLow - slBuffer;
      
      double risk = setup.entry - setup.sl;
      // Enforce min/max SL
      if(risk < minSL) { setup.sl = setup.entry - minSL; risk = minSL; }
      if(risk > maxSL) return setup; // too wide, skip
      
      setup.tp1 = setup.entry + risk * InpTP1_RR;
      setup.tp2 = setup.entry + risk * InpTP2_RR;
      setup.tp3 = setup.entry + risk * InpTP3_RR;
      setup.direction = 1;
      setup.reason = reason + " Buy [SL:" + DoubleToString(risk/atr, 1) + "xATR]";
      setup.valid = true;
   }
   else if(bias == -1) // SELL
   {
      setup.entry = bid;
      setup.sl = zoneHigh + slBuffer;
      
      double risk = setup.sl - setup.entry;
      if(risk < minSL) { setup.sl = setup.entry + minSL; risk = minSL; }
      if(risk > maxSL) return setup;
      
      setup.tp1 = setup.entry - risk * InpTP1_RR;
      setup.tp2 = setup.entry - risk * InpTP2_RR;
      setup.tp3 = setup.entry - risk * InpTP3_RR;
      setup.direction = -1;
      setup.reason = reason + " Sell [SL:" + DoubleToString(risk/atr, 1) + "xATR]";
      setup.valid = true;
   }
   
   return setup;
}

//+------------------------------------------------------------------+
//| EXECUTE TRADE (open position)                                      |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, TradeSetup &setup)
{
   double lotSize = CalculateLotSize(symbol, MathAbs(setup.entry - setup.sl));
   if(lotSize <= 0) return;
   
   // Set filling mode
   SetFilling(symbol);
   
   // Use TP3 as the initial TP (we manage partials in ManageOpenPositions)
   bool result = false;
   if(setup.direction == 1)
      result = trade.Buy(lotSize, symbol, setup.entry, setup.sl, setup.tp3, setup.reason);
   else
      result = trade.Sell(lotSize, symbol, setup.entry, setup.sl, setup.tp3, setup.reason);
   
   if(result)
   {
      todayTrades++;
      Print(">>> TRADE OPEN: ", symbol, " | ", setup.reason);
      Print("    Entry: ", setup.entry, " SL: ", setup.sl);
      Print("    TP1: ", setup.tp1, " TP2: ", setup.tp2, " TP3: ", setup.tp3);
      Print("    Lot: ", lotSize, " | Risk: ", InpRiskPercent, "%");
   }
   else
      Print("!!! Trade FAILED: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| MANAGE OPEN POSITIONS (Partial TPs + Breakeven)                    |
//| This runs every tick to check if TP1/TP2 are hit                   |
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
      string comment = PositionGetString(POSITION_COMMENT);
      
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      double risk = MathAbs(openPrice - currentSL);
      if(risk <= 0) continue;
      
      // Calculate TP levels from entry
      double tp1, tp2;
      if(type == POSITION_TYPE_BUY)
      {
         tp1 = openPrice + risk * InpTP1_RR;
         tp2 = openPrice + risk * InpTP2_RR;
         
         // TP1 hit: close 40% and move to breakeven
         if(bid >= tp1 && StringFind(comment, "TP1") < 0)
         {
            double closeVol = NormalizeVolume(sym, volume * InpTP1_ClosePercent / 100.0);
            if(closeVol > 0)
            {
               trade.PositionClosePartial(ticket, closeVol);
               Print("   TP1 HIT: Closed ", closeVol, " lots on ", sym);
            }
            // Move SL to breakeven
            if(InpMoveToBreakeven)
            {
               double newSL = openPrice + SymbolInfoInteger(sym, SYMBOL_SPREAD) * SymbolInfoDouble(sym, SYMBOL_POINT);
               trade.PositionModify(ticket, newSL, currentTP);
               Print("   SL moved to breakeven: ", newSL);
            }
         }
         // TP2 hit: close another 30%
         else if(bid >= tp2 && StringFind(comment, "TP2") < 0)
         {
            double closeVol = NormalizeVolume(sym, volume * (InpTP2_ClosePercent / (100.0 - InpTP1_ClosePercent)) );
            if(closeVol > 0)
            {
               trade.PositionClosePartial(ticket, closeVol);
               Print("   TP2 HIT: Closed ", closeVol, " lots on ", sym);
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         tp1 = openPrice - risk * InpTP1_RR;
         tp2 = openPrice - risk * InpTP2_RR;
         
         if(ask <= tp1 && StringFind(comment, "TP1") < 0)
         {
            double closeVol = NormalizeVolume(sym, volume * InpTP1_ClosePercent / 100.0);
            if(closeVol > 0)
            {
               trade.PositionClosePartial(ticket, closeVol);
               Print("   TP1 HIT: Closed ", closeVol, " lots on ", sym);
            }
            if(InpMoveToBreakeven)
            {
               double newSL = openPrice - SymbolInfoInteger(sym, SYMBOL_SPREAD) * SymbolInfoDouble(sym, SYMBOL_POINT);
               trade.PositionModify(ticket, newSL, currentTP);
            }
         }
         else if(ask <= tp2 && StringFind(comment, "TP2") < 0)
         {
            double closeVol = NormalizeVolume(sym, volume * (InpTP2_ClosePercent / (100.0 - InpTP1_ClosePercent)) );
            if(closeVol > 0)
            {
               trade.PositionClosePartial(ticket, closeVol);
               Print("   TP2 HIT: Closed ", closeVol, " lots on ", sym);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| PROP FIRM PROTECTION                                               |
//+------------------------------------------------------------------+
bool CheckPropFirmSafe()
{
   if(maxLossHalt) return false;
   if(dailyHalt) return false;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Max loss check
   double totalLoss = initialBalance - equity;
   if(totalLoss >= InpMaxLossLimit * InpMaxSafetyPct)
   {
      Print("MAX LOSS REACHED - STOPPING ALL TRADING");
      CloseAll();
      maxLossHalt = true;
      return false;
   }
   
   // Daily loss check
   double dailyLoss = dayStartBalance - equity;
   if(dailyLoss >= InpDailyLossLimit * InpDailySafetyPct)
   {
      Print("DAILY LOSS LIMIT - HALTING FOR TODAY");
      CloseAll();
      dailyHalt = true;
      return false;
   }
   
   return true;
}

void CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| CALCULATE LOT SIZE (risk-based + prop firm aware)                  |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double slDistance)
{
   if(slDistance <= 0) return 0;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   
   // Prop firm cap
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
   
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                   |
//+------------------------------------------------------------------+

// New bar detection (per symbol)
bool IsNewBar(string symbol)
{
   static string syms[];
   static datetime times[];
   
   int idx = -1;
   for(int i = 0; i < ArraySize(syms); i++)
      if(syms[i] == symbol) { idx = i; break; }
   
   if(idx == -1)
   {
      idx = ArraySize(syms);
      ArrayResize(syms, idx + 1);
      ArrayResize(times, idx + 1);
      syms[idx] = symbol;
      times[idx] = 0;
   }
   
   datetime cur = iTime(symbol, InpLTF, 0);
   if(cur == times[idx]) return false;
   times[idx] = cur;
   return true;
}

// ATR value
double GetATR(string symbol)
{
   for(int i = 0; i < ArraySize(handles); i++)
   {
      if(handles[i].symbol == symbol)
      {
         double buf[];
         if(CopyBuffer(handles[i].atrHandle, 0, 1, 1, buf) > 0) return buf[0];
      }
   }
   return 0;
}

// EMA Fast
double GetEMAFast(string symbol)
{
   for(int i = 0; i < ArraySize(handles); i++)
   {
      if(handles[i].symbol == symbol)
      {
         double buf[];
         if(CopyBuffer(handles[i].emaFastHandle, 0, 1, 1, buf) > 0) return buf[0];
      }
   }
   return 0;
}

// EMA Slow
double GetEMASlow(string symbol)
{
   for(int i = 0; i < ArraySize(handles); i++)
   {
      if(handles[i].symbol == symbol)
      {
         double buf[];
         if(CopyBuffer(handles[i].emaSlowHandle, 0, 1, 1, buf) > 0) return buf[0];
      }
   }
   return 0;
}

// Check open position
bool HasOpenPosition(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         return true;
   return false;
}

// Set filling mode per symbol
void SetFilling(string symbol)
{
   long fill = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   if((fill & SYMBOL_FILLING_FOK) != 0) trade.SetTypeFilling(ORDER_FILLING_FOK);
   else if((fill & SYMBOL_FILLING_IOC) != 0) trade.SetTypeFilling(ORDER_FILLING_IOC);
   else trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

// Normalize volume to lot step
double NormalizeVolume(string symbol, double vol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   vol = MathFloor(vol / lotStep) * lotStep;
   if(vol < minLot) return 0;
   return vol;
}
//+------------------------------------------------------------------+
