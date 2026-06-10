//+------------------------------------------------------------------+
//|                                                     Defines.mqh  |
//|                     Shared Enums & Structures                     |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"

#ifndef DEFINES_MQH
#define DEFINES_MQH

//+------------------------------------------------------------------+
//| Market Bias Enum                                                   |
//+------------------------------------------------------------------+
enum ENUM_MARKET_BIAS
{
   BIAS_BULLISH,    // Bullish - Higher Highs, Higher Lows
   BIAS_BEARISH,    // Bearish - Lower Highs, Lower Lows
   BIAS_NEUTRAL     // No clear direction
};

//+------------------------------------------------------------------+
//| Structure Break Type                                               |
//+------------------------------------------------------------------+
enum ENUM_STRUCTURE_TYPE
{
   STRUCTURE_BOS,   // Break of Structure (continuation)
   STRUCTURE_CHOCH, // Change of Character (reversal)
   STRUCTURE_MSS,   // Market Structure Shift
   STRUCTURE_NONE
};

//+------------------------------------------------------------------+
//| Swing Point Structure                                              |
//+------------------------------------------------------------------+
struct SwingPoint
{
   double   price;
   datetime time;
   int      barIndex;
   bool     isHigh;    // true = swing high, false = swing low
   bool     isBroken;  // has this swing been broken?
};

#endif
//+------------------------------------------------------------------+
