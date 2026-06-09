# -*- coding: utf-8 -*-
# Contenu dyal l'guide b darija (Latin script bla 7uruf 3arabiya). Markers:
# [TITLE] / [SUB] / # / ## / ### / * bullet / [NOTE] / --- rule / [PB] pagebreak

DOC = r"""

[TITLE] ICT TRADING STRATEGY
[SUB] Guide kaml b darija - mn A to Z

[SUB] Bot: ICT 2022 Confluence Model (MT5)
[SUB] Instruments: EURUSD - XAUUSD (Gold) - NAS100 (Nasdaq)
[SUB] Account: FundedNext 15000 USD

---

[NOTE] Had l'guide mektob bach tefhem strategy kamla, tradi b yedek wala b bot. Kollchi mchro7 b darija sahla.

[PB]

# 0. MUQADDIMA: Ash huwa ICT?

ICT = Inner Circle Trader, smiya dyal Michael Huddleston, li dewwa b mafhoum "Smart Money".

L'fikra l'asasiya: l'marche ma kayt7arrekch 3la 7sab retail traders (7na les petits), walakin kayt7arrek bach yjbed l'liquidity dyal les banques o les institutions (Smart Money).

## L'mantiq dyal Smart Money:
* Les banques 3andhom orders kbar bezzaf. Bach ynfdohom, khasshom liquidity (orders dyal nas khrin).
* Liquidity kat-tjma3 fin kayn stop losses dyal traders (fo9 les highs o ta7t les lows).
* Smart Money kayde7 l'price bach yjbed had liquidity (stop hunt), mn ba3d kay-reversi f l'jiha l7a9i9iya.

[NOTE] L'7a9i9a l'kbira: 9elleb fin kaynin les stops dyal nas, temma fin ghadi ymchi l'price 9bel ma y-reversi.

## L'philosophy dyal had bot:
Had bot kay9elleb 3la had l'7arakat: kaytsenna Smart Money yjbed liquidity, mn ba3d kaydkhol m3ahom f l'jiha s7i7a, b confluence dyal bezzaf models.

[PB]

# 1. KILL ZONES (Les heures dyal trading)

## Ash hiya:
Kill Zones huma les fenetres dyal l'wa9t fin l'marche kaykon active o volatile, fin kaydkhlo les banques. Barra mn had l'wa9t, l'marche kaykon bati o khatar (false moves).

## Les Kill Zones l'asasiyin:
* London Kill Zone: kat-jib l'volatility dyal sba7 (Europe).
* New York Kill Zone: kat-jib l'volatility dyal l'America.
* L'overlap (London + NY) huwa ahsan wa9t (akbar volume).

## 3lash muhimma:
* 80% dyal l'7arakat l'kbar kaytra f had les zones.
* Barra mnhom, l'price kayt7arrek b3so9 o kayn risk dyal manipulation bla direction.

## F l'bot:
Bot ma kaytradich kollchi nhar. Kaytsenna ghir Kill Zones. Had chi kay9elleb l'quality dyal trades o kay9ess les false signals.

[NOTE] Re3la: ma tradi-ch barra Kill Zone. Sber 7ta yji l'wa9t s7i7.

[PB]

# 2. LIQUIDITY (BSL / SSL) + LIQUIDITY SWEEP

## 2.1 Ash hiya Liquidity:
Liquidity = l'blassa fin kaynin orders bezzaf (surtout stop losses). Kayn jouj anwa3:
* BSL (Buy Side Liquidity): fo9 les highs. Temma kaynin les stops dyal sellers o les buy stops.
* SSL (Sell Side Liquidity): ta7t les lows. Temma kaynin les stops dyal buyers o les sell stops.

## Fin kat-tjma3 liquidity:
* Fo9 / ta7t Previous Day High/Low (PDH/PDL).
* Fo9 / ta7t Previous Week High/Low (PWH/PWL).
* 3la les Equal Highs / Equal Lows (double tops/bottoms).
* Fo9/ta7t Asian session range.

## 2.2 Liquidity Sweep (Stop Hunt):
Liquidity Sweep = mnin l'price kaydoz fo9 (wala ta7t) chi level, kayjbed les stops, mn ba3d kayrje3 b sor3a (rejection).

### Kifach t-3rfo:
* L'price kaytla3 fo9 high mu3ayyan (wick twila).
* Mn ba3d kay-closi ta7t had high (ma b9ach fo9).
* Hadi 3lama belli Smart Money jbed liquidity o ghadi yreversi.

## L'mantiq:
* Sweep dyal BSL (fo9 high) -> setup BEARISH (ghadi yhbet).
* Sweep dyal SSL (ta7t low) -> setup BULLISH (ghadi ytla3).

[NOTE] Sweep bo7do MACHI signal kafi. Khass confirmation mn ba3d (MSS, FVG...). Hada howa l'asas dyal confluence.

[PB]

# 3. MARKET STRUCTURE (BOS / MSS / CISD)

## 3.1 Market Structure:
L'price kayt7arrek b chkel dyal swings (highs o lows):
* Uptrend: Higher Highs (HH) o Higher Lows (HL).
* Downtrend: Lower Highs (LH) o Lower Lows (LL).

## 3.2 BOS (Break of Structure):
BOS = mnin l'price kayksser akhir high (f uptrend) wala akhir low (f downtrend) = continuation dyal trend.

## 3.3 MSS (Market Structure Shift):
MSS = mnin l'price kayksser l'structure f l'jiha l'3aksiya = 3lama dyal reversal.
* Mthlan f downtrend, ila l'price ksser akhir Lower High -> MSS bullish (trend ghadi ytbeddel).

## 3.4 CISD (Change in State of Delivery):
CISD = mafhoum da9i9 dyal MSS. Kay3ni l'price closa fo9 l'open dyal akhir sequence bearish (CISD bullish), wala closa ta7t l'open dyal sequence bullish (CISD bearish). Kay3ti signal dyal reversal 9bel mn MSS classique.

## L'mantiq f strategy:
* Awwel: Liquidity Sweep (Smart Money jbed stops).
* Mn ba3d: MSS/CISD (confirmation belli direction tbeddlet).
Had jouj m3a ba3d = signal qawi bezzaf.

[NOTE] Sweep + MSS = l'asas dyal ICT 2022 Model. Bla MSS, sweep ymken ykon ghir continuation machi reversal.

[PB]

# 4. DISPLACEMENT

## Ash huwa:
Displacement = 7araka qawiya o sari3a dyal l'price (candle wala bezzaf candles kbar) f jiha wa7da. Kat-bayyen belli Smart Money dakhel b 9owwa.

## Kifach t-3rfo:
* Candle kbira b body twil (machi wicks).
* Kat-ksser l'structure (kat-3mel MSS/BOS).
* Ghalban kat-khelli FVG mn ba3dha (imbalance).

## 3lash muhim:
* Displacement = bsma dyal Smart Money.
* L'FVG li kayt-khle9 f displacement = ahsan blassa dyal entry.
* Bla displacement, l'move ma 3andoch 9owwa o ymken ykon fake.

[NOTE] L'displacement huwa li kayfre9 bin MSS 7a9i9i o MSS d3if. Khass l'move ykon qawi.

[PB]

# 5. ORDER BLOCK (OB)

## Ash huwa:
Order Block = akhir candle 3aksiya 9bel displacement qawiya. Hiya l'blassa fin Smart Money dar les orders dyalo.

## Anwa3:
* Bullish OB: akhir candle 7amra (bearish) 9bel 7araka qawiya l'fo9. Kat-khdem b7al support.
* Bearish OB: akhir candle khadra (bullish) 9bel 7araka qawiya l'ta7t. Kat-khdem b7al resistance.

## Kifach t-tradi biha:
* Mnin l'price kayrje3 l OB zone -> entry f jiha dyal displacement.
* SL: ta7t/fo9 l OB.
* TP: l'liquidity li jaya.

## L'mantiq:
Smart Money khella orders ma-tnefdoch kollhom f OB. Mnin l'price kayrje3, kaynfdo l'ba9i -> l'price kayt7arrek mn temma.

[NOTE] Ahsan OB: li 3mel sweep 9bel + displacement b FVG mn ba3d. Hadak OB qawi bezzaf.

[PB]

# 6. FAIR VALUE GAP (FVG)

## Ash huwa:
FVG (Fair Value Gap) = imbalance f l'price, gap bin 3 candles fin l'price t7arrek b sor3a o ma 3tach chance l'orders kollhom ynfdo.

## Kifach t-7sbo (3 candles):
* Bullish FVG: l'gap bin l'HIGH dyal candle 1 o l'LOW dyal candle 3 (candle 2 f l'wost displacement). L'gap khass ykon fo9.
* Bearish FVG: l'gap bin l'LOW dyal candle 1 o l'HIGH dyal candle 3.

## L'mantiq:
* L'price kay7ebb y-ymli had l'gap (kayrje3 lih).
* Mnin kayrje3 l FVG -> entry zone.
* L'FVG kat-khdem b7al magnet o b7al support/resistance.

## Kifach t-tradi:
* Bullish FVG: tsenna l'price yrje3 l l'gap mn fo9 -> BUY.
* Bearish FVG: tsenna l'price yrje3 l l'gap mn ta7t -> SELL.
* SL: l'jiha l'khra dyal FVG.

[NOTE] Ahsan FVG: li tkhle9 mn displacement b3d MSS, o li kayn f OTE zone (chouf section 8).

[PB]

# 7. INVERSE FVG (IFVG)

## Ash huwa:
IFVG (Inverse FVG) = FVG li t-mla (l'price doz mnha kamla), o daba kat-khdem b l'3aks.

## L'mantiq:
* Ila bullish FVG t-ksser (l'price hbet ta7tha o closa) -> daba kat-weli resistance (bearish IFVG).
* Ila bearish FVG t-ksser (l'price tla3 fo9ha o closa) -> daba kat-weli support (bullish IFVG).

## 3lash qawiya:
* IFVG kat-bayyen belli l'sentiment tbeddel.
* Mnin FVG kat-fchel (t-mla o tnksser), kat-3ti signal qawi f l'jiha l-3aksiya.
* Bezzaf traders kayt-7esro f l'FVG l9dim, o IFVG kayjbedhom (liquidity).

## Kifach t-tradi:
* Bullish IFVG: bearish FVG l9dim li tksser -> daba support -> BUY mnin l'price kayrje3 lih.
* Bearish IFVG: bullish FVG l9dim li tksser -> daba resistance -> SELL.

[NOTE] IFVG + Liquidity Sweep = combo qawi bezzaf (chouf section dyal confluences).

[PB]

# 8. OTE (Optimal Trade Entry)

## Ash huwa:
OTE = Optimal Trade Entry, zone dyal entry b ahsan prix mn b3d displacement, b isti3mal Fibonacci.

## Les niveaux:
* OTE zone = bin 62% o 79% retracement dyal l'move (displacement).
* L'ahsan niveau f l'wost: 70.5%.

## L'mantiq:
* Mnin l'price kay-displacy, kayrje3 (retracement) 9bel ma ykmmel.
* Ahsan blassa dyal entry = bin 62% o 79% (machi b9eet l'move).
* Hna kayn ahsan Risk/Reward (SL 9rib, TP b3id).

## Kifach t-tradi:
* 7ess b displacement (move qawi).
* 7ot Fibonacci mn l'bdaya l l'nihaya dyal l'move.
* Tsenna l'price yrje3 l zone 62%-79%.
* Ila kayn FVG/OB f had zone -> entry mzyan.

[NOTE] OTE + FVG + OB f nefs zone = entry A+. Hada howa li kay9elleb l'win rate.

[PB]

# 9. CRT (Candle Range Theory)

## Ash huwa:
CRT (Candle Range Theory) = mafhoum li kaychof kol candle b7al "range" (high o low), o kif Smart Money kat-manipuli had range.

## L'model AMD (Accumulation, Manipulation, Distribution):
* Accumulation: candle l'oula kat-3mel range (Smart Money kayjma3 positions).
* Manipulation: candle jaya kat-ksser jiha wa7da dyal range (stop hunt / fake move).
* Distribution: l'price kay-reversi o kay-expandi f l'jiha l'khra (l'move l7a9i9i).

## Kifach t-tradi:
* 7dded l'range dyal candle l9dima (high/low) f timeframe kbira (mthlan H1, H4).
* Tsenna l'price yksser jiha wa7da (manipulation/sweep).
* Mnin kayrje3 l dakhel l range o kay-closi -> entry f jiha l'3aksiya.

## Misal (Bullish CRT):
* Candle l9dima 3andha range.
* Candle jaya hebtet ta7t l'low (sweep dyal SSL).
* Mn ba3d rej3et l dakhel o closet fo9 l'wost -> BUY.

[NOTE] CRT mzyan bezzaf 3la timeframes kbar (H4, Daily). Kay3ti bias wade7 dyal l'jiha.

[PB]

# 10. SMT DIVERGENCE (Smart Money Technique)

## Ash hiya:
SMT = mnin kat-9aren jouj instruments correles. Ila wa7d 3mel new high/low o l'akhor LA -> divergence = signal dyal reversal.

## Les correlations:
* EURUSD o USDX (DXY): correle 3aksi (mnin EURUSD ytla3, DXY kayhbet).
* XAUUSD (Gold) o USDX: correle 3aksi.
* NAS100 o US500 (SP500): correle b l'jiha (kaytla3o m3a ba3d).

## Kifach t-tradi (misal bearish):
* EURUSD 3mel new high.
* Walakin DXY MA-3melch new low (ma confirmach).
* Hadi divergence -> EURUSD ghadi yreversi l ta7t -> SELL.

## L'mantiq:
* Ila les correles ma-mchawch m3a ba3d, kayn de3f f l'move.
* Smart Money ghalban kat-bayyen had l'divergence 9bel reversal.

[NOTE] SMT confirmation qawiya bezzaf. Mnin t-ji m3a Sweep + MSS, l'probabilite kat-tla3 bezzaf.

[PB]

# 11. CONFLUENCES: KIFACH MODELS KAYTKAMLO BA3DOM

Hna l'asas dyal strategy. Model bo7do machi kafi. L'qowwa f l'confluence (mnin bezzaf models kayt-tfo f nefs l'blassa o nefs l'jiha).

## Confluence 1: Liquidity Sweep + MSS
* Sweep = Smart Money jbed stops.
* MSS = direction tbeddlet b confirmation.
* Hada howa l'asas. Bla had jouj, ma kaynch setup.

## Confluence 2: Sweep + IFVG
* L'price 3mel sweep dyal liquidity.
* Mn ba3d FVG l9dim tksser o weli IFVG.
* Entry f IFVG f jiha dyal sweep -> qawi.
* Misal: Sweep dyal BSL (fo9) + bullish FVG l9dim tksser (weli resistance) -> SELL.

## Confluence 3: FVG + Order Block (UNICORN)
* Mnin FVG o OB kayt-3ato f nefs zone = "Unicorn" setup.
* Hada mn ahsan setups f ICT.
* Probabilite 3aliya bezzaf.

## Confluence 4: Sweep + MSS + FVG + OTE (Full ICT 2022)
* Sweep (liquidity grab).
* MSS (structure shift + displacement).
* FVG f l'displacement.
* L'FVG kayn f OTE zone (62-79%).
* Hada howa l'core dyal ICT 2022 Model. Setup complet.

## Confluence 5: CRT + SMT
* CRT kay3ti bias o range dyal HTF.
* SMT kay3ti confirmation b correlation.
* Mnin t-jiw m3a l'core setup -> A+ trade.

[NOTE] L'9a3ida: ktar ma kayn confluences, ktar l'probabilite kat-tla3. Walakin ma t-sennach perfection - 3 wala 4 confluences kafyin.

[PB]

# 12. STRATEGY KAMLA: A TO Z (7 PHASES)

Hadchi howa l'flow l'kamel dyal bot (o li t9der tradi bih b yedek):

## PHASE 1: Kill Zone
* Verifie wach 7na f London wala NY Kill Zone.
* Ila LA -> ma tradi-ch. Sber.

## PHASE 2: HTF Liquidity Levels
* 7dded les levels: PDH/PDL, PWH/PWL, Asian range, Swing H/L.
* Hadu huma les targets dyal sweep.

## PHASE 3: Liquidity Sweep
* Tsenna l'price y3mel sweep dyal wa7d mn had les levels.
* Wick kat-doz l'level mn ba3d rejection (close mra khra).
* Sweep BSL -> bias bearish. Sweep SSL -> bias bullish.

## PHASE 4: MSS / CISD
* Mn ba3d sweep, tsenna l'price yksser l'structure b displacement.
* Hadi confirmation belli direction tbeddlet.

## PHASE 5: Entry (FVG/IFVG/OB f OTE)
* 9elleb 3la FVG li tkhle9 mn displacement.
* Wala Order Block 9bel displacement.
* Verifie wach kayn f OTE zone (62-79%).
* Ila FVG+OB kayt3ato -> Unicorn (ahsan).
* Entry mnin l'price kayrje3 l had zone.

## PHASE 6: CRT + SMT Confirmation
* Verifie CRT (range manipulation f HTF).
* Verifie SMT (divergence m3a correle).
* Had jouj kayzido confiance (machi obligatoire walakin mzyan).

## PHASE 7: Execution + Risk
* Dkhol b lot size m7soba 3la risk (chouf section 13).
* SL: l'jiha l'khra dyal FVG/OB.
* TP: RR 1:3 wala l'liquidity li jaya.

[NOTE] Checklist sari3a: KillZone? Sweep? MSS? FVG/OB f OTE? -> Dkhol. Ila chi wa7d na9es -> ma tdkhol-ch.

[PB]

# 13. RISK MANAGEMENT + PROP FIRM (FundedNext)

## L'9a3ida l'dahabiya:
Risk management huwa li kayfre9 bin trader na7i7 o wa7d li kayfsed account. Strategy mzyana b risk khayb = khsara.

## Les regles dyal bot:
* Risk 1% per trade max.
* RR minimum 1:3 (kol trade ghadi yrbe7 3 mra ktar mn li ymken ykhsser).
* Max 2 trades f nhar (quality machi quantity).

## FundedNext Protection (Account 15000 USD):
* Daily Loss Limit: 750 USD. Bot kayw9ef f 80% (600 USD) bach ma yksserch l'regle.
* Max Loss Limit: 1500 USD. Floor = 13500 USD. Bot kayseker kollchi f 85% (1275 USD).
* Lot size kayt-7sab bach 7ta ila darbet SL, ma t-kssrch les limites.

## Kifach kayt7sab lot size:
* Risk USD = MIN dyal: (1% account, daily room ba9i, max-loss room ba9i).
* Lot = Risk USD / (SL distance x tick value).
* Hakda lot dima logique m3a l'7sab o m3a les limites.

[NOTE] F prop firm, l'ahamm machi t-rbe7 bezzaf, walakin ma t-kssrch les regles. Protege l'account 9bel kollchi.

[PB]

# 14. CHECKLIST DYAL TRADING MANUAL

Print had checklist o 7ottha 7da chart. 9bel kol trade, jaweb 3la had les questions:

## 9bel l'entry:
* Wach 7na f Kill Zone (London/NY)? [Iyeh/La]
* Wach kayn HTF bias wade7 (CRT/structure)? [Iyeh/La]
* Wach l'price 3mel Liquidity Sweep? [Iyeh/La]
* Wach kayn MSS/CISD b displacement? [Iyeh/La]
* Wach kayn FVG/IFVG/OB f OTE zone? [Iyeh/La]
* Wach SMT confirma (optionnel)? [Iyeh/La]

## Ila kollchi Iyeh (wala l'aghlabiya):
* 7dded entry, SL, TP.
* 7sab lot size (1% risk max).
* Verifie RR minimum 1:3.
* Dkhol o sber.

## Regles dyal discipline:
* Ma tdkhol-ch barra Kill Zone.
* Ma tzidch lot size mn l'ghadab (revenge trading).
* Ila darbet 2 SL f nhar -> w9ef.
* Ma t-7errekch SL b3id (respect l'plan).

[NOTE] Discipline > Strategy. Ahsan strategy m3a discipline khayba = khsara. Strategy 3adiya m3a discipline qawiya = rb7.

[PB]

# 15. KHATIMA

Had l'guide kay3tik kollchi 3la ICT 2022 Confluence Model:
* 10 models mchro7in kol wa7d bo7do.
* Kifach kaytkamlo f confluences.
* Strategy kamla f 7 phases.
* Risk management m3a prop firm.

## Nasa-i7 akhira:
* Backtest 9bel kol haja (MT5 Strategy Tester, FREE).
* Demo account 1-2 chhor 9bel real money.
* Journal: kteb kol trade o 3lash dkhalti.
* Sber: ICT setups ma kaynch kol sa3a. Quality > Quantity.

## L'bot dyalek:
GitHub: github.com/hamza199997/Bot_ICT
Fichier: ICT_Bot_EA.mq5

Bel tawfiq f trading, Hamza! Respect l'risk o sber 3la setups l'A+.

"""
