//+------------------------------------------------------------------+
//|                                                   KillZones.mqh   |
//|                    ICT Kill Zone / Session Time Filter             |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"

#include "Defines.mqh"

//+------------------------------------------------------------------+
enum ENUM_SESSION
{
   SESSION_NONE,
   SESSION_ASIA,
   SESSION_LONDON,
   SESSION_NY,
   SESSION_LONDON_CLOSE
};

//+------------------------------------------------------------------+
class CKillZones
{
private:
   int m_LondonStart, m_LondonEnd;
   int m_NYStart, m_NYEnd;
   int m_LondonCloseStart, m_LondonCloseEnd;
   int m_GMTOffset;
   int m_AsiaStart, m_AsiaEnd;
   
public:
   CKillZones(int londonStart, int londonEnd,
              int nyStart, int nyEnd,
              int londonCloseStart, int londonCloseEnd,
              int gmtOffset);
   ~CKillZones();
   
   bool IsInKillZone(datetime time);
   ENUM_SESSION GetCurrentSession(datetime time);
   bool IsLondonOpen(datetime time);
   bool IsNewYorkOpen(datetime time);
   bool IsLondonClose(datetime time);
   bool IsTradingDay(datetime time);
   double GetSessionHigh(string symbol, ENUM_SESSION session);
   double GetSessionLow(string symbol, ENUM_SESSION session);
};

//+------------------------------------------------------------------+
CKillZones::CKillZones(int londonStart, int londonEnd,
                        int nyStart, int nyEnd,
                        int londonCloseStart, int londonCloseEnd,
                        int gmtOffset)
{
   m_LondonStart = londonStart;
   m_LondonEnd = londonEnd;
   m_NYStart = nyStart;
   m_NYEnd = nyEnd;
   m_LondonCloseStart = londonCloseStart;
   m_LondonCloseEnd = londonCloseEnd;
   m_GMTOffset = gmtOffset;
   m_AsiaStart = 0;
   m_AsiaEnd = 6;
}

CKillZones::~CKillZones() {}

//+------------------------------------------------------------------+
bool CKillZones::IsInKillZone(datetime time)
{
   return (IsLondonOpen(time) || IsNewYorkOpen(time) || IsLondonClose(time));
}

//+------------------------------------------------------------------+
ENUM_SESSION CKillZones::GetCurrentSession(datetime time)
{
   if(IsLondonOpen(time)) return SESSION_LONDON;
   if(IsNewYorkOpen(time)) return SESSION_NY;
   if(IsLondonClose(time)) return SESSION_LONDON_CLOSE;
   return SESSION_NONE;
}

//+------------------------------------------------------------------+
bool CKillZones::IsLondonOpen(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   int gmtHour = dt.hour - m_GMTOffset;
   if(gmtHour < 0) gmtHour += 24;
   if(gmtHour >= 24) gmtHour -= 24;
   return (gmtHour >= m_LondonStart && gmtHour < m_LondonEnd);
}

//+------------------------------------------------------------------+
bool CKillZones::IsNewYorkOpen(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   int gmtHour = dt.hour - m_GMTOffset;
   if(gmtHour < 0) gmtHour += 24;
   if(gmtHour >= 24) gmtHour -= 24;
   return (gmtHour >= m_NYStart && gmtHour < m_NYEnd);
}

//+------------------------------------------------------------------+
bool CKillZones::IsLondonClose(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   int gmtHour = dt.hour - m_GMTOffset;
   if(gmtHour < 0) gmtHour += 24;
   if(gmtHour >= 24) gmtHour -= 24;
   return (gmtHour >= m_LondonCloseStart && gmtHour < m_LondonCloseEnd);
}

//+------------------------------------------------------------------+
bool CKillZones::IsTradingDay(datetime time)
{
   MqlDateTime dt;
   TimeToStruct(time, dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   return true;
}

//+------------------------------------------------------------------+
double CKillZones::GetSessionHigh(string symbol, ENUM_SESSION session)
{
   int startHour = 0, endHour = 0;
   switch(session)
   {
      case SESSION_LONDON: startHour = m_LondonStart; endHour = m_LondonEnd; break;
      case SESSION_NY: startHour = m_NYStart; endHour = m_NYEnd; break;
      default: return 0;
   }
   
   double high[];
   datetime time[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(time, true);
   CopyHigh(symbol, PERIOD_M5, 0, 200, high);
   CopyTime(symbol, PERIOD_M5, 0, 200, time);
   
   double sessionHigh = 0;
   MqlDateTime dt;
   for(int i = 0; i < ArraySize(time); i++)
   {
      TimeToStruct(time[i], dt);
      int gmtHour = dt.hour - m_GMTOffset;
      if(gmtHour < 0) gmtHour += 24;
      if(gmtHour >= startHour && gmtHour < endHour)
      {
         if(high[i] > sessionHigh)
            sessionHigh = high[i];
      }
   }
   return sessionHigh;
}

//+------------------------------------------------------------------+
double CKillZones::GetSessionLow(string symbol, ENUM_SESSION session)
{
   int startHour = 0, endHour = 0;
   switch(session)
   {
      case SESSION_LONDON: startHour = m_LondonStart; endHour = m_LondonEnd; break;
      case SESSION_NY: startHour = m_NYStart; endHour = m_NYEnd; break;
      default: return 0;
   }
   
   double low[];
   datetime time[];
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   CopyLow(symbol, PERIOD_M5, 0, 200, low);
   CopyTime(symbol, PERIOD_M5, 0, 200, time);
   
   double sessionLow = DBL_MAX;
   MqlDateTime dt;
   for(int i = 0; i < ArraySize(time); i++)
   {
      TimeToStruct(time[i], dt);
      int gmtHour = dt.hour - m_GMTOffset;
      if(gmtHour < 0) gmtHour += 24;
      if(gmtHour >= startHour && gmtHour < endHour)
      {
         if(low[i] < sessionLow)
            sessionLow = low[i];
      }
   }
   return (sessionLow == DBL_MAX) ? 0 : sessionLow;
}
//+------------------------------------------------------------------+
