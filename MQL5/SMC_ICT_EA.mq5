//+------------------------------------------------------------------+
//|                                                   SMC_ICT_EA.mq5 |
//|                        SMC/ICT 2022 Model Trading Bot            |
//|                        For Funded Accounts (MT5)                  |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| INCLUDES                                                          |
//+------------------------------------------------------------------+
#include "Modules/MarketStructure.mqh"
#include "Modules/Liquidity.mqh"
#include "Modules/OrderBlocks.mqh"
#include "Modules/FairValueGap.mqh"
#include "Modules/KillZones.mqh"
#include "Modules/RiskManager.mqh"
#include "Modules/TradeManager.mqh"

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input string   inp00 = "══════ GENERAL ══════";     // ─── General Settings ───
input int      MagicNumber          = 202201;        // Magic Number
input string   TradeComment         = "SMC_ICT";     // Trade Comment
input ENUM_TIMEFRAMES HTF_Timeframe = PERIOD_H4;     // Higher Timeframe (Bias)
input ENUM_TIMEFRAMES LTF_Timeframe = PERIOD_M15;    // Lower Timeframe (Entry)

input string   inp01 = "══════ SMC/ICT ══════";     // ─── SMC/ICT Settings ───
input int      StructureLookback    = 20;            // Swing Detection Lookback
input int      HTF_StructureLookback= 50;            // HTF Structure Lookback
input double   FVG_MinSize_Points   = 30;            // Min FVG Size (points)
input double   OB_MinDisplacement   = 1.5;           // Min OB Displacement (ATR x)
input double   OTE_Level            = 0.62;          // OTE Fib Level
input bool     RequireLiqSweep      = true;          // Require Liquidity Sweep
input bool     RequireFVG           = true;          // Require FVG Confirmation
input bool     RequireOB            = true;          // Require Order Block

input string   inp02 = "══════ SESSIONS ══════";    // ─── Sessions ───
input bool     TradeOnlyKillZones   = true;          // Trade Only in Kill Zones
input int      London_Start         = 7;             // London Open (GMT)
input int      London_End           = 10;            // London End (GMT)
input int      NY_Start             = 13;            // NY Open (GMT)
input int      NY_End               = 16;            // NY End (GMT)
input int      LdnClose_Start       = 15;            // London Close Start (GMT)
input int      LdnClose_End         = 16;            // London Close End (GMT)
input int      GMT_Offset           = 0;             // Broker GMT Offset

input string   inp03 = "══════ RISK ══════";        // ─── Risk Management ───
input double   RiskPerTrade         = 1.0;           // Risk Per Trade (%)
input double   MaxDailyLoss         = 3.0;           // Max Daily Loss (%)
input double   MaxTotalDrawdown     = 6.0;           // Max Total Drawdown (%)
input int      MaxTradesPerDay      = 3;             // Max Trades Per Day
input int      MaxOpenTrades        = 2;             // Max Open Trades
input double   MinRiskReward        = 2.0;           // Minimum R:R

input string   inp04 = "══════ TRADE MGMT ══════";  // ─── Trade Management ───
input bool     UseBreakEven         = true;          // Use Break Even
input double   BETrigger            = 1.0;           // BE Trigger (x Risk)
input double   BEOffset             = 5;             // BE Offset (points)
input bool     UseTrailing          = true;          // Use Trailing Stop
input double   TrailActivation      = 2.0;           // Trail Activation (x Risk)
input double   TrailStep            = 0.5;           // Trail Step (x Risk)
input bool     UsePartialClose      = true;          // Use Partial Close
input double   PartialPercent       = 50.0;          // Partial Close %
input double   PartialLevel         = 1.5;           // Partial Level (x Risk)

input string   inp05 = "══════ FUNDED ══════";      // ─── Funded Account ───
input bool     FundedMode           = true;          // Funded Mode ON/OFF
input double   StartBalance         = 100000;        // Starting Balance
input double   DailyDD_Limit        = 5.0;           // Daily DD Limit (%)
input double   TotalDD_Limit        = 10.0;          // Total DD Limit (%)
input double   SafetyBuffer         = 2.0;           // Safety Buffer (%)
input bool     PauseAfterLoss       = true;          // Pause After Consec Losses
input int      MaxConsecLoss        = 3;             // Max Consec Losses
input int      PauseHours           = 4;             // Pause Hours

input string   inp06 = "══════ NEWS ══════";        // ─── News Filter ───
input bool     UseNewsFilter        = true;          // Enable News Filter
input int      NewsMinBefore        = 30;            // Minutes Before News
input int      NewsMinAfter         = 30;            // Minutes After News

