//+------------------------------------------------------------------+
//|                                          ICT_Bot_EA.mq5          |
//|           ICT/SMC Strategy v4.0 — Clean & Proven                  |
//|           CHoCH/BOS + OB + FVG + OTE + Sweep + Kill Zones        |
//|           Full TP (no partial) + Trailing + Prop Firm Safe        |
//+------------------------------------------------------------------+
#property copyright "ICT Bot v4.0"
#property version   "4.00"
#property strict
#property description "v4: CHoCH/BOS + Order Block + FVG + OTE Fib + Precise Kill Zones"
#property description "Full close at TP (3xRisk). No partial close. Tight SL."

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

//--- Timeframes
input ENUM_TIMEFRAMES InpHTF         = PERIOD_H1;     // HTF: Bias
input ENUM_TIMEFRAMES InpLTF         = PERIOD_M5;     // LTF: Entry

//--- Kill Zone PRECISE (server time)
input bool     InpKZ_Enabled         = true;  // Enable Kill Zone filter
input int      InpKZ_AsianStart      = 0;     // Asian macro start
input int      InpKZ_AsianEnd        = 4;     // Asian macro end
input int      InpKZ_LondonStart     = 7;     // London AM start
input int      InpKZ_LondonEnd       = 10;    // London AM end
input int      InpKZ_NYAMStart       = 12;    // NY AM start (best window)
input int      InpKZ_NYAMEnd         = 15;    // NY AM end
input int      InpKZ_NYPMStart       = 15;    // NY PM / London close
input int      InpKZ_NYPMEnd         = 17;    // NY PM end

//--- Day Filter
input bool     InpDayFilterOn        = true;  // Enable Day Filter
input bool     InpBlockTuesday       = true;  // Block Tuesday
input bool     InpBlockFriday        = false; // Block Friday

//--- HTF Bias (EMA)
input int      InpEMA_Fast           = 21;    // Fast EMA
input int      InpEMA_Slow           = 50;    // Slow EMA

//--- CHoCH / BOS Detection
input int      InpCHoCH_Lookback     = 20;    // Swing lookback for CHoCH/BOS
input double   InpCHoCH_ATR_MinMove  = 0.5;   // Min move size for valid BOS (x ATR)

//--- Order Block
input int      InpOB_Lookback        = 25;    // OB scan range
input double   InpOB_ATR_MinBody     = 0.3;   // OB min body (x ATR)
input double   InpOB_ATR_Displacement= 1.5;   // Displacement strength (x ATR)

//--- FVG
input int      InpFVG_Lookback       = 20;    // FVG scan range
input double   InpFVG_ATR_MinSize    = 0.15;  // Min FVG size (x ATR)

//--- Liquidity Sweep
input int      InpSweep_Lookback     = 25;    // Swing H/L lookback
input double   InpSweep_ATR_Thresh   = 0.1;   // Sweep threshold (x ATR)

//--- OTE Fibonacci Zone
input double   InpOTE_Start          = 0.62;  // OTE zone start (fib)
input double   InpOTE_End            = 0.79;  // OTE zone end (fib)
input bool     InpOTE_Required       = true;  // Require entry in OTE zone

//--- Stop Loss (ATR-based TIGHT)
input int      InpATR_Period         = 14;    // ATR Period
input double   InpSL_ATR_Mult       = 0.3;   // SL buffer (x ATR)
input double   InpSL_Min_ATR        = 0.4;   // Min SL (x ATR)
input double   InpSL_Max_ATR        = 1.0;   // Max SL (x ATR)

//--- Take Profit (FULL close, no partial!)
input double   InpTP_RR             = 3.0;   // TP = 3x Risk (FULL close)
input double   InpBE_RR             = 1.5;   // Move to Breakeven at 1.5x Risk

//--- Trailing Stop
input bool     InpUseTrailing        = true;  // Enable Trailing
input double   InpTrailATRMult       = 1.0;   // Trail distance (x ATR)
input double   InpTrailActivateRR    = 2.0;   // Activate trailing at 2x Risk

//--- Risk Management
input double   InpRiskPercent        = 1.0;   // Risk Per Trade (%)
input int      InpMaxTradesPerDay    = 2;     // Max Total Trades/Day
input int      InpMaxTradesPerSymbol = 1;     // Max Trades/Symbol/Day
input int      InpMagicNumber        = 400400; // Magic Number
input double   InpMaxSpread_ATR     = 0.3;   // Max Spread (x ATR)

