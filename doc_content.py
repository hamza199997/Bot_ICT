# -*- coding: utf-8 -*-
# Contenu dyal l'guide b darija (Latin script). Markers:
# [TITLE] / [SUB] / # / ## / ### / * bullet / [NOTE] / --- rule / [PB] pagebreak

DOC = r"""

[TITLE] ICT TRADING STRATEGY
[SUB] Guide kaml b darija - mn A to Z

[SUB] Bot: ICT 2022 Confluence Model (MT5)
[SUB] Instruments: EURUSD - XAUUSD (Gold) - NAS100 (Nasdaq)
[SUB] Account: FundedNext 15000 USD

---

[NOTE] Had l'guide mektob bach tefhem strategy kamla, tradi b yedek wala b bot. Kollshi mshro7 b darija.

[PB]

# 0. MUQADDIMA: Ash huwa ICT?

ICT = Inner Circle Trader, smiya dyal Michael Huddleston, li dewa b mafhoum "Smart Money".

L'fikra l'asasiya: l'marche ma kayt7arrekch 3la 7sab retail traders (na7nu les petits), walakin kayt7arrek bach yjbed l'liquidity dyal les banques o les institutions (Smart Money).

## L'mantiq dyal Smart Money:
* Les banques 3andhom orders kbar bezzaf. Bach ynfdohom, khasshom liquidity (orders dyal nas okhrin).
* Liquidity kat-tjma3 7it kayn stop losses dyal traders (foq les highs o ta7t les lows).
* Smart Money kayde7 l'price bach yjbed had liquidity (stop hunt), mn ba3d kay-reversi f l'jiha l7a9i9iya.

[NOTE] L'7a9i9a l'kbira: glب lik fin kaynin les stops dyal nas, temma fin ghadi ymshi l'price 9bel ma y-reversi.

## L'philosophy dyal had bot:
Had bot kayqelleb 3la had l'7arakat: kaytsenna Smart Money yjbed liquidity, mn ba3d kaydkhol m3ahom f l'jiha s7i7a, b confluence dyal bezzaf models.

[PB]

# 1. KILL ZONES (Les heures dyal trading)

## Ash hiya:
Kill Zones huma les fenetres dyal l'wa9t fin l'marche kaykon active o volatile, 7it kaydkhlo les banques. Barra mn had l'wa9t, l'marche kaykon batey o khatar (false moves).

## Les Kill Zones l'asasiyin:
* London Kill Zone: kat-jib l'volatility dyal sba7 (Europe).
* New York Kill Zone: kat-jib l'volatility dyal l'America.
* L'overlap (London + NY) huwa ahsan wa9t (akbar volume).

## 3lash muhimma:
* 80% dyal l'7arakat l'kbar kaytra f had les zones.
* Barra mnهom, l'price kayt7arrek b3sho9 o kayn risk dyal manipulation bla direction.

## F l'bot:
Bot ma kaytradich kollshi nhar. Kaytsenna ghir Kill Zones. Had chi kayqelleb l'quality dyal trades o kaye99ess les false signals.

[NOTE] Regle: ma tradi-sh barra Kill Zones. Sber 7ta yji l'wa9t s7i7.

[PB]

# 2. LIQUIDITY (BSL / SSL) + LIQUIDITY SWEEP

## 2.1 Ash hiya Liquidity:
Liquidity = l'blassa fin kaynin orders bezzaf (surtout stop losses). Kayn jouj anwa3:
* BSL (Buy Side Liquidity): foq les highs. Temma kaynin les stops dyal sellers o les buy stops.
* SSL (Sell Side Liquidity): ta7t les lows. Temma kaynin les stops dyal buyers o les sell stops.

## Fin kat-tjma3 liquidity:
* Foq / ta7t Previous Day High/Low (PDH/PDL).
* Foq / ta7t Previous Week High/Low (PWH/PWL).
* 3la les Equal Highs / Equal Lows (double tops/bottoms).
* Foq/ta7t Asian session range.

## 2.2 Liquidity Sweep (Stop Hunt):
Liquidity Sweep = mnin l'price kaydoz foq (wala ta7t) chi level, kayjbed les stops, mn ba3d kayrje3 b sor3a (rejection).

### Kifash t-3rfo:
* L'price kaytla3 foq high mu3ayyan (wick twila).
* Mn ba3d kay-closi ta7t had high (ma b9ach foq).
* Hadi 3lama belli Smart Money jbed liquidity o ghadi yreversi.

## L'mantiq:
* Sweep dyal BSL (foq high) -> setup BEARISH (ghadi yhbet).
* Sweep dyal SSL (ta7t low) -> setup BULLISH (ghadi ytla3).

[NOTE] Sweep bo7do MACHI signal kafi. Khass confirmation mn ba3d (MSS, FVG...). Hada howa l'asas dyal confluence.

[PB]

# 3. MARKET STRUCTURE (BOS / MSS / CISD)

## 3.1 Market Structure:
L'price kayt7arrek b shكل dyal swings (highs o lows):
* Uptrend: Higher Highs (HH) o Higher Lows (HL).
* Downtrend: Lower Highs (LH) o Lower Lows (LL).

## 3.2 BOS (Break of Structure):
BOS = mnin l'price kayksser akhir high (f uptrend) wala akhir low (f downtrend) = continuation dyal trend.

## 3.3 MSS (Market Structure Shift):
MSS = mnin l'price kayksser l'structure f l'jiha l'3aksiya = 3lama dyal reversal.
* Mثlan f downtrend, ila l'price ksser akhir Lower High -> MSS bullish (trend ghadi ytbeddel).

## 3.4 CISD (Change in State of Delivery):
CISD = mafhoum daقiق dyal MSS. Kayعni l'price closa foq l'open dyal akhir sequence bearish (CISD bullish), wala closa ta7t l'open dyal sequence bullish (CISD bearish). Kay3tik signal dyal reversal 9bel mن MSS classique.

## L'mantiq f strategy:
* Awwel: Liquidity Sweep (Smart Money jbed stops).
* Mn ba3d: MSS/CISD (confirmation belli direction tbeddlet).
Had jouj m3a ba3d = signal qawi bezzaf.

[NOTE] Sweep + MSS = l'asas dyal ICT 2022 Model. Bla MSS, sweep ymken ykon ghir continuation machi reversal.

[PB]

# 4. DISPLACEMENT

## Ash huwa:
Displacement = 7araka qawiya o sari3a dyal l'price (candle wala bezzaf candles kbar) f jiha wa7da. Kat-bayyen belli Smart Money dakhel b qowwa.

## Kifash t-3rfo:
* Candle kbira b body twil (machi wicks).
* Kat-ksser l'structure (kat-3mel MSS/BOS).
* Ghalban kat-khelli FVG men ba3dha (imbalance).

## 3lash muhim:
* Displacement = bصma dyal Smart Money.
* L'FVG li kayt-khlleq f displacement = ahsan blassa dyal entry.
* Bla displacement, l'move ma 3andoش qowwa o ymken ykon fake.

[NOTE] L'displacement huwa li kayfer9 bin MSS 7a9i9i o MSS d3if. Khass l'move ykon qawi.

[PB]

# 5. ORDER BLOCK (OB)

## Ash huwa:
Order Block = akhir candle 3aksiya 9bel displacement qawiya. Hiya l'blassa fin Smart Money dar les orders dyalo.

## Anwa3:
* Bullish OB: akhir candle 7amra (bearish) 9bel 7araka qawiya l'foq. Kat-khdem ka support.
* Bearish OB: akhir candle khadra (bullish) 9bel 7araka qawiya l'ta7t. Kat-khdem ka resistance.

## Kifash t-tradi biha:
* Mnin l'price kayrje3 l OB zone -> entry f jiha dyal displacement.
* SL: ta7t/foq l OB.
* TP: l'liquidity li jaya.

## L'mantiq:
Smart Money khella orders ma-tnefdoش kollhom f OB. Mnin l'price kayrje3, kaynfdo l'ba9i -> l'price kayt7arrek mn temma.

[NOTE] Ahsan OB: li 3mel sweep 9bel + displacement b FVG men ba3d. Hadak OB qawi bezzaf.

[PB]

# 6. FAIR VALUE GAP (FVG)

## Ash huwa:
FVG (Fair Value Gap) = imbalance f l'price, gap bin 3 candles fin l'price t7arrek b sor3a o ma 3tach chance l'orders kollhom ynfdo.

## Kifash t-7sbo (3 candles):
* Bullish FVG: l'gap bin l'HIGH dyal candle 1 o l'LOW dyal candle 3 (candle 2 f l'wost displacement). L'gap khass ykon foq.
* Bearish FVG: l'gap bin l'LOW dyal candle 1 o l'HIGH dyal candle 3.

## L'mantiq:
* L'price kay7ebb y"ymli" had l'gap (kayrje3 lih).
* Mnin kayrje3 l FVG -> entry zone.
* L'FVG kat-khdem ka magnet o ka support/resistance.

## Kifash t-tradi:
* Bullish FVG: tsenna l'price yrje3 l l'gap mn foq -> BUY.
* Bearish FVG: tsenna l'price yrje3 l l'gap mn ta7t -> SELL.
* SL: l'jiha l'okhra dyal FVG.

[NOTE] Ahsan FVG: li tkhleq mn displacement b3d MSS, o li kayn f OTE zone (chouf section 8).

[PB]

# 7. INVERSE FVG (IFVG)

## Ash huwa:
IFVG (Inverse FVG) = FVG li t-mla (l'price doz mnha kamla), o daba kat-khdem b l'3aks.

## L'mantiq:
* Ila bullish FVG t-ksser (l'price hbet ta7tها o closa) -> daba kat-wELi resistance (bearish IFVG).
* Ila bearish FVG t-ksser (l'price tla3 foqها o closa) -> daba kat-wELi support (bullish IFVG).

## 3lash qawiya:
* IFVG kat-bayyen belli l'sentiment tbeddel.
* Mnin FVG kat-fshel (t-mla o tنkser), kat-3ti signal qawi f l'jiha l-3aksiya.
* Bezzaf traders kayt-7easro f l'FVG l9dim, o IFVG kayجbدهom (liquidity).

## Kifash t-tradi:
* Bullish IFVG: bearish FVG l9dim li tكسر -> daba support -> BUY mnin l'price kayrje3 lih.
* Bearish IFVG: bullish FVG l9dim li tكسر -> daba resistance -> SELL.

[NOTE] IFVG + Liquidity Sweep = combo qawi bezzaf (chouf section dyal confluences).

[PB]

# 8. OTE (Optimal Trade Entry)

## Ash huwa:
OTE = Optimal Trade Entry, zone dyal entry b ahsan prix mn b3d displacement, b استعمال Fibonacci.

## Les niveaux:
* OTE zone = bin 62% o 79% retracement dyal l'move (displacement).
* L'ahsan niveau f l'wost: 70.5%.

## L'mantiq:
* Mnin l'price kay-displacy, kayrje3 (retracement) 9bel ma ykmmel.
* Ahsan blassa dyal entry = bin 62% o 79% (machi b9eet l'move).
* Hna kayn ahsan Risk/Reward (SL qrib, TP b3id).

## Kifash t-tradi:
* 7sse b displacement (move qawi).
* 7ot Fibonacci mn l'bدية l l'nihaya dyal l'move.
* Tsenna l'price yrje3 l zone 62%-79%.
* Ila kayn FVG/OB f had zone -> entry mزyan.

[NOTE] OTE + FVG + OB f nefs zone = entry A+. Hada howa li kayqelleb l'win rate.

[PB]

# 9. CRT (Candle Range Theory)

## Ash huwa:
CRT (Candle Range Theory) = mafhoum li kayشof kل candle ka "range" (high o low), o kif Smart Money kat-manipuli had range.

## L'model AMD (Accumulation, Manipulation, Distribution):
* Accumulation: candle l'oula kat-3mel range (Smart Money kayjma3 positions).
* Manipulation: candle jaya kat-ksser jiha wa7da dyal range (stop hunt / fake move).
* Distribution: l'price kay-reversi o kay-expandi f l'jiha l'okhra (l'move l7a9i9i).

## Kifash t-tradi:
* 7dded l'range dyal candle l9dima (high/low) f timeframe kbira (mثlan H1, H4).
* Tsenna l'price yksser jiha wa7da (manipulation/sweep).
* Mnin kayrje3 l dakhel l range o kay-closi -> entry f jiha l'3aksiya.

## Misal (Bullish CRT):
* Candle l9dima 3andha range.
* Candle jaya hebtet ta7t l'low (sweep dyal SSL).
* Mn ba3d rej3et l dakhel o closet foq l'wost -> BUY.

[NOTE] CRT mزyan bezzaf 3la timeframes kbar (H4, Daily). Kayعti bias wade7 dyal l'jiha.

[PB]

# 10. SMT DIVERGENCE (Smart Money Technique)

## Ash hiya:
SMT = mnin kat-9aren jouj instruments correles. Ila wa7d 3mel new high/low o l'akhor LA -> divergence = signal dyal reversal.

## Les correlations:
* EURUSD o USDX (DXY): correle 3aksi (mnin EURUSD ytla3, DXY kayhbet).
* XAUUSD (Gold) o USDX: correle 3aksi.
* NAS100 o US500 (SP500): correle b l'jiha (kaytla3o m3a ba3d).

## Kifash t-tradi (misal bearish):
* EURUSD 3mel new high.
* Walakin DXY MA-3melch new low (ma confirmaش).
* Hadi divergence -> EURUSD ghadi yreversi l ta7t -> SELL.

## L'mantiq:
* Ila les correles ma-mshawch m3a ba3d, kayn de9f f l'move.
* Smart Money ghalban kat-bayyen had l'divergence 9bel reversal.

[NOTE] SMT confirmation qawiya bezzaf. Mnin t-ji m3a Sweep + MSS, l'probabilite kat-tla3 bezzaf.

[PB]

# 11. CONFLUENCES: KIFASH MODELS KAYTKMMLO BA3DOM

Hna l'asas dyal strategy. Model bo7do machi kafi. L'qowwa f l'confluence (mnin bezzaf models kayt-fقo f nefs l'blassa o nefs l'jiha).

## Confluence 1: Liquidity Sweep + MSS
* Sweep = Smart Money jbed stops.
* MSS = direction tbeddlet b confirmation.
* Hada howa l'asas. Bla had jouj, ma kaynsh setup.

## Confluence 2: Sweep + IFVG
* L'price 3mel sweep dyal liquidity.
* Mn ba3d FVG l9dim tكسر o wELi IFVG.
* Entry f IFVG f jiha dyal sweep -> qawi.
* Misal: Sweep dyal BSL (foq) + bullish FVG l9dim tكسر (wELi resistance) -> SELL.

## Confluence 3: FVG + Order Block (UNICORN)
* Mnin FVG o OB kayt-3atو f nefs zone = "Unicorn" setup.
* Hada mn ahsan setups f ICT.
* Probabilite 3aliya bezzaf.

## Confluence 4: Sweep + MSS + FVG + OTE (Full ICT 2022)
* Sweep (liquidity grab).
* MSS (structure shift + displacement).
* FVG f l'displacement.
* L'FVG kayn f OTE zone (62-79%).
* Hada howa l'core dyal ICT 2022 Model. Setup complet.

## Confluence 5: CRT + SMT
* CRT kayعti bias o range dyal HTF.
* SMT kayعti confirmation b correlation.
* Mnin t-jiو m3a l'core setup -> A+ trade.

[NOTE] L'9a3ida: ktar ma kayn confluences, ktar l'probabilite kat-tla3. Walakin ma t-sennaش perfection - 3 wala 4 confluences kafyin.

[PB]

# 12. STRATEGY KAMLA: A TO Z (7 PHASES)

Hadchi howa l'flow l'kamel dyal bot (o li t9der tradi bih b yedek):

## PHASE 1: Kill Zone
* Verifie wach 7na f London wala NY Kill Zone.
* Ila LA -> ma tradi-sh. Sber.

## PHASE 2: HTF Liquidity Levels
* 7dded les levels: PDH/PDL, PWH/PWL, Asian range, Swing H/L.
* Hadو huma les targets dyal sweep.

## PHASE 3: Liquidity Sweep
* Tsenna l'price yعmel sweep dyal wa7d mn had les levels.
* Wick kat-doz l'level mn ba3d rejection (close mra okhra).
* Sweep BSL -> bias bearish. Sweep SSL -> bias bullish.

## PHASE 4: MSS / CISD
* Mn ba3d sweep, tsenna l'price yكسر l'structure b displacement.
* Hadi confirmation belli direction tbeddlet.

## PHASE 5: Entry (FVG/IFVG/OB f OTE)
* Qelleb 3la FVG li tkhleq mn displacement.
* Wala Order Block 9bel displacement.
* Verifie wach kayn f OTE zone (62-79%).
* Ila FVG+OB kayt3atو -> Unicorn (ahsan).
* Entry mnin l'price kayrje3 l had zone.

## PHASE 6: CRT + SMT Confirmation
* Verifie CRT (range manipulation f HTF).
* Verifie SMT (divergence m3a correle).
* Had jouj kayziدو confiance (machi obligatoire walakin mزyan).

## PHASE 7: Execution + Risk
* Dkhol b lot size محسoba 3la risk (chouf section 13).
* SL: l'jiha l'okhra dyal FVG/OB.
* TP: RR 1:3 wala l'liquidity li jaya.

[NOTE] Checklist sari3a: KillZone? Sweep? MSS? FVG/OB f OTE? -> Dkhol. Ila chi wa7d ناقص -> ma tdkhol-sh.

[PB]

# 13. RISK MANAGEMENT + PROP FIRM (FundedNext)

## L'9a3ida l'dahabiya:
Risk management huwa li kayfer9 bin trader na7i9 o wa7d li kayfasad account. Strategy mزyana b risk khayب = khsara.

## Les regles dyal bot:
* Risk 1% per trade max.
* RR minimum 1:3 (kل trade ghadi yrbe7 3 mra ktar mn li ymken ykhsser).
* Max 2 trades f nhar (quality machi quantity).

## FundedNext Protection (Account 15000 USD):
* Daily Loss Limit: 750 USD. Bot kayweقef f 80% (600 USD) bach ma yكسرش l'regle.
* Max Loss Limit: 1500 USD. Floor = 13500 USD. Bot kayseker kollshi f 85% (1275 USD).
* Lot size kayt-7sab bach even ila darbet SL, ma t-kssrش les limites.

## Kifash kayt7sab lot size:
* Risk USD = MIN dyal: (1% account, daily room ba9i, max-loss room ba9i).
* Lot = Risk USD / (SL distance x tick value).
* Hakda lot dima logique m3a l'7ساب o m3a les limites.

[NOTE] F prop firm, l'a-hamm machi t-rbe7 bezzaf, walakin ma t-kssrش les regles. Protege l'account 9bel kollshi.

[PB]

# 14. CHECKLIST DYAL TRADING MANUAL

Print had checklist o 7ottها 7da chart. 9bel kل trade, jaweb 3la had les questions:

## 9bel l'entry:
* Wach 7na f Kill Zone (London/NY)? [Iyeh/La]
* Wach kayn HTF bias wade7 (CRT/structure)? [Iyeh/La]
* Wach l'price 3mel Liquidity Sweep? [Iyeh/La]
* Wach kayn MSS/CISD b displacement? [Iyeh/La]
* Wach kayn FVG/IFVG/OB f OTE zone? [Iyeh/La]
* Wach SMT confirma (optionnel)? [Iyeh/La]

## Ila kollshi Iyeh (wala l'aghlabiya):
* 7dded entry, SL, TP.
* 7sab lot size (1% risk max).
* Verifie RR minimum 1:3.
* Dkhol o sber.

## Regles dyal discipline:
* Ma tdkhol-sh barra Kill Zone.
* Ma tzidش lot size mن l'ghadab (revenge trading).
* Ila darbet 2 SL f nhar -> w9ef.
* Ma t-7errekش SL b3id (respect l'plan).

[NOTE] Discipline > Strategy. Ahsan strategy m3a discipline khayба = khsara. Strategy 3adiya m3a discipline qawiya = rb7.

[PB]

# 15. KHATIMA

Had l'guide kayعtik kollshi 3la ICT 2022 Confluence Model:
* 10 models mshro7in kل wa7d bo7do.
* Kifash kaytkmmlو f confluences.
* Strategy kamla f 7 phases.
* Risk management m3a prop firm.

## Nصa-i7 akhira:
* Backtest 9bel kل haja (MT5 Strategy Tester, FREE).
* Demo account 1-2 chhor 9bel real money.
* Journal: kteb kل trade o 3lash dkhalti.
* Sber: ICT setups ma kaynش kل sa3a. Quality > Quantity.

## L'bot dyalek:
GitHub: github.com/hamza199997/Bot_ICT
Fichier: ICT_Bot_EA.mq5

Bel tawfiq f trading, Hamza! Respect l'risk o sber 3la setups l'A+.

"""