//+------------------------------------------------------------------+
//| GLOBAL OBJECTS                                                     |
//+------------------------------------------------------------------+
CMarketStructure   *g_Structure;
CLiquidity         *g_Liquidity;
COrderBlocks       *g_OrderBlocks;
CFairValueGap      *g_FVG;
CKillZones         *g_KillZones;
CRiskManager       *g_RiskManager;
CTradeManager      *g_TradeManager;

datetime g_LastBarTime = 0;
int      g_TodayTrades = 0;
datetime g_TodayDate = 0;
int      g_ConsecLosses = 0;
datetime g_PauseUntil = 0;
double   g_DayStartEquity = 0;
double   g_InitialBalance = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   g_Structure    = new CMarketStructure(StructureLookback, HTF_StructureLookback);
   g_Liquidity    = new CLiquidity(StructureLookback);
   g_OrderBlocks  = new COrderBlocks(OB_MinDisplacement);
   g_FVG          = new CFairValueGap(FVG_MinSize_Points);
   g_KillZones    = new CKillZones(London_Start, London_End, NY_Start, NY_End,
                                    LdnClose_Start, LdnClose_End, GMT_Offset);
   g_RiskManager  = new CRiskManager(RiskPerTrade, MaxDailyLoss, MaxTotalDrawdown,
                                      MaxTradesPerDay, MaxOpenTrades, MinRiskReward,
                                      FundedMode, DailyDD_Limit, TotalDD_Limit,
                                      SafetyBuffer, StartBalance);
   g_TradeManager = new CTradeManager(MagicNumber, TradeComment,
                                       UseBreakEven, BETrigger, BEOffset,
                                       UseTrailing, TrailActivation, TrailStep,
                                       UsePartialClose, PartialPercent, PartialLevel);

   g_InitialBalance = (StartBalance > 0) ? StartBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   g_DayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_TodayDate = iTime(_Symbol, PERIOD_D1, 0);
   
   Print("╔══════════════════════════════════════════╗");
   Print("║   SMC/ICT 2022 Model EA v1.0            ║");
   Print("║   Funded Mode: ", FundedMode ? "ON " : "OFF", "                     ║");
   Print("╚══════════════════════════════════════════╝");
   Print("Balance: ", g_InitialBalance, " | Risk: ", RiskPerTrade, "% | R:R min: ", MinRiskReward);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   delete g_Structure;
   delete g_Liquidity;
   delete g_OrderBlocks;
   delete g_FVG;
   delete g_KillZones;
   delete g_RiskManager;
   delete g_TradeManager;
}

//+------------------------------------------------------------------+
void OnTick()
{
   // New Day Reset
   datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
   if(currentDay != g_TodayDate)
   {
      g_TodayDate = currentDay;
      g_TodayTrades = 0;
      g_DayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   }
   
   // Manage existing trades
   g_TradeManager.ManageOpenTrades(_Symbol, LTF_Timeframe);
   
   // New Bar check
   datetime currentBarTime = iTime(_Symbol, LTF_Timeframe, 0);
   if(currentBarTime == g_LastBarTime) return;
   g_LastBarTime = currentBarTime;
   
   // Safety checks
   if(!g_RiskManager.IsTradingAllowed(g_DayStartEquity, g_InitialBalance)) return;
   if(PauseAfterLoss && TimeCurrent() < g_PauseUntil) return;
   if(g_TodayTrades >= MaxTradesPerDay) return;
   if(g_TradeManager.CountOpenTrades(MagicNumber) >= MaxOpenTrades) return;
   if(TradeOnlyKillZones && !g_KillZones.IsInKillZone(TimeCurrent())) return;
   if(UseNewsFilter && IsHighImpactNews()) return;
   
   // Execute strategy
   ExecuteStrategy();
}

