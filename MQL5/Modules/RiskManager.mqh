//+------------------------------------------------------------------+
//|                                                 RiskManager.mqh   |
//|                  Risk Management & Funded Account Protection       |
//+------------------------------------------------------------------+
#property copyright "SMC ICT Bot"

#include "Defines.mqh"

//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double   m_RiskPercent;
   double   m_MaxDailyLoss;
   double   m_MaxTotalDrawdown;
   int      m_MaxTradesPerDay;
   int      m_MaxOpenTrades;
   double   m_MinRR;
   
   bool     m_FundedMode;
   double   m_DailyDD_Limit;
   double   m_TotalDD_Limit;
   double   m_SafetyBuffer;
   double   m_AccountStartBalance;
   double   m_HighWaterMark;
   
public:
   CRiskManager(double riskPercent, double maxDailyLoss, double maxTotalDrawdown,
                int maxTradesPerDay, int maxOpenTrades, double minRR,
                bool fundedMode, double dailyDDLimit, double totalDDLimit,
                double safetyBuffer, double startBalance);
   ~CRiskManager();
   
   double   CalculateLotSize(string symbol, double entryPrice, double stopLoss);
   bool     IsTradingAllowed(double dayStartEquity, double initialBalance);
   bool     CheckDailyDrawdown(double dayStartEquity);
   bool     CheckTotalDrawdown(double initialBalance);
   double   GetCurrentDrawdown(double initialBalance);
   void     UpdateHighWaterMark();
};

//+------------------------------------------------------------------+
CRiskManager::CRiskManager(double riskPercent, double maxDailyLoss, double maxTotalDrawdown,
                            int maxTradesPerDay, int maxOpenTrades, double minRR,
                            bool fundedMode, double dailyDDLimit, double totalDDLimit,
                            double safetyBuffer, double startBalance)
{
   m_RiskPercent = riskPercent;
   m_MaxDailyLoss = maxDailyLoss;
   m_MaxTotalDrawdown = maxTotalDrawdown;
   m_MaxTradesPerDay = maxTradesPerDay;
   m_MaxOpenTrades = maxOpenTrades;
   m_MinRR = minRR;
   m_FundedMode = fundedMode;
   m_DailyDD_Limit = dailyDDLimit;
   m_TotalDD_Limit = totalDDLimit;
   m_SafetyBuffer = safetyBuffer;
   m_AccountStartBalance = startBalance;
   m_HighWaterMark = (startBalance > 0) ? startBalance : AccountInfoDouble(ACCOUNT_BALANCE);
}

CRiskManager::~CRiskManager() {}

//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(string symbol, double entryPrice, double stopLoss)
{
   if(entryPrice == 0 || stopLoss == 0 || entryPrice == stopLoss) return 0;
   
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = accountEquity * (m_RiskPercent / 100.0);
   
   if(m_FundedMode)
   {
      double currentDD = GetCurrentDrawdown(m_AccountStartBalance);
      double ddRemaining = m_TotalDD_Limit - m_SafetyBuffer - currentDD;
      if(ddRemaining < m_RiskPercent * 2)
      {
         riskAmount *= 0.5;
         Print("⚠️ Risk reduced - approaching DD limit: ", DoubleToString(currentDD, 2), "%");
      }
   }
   
   double stopDistance = MathAbs(entryPrice - stopLoss);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   if(tickSize == 0 || tickValue == 0) return 0;
   
   double ticks = stopDistance / tickSize;
   double riskPerLot = ticks * tickValue;
   if(riskPerLot == 0) return 0;
   
   double lots = riskAmount / riskPerLot;
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(lots, minLot);
   lots = MathMin(lots, maxLot);
   
   return lots;
}

//+------------------------------------------------------------------+
bool CRiskManager::IsTradingAllowed(double dayStartEquity, double initialBalance)
{
   if(!CheckDailyDrawdown(dayStartEquity))
   {
      Print("🛑 TRADING STOPPED: Daily drawdown limit!");
      return false;
   }
   if(!CheckTotalDrawdown(initialBalance))
   {
      Print("🛑 TRADING STOPPED: Total drawdown limit!");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyDrawdown(double dayStartEquity)
{
   if(dayStartEquity <= 0) return true;
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyLoss = (dayStartEquity - currentEquity) / dayStartEquity * 100.0;
   double limit = m_FundedMode ? (m_DailyDD_Limit - m_SafetyBuffer) : m_MaxDailyLoss;
   
   if(dailyLoss >= limit)
   {
      Print("⛔ Daily Loss: ", DoubleToString(dailyLoss, 2), "% >= ", DoubleToString(limit, 2), "%");
      return false;
   }
   if(dailyLoss >= limit * 0.7)
      Print("⚠️ Daily loss warning: ", DoubleToString(dailyLoss, 2), "%");
   return true;
}

//+------------------------------------------------------------------+
bool CRiskManager::CheckTotalDrawdown(double initialBalance)
{
   if(initialBalance <= 0) return true;
   UpdateHighWaterMark();
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double totalDD = (m_HighWaterMark - currentEquity) / m_HighWaterMark * 100.0;
   double limit = m_FundedMode ? (m_TotalDD_Limit - m_SafetyBuffer) : m_MaxTotalDrawdown;
   
   if(totalDD >= limit)
   {
      Print("⛔ Total DD: ", DoubleToString(totalDD, 2), "% >= ", DoubleToString(limit, 2), "%");
      return false;
   }
   if(totalDD >= limit * 0.7)
      Print("⚠️ Total DD warning: ", DoubleToString(totalDD, 2), "%");
   return true;
}

//+------------------------------------------------------------------+
double CRiskManager::GetCurrentDrawdown(double initialBalance)
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(m_HighWaterMark <= 0) return 0;
   return (m_HighWaterMark - currentEquity) / m_HighWaterMark * 100.0;
}

//+------------------------------------------------------------------+
void CRiskManager::UpdateHighWaterMark()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(currentBalance > m_HighWaterMark)
      m_HighWaterMark = currentBalance;
}
//+------------------------------------------------------------------+
