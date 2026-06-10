//+------------------------------------------------------------------+
//|                                                 OrderBlocks.mqh   |
//|                         Order Block Detection                      |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"

#include "Defines.mqh"

//+------------------------------------------------------------------+
struct OrderBlock
{
   double   top;
   double   bottom;
   datetime time;
   int      barIndex;
   bool     isBullish;
   bool     isMitigated;
   double   strength;
};

//+------------------------------------------------------------------+
class COrderBlocks
{
private:
   double      m_MinDisplacement;
   OrderBlock  m_Blocks[];
   
   double   GetATR(string symbol, ENUM_TIMEFRAMES tf, int period, int shift);
   
public:
   COrderBlocks(double minDisplacement);
   ~COrderBlocks();
   
   bool     FindValidOB(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias,
                        double &obTop, double &obBottom);
   void     DetectOrderBlocks(string symbol, ENUM_TIMEFRAMES tf, int lookback);
   int      GetBlockCount() { return ArraySize(m_Blocks); }
};

//+------------------------------------------------------------------+
COrderBlocks::COrderBlocks(double minDisplacement)
{
   m_MinDisplacement = minDisplacement;
}

COrderBlocks::~COrderBlocks() {}

//+------------------------------------------------------------------+
double COrderBlocks::GetATR(string symbol, ENUM_TIMEFRAMES tf, int period, int shift)
{
   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE) return 0;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(handle, 0, shift, 1, atr);
   IndicatorRelease(handle);
   
   return (ArraySize(atr) > 0) ? atr[0] : 0;
}

//+------------------------------------------------------------------+
void COrderBlocks::DetectOrderBlocks(string symbol, ENUM_TIMEFRAMES tf, int lookback)
{
   ArrayResize(m_Blocks, 0);
   
   double open[], high[], low[], close[];
   datetime time[];
   
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);
   
   int bars = lookback + 10;
   CopyOpen(symbol, tf, 0, bars, open);
   CopyHigh(symbol, tf, 0, bars, high);
   CopyLow(symbol, tf, 0, bars, low);
   CopyClose(symbol, tf, 0, bars, close);
   CopyTime(symbol, tf, 0, bars, time);
   
   if(ArraySize(open) < bars) return;
   
   for(int i = 2; i < lookback; i++)
   {
      double atr = GetATR(symbol, tf, 14, i);
      if(atr == 0) continue;
      
      // Bullish OB: bearish candle followed by strong bullish
      if(close[i+1] < open[i+1])
      {
         if(close[i] > open[i])
         {
            double body = close[i] - open[i];
            if(body >= atr * m_MinDisplacement)
            {
               if(close[i] > high[i+1])
               {
                  OrderBlock ob;
                  ob.top = high[i+1];
                  ob.bottom = low[i+1];
                  ob.time = time[i+1];
                  ob.barIndex = i+1;
                  ob.isBullish = true;
                  ob.isMitigated = false;
                  ob.strength = body / atr;
                  
                  for(int j = 0; j < i; j++)
                  {
                     if(low[j] <= ob.top)
                     {
                        ob.isMitigated = true;
                        break;
                     }
                  }
                  
                  int size = ArraySize(m_Blocks);
                  ArrayResize(m_Blocks, size + 1);
                  m_Blocks[size] = ob;
               }
            }
         }
      }
      
      // Bearish OB: bullish candle followed by strong bearish
      if(close[i+1] > open[i+1])
      {
         if(close[i] < open[i])
         {
            double body = open[i] - close[i];
            if(body >= atr * m_MinDisplacement)
            {
               if(close[i] < low[i+1])
               {
                  OrderBlock ob;
                  ob.top = high[i+1];
                  ob.bottom = low[i+1];
                  ob.time = time[i+1];
                  ob.barIndex = i+1;
                  ob.isBullish = false;
                  ob.isMitigated = false;
                  ob.strength = body / atr;
                  
                  for(int j = 0; j < i; j++)
                  {
                     if(high[j] >= ob.bottom)
                     {
                        ob.isMitigated = true;
                        break;
                     }
                  }
                  
                  int size = ArraySize(m_Blocks);
                  ArrayResize(m_Blocks, size + 1);
                  m_Blocks[size] = ob;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
bool COrderBlocks::FindValidOB(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias,
                                double &obTop, double &obBottom)
{
   DetectOrderBlocks(symbol, tf, 50);
   
   double close[];
   ArraySetAsSeries(close, true);
   CopyClose(symbol, tf, 0, 1, close);
   double currentPrice = close[0];
   
   double bestDistance = DBL_MAX;
   bool found = false;
   
   for(int i = 0; i < ArraySize(m_Blocks); i++)
   {
      if(m_Blocks[i].isMitigated) continue;
      
      if(bias == BIAS_BULLISH && m_Blocks[i].isBullish)
      {
         if(currentPrice >= m_Blocks[i].bottom && currentPrice <= m_Blocks[i].top)
         {
            obTop = m_Blocks[i].top;
            obBottom = m_Blocks[i].bottom;
            return true;
         }
         if(m_Blocks[i].top < currentPrice)
         {
            double distance = currentPrice - m_Blocks[i].top;
            if(distance < bestDistance)
            {
               bestDistance = distance;
               obTop = m_Blocks[i].top;
               obBottom = m_Blocks[i].bottom;
               found = true;
            }
         }
      }
      else if(bias == BIAS_BEARISH && !m_Blocks[i].isBullish)
      {
         if(currentPrice >= m_Blocks[i].bottom && currentPrice <= m_Blocks[i].top)
         {
            obTop = m_Blocks[i].top;
            obBottom = m_Blocks[i].bottom;
            return true;
         }
         if(m_Blocks[i].bottom > currentPrice)
         {
            double distance = m_Blocks[i].bottom - currentPrice;
            if(distance < bestDistance)
            {
               bestDistance = distance;
               obTop = m_Blocks[i].top;
               obBottom = m_Blocks[i].bottom;
               found = true;
            }
         }
      }
   }
   
   if(found)
   {
      double atr = GetATR(symbol, tf, 14, 0);
      if(bestDistance <= atr * 2.0)
         return true;
   }
   
   obTop = 0;
   obBottom = 0;
   return false;
}
//+------------------------------------------------------------------+