//+------------------------------------------------------------------+
void ExecuteStrategy()
{
   // 1. HTF Bias
   ENUM_MARKET_BIAS bias = g_Structure.GetBias(_Symbol, HTF_Timeframe, HTF_StructureLookback);
   if(bias == BIAS_NEUTRAL) return;
   
   // 2. Premium/Discount Zone
   if(!g_Structure.IsInCorrectZone(_Symbol, HTF_Timeframe, bias)) return;
   
   // 3. Liquidity Sweep
   double sweepLevel = 0;
   if(RequireLiqSweep)
   {
      if(!g_Liquidity.DetectSweep(_Symbol, LTF_Timeframe, bias, sweepLevel)) return;
   }
   
   // 4. Market Structure Shift (CHoCH)
   if(!g_Structure.DetectMSS(_Symbol, LTF_Timeframe, bias)) return;
   
   // 5. Order Block
   double obTop = 0, obBottom = 0;
   if(RequireOB)
   {
      if(!g_OrderBlocks.FindValidOB(_Symbol, LTF_Timeframe, bias, obTop, obBottom)) return;
   }
   
   // 6. Fair Value Gap
   double fvgTop = 0, fvgBottom = 0;
   if(RequireFVG)
   {
      if(!g_FVG.FindValidFVG(_Symbol, LTF_Timeframe, bias, fvgTop, fvgBottom)) return;
   }
   
   // 7. Calculate levels
   double entry = 0, sl = 0, tp = 0;
   double zoneTop = (fvgTop > 0) ? fvgTop : obTop;
   double zoneBot = (fvgBottom > 0) ? fvgBottom : obBottom;
   
   double atr = GetATR(_Symbol, LTF_Timeframe, 14);
   
   if(bias == BIAS_BULLISH)
   {
      entry = zoneTop - (zoneTop - zoneBot) * OTE_Level;
      sl = MathMin(obBottom, sweepLevel > 0 ? sweepLevel : obBottom) - atr * 0.2;
      double nextLiq = g_Liquidity.FindNextLiquidityAbove(_Symbol, LTF_Timeframe, entry);
      tp = (nextLiq > 0 && (nextLiq - entry) / (entry - sl) >= MinRiskReward) ? nextLiq : entry + (entry - sl) * MinRiskReward;
   }
   else
   {
      entry = zoneBot + (zoneTop - zoneBot) * OTE_Level;
      sl = MathMax(obTop, sweepLevel > 0 ? sweepLevel : obTop) + atr * 0.2;
      double nextLiq = g_Liquidity.FindNextLiquidityBelow(_Symbol, LTF_Timeframe, entry);
      tp = (nextLiq > 0 && (entry - nextLiq) / (sl - entry) >= MinRiskReward) ? nextLiq : entry - (sl - entry) * MinRiskReward;
   }
   
   // 8. Validate R:R
   double rr = 0;
   if(bias == BIAS_BULLISH && entry > sl)
      rr = (tp - entry) / (entry - sl);
   else if(bias == BIAS_BEARISH && sl > entry)
      rr = (entry - tp) / (sl - entry);
   
   if(rr < MinRiskReward) return;
   
   // 9. Position size
   double lots = g_RiskManager.CalculateLotSize(_Symbol, entry, sl);
   if(lots <= 0) return;
   
   // 10. Execute
   bool opened = false;
   if(bias == BIAS_BULLISH)
      opened = g_TradeManager.OpenBuy(_Symbol, lots, sl, tp, entry);
   else
      opened = g_TradeManager.OpenSell(_Symbol, lots, sl, tp, entry);
   
   if(opened)
   {
      g_TodayTrades++;
      Print("═══ TRADE #", g_TodayTrades, " ═══");
      Print("Bias: ", bias == BIAS_BULLISH ? "BUY" : "SELL",
            " | Entry: ", entry, " | SL: ", sl, " | TP: ", tp, " | R:R: ", DoubleToString(rr, 2));
   }
}

//+------------------------------------------------------------------+
double GetATR(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE) return 0;
   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(handle, 0, 0, 1, atr);
   IndicatorRelease(handle);
   return (ArraySize(atr) > 0) ? atr[0] : 0;
}

//+------------------------------------------------------------------+
bool IsHighImpactNews()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   int hour = dt.hour - GMT_Offset;
   int minute = dt.min;
   
   // Common US news time: 13:30 GMT
   if(hour == 13 && minute >= (30 - NewsMinBefore) && minute <= (30 + NewsMinAfter))
      return true;
   // FOMC: 19:00 GMT  
   if(hour == 19 && minute <= NewsMinAfter)
      return true;
   if(hour == 18 && minute >= (60 - NewsMinBefore))
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         if(HistoryDealSelect(trans.deal))
         {
            double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            if(profit < 0)
            {
               g_ConsecLosses++;
               if(PauseAfterLoss && g_ConsecLosses >= MaxConsecLoss)
               {
                  g_PauseUntil = TimeCurrent() + PauseHours * 3600;
                  Print("⚠️ ", MaxConsecLoss, " losses - PAUSE until ", TimeToString(g_PauseUntil));
               }
            }
            else if(profit > 0)
               g_ConsecLosses = 0;
         }
      }
   }
}
//+------------------------------------------------------------------+
