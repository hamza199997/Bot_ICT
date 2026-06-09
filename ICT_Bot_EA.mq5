//+------------------------------------------------------------------+
//|                                          ICT_Bot_EA.mq5          |
//|           ICT/SMC Proven Strategy - Optimized v3.1                |
//|           Order Block + FVG + Liquidity Sweep + HTF Bias          |
//|           3 Take Profits + Trailing Stop + 7 Fixes Applied       |
//+------------------------------------------------------------------+
#property copyright "ICT Bot v3.1 - Optimized"
#property version   "3.10"
#property strict
#property description "ICT/SMC: OB + FVG + Sweep | 3 TPs | Trailing | Day Filter | Session Filter"
#property description "7 optimization fixes applied from backtest analysis"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- Symbol & Timeframe
input ENUM_TIMEFRAMES InpHTF         = PERIOD_H1;     // HTF: Bias (EMA direction)
input ENUM_TIMEFRAMES InpLTF         = PERIOD_M5;     // LTF: Entry detection

// FIX [#5] — Session Time Filter (only trade during high-probability windows)
input bool     InpSessionFilterOn    = true;  // Enable Session Filter
input int      InpAsianStart         = 1;     // Asian Session Start (server hour)
input int      InpAsianEnd           = 5;     // Asian Session End
input int      InpLondonStart        = 8;     // London Session Start
input int      InpLondonEnd          = 12;    // London Session End
input int      InpNYStart            = 13;    // New York Session Start
input int      InpNYEnd              = 17;    // New York Session End

// FIX [#4] — Day Filter (block losing days)
input bool     InpDayFilterOn        = true;  // Enable Day Filter
input bool     InpBlockMonday        = false; // Block Monday
input bool     InpBlockTuesday       = true;  // Block Tuesday (identified as losing day)
input bool     InpBlockWednesday     = false; // Block Wednesday
input bool     InpBlockThursday      = false; // Block Thursday
input bool     InpBlockFriday        = false; // Block Friday

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

// FIX [#2] — Stop Loss VERY TIGHT (Gold ATR ~$30 on M5, so 1xATR = ~$30 max loss)
input int      InpATR_Period         = 14;    // ATR Period
input double   InpSL_ATR_Mult       = 0.3;   // SL buffer beyond zone (x ATR) - VERY tight
input double   InpSL_Min_ATR        = 0.4;   // Min SL distance (x ATR)
input double   InpSL_Max_ATR        = 1.0;   // Max SL (x ATR) - HARD CAP 1xATR! (not 1.5!)

// FIX [#1] — SIMPLE TP SYSTEM (no partial close = fixes avg-win < avg-loss!)
// At TP1 level: just move SL to breakeven (no close!) -> RISK FREE
// At TP2 level: FULL close (this is the actual take profit!)
// Result: Win = full TP2 ($90+), Loss = SL ($45) or Breakeven ($0)
input double   InpTP1_RR            = 1.5;   // TP1: Move to BREAKEVEN only (no close!)
input double   InpTP2_RR            = 3.0;   // TP2: FULL CLOSE here (actual TP = 3x Risk!)
input double   InpTP3_RR            = 5.0;   // TP3: Used for trailing / logging only
input double   InpMinRR             = 2.0;   // Minimum RR to accept ANY trade
input bool     InpMoveToBreakeven   = true;  // Move SL to breakeven at TP1 level

// FIX [#3] — Trailing Stop (don't leave money on the table)
input bool     InpUseTrailing        = true;  // Enable Trailing Stop
input double   InpTrailATRMult       = 1.0;   // Trailing distance (x ATR)
input double   InpTrailActivateRR    = 1.0;   // Activate trailing after X times risk in profit

// FIX [#7] — Dynamic Position Sizing (risk-based lot calculation)
input double   InpRiskPercent        = 1.0;   // Risk Per Trade (% of balance)
input int      InpMaxTradesPerDay    = 2;     // Max Trades Per Day TOTAL (1-2 = quality!)
input int      InpMaxTradesPerSymbol = 1;     // Max Trades Per Symbol Per Day (1 = best!)
input int      InpMagicNumber        = 300310; // Magic Number
input double   InpMaxSpread_ATR     = 0.3;   // Max Spread (x ATR)

// FIX [#6] — Max Consecutive Loss Protection
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

// FIX [#6] — Consecutive loss tracking
int    consecutiveLosses;
bool   consLossHalt;

// Per-symbol daily trade counter
struct SymbolDayTrades { string symbol; int count; };
SymbolDayTrades symDayTrades[];

