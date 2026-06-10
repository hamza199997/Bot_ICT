//+------------------------------------------------------------------+
//|                                                TradeManager.mqh   |
//|                     Trade Execution & Management                   |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"

#include "Defines.mqh"
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
class CTradeManager
{
private:
   CTrade         m_Trade;
   CPositionInfo  m_Position;
   
   int      m_MagicNumber;
   string   m_Comment;
   
   bool     m_UseBreakEven;
   double   m_BETrigger;
   double   m_BEOffset;
   
   bool     m_UseTrailing;
   double   m_TrailActivation;
   double   m_TrailStep;
   
   bool     m_UsePartial;
   double   m_PartialPercent;
   double   m_PartialLevel;
   
   struct TradeInfo
   {
      ulong    ticket;
      double   entryPrice;
      double   originalSL;
      double   originalTP;
      double   riskInPoints;
      bool     breakEvenApplied;
      bool     partialClosed;
   };
   
   TradeInfo m_Trades[];
   
   void     AddTradeInfo(ulong ticket, double entry, double sl, double tp, string symbol);
   int      FindTradeIndex(ulong ticket);
   void     RemoveTradeInfo(ulong ticket);
   
public:
   CTradeManager(int magicNumber, string comment,
                 bool useBreakEven, double beTrigger, double beOffset,
                 bool useTrailing, double trailActivation, double trailStep,
                 bool usePartial, double partialPercent, double partialLevel);
   ~CTradeManager();
   
   bool     OpenBuy(string symbol, double lots, double sl, double tp, double entryPrice);
   bool     OpenSell(string symbol, double lots, double sl, double tp, double entryPrice);
   void     ManageOpenTrades(string symbol, ENUM_TIMEFRAMES tf);
   int      CountOpenTrades(int magicNumber);
   void     CloseAllTrades(string symbol);
};

//+------------------------------------------------------------------+
CTradeManager::CTradeManager(int magicNumber, string comment,
                              bool useBreakEven, double beTrigger, double beOffset,
                              bool useTrailing, double trailActivation, double trailStep,
                              bool usePartial, double partialPercent, double partialLevel)
{
   m_MagicNumber = magicNumber;
   m_Comment = comment;
   m_UseBreakEven = useBreakEven;
   m_BETrigger = beTrigger;
   m_BEOffset = beOffset;
   m_UseTrailing = useTrailing;
   m_TrailActivation = trailActivation;
   m_TrailStep = trailStep;
   m_UsePartial = usePartial;
   m_PartialPercent = partialPercent;
   m_PartialLevel = partialLevel;
   
   m_Trade.SetExpertMagicNumber(magicNumber);
   m_Trade.SetDeviationInPoints(30);
   m_Trade.SetTypeFilling(ORDER_FILLING_FOK);
}

CTradeManager::~CTradeManager() {}

//+------------------------------------------------------------------+
bool CTradeManager::OpenBuy(string symbol, double lots, double sl, double tp, double entryPrice)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   bool result = m_Trade.Buy(lots, symbol, 0, sl, tp, m_Comment);
   
   if(result)
   {
      ulong ticket = m_Trade.ResultOrder();
      if(ticket > 0)
      {
         AddTradeInfo(ticket, ask, sl, tp, symbol);
         Print("✅ BUY: #", ticket, " @ ", ask, " SL:", sl, " TP:", tp, " Lots:", lots);
      }
      return true;
   }
   Print("❌ BUY failed: ", m_Trade.ResultRetcodeDescription());
   return false;
}

//+------------------------------------------------------------------+
bool CTradeManager::OpenSell(string symbol, double lots, double sl, double tp, double entryPrice)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   bool result = m_Trade.Sell(lots, symbol, 0, sl, tp, m_Comment);
   
   if(result)
   {
      ulong ticket = m_Trade.ResultOrder();
      if(ticket > 0)
      {
         AddTradeInfo(ticket, bid, sl, tp, symbol);
         Print("✅ SELL: #", ticket, " @ ", bid, " SL:", sl, " TP:", tp, " Lots:", lots);
      }
      return true;
   }
   Print("❌ SELL failed: ", m_Trade.ResultRetcodeDescription());
   return false;
}