//--- Consecutive Loss Breaker
input bool     InpUseConsLossBreaker = true;  // Enable Loss Breaker
input int      InpMaxConsLosses      = 3;     // Max consecutive losses

//--- Prop Firm
input bool     InpPropFirmMode       = true;  // Prop Firm Protection
input double   InpAccountSize        = 15000; // Account Size ($)
input double   InpDailyLossLimit     = 750;   // Daily Loss Limit ($)
input double   InpMaxLossLimit       = 1500;  // Max Loss Limit ($)
input double   InpDailySafetyPct    = 0.75;  // Stop at % of daily limit
input double   InpMaxSafetyPct      = 0.80;  // Stop at % of max limit

//--- Symbols
input bool     InpTradeEURUSD        = true;  // Trade EURUSD
input bool     InpTradeXAUUSD        = true;  // Trade XAUUSD
input bool     InpTradeNAS100        = true;  // Trade NAS100

//+------------------------------------------------------------------+
//| STRUCTURES                                                         |
//+------------------------------------------------------------------+
struct TradeSetup
{
   bool   valid;
   int    direction;
   double entry;
   double sl;
   double tp;
   string reason;
};

//+------------------------------------------------------------------+
//| GLOBALS                                                            |
//+------------------------------------------------------------------+
CTrade trade;
int    todayTrades;
datetime lastTradeDay;
double dayStartBalance, initialBalance;
bool   dailyHalt, maxLossHalt, consLossHalt;
int    consecutiveLosses;

struct SymHandles { string sym; int atr, emaF, emaS; };
SymHandles handles[];

struct SymDayCount { string sym; int count; };
SymDayCount symDay[];