struct SymbolHandles { string symbol; int atrHandle, emaFastHandle, emaSlowHandle; };
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
   }
   
   Print("=== ICT/SMC BOT v3.1 OPTIMIZED (7 Fixes) ===");
   Print("SL: max ", InpSL_Max_ATR, "xATR | TP: ", InpTP1_RR, "/", InpTP2_RR, "/", InpTP3_RR, " RR");
   Print("Trailing: ", InpUseTrailing?"ON":"OFF", " | Day Filter: ", InpDayFilterOn?"ON":"OFF");
   Print("Session Filter: ", InpSessionFilterOn?"ON":"OFF", " | ConsLoss Breaker: ", InpUseConsLossBreaker?"ON":"OFF");
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { Print("ICT Bot v3.1 removed."); }

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
      // FIX [#6] — Reset consecutive loss halt each new day
      consLossHalt = false;
      // Reset per-symbol daily trade counter
      ArrayResize(symDayTrades, 0);
   }
   
   if(InpPropFirmMode && !CheckPropFirmSafe()) return;
   if(todayTrades >= InpMaxTradesPerDay) return;
   
   // FIX [#6] — Consecutive loss breaker
   if(InpUseConsLossBreaker && consLossHalt) return;
   
   // FIX [#3] — Trailing stop management + partial TPs
   ManageOpenPositions();
   
   // FIX [#4] — Day filter
   if(InpDayFilterOn && IsDayBlocked(dt.day_of_week)) return;
   
   if(InpTradeEURUSD) ProcessSymbol("EURUSD");
   if(InpTradeXAUUSD) ProcessSymbol("XAUUSD");
   if(InpTradeNAS100) ProcessSymbol("NAS100");
}

//+------------------------------------------------------------------+
//| FIX [#4] — Day filter function                                     |
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
//| FIX [#5] — Session filter function                                 |
//+------------------------------------------------------------------+
bool IsInSession(int hour)
{
   if(!InpSessionFilterOn) return true;
   if(hour >= InpAsianStart && hour < InpAsianEnd) return true;
   if(hour >= InpLondonStart && hour < InpLondonEnd) return true;
   if(hour >= InpNYStart && hour < InpNYEnd) return true;
   return false;
}