//+------------------------------------------------------------------+
void CTradeManager::ManageOpenTrades(string symbol, ENUM_TIMEFRAMES tf)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!m_Position.SelectByIndex(i)) continue;
      if(m_Position.Magic() != m_MagicNumber) continue;
      if(m_Position.Symbol() != symbol) continue;
      
      ulong ticket = m_Position.Ticket();
      int idx = FindTradeIndex(ticket);
      
      if(idx < 0)
      {
         AddTradeInfo(ticket, m_Position.PriceOpen(), m_Position.StopLoss(), m_Position.TakeProfit(), symbol);
         idx = FindTradeIndex(ticket);
         if(idx < 0) continue;
      }
      
      double entryPrice = m_Trades[idx].entryPrice;
      double riskPoints = m_Trades[idx].riskInPoints;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      // Break Even
      if(m_UseBreakEven && !m_Trades[idx].breakEvenApplied)
      {
         double triggerDist = riskPoints * m_BETrigger;
         double currentPrice = 0;
         double profit = 0;
         
         if(m_Position.PositionType() == POSITION_TYPE_BUY)
         {
            currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            profit = (currentPrice - entryPrice) / point;
         }
         else
         {
            currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            profit = (entryPrice - currentPrice) / point;
         }
         
         if(profit >= triggerDist)
         {
            double newSL = 0;
            if(m_Position.PositionType() == POSITION_TYPE_BUY)
               newSL = entryPrice + m_BEOffset * point;
            else
               newSL = entryPrice - m_BEOffset * point;
            
            if((m_Position.PositionType() == POSITION_TYPE_BUY && newSL > m_Position.StopLoss()) ||
               (m_Position.PositionType() == POSITION_TYPE_SELL && (newSL < m_Position.StopLoss() || m_Position.StopLoss() == 0)))
            {
               m_Trade.PositionModify(ticket, newSL, m_Position.TakeProfit());
               m_Trades[idx].breakEvenApplied = true;
               Print("🔒 BE applied: #", ticket);
            }
         }
      }
      
      // Trailing Stop
      if(m_UseTrailing && m_Trades[idx].breakEvenApplied)
      {
         double activDist = riskPoints * m_TrailActivation;
         double trailDist = riskPoints * m_TrailStep;
         
         if(m_Position.PositionType() == POSITION_TYPE_BUY)
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            double profit = (currentPrice - entryPrice) / point;
            if(profit >= activDist)
            {
               double newSL = currentPrice - trailDist * point;
               if(newSL > m_Position.StopLoss())
                  m_Trade.PositionModify(ticket, newSL, m_Position.TakeProfit());
            }
         }
         else
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double profit = (entryPrice - currentPrice) / point;
            if(profit >= activDist)
            {
               double newSL = currentPrice + trailDist * point;
               if(newSL < m_Position.StopLoss() || m_Position.StopLoss() == 0)
                  m_Trade.PositionModify(ticket, newSL, m_Position.TakeProfit());
            }
         }
      }
      
      // Partial Close
      if(m_UsePartial && !m_Trades[idx].partialClosed)
      {
         double triggerDist = riskPoints * m_PartialLevel;
         double profit = 0;
         
         if(m_Position.PositionType() == POSITION_TYPE_BUY)
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            profit = (currentPrice - entryPrice) / point;
         }
         else
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            profit = (entryPrice - currentPrice) / point;
         }
         
         if(profit >= triggerDist)
         {
            double closeVol = m_Position.Volume() * (m_PartialPercent / 100.0);
            double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
            double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            closeVol = MathFloor(closeVol / lotStep) * lotStep;
            closeVol = MathMax(closeVol, minLot);
            
            if(closeVol < m_Position.Volume())
            {
               if(m_Position.PositionType() == POSITION_TYPE_BUY)
                  m_Trade.Sell(closeVol, symbol);
               else
                  m_Trade.Buy(closeVol, symbol);
               m_Trades[idx].partialClosed = true;
               Print("📊 Partial close: ", DoubleToString(m_PartialPercent, 0), "% of #", ticket);
            }
         }
      }
   }
   
   // Clean up closed trades
   for(int i = ArraySize(m_Trades) - 1; i >= 0; i--)
   {
      bool found = false;
      for(int j = PositionsTotal() - 1; j >= 0; j--)
      {
         if(m_Position.SelectByIndex(j) && m_Position.Ticket() == m_Trades[i].ticket)
         { found = true; break; }
      }
      if(!found) RemoveTradeInfo(m_Trades[i].ticket);
   }
}

//+------------------------------------------------------------------+
int CTradeManager::CountOpenTrades(int magicNumber)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_Position.SelectByIndex(i) && m_Position.Magic() == magicNumber)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
void CTradeManager::CloseAllTrades(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(m_Position.SelectByIndex(i))
      {
         if(m_Position.Magic() == m_MagicNumber && m_Position.Symbol() == symbol)
            m_Trade.PositionClose(m_Position.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
void CTradeManager::AddTradeInfo(ulong ticket, double entry, double sl, double tp, string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point == 0) point = 0.00001;
   
   TradeInfo info;
   info.ticket = ticket;
   info.entryPrice = entry;
   info.originalSL = sl;
   info.originalTP = tp;
   info.riskInPoints = MathAbs(entry - sl) / point;
   info.breakEvenApplied = false;
   info.partialClosed = false;
   
   int size = ArraySize(m_Trades);
   ArrayResize(m_Trades, size + 1);
   m_Trades[size] = info;
}

//+------------------------------------------------------------------+
int CTradeManager::FindTradeIndex(ulong ticket)
{
   for(int i = 0; i < ArraySize(m_Trades); i++)
   {
      if(m_Trades[i].ticket == ticket) return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
void CTradeManager::RemoveTradeInfo(ulong ticket)
{
   int idx = FindTradeIndex(ticket);
   if(idx < 0) return;
   int last = ArraySize(m_Trades) - 1;
   if(idx != last) m_Trades[idx] = m_Trades[last];
   ArrayResize(m_Trades, last);
}
//+------------------------------------------------------------------+