//+------------------------------------------------------------------+
//| INIT                                                               |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   todayTrades = 0; lastTradeDay = 0;
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dayStartBalance = initialBalance;
   dailyHalt = false; maxLossHalt = false; consLossHalt = false;
   consecutiveLosses = 0;

   string syms[] = {"EURUSD","XAUUSD","NAS100"};
   for(int i = 0; i < 3; i++)
   {
      if(!SymbolSelect(syms[i], true)) continue;
      int idx = ArraySize(handles);
      ArrayResize(handles, idx+1);
      handles[idx].sym = syms[i];
      handles[idx].atr = iATR(syms[i], InpLTF, InpATR_Period);
      handles[idx].emaF = iMA(syms[i], InpHTF, InpEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      handles[idx].emaS = iMA(syms[i], InpHTF, InpEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   }

   Print("=== ICT BOT v4.0 ===");
   Print("CHoCH/BOS + OB + FVG + OTE + Sweep");
   Print("TP: ", InpTP_RR, "xRisk (FULL) | SL: max ", InpSL_Max_ATR, "xATR");
   Print("BE at: ", InpBE_RR, "xRisk | Trail: ", InpUseTrailing?"ON":"OFF");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { Print("ICT Bot v4 removed."); }

//+------------------------------------------------------------------+
//| TICK                                                                |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlDateTime dt; TimeCurrent(dt);
   datetime today = StringToTime(IntegerToString(dt.year)+"."+IntegerToString(dt.mon)+"."+IntegerToString(dt.day));

   if(today != lastTradeDay)
   {
      todayTrades = 0; lastTradeDay = today;
      dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      dailyHalt = false; consLossHalt = false;
      ArrayResize(symDay, 0);
   }

   if(InpPropFirmMode && !PropFirmSafe()) return;
   if(todayTrades >= InpMaxTradesPerDay) return;
   if(InpUseConsLossBreaker && consLossHalt) return;

   ManagePositions();
   TrackLosses();

   if(InpDayFilterOn && DayBlocked(dt.day_of_week)) return;

   if(InpTradeEURUSD) Process("EURUSD");
   if(InpTradeXAUUSD) Process("XAUUSD");
   if(InpTradeNAS100) Process("NAS100");
}

//+------------------------------------------------------------------+
//| MAIN STRATEGY LOGIC                                                |
//|                                                                    |
//| FLOW:                                                              |
//|  1. Kill Zone precise?                                             |
//|  2. HTF Bias (EMA)?                                                |
//|  3. Liquidity Sweep?                                               |
//|  4. CHoCH / BOS confirmed?                                        |
//|  5. OB or FVG entry zone?                                          |
//|  6. Price in OTE zone (62-79%)?                                    |
//|  7. Build setup -> Execute                                         |
//+------------------------------------------------------------------+
void Process(string symbol)
{
   if(!SymbolSelect(symbol, true)) return;
   if(HasPosition(symbol)) return;
   if(!NewBar(symbol)) return;
   if(GetSymDayCount(symbol) >= InpMaxTradesPerSymbol) return;

   double atr = ATR(symbol);
   if(atr <= 0) return;

   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(spread > atr * InpMaxSpread_ATR) return;

   // STEP 1: Kill Zone
   MqlDateTime dt; TimeCurrent(dt);
   if(InpKZ_Enabled && !InKillZone(dt.hour)) return;

   // STEP 2: HTF Bias
   int bias = Bias(symbol);
   if(bias == 0) return;

   // STEP 3: Liquidity Sweep
   if(!Sweep(symbol, bias, atr)) return;

   // STEP 4: CHoCH / BOS Confirmation
   if(!CHoCH(symbol, bias, atr)) return;

   // STEP 5: Find OB or FVG
   double zoneHigh = 0, zoneLow = 0;
   string entryType = "";
   if(FindOB(symbol, bias, atr, zoneLow, zoneHigh))
      entryType = "OB";
   else if(FindFVG(symbol, bias, atr, zoneLow, zoneHigh))
      entryType = "FVG";
   else return;

   // STEP 6: OTE check
   if(InpOTE_Required && !InOTE(symbol, bias, atr, zoneLow, zoneHigh)) return;

   // STEP 7: Build & Execute
   TradeSetup setup = Build(symbol, bias, zoneLow, zoneHigh, atr, entryType);
   if(setup.valid) Execute(symbol, setup);
}

//+------------------------------------------------------------------+
//| KILL ZONE PRECISE                                                  |
//+------------------------------------------------------------------+
bool InKillZone(int hour)
{
   if(hour >= InpKZ_AsianStart && hour < InpKZ_AsianEnd) return true;
   if(hour >= InpKZ_LondonStart && hour < InpKZ_LondonEnd) return true;
   if(hour >= InpKZ_NYAMStart && hour < InpKZ_NYAMEnd) return true;
   if(hour >= InpKZ_NYPMStart && hour < InpKZ_NYPMEnd) return true;
   return false;
}

//+------------------------------------------------------------------+
//| HTF BIAS                                                           |
//+------------------------------------------------------------------+
int Bias(string symbol)
{
   double f = EMAFast(symbol), s = EMASlow(symbol);
   if(f <= 0 || s <= 0) return 0;
   double c = iClose(symbol, InpHTF, 1);
   if(f > s && c > f) return 1;
   if(f < s && c < f) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| LIQUIDITY SWEEP                                                    |
//+------------------------------------------------------------------+
bool Sweep(string symbol, int bias, double atr)
{
   double thr = InpSweep_ATR_Thresh * atr;
   double swH = 0, swL = DBL_MAX;
   for(int i = 3; i <= InpSweep_Lookback; i++)
   {
      double h = iHigh(symbol, InpLTF, i), l = iLow(symbol, InpLTF, i);
      if(h > swH) swH = h;
      if(l < swL) swL = l;
   }
   for(int i = 1; i <= 5; i++)
   {
      double h = iHigh(symbol, InpLTF, i), l = iLow(symbol, InpLTF, i), c = iClose(symbol, InpLTF, i);
      if(bias == 1 && l < swL - thr && c > swL) return true;
      if(bias == -1 && h > swH + thr && c < swH) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| CHoCH / BOS CONFIRMATION                                           |
//| After sweep, check if market structure actually shifted            |
//+------------------------------------------------------------------+
bool CHoCH(string symbol, int bias, double atr)
{
   double minMove = InpCHoCH_ATR_MinMove * atr;

   double swH = 0, swL = DBL_MAX;
   for(int i = 2; i <= InpCHoCH_Lookback; i++)
   {
      double h = iHigh(symbol, InpLTF, i), l = iLow(symbol, InpLTF, i);
      if(i > 2 && i < InpCHoCH_Lookback - 1)
      {
         double prevH = iHigh(symbol, InpLTF, i+1), nextH = iHigh(symbol, InpLTF, i-1);
         if(h > prevH && h > nextH && h > swH) swH = h;
         double prevL = iLow(symbol, InpLTF, i+1), nextL = iLow(symbol, InpLTF, i-1);
         if(l < prevL && l < nextL && l < swL) swL = l;
      }
   }

   if(swH == 0 || swL == DBL_MAX) return false;

   for(int i = 1; i <= 3; i++)
   {
      double c = iClose(symbol, InpLTF, i);
      double o = iOpen(symbol, InpLTF, i);
      double body = MathAbs(c - o);

      if(bias == 1 && c > swH && body >= minMove) return true;
      if(bias == -1 && c < swL && body >= minMove) return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| ORDER BLOCK                                                        |
//+------------------------------------------------------------------+
bool FindOB(string symbol, int bias, double atr, double &zL, double &zH)
{
   double minBody = InpOB_ATR_MinBody * atr;
   double minDisp = InpOB_ATR_Displacement * atr;
   double price = (bias == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

   for(int i = 3; i < InpOB_Lookback; i++)
   {
      double o = iOpen(symbol, InpLTF, i), c = iClose(symbol, InpLTF, i);
      double h = iHigh(symbol, InpLTF, i), l = iLow(symbol, InpLTF, i);
      if(MathAbs(c - o) < minBody) continue;

      if(bias == 1 && c < o)
      {
         double maxH = 0;
         for(int j = i-1; j >= 1; j--) { double hj = iHigh(symbol, InpLTF, j); if(hj > maxH) maxH = hj; }
         if(maxH - h >= minDisp && price >= l && price <= h)
         { zL = l; zH = h; return true; }
      }
      if(bias == -1 && c > o)
      {
         double minL = DBL_MAX;
         for(int j = i-1; j >= 1; j--) { double lj = iLow(symbol, InpLTF, j); if(lj < minL) minL = lj; }
         if(l - minL >= minDisp && price <= h && price >= l)
         { zL = l; zH = h; return true; }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| FVG                                                                |
//+------------------------------------------------------------------+
bool FindFVG(string symbol, int bias, double atr, double &zL, double &zH)
{
   double minSz = InpFVG_ATR_MinSize * atr;
   double price = (bias == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

   for(int i = 2; i < InpFVG_Lookback; i++)
   {
      double h1 = iHigh(symbol, InpLTF, i+1), l1 = iLow(symbol, InpLTF, i+1);
      double l3 = iLow(symbol, InpLTF, i-1), h3 = iHigh(symbol, InpLTF, i-1);

      if(bias == 1) { double gH=l3, gL=h1; if(gH>gL && gH-gL>=minSz && price>=gL && price<=gH) { zL=gL; zH=gH; return true; } }
      if(bias == -1) { double gH=l1, gL=h3; if(gH>gL && gH-gL>=minSz && price<=gH && price>=gL) { zL=gL; zH=gH; return true; } }
   }
   return false;
}

//+------------------------------------------------------------------+
//| OTE FIBONACCI CHECK                                                |
//+------------------------------------------------------------------+
bool InOTE(string symbol, int bias, double atr, double zL, double zH)
{
   double moveHigh = 0, moveLow = DBL_MAX;
   for(int i = 1; i <= InpCHoCH_Lookback; i++)
   {
      double h = iHigh(symbol, InpLTF, i), l = iLow(symbol, InpLTF, i);
      if(h > moveHigh) moveHigh = h;
      if(l < moveLow) moveLow = l;
   }

   double range = moveHigh - moveLow;
   if(range <= 0) return false;

   double zoneMid = (zL + zH) / 2.0;

   if(bias == 1)
   {
      double oteTop = moveHigh - range * InpOTE_Start;
      double oteBot = moveHigh - range * InpOTE_End;
      return (zoneMid <= oteTop && zoneMid >= oteBot);
   }
   else
   {
      double oteBot = moveLow + range * InpOTE_Start;
      double oteTop = moveLow + range * InpOTE_End;
      return (zoneMid >= oteBot && zoneMid <= oteTop);
   }
}

//+------------------------------------------------------------------+
//| BUILD SETUP                                                        |
//+------------------------------------------------------------------+
TradeSetup Build(string symbol, int bias, double zL, double zH, double atr, string reason)
{
   TradeSetup s; s.valid = false;
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double buf = InpSL_ATR_Mult * atr;
   double minSL = InpSL_Min_ATR * atr, maxSL = InpSL_Max_ATR * atr;

   if(bias == 1)
   {
      s.entry = ask;
      s.sl = zL - buf;
      double risk = s.entry - s.sl;
      if(risk < minSL) { s.sl = s.entry - minSL; risk = minSL; }
      if(risk > maxSL) return s;
      s.tp = s.entry + risk * InpTP_RR;
      s.direction = 1;
      s.reason = reason + " Buy";
      s.valid = true;
   }
   else
   {
      s.entry = bid;
      s.sl = zH + buf;
      double risk = s.sl - s.entry;
      if(risk < minSL) { s.sl = s.entry + minSL; risk = minSL; }
      if(risk > maxSL) return s;
      s.tp = s.entry - risk * InpTP_RR;
      s.direction = -1;
      s.reason = reason + " Sell";
      s.valid = true;
   }
   return s;
}

//+------------------------------------------------------------------+
//| EXECUTE                                                            |
//+------------------------------------------------------------------+
void Execute(string symbol, TradeSetup &s)
{
   double lot = LotSize(symbol, MathAbs(s.entry - s.sl));
   if(lot <= 0) return;
   SetFill(symbol);

   bool ok = (s.direction == 1) ?
      trade.Buy(lot, symbol, s.entry, s.sl, s.tp, s.reason) :
      trade.Sell(lot, symbol, s.entry, s.sl, s.tp, s.reason);

   if(ok)
   {
      todayTrades++;
      IncSymDay(symbol);
      Print(">>> ", symbol, " ", s.reason, " Lot:", lot, " SL:", s.sl, " TP:", s.tp);
   }
   else Print("!!! FAIL: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| MANAGE POSITIONS (Breakeven + Trailing, NO partial close)          |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      string sym = PositionGetString(POSITION_SYMBOL);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      long type = PositionGetInteger(POSITION_TYPE);
      double risk = MathAbs(open - sl);
      if(risk <= 0) continue;

      double atr = ATR(sym);
      if(atr <= 0) atr = risk;
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

      if(type == POSITION_TYPE_BUY)
      {
         double profit = bid - open;
         if(profit >= risk * InpBE_RR && sl < open)
         {
            double be = open + SymbolInfoInteger(sym, SYMBOL_SPREAD) * SymbolInfoDouble(sym, SYMBOL_POINT);
            trade.PositionModify(ticket, be, tp);
         }
         if(InpUseTrailing && profit >= risk * InpTrailActivateRR && sl >= open)
         {
            double newSL = bid - InpTrailATRMult * atr;
            if(newSL > sl) trade.PositionModify(ticket, newSL, tp);
         }
      }
      else
      {
         double profit = open - ask;
         if(profit >= risk * InpBE_RR && sl > open)
         {
            double be = open - SymbolInfoInteger(sym, SYMBOL_SPREAD) * SymbolInfoDouble(sym, SYMBOL_POINT);
            trade.PositionModify(ticket, be, tp);
         }
         if(InpUseTrailing && profit >= risk * InpTrailActivateRR && sl <= open)
         {
            double newSL = ask + InpTrailATRMult * atr;
            if(newSL < sl) trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CONSECUTIVE LOSS TRACKER                                           |
//+------------------------------------------------------------------+
void TrackLosses()
{
   static int lastDeals = 0;
   HistorySelect(0, TimeCurrent());
   int deals = HistoryDealsTotal();
   if(deals <= lastDeals) return;

   ulong ticket = HistoryDealGetTicket(deals - 1);
   if(ticket <= 0) return;
   if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) return;
   if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) return;

   double pnl = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                HistoryDealGetDouble(ticket, DEAL_SWAP) +
                HistoryDealGetDouble(ticket, DEAL_COMMISSION);

   if(pnl < 0) { consecutiveLosses++; if(consecutiveLosses >= InpMaxConsLosses) consLossHalt = true; }
   else if(pnl > 0) consecutiveLosses = 0;

   lastDeals = deals;
}

//+------------------------------------------------------------------+
//| PROP FIRM                                                          |
//+------------------------------------------------------------------+
bool PropFirmSafe()
{
   if(maxLossHalt || dailyHalt) return false;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   if(initialBalance - eq >= InpMaxLossLimit * InpMaxSafetyPct) { CloseAll(); maxLossHalt = true; return false; }
   if(dayStartBalance - eq >= InpDailyLossLimit * InpDailySafetyPct) { CloseAll(); dailyHalt = true; return false; }
   return true;
}

void CloseAll()
{ for(int i = PositionsTotal()-1; i >= 0; i--) { ulong t = PositionGetTicket(i); if(t > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) trade.PositionClose(t); } }

//+------------------------------------------------------------------+
//| LOT SIZE (dynamic risk-based)                                      |
//+------------------------------------------------------------------+
double LotSize(string symbol, double slDist)
{
   if(slDist <= 0) return 0;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk = bal * (InpRiskPercent / 100.0);

   if(InpPropFirmMode)
   {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      double dr = (InpDailyLossLimit * InpDailySafetyPct) - (dayStartBalance - eq);
      double mr = (InpMaxLossLimit * InpMaxSafetyPct) - (initialBalance - eq);
      risk = MathMin(risk, MathMax(0, dr));
      risk = MathMin(risk, MathMax(0, mr));
      if(risk <= 0) return 0;
   }

   double tv = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double ts = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tv <= 0 || ts <= 0) return 0;

   double lot = risk / ((slDist / ts) * tv);
   double mn = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double mx = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double st = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / st) * st;
   lot = MathMax(mn, MathMin(mx, lot));
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| HELPERS                                                            |
//+------------------------------------------------------------------+
bool NewBar(string symbol)
{
   static string ss[]; static datetime tt[];
   int idx = -1;
   for(int i = 0; i < ArraySize(ss); i++) if(ss[i] == symbol) { idx = i; break; }
   if(idx == -1) { idx = ArraySize(ss); ArrayResize(ss, idx+1); ArrayResize(tt, idx+1); ss[idx] = symbol; tt[idx] = 0; }
   datetime c = iTime(symbol, InpLTF, 0);
   if(c == tt[idx]) return false;
   tt[idx] = c; return true;
}

double ATR(string symbol)
{ for(int i = 0; i < ArraySize(handles); i++) if(handles[i].sym == symbol) { double b[]; if(CopyBuffer(handles[i].atr, 0, 1, 1, b) > 0) return b[0]; } return 0; }

double EMAFast(string symbol)
{ for(int i = 0; i < ArraySize(handles); i++) if(handles[i].sym == symbol) { double b[]; if(CopyBuffer(handles[i].emaF, 0, 1, 1, b) > 0) return b[0]; } return 0; }

double EMASlow(string symbol)
{ for(int i = 0; i < ArraySize(handles); i++) if(handles[i].sym == symbol) { double b[]; if(CopyBuffer(handles[i].emaS, 0, 1, 1, b) > 0) return b[0]; } return 0; }

bool HasPosition(string symbol)
{ for(int i = PositionsTotal()-1; i >= 0; i--) if(PositionGetSymbol(i) == symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) return true; return false; }

void SetFill(string symbol)
{ long f = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE); if((f & SYMBOL_FILLING_FOK) != 0) trade.SetTypeFilling(ORDER_FILLING_FOK); else if((f & SYMBOL_FILLING_IOC) != 0) trade.SetTypeFilling(ORDER_FILLING_IOC); else trade.SetTypeFilling(ORDER_FILLING_RETURN); }

bool DayBlocked(int d)
{ if(d == 2 && InpBlockTuesday) return true; if(d == 5 && InpBlockFriday) return true; return false; }

int GetSymDayCount(string symbol)
{ for(int i = 0; i < ArraySize(symDay); i++) if(symDay[i].sym == symbol) return symDay[i].count; return 0; }

void IncSymDay(string symbol)
{ for(int i = 0; i < ArraySize(symDay); i++) if(symDay[i].sym == symbol) { symDay[i].count++; return; } int n = ArraySize(symDay); ArrayResize(symDay, n+1); symDay[n].sym = symbol; symDay[n].count = 1; }
//+------------------------------------------------------------------+