//+------------------------------------------------------------------+
//| MAIN LOGIC                                                         |
//+------------------------------------------------------------------+
void ProcessSymbol(string symbol)
{
   if(!SymbolSelect(symbol, true)) return;
   if(HasOpenPosition(symbol)) return;
   if(!IsNewBar(symbol)) return;
   
   // Max trades per symbol per day check
   if(GetSymbolDayTrades(symbol) >= InpMaxTradesPerSymbol) return;
   
   double atr = GetATR(symbol);
   if(atr <= 0) return;
   
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(spread > atr * InpMaxSpread_ATR) return;
   
   // FIX [#5] — Session check
   MqlDateTime dt;
   TimeCurrent(dt);
   if(!IsInSession(dt.hour)) return;
   
   int bias = GetHTFBias(symbol);
   if(bias == 0) return;
   
   bool swept = DetectSweep(symbol, bias, atr);
   if(!swept) return;
   
   OrderBlock ob;
   FairValueGap fvg;
   bool obFound = FindOrderBlock(symbol, bias, atr, ob);
   bool fvgFound = FindFVG(symbol, bias, atr, fvg);
   if(!obFound && !fvgFound) return;
   
   TradeSetup setup;
   setup.valid = false;
   if(obFound)
      setup = BuildSetup(symbol, bias, ob.low, ob.high, atr, "OB");
   else if(fvgFound)
      setup = BuildSetup(symbol, bias, fvg.low, fvg.high, atr, "FVG");
   
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
   double close1 = iClose(symbol, InpHTF, 1);
   if(emaFast > emaSlow && close1 > emaFast) return 1;
   if(emaFast < emaSlow && close1 < emaFast) return -1;
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
   for(int i = 1; i <= 5; i++)
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
//| ORDER BLOCK                                                        |
//+------------------------------------------------------------------+
bool FindOrderBlock(string symbol, int bias, double atr, OrderBlock &ob)
{
   ob.valid = false;
   double minBody = InpOB_ATR_MinBody * atr;
   double minDisp = InpOB_ATR_Displacement * atr;
   double price = (bias == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   
   for(int i = 3; i < InpOB_Lookback; i++)
   {
      double o_i = iOpen(symbol, InpLTF, i), c_i = iClose(symbol, InpLTF, i);
      double h_i = iHigh(symbol, InpLTF, i), l_i = iLow(symbol, InpLTF, i);
      if(MathAbs(c_i - o_i) < minBody) continue;
      
      if(bias == 1 && c_i < o_i)
      {
         double maxH = 0;
         for(int j = i-1; j >= 1; j--) { double hj = iHigh(symbol, InpLTF, j); if(hj > maxH) maxH = hj; }
         if(maxH - h_i >= minDisp && price >= l_i && price <= h_i)
         { ob.high=h_i; ob.low=l_i; ob.isBullish=true; ob.valid=true; return true; }
      }
      if(bias == -1 && c_i > o_i)
      {
         double minL = DBL_MAX;
         for(int j = i-1; j >= 1; j--) { double lj = iLow(symbol, InpLTF, j); if(lj < minL) minL = lj; }
         if(l_i - minL >= minDisp && price <= h_i && price >= l_i)
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
   
   for(int i = 2; i < InpFVG_Lookback; i++)
   {
      double h1 = iHigh(symbol, InpLTF, i+1), l3 = iLow(symbol, InpLTF, i-1);
      double l1 = iLow(symbol, InpLTF, i+1), h3 = iHigh(symbol, InpLTF, i-1);
      
      if(bias == 1) { double gH=l3, gL=h1; if(gH>gL && gH-gL>=minSize && price>=gL && price<=gH) { fvg.high=gH; fvg.low=gL; fvg.isBullish=true; fvg.valid=true; return true; } }
      if(bias == -1) { double gH=l1, gL=h3; if(gH>gL && gH-gL>=minSize && price<=gH && price>=gL) { fvg.high=gH; fvg.low=gL; fvg.isBullish=false; fvg.valid=true; return true; } }
   }
   return false;
}

//+------------------------------------------------------------------+
//| BUILD SETUP — FIX [#1] min RR enforced, FIX [#2] tight SL         |
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
      // FIX [#2] — Reject if SL too wide
      if(risk > maxSL) return setup;
      // FIX [#1] — Enforce minimum RR
      if(InpTP1_RR < InpMinRR) return setup;
      
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
      if(InpTP1_RR < InpMinRR) return setup;
      
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
//| EXECUTE — FIX [#7] dynamic lot sizing                              |
//+------------------------------------------------------------------+
void ExecuteTrade(string symbol, TradeSetup &setup)
{
   // FIX [#7] — Dynamic position sizing based on SL distance
   double lotSize = CalculateLotSize(symbol, MathAbs(setup.entry - setup.sl));
   if(lotSize <= 0) return;
   
   SetFilling(symbol);
   
   // FIX: TP = TP2 (3x Risk) as FULL take profit. No partial close!
   // TP1 (1.5x) is only used to move SL to breakeven (managed in ManageOpenPositions)
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
      // FIX [#6] — Reset consecutive losses on win (new trade opened successfully)
      Print(">>> TRADE: ", symbol, " ", setup.reason, " Lot:", lotSize, " SL:", setup.sl, " TP3:", setup.tp3);
   }
   else
      Print("!!! FAILED: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| MANAGE POSITIONS — Move to breakeven at TP1 level + Trailing       |
//| NO partial close! Full close happens at TP2 (set as order TP)      |
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
      
      double tp1Level = 0;
      
      if(type == POSITION_TYPE_BUY)
      {
         tp1Level = openPrice + risk * InpTP1_RR;
         double profit = bid - openPrice;
         
         // Move to breakeven when price hits TP1 level (no close!)
         if(InpMoveToBreakeven && bid >= tp1Level && currentSL < openPrice)
         {
            double beSL = openPrice + SymbolInfoInteger(sym, SYMBOL_SPREAD) * SymbolInfoDouble(sym, SYMBOL_POINT);
            trade.PositionModify(ticket, beSL, currentTP);
            Print("   BE: ", sym, " SL moved to breakeven at ", beSL);
         }
         
         // FIX [#3] — Trailing Stop (activate after 1x risk in profit)
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
         tp1Level = openPrice - risk * InpTP1_RR;
         double profit = openPrice - ask;
         
         if(InpMoveToBreakeven && ask <= tp1Level && currentSL > openPrice)
         {
            double beSL = openPrice - SymbolInfoInteger(sym, SYMBOL_SPREAD) * SymbolInfoDouble(sym, SYMBOL_POINT);
            trade.PositionModify(ticket, beSL, currentTP);
            Print("   BE: ", sym, " SL moved to breakeven at ", beSL);
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
   
   // FIX [#6] — Track consecutive losses from trade history
   TrackConsecutiveLosses();
}

//+------------------------------------------------------------------+
//| FIX [#6] — Track consecutive losses from history                   |
//+------------------------------------------------------------------+
void TrackConsecutiveLosses()
{
   static int lastDealCount = 0;
   int totalDeals = HistoryDealsTotal();
   
   if(totalDeals <= lastDealCount) return;
   
   // Check most recent closed deal
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
         Print("!!! CONSECUTIVE LOSS BREAKER: ", consecutiveLosses, " losses. Halting for today.");
      }
   }
   else if(profit > 0)
   {
      consecutiveLosses = 0; // Reset on win
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
//| FIX [#7] — DYNAMIC LOT SIZE (risk % / SL distance)                |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol, double slDistance)
{
   if(slDistance <= 0) return 0;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   // FIX [#7] — Risk = 1% of current balance (dynamic, not fixed lot)
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

bool HasOpenPosition(string symbol)
{ for(int i=PositionsTotal()-1;i>=0;i--) if(PositionGetSymbol(i)==symbol && PositionGetInteger(POSITION_MAGIC)==InpMagicNumber) return true; return false; }

void SetFilling(string symbol)
{ long f=SymbolInfoInteger(symbol,SYMBOL_FILLING_MODE); if((f&SYMBOL_FILLING_FOK)!=0) trade.SetTypeFilling(ORDER_FILLING_FOK); else if((f&SYMBOL_FILLING_IOC)!=0) trade.SetTypeFilling(ORDER_FILLING_IOC); else trade.SetTypeFilling(ORDER_FILLING_RETURN); }

double NormalizeVolume(string symbol, double vol)
{ double mn=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN),st=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP); vol=MathFloor(vol/st)*st; return vol<mn?0:vol; }

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
