//+------------------------------------------------------------------+
//|                                                   Liquidity.mqh   |
//|                  Liquidity Detection & Sweep Analysis              |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"

#include "Defines.mqh"

//+------------------------------------------------------------------+
struct LiquidityPool
{
   double   level;
   datetime time;
   int      touchCount;
   bool     isAbove;     // true = buy-side, false = sell-side
   bool     isSwept;
};

//+------------------------------------------------------------------+
class CLiquidity
{
private:
   int      m_Lookback;
   double   m_Tolerance;
   LiquidityPool m_Pools[];
   
   void     DetectEqualHighs(string symbol, ENUM_TIMEFRAMES tf, double tolerance);
   void     DetectEqualLows(string symbol, ENUM_TIMEFRAMES tf, double tolerance);
   void     DetectPDHL(string symbol);
   bool     AreEqual(double price1, double price2, double tolerance);
   
public:
   CLiquidity(int lookback);
   ~CLiquidity();
   
   bool     DetectSweep(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias, double &sweepLevel);
   void     UpdatePools(string symbol, ENUM_TIMEFRAMES tf);
   double   FindNextLiquidityAbove(string symbol, ENUM_TIMEFRAMES tf, double currentPrice);
   double   FindNextLiquidityBelow(string symbol, ENUM_TIMEFRAMES tf, double currentPrice);
   int      GetPoolCount() { return ArraySize(m_Pools); }
};

//+------------------------------------------------------------------+
CLiquidity::CLiquidity(int lookback)
{
   m_Lookback = lookback;
   m_Tolerance = 0;
}

CLiquidity::~CLiquidity() {}

//+------------------------------------------------------------------+
bool CLiquidity::AreEqual(double price1, double price2, double tolerance)
{
   return (MathAbs(price1 - price2) <= tolerance);
}

