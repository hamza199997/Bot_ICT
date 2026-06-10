//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh  |
//|                     Market Structure Analysis (BOS/CHoCH/MSS)     |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"

#include "Defines.mqh"

//+------------------------------------------------------------------+
//| CMarketStructure Class                                             |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   int      m_LTF_Lookback;
   int      m_HTF_Lookback;
   
   SwingPoint m_SwingHighs[];
   SwingPoint m_SwingLows[];
   
   bool     IsSwingHigh(const double &high[], int index, int lookback);
   bool     IsSwingLow(const double &low[], int index, int lookback);
   void     FindSwingPoints(string symbol, ENUM_TIMEFRAMES tf, int lookback, int depth);
   
public:
   CMarketStructure(int ltfLookback, int htfLookback);
   ~CMarketStructure();
   
   ENUM_MARKET_BIAS GetBias(string symbol, ENUM_TIMEFRAMES tf, int lookback);
   bool DetectMSS(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS expectedBias);
   bool IsInCorrectZone(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias);
   double GetLastBOSLevel(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias);
   void GetSwingHighs(SwingPoint &highs[]);
   void GetSwingLows(SwingPoint &lows[]);
};

//+------------------------------------------------------------------+
CMarketStructure::CMarketStructure(int ltfLookback, int htfLookback)
{
   m_LTF_Lookback = ltfLookback;
   m_HTF_Lookback = htfLookback;
}

CMarketStructure::~CMarketStructure() {}

//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingHigh(const double &high[], int index, int lookback)
{
   if(index < lookback || index >= ArraySize(high) - lookback)
      return false;
   for(int i = 1; i <= lookback; i++)
   {
      if(high[index] <= high[index - i] || high[index] <= high[index + i])
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool CMarketStructure::IsSwingLow(const double &low[], int index, int lookback)
{
   if(index < lookback || index >= ArraySize(low) - lookback)
      return false;
   for(int i = 1; i <= lookback; i++)
   {
      if(low[index] >= low[index - i] || low[index] >= low[index + i])
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
void CMarketStructure::FindSwingPoints(string symbol, ENUM_TIMEFRAMES tf, int lookback, int depth)
{
   double high[], low[];
   datetime time[];
   
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   int bars = depth + lookback * 2;
   CopyHigh(symbol, tf, 0, bars, high);
   CopyLow(symbol, tf, 0, bars, low);
   CopyTime(symbol, tf, 0, bars, time);
   
   ArrayResize(m_SwingHighs, 0);
   ArrayResize(m_SwingLows, 0);
   
   for(int i = lookback; i < bars - lookback; i++)
   {
      if(IsSwingHigh(high, i, lookback))
      {
         SwingPoint sp;
         sp.price = high[i];
         sp.time = time[i];
         sp.barIndex = i;
         sp.isHigh = true;
         sp.isBroken = false;
         int size = ArraySize(m_SwingHighs);
         ArrayResize(m_SwingHighs, size + 1);
         m_SwingHighs[size] = sp;
      }
      
      if(IsSwingLow(low, i, lookback))
      {
         SwingPoint sp;
         sp.price = low[i];
         sp.time = time[i];
         sp.barIndex = i;
         sp.isHigh = false;
         sp.isBroken = false;
         int size = ArraySize(m_SwingLows);
         ArrayResize(m_SwingLows, size + 1);
         m_SwingLows[size] = sp;
      }
   }
}

//+------------------------------------------------------------------+
ENUM_MARKET_BIAS CMarketStructure::GetBias(string symbol, ENUM_TIMEFRAMES tf, int lookback)
{
   FindSwingPoints(symbol, tf, 3, lookback);
   
   int highCount = ArraySize(m_SwingHighs);
   int lowCount = ArraySize(m_SwingLows);
   
   if(highCount < 2 || lowCount < 2)
      return BIAS_NEUTRAL;
   
   bool higherHighs = (m_SwingHighs[0].price > m_SwingHighs[1].price);
   bool higherLows = (m_SwingLows[0].price > m_SwingLows[1].price);
   bool lowerHighs = (m_SwingHighs[0].price < m_SwingHighs[1].price);
   bool lowerLows = (m_SwingLows[0].price < m_SwingLows[1].price);
   
   if(higherHighs && higherLows)
      return BIAS_BULLISH;
   if(lowerHighs && lowerLows)
      return BIAS_BEARISH;
   
   return BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
bool CMarketStructure::DetectMSS(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS expectedBias)
{
   FindSwingPoints(symbol, tf, 2, m_LTF_Lookback);
   
   double close[];
   ArraySetAsSeries(close, true);
   CopyClose(symbol, tf, 0, 5, close);
   double currentPrice = close[0];
   
   if(expectedBias == BIAS_BULLISH)
   {
      if(ArraySize(m_SwingHighs) >= 2 && ArraySize(m_SwingLows) >= 2)
      {
         double recentSwingHigh = m_SwingHighs[0].price;
         double prevSwingLow = m_SwingLows[0].price;
         double prevPrevSwingLow = m_SwingLows[1].price;
         
         bool wasBearish = (prevSwingLow < prevPrevSwingLow);
         bool breakAbove = (currentPrice > recentSwingHigh);
         
         if(wasBearish && breakAbove)
            return true;
      }
   }
   else if(expectedBias == BIAS_BEARISH)
   {
      if(ArraySize(m_SwingLows) >= 2 && ArraySize(m_SwingHighs) >= 2)
      {
         double recentSwingLow = m_SwingLows[0].price;
         double prevSwingHigh = m_SwingHighs[0].price;
         double prevPrevSwingHigh = m_SwingHighs[1].price;
         
         bool wasBullish = (prevSwingHigh > prevPrevSwingHigh);
         bool breakBelow = (currentPrice < recentSwingLow);
         
         if(wasBullish && breakBelow)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
bool CMarketStructure::IsInCorrectZone(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias)
{
   FindSwingPoints(symbol, tf, 3, m_HTF_Lookback);
   
   if(ArraySize(m_SwingHighs) < 1 || ArraySize(m_SwingLows) < 1)
      return false;
   
   double swingHigh = m_SwingHighs[0].price;
   double swingLow = m_SwingLows[0].price;
   double range = swingHigh - swingLow;
   
   if(range <= 0) return false;
   
   double close[];
   ArraySetAsSeries(close, true);
   CopyClose(symbol, tf, 0, 1, close);
   double currentPrice = close[0];
   
   double position = (currentPrice - swingLow) / range;
   
   if(bias == BIAS_BULLISH)
      return (position <= 0.5);
   else if(bias == BIAS_BEARISH)
      return (position >= 0.5);
   
   return false;
}

//+------------------------------------------------------------------+
double CMarketStructure::GetLastBOSLevel(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias)
{
   FindSwingPoints(symbol, tf, 3, m_LTF_Lookback);
   
   if(bias == BIAS_BULLISH && ArraySize(m_SwingHighs) > 0)
      return m_SwingHighs[0].price;
   if(bias == BIAS_BEARISH && ArraySize(m_SwingLows) > 0)
      return m_SwingLows[0].price;
   
   return 0;
}

//+------------------------------------------------------------------+
void CMarketStructure::GetSwingHighs(SwingPoint &highs[])
{
   ArrayCopy(highs, m_SwingHighs);
}

void CMarketStructure::GetSwingLows(SwingPoint &lows[])
{
   ArrayCopy(lows, m_SwingLows);
}
//+------------------------------------------------------------------+
