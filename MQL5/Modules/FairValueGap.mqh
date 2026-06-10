//+------------------------------------------------------------------+
//|                                                 FairValueGap.mqh  |
//|                        Fair Value Gap (FVG) Detection              |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"

#include "Defines.mqh"

//+------------------------------------------------------------------+
struct FVGZone
{
   double   top;
   double   bottom;
   double   midPoint;
   datetime time;
   int      barIndex;
   bool     isBullish;
   bool     isFilled;
   double   fillPercent;
   double   size;
};

//+------------------------------------------------------------------+
class CFairValueGap
{
private:
   double   m_MinSize;
   FVGZone  m_Gaps[];
   
public:
   CFairValueGap(double minSize);
   ~CFairValueGap();
   
   bool     FindValidFVG(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias,
                         double &fvgTop, double &fvgBottom);
   void     DetectFVGs(string symbol, ENUM_TIMEFRAMES tf, int lookback);
   bool     IsPriceInFVG(double price, ENUM_MARKET_BIAS bias, double &fvgTop, double &fvgBottom);
   int      GetGapCount() { return ArraySize(m_Gaps); }
};

//+------------------------------------------------------------------+
CFairValueGap::CFairValueGap(double minSize)
{
   m_MinSize = minSize;
}

CFairValueGap::~CFairValueGap() {}

//+------------------------------------------------------------------+
void CFairValueGap::DetectFVGs(string symbol, ENUM_TIMEFRAMES tf, int lookback)
{
   ArrayResize(m_Gaps, 0);
   
   double open[], high[], low[], close[];
   datetime time[];
   
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);
   
   int bars = lookback + 5;
   CopyOpen(symbol, tf, 0, bars, open);
   CopyHigh(symbol, tf, 0, bars, high);
   CopyLow(symbol, tf, 0, bars, low);
   CopyClose(symbol, tf, 0, bars, close);
   CopyTime(symbol, tf, 0, bars, time);
   
   if(ArraySize(high) < bars) return;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   for(int i = 1; i < lookback - 2; i++)
   {
      // Bullish FVG: candle3 low > candle1 high
      double bullGapBottom = high[i+2];
      double bullGapTop = low[i];
      
      if(bullGapTop > bullGapBottom)
      {
         double gapSize = (bullGapTop - bullGapBottom) / point;
         if(gapSize >= m_MinSize)
         {
            FVGZone fvg;
            fvg.top = bullGapTop;
            fvg.bottom = bullGapBottom;
            fvg.midPoint = (bullGapTop + bullGapBottom) / 2.0;
            fvg.time = time[i+1];
            fvg.barIndex = i+1;
            fvg.isBullish = true;
            fvg.isFilled = false;
            fvg.fillPercent = 0;
            fvg.size = gapSize;
            
            for(int j = 0; j < i; j++)
            {
               if(low[j] <= fvg.bottom)
               {
                  fvg.isFilled = true;
                  break;
               }
            }
            
            int size = ArraySize(m_Gaps);
            ArrayResize(m_Gaps, size + 1);
            m_Gaps[size] = fvg;
         }
      }
      
      // Bearish FVG: candle1 low > candle3 high
      double bearGapTop = low[i+2];
      double bearGapBottom = high[i];
      
      if(bearGapTop > bearGapBottom)
      {
         double gapSize = (bearGapTop - bearGapBottom) / point;
         if(gapSize >= m_MinSize)
         {
            FVGZone fvg;
            fvg.top = bearGapTop;
            fvg.bottom = bearGapBottom;
            fvg.midPoint = (bearGapTop + bearGapBottom) / 2.0;
            fvg.time = time[i+1];
            fvg.barIndex = i+1;
            fvg.isBullish = false;
            fvg.isFilled = false;
            fvg.fillPercent = 0;
            fvg.size = gapSize;
            
            for(int j = 0; j < i; j++)
            {
               if(high[j] >= fvg.top)
               {
                  fvg.isFilled = true;
                  break;
               }
            }
            
            int size = ArraySize(m_Gaps);
            ArrayResize(m_Gaps, size + 1);
            m_Gaps[size] = fvg;
         }
      }
   }
}

//+------------------------------------------------------------------+
bool CFairValueGap::FindValidFVG(string symbol, ENUM_TIMEFRAMES tf, ENUM_MARKET_BIAS bias,
                                  double &fvgTop, double &fvgBottom)
{
   DetectFVGs(symbol, tf, 30);
   
   double close[];
   ArraySetAsSeries(close, true);
   CopyClose(symbol, tf, 0, 1, close);
   double currentPrice = close[0];
   
   for(int i = 0; i < ArraySize(m_Gaps); i++)
   {
      if(m_Gaps[i].isFilled) continue;
      
      if(bias == BIAS_BULLISH && m_Gaps[i].isBullish)
      {
         if(currentPrice >= m_Gaps[i].bottom && currentPrice <= m_Gaps[i].top)
         {
            fvgTop = m_Gaps[i].top;
            fvgBottom = m_Gaps[i].bottom;
            return true;
         }
         double distance = currentPrice - m_Gaps[i].top;
         double fvgSize = m_Gaps[i].top - m_Gaps[i].bottom;
         if(distance >= 0 && distance <= fvgSize * 2)
         {
            fvgTop = m_Gaps[i].top;
            fvgBottom = m_Gaps[i].bottom;
            return true;
         }
      }
      else if(bias == BIAS_BEARISH && !m_Gaps[i].isBullish)
      {
         if(currentPrice >= m_Gaps[i].bottom && currentPrice <= m_Gaps[i].top)
         {
            fvgTop = m_Gaps[i].top;
            fvgBottom = m_Gaps[i].bottom;
            return true;
         }
         double distance = m_Gaps[i].bottom - currentPrice;
         double fvgSize = m_Gaps[i].top - m_Gaps[i].bottom;
         if(distance >= 0 && distance <= fvgSize * 2)
         {
            fvgTop = m_Gaps[i].top;
            fvgBottom = m_Gaps[i].bottom;
            return true;
         }
      }
   }
   
   fvgTop = 0;
   fvgBottom = 0;
   return false;
}

//+------------------------------------------------------------------+
bool CFairValueGap::IsPriceInFVG(double price, ENUM_MARKET_BIAS bias, double &fvgTop, double &fvgBottom)
{
   for(int i = 0; i < ArraySize(m_Gaps); i++)
   {
      if(m_Gaps[i].isFilled) continue;
      if(price >= m_Gaps[i].bottom && price <= m_Gaps[i].top)
      {
         if((bias == BIAS_BULLISH && m_Gaps[i].isBullish) ||
            (bias == BIAS_BEARISH && !m_Gaps[i].isBullish))
         {
            fvgTop = m_Gaps[i].top;
            fvgBottom = m_Gaps[i].bottom;
            return true;
         }
      }
   }
   fvgTop = 0;
   fvgBottom = 0;
   return false;
}
//+------------------------------------------------------------------+