//+------------------------------------------------------------------+
void CLiquidity::DetectEqualHighs(string symbol, ENUM_TIMEFRAMES tf, double tolerance)
{
   double high[];
   datetime time[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(time, true);
   
   CopyHigh(symbol, tf, 0, m_Lookback * 3, high);
   CopyTime(symbol, tf, 0, m_Lookback * 3, time);
   int bars = ArraySize(high);
   
   for(int i = 3; i < bars - 3; i++)
   {
      if(high[i] > high[i-1] && high[i] > high[i-2] &&
         high[i] > high[i+1] && high[i] > high[i+2])
      {
         int touches = 1;
         for(int j = i + 5; j < bars - 3; j++)
         {
            if(high[j] > high[j-1] && high[j] > high[j-2] &&
               high[j] > high[j+1] && high[j] > high[j+2])
            {
               if(AreEqual(high[i], high[j], tolerance))
                  touches++;
            }
         }
         
         if(touches >= 2)
         {
            LiquidityPool pool;
            pool.level = high[i];
            pool.time = time[i];
            pool.touchCount = touches;
            pool.isAbove = true;
            pool.isSwept = false;
            
            bool exists = false;
            for(int k = 0; k < ArraySize(m_Pools); k++)
            {
               if(AreEqual(m_Pools[k].level, pool.level, tolerance) && m_Pools[k].isAbove)
               { exists = true; break; }
            }
            if(!exists)
            {
               int size = ArraySize(m_Pools);
               ArrayResize(m_Pools, size + 1);
               m_Pools[size] = pool;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void CLiquidity::DetectEqualLows(string symbol, ENUM_TIMEFRAMES tf, double tolerance)
{
   double low[];
   datetime time[];
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   CopyLow(symbol, tf, 0, m_Lookback * 3, low);
   CopyTime(symbol, tf, 0, m_Lookback * 3, time);
   int bars = ArraySize(low);
   
   for(int i = 3; i < bars - 3; i++)
   {
      if(low[i] < low[i-1] && low[i] < low[i-2] &&
         low[i] < low[i+1] && low[i] < low[i+2])
      {
         int touches = 1;
         for(int j = i + 5; j < bars - 3; j++)
         {
            if(low[j] < low[j-1] && low[j] < low[j-2] &&
               low[j] < low[j+1] && low[j] < low[j+2])
            {
               if(AreEqual(low[i], low[j], tolerance))
                  touches++;
            }
         }
         
         if(touches >= 2)
         {
            LiquidityPool pool;
            pool.level = low[i];
            pool.time = time[i];
            pool.touchCount = touches;
            pool.isAbove = false;
            pool.isSwept = false;
            
            bool exists = false;
            for(int k = 0; k < ArraySize(m_Pools); k++)
            {
               if(AreEqual(m_Pools[k].level, pool.level, tolerance) && !m_Pools[k].isAbove)
               { exists = true; break; }
            }
            if(!exists)
            {
               int size = ArraySize(m_Pools);
               ArrayResize(m_Pools, size + 1);
               m_Pools[size] = pool;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void CLiquidity::DetectPDHL(string symbol)
{
   double dailyHigh[], dailyLow[];
   ArraySetAsSeries(dailyHigh, true);
   ArraySetAsSeries(dailyLow, true);
   
   CopyHigh(symbol, PERIOD_D1, 0, 5, dailyHigh);
   CopyLow(symbol, PERIOD_D1, 0, 5, dailyLow);
   
   if(ArraySize(dailyHigh) >= 2)
   {
      LiquidityPool pdh;
      pdh.level = dailyHigh[1];
      pdh.time = 0;
      pdh.touchCount = 1;
      pdh.isAbove = true;
      pdh.isSwept = false;
      int size = ArraySize(m_Pools);
      ArrayResize(m_Pools, size + 1);
      m_Pools[size] = pdh;
   }
   
   if(ArraySize(dailyLow) >= 2)
   {
      LiquidityPool pdl;
      pdl.level = dailyLow[1];
      pdl.time = 0;
      pdl.touchCount = 1;
      pdl.isAbove = false;
      pdl.isSwept = false;
      int size = ArraySize(m_Pools);
      ArrayResize(m_Pools, size + 1);
      m_Pools[size] = pdl;
   }
}

//+------------------------------------------------------------------+
void CLiquidity::UpdatePools(string symbol, ENUM_TIMEFRAMES tf)
{
   ArrayResize(m_Pools, 0);
   
   int atrHandle = iATR(symbol, tf, 14);
   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(atrHandle, 0, 0, 1, atr);
   IndicatorRelease(atrHandle);
   
   m_Tolerance = (ArraySize(atr) > 0) ? atr[0] * 0.1 : 0;
   
   DetectEqualHighs(symbol, tf, m_Tolerance);
   DetectEqualLows(symbol, tf, m_Tolerance);
   DetectPDHL(symbol);
}

//+------------------------------------------------------------------+
bool CLiquidity::DetectSweep(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias, double &sweepLevel)
{
   UpdatePools(symbol, tf);
   
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   CopyHigh(symbol, tf, 0, 10, high);
   CopyLow(symbol, tf, 0, 10, low);
   CopyClose(symbol, tf, 0, 10, close);
   
   if(bias == BIAS_BULLISH)
   {
      for(int p = 0; p < ArraySize(m_Pools); p++)
      {
         if(!m_Pools[p].isAbove && !m_Pools[p].isSwept)
         {
            for(int i = 1; i <= 5; i++)
            {
               if(low[i] < m_Pools[p].level && close[i] > m_Pools[p].level)
               {
                  m_Pools[p].isSwept = true;
                  sweepLevel = m_Pools[p].level;
                  return true;
               }
            }
         }
      }
   }
   else if(bias == BIAS_BEARISH)
   {
      for(int p = 0; p < ArraySize(m_Pools); p++)
      {
         if(m_Pools[p].isAbove && !m_Pools[p].isSwept)
         {
            for(int i = 1; i <= 5; i++)
            {
               if(high[i] > m_Pools[p].level && close[i] < m_Pools[p].level)
               {
                  m_Pools[p].isSwept = true;
                  sweepLevel = m_Pools[p].level;
                  return true;
               }
            }
         }
      }
   }
   
   sweepLevel = 0;
   return false;
}

//+------------------------------------------------------------------+
double CLiquidity::FindNextLiquidityAbove(string symbol, ENUM_TIMEFRAMES tf, double currentPrice)
{
   UpdatePools(symbol, tf);
   double nearest = 0;
   double minDist = DBL_MAX;
   
   for(int i = 0; i < ArraySize(m_Pools); i++)
   {
      if(m_Pools[i].isAbove && !m_Pools[i].isSwept && m_Pools[i].level > currentPrice)
      {
         double dist = m_Pools[i].level - currentPrice;
         if(dist < minDist)
         { minDist = dist; nearest = m_Pools[i].level; }
      }
   }
   return nearest;
}

//+------------------------------------------------------------------+
double CLiquidity::FindNextLiquidityBelow(string symbol, ENUM_TIMEFRAMES tf, double currentPrice)
{
   UpdatePools(symbol, tf);
   double nearest = 0;
   double minDist = DBL_MAX;
   
   for(int i = 0; i < ArraySize(m_Pools); i++)
   {
      if(!m_Pools[i].isAbove && !m_Pools[i].isSwept && m_Pools[i].level < currentPrice)
      {
         double dist = currentPrice - m_Pools[i].level;
         if(dist < minDist)
         { minDist = dist; nearest = m_Pools[i].level; }
      }
   }
   return nearest;
}
//+------------------------------------------------------------------+
