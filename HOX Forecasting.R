###############################################################
##  Pseudo out-of-sample forecasting: HOX Housing index      ##
###############################################################


library(stargazer)
library(AER)
library(lmtest)
library(tseries)
library(urca)
library(dynlm)
library(sandwich)
library(readxl)
library(forecast)
library(xts)


HOXSWE <- read_excel("Valueguardhela.xls")
str(HOXSWE)
class(HOXSWE) 


HOXSWE_dataframe <- HOXSWE[,"HOXSWE"]
View(HOXSWE_dataframe)
class(HOXSWE_dataframe)
HOXSWE_ts<- ts(HOXSWE_dataframe, start=c(2005,01), end = c(2016,01), frequency = 12)
HOXSWE <- ts(HOXSWE_ts, start=c(2005,01), end = c(2016,01), frequency = 12 )

ts.plot(HOXSWE)


HOXSWE_hela<- ts(HOXSWE_ts, start=c(2005,01), end = c(2018,01), frequency = 12)
plot(HOXSWE_hela)
is.ts(HOXSWE_hela)


class(HOXSWE) 
is.ts(HOXSWE) 

## Grafisk illustration av serien - Valueguard Boprisindexet
## fr�n 2005-2016, d.v.s den mer begr�nsade tidsperioden.
plot(HOXSWE, main = "BOPRISINDEX HOXSWE", xlab = "Tid")
grid(col = "lightgray", lty = "dotted",
     lwd = par("lwd"), equilogs = TRUE)
legend("topleft", "Boprisindex HOXSWE", lty=1, bg="lightgray",  cex = 0.75)

HOXSWE 
## M�nadsdatan str�cker sig fr�n januari m�nad 2005 (2005:M01) 
## �nda fram till Januari �r 2016 (2016:M01)


## Deskriptiv statistik i form av en tabell.
summary(HOXSWE_dataframe)
sum_HOXSWE <- summary(HOXSWE_dataframe)
stargazer(sum_HOXSWE,  type = 'latex', title = "Deskriptiv Statistik")

###############################################################
##                     ARIMA-modellering                     ##
##                                                           ##
###############################################################




################################################################
##
##  1) IDENTIFIERING 
##
################################################################


## En f�ruts�ttning f�r att genomf�ra en ARIMA-modellering med
## huvudsaklig grund i Box-Jenkin metodik inom ekonometri f�r att
## d�rmed genomf�ra prognostisering, �r det f�rst och fr�mst av vikt
## att s�kerst�lla att v�r n�got begr�nsade serie �r station�rt. Vi b�rjar 
## med att genomf�ra ett standardtest avseende enhetsr�tter vid namn
## Augmented Dickey-Fuller test.


## Augmented Dickey-Fuller Test (ADF-test) - Test f�r enhetsrot.

ADF.test <- function(data){
  ADF <- function(type, data) {
    require(urca)
    result1 <- ur.df(data,
                     type = type,
                     lags = 3*frequency(data),
                     selectlags = "AIC")
    cbind(t(result1@teststat),result1@cval)
  }
  types <- c("trend", "drift", "none")
  result2 <- apply(t(types), 2, ADF, data)
  cat(rep("#", 17),'\n')
  cat("Augmented Dickey--Fuller test\n")
  cat(rep("#", 17),'\n')
  round(rbind(result2[[1]][c(1,3),],
              result2[[2]],
              result2[[3]]), 2)
}


## H0: Finns en enhetsrot
## HA: Finns ej en enhetsrot

ADF.test(HOXSWE) # URSPRUNGSDATA
## D� teststatistikan f�r tau3 i absoluta tal understiger
## de kritiska v�rdena p� valfri signifikansniv� kan vi konstatera
## att vi har en enhetsrot. Vi kan i detta fall dra slutsatsen att vi
## kan f�rkasta determinstisk trend och drift samt att d� nollhypotesen
## avseende om att en enhetsrot f�religger, inte kan f�rkastas!


## Efter ett kvantiferat konstaterande om att v�r data inte �r station�rt
## kan vi �ven genom autokorrelationsplotten (ACF) utr�na ifall det visuellt
## �r station�rt eller inte. F�rslagsvis, ett mycket svagt avtagande ACF skulle 
## indikera p� icke-station�ritet.


par(mfrow=c(2,1))
acf(HOXSWE, main = "ACF Boprisindex | Ursprunglig serie") 
pacf(HOXSWE, main = "PACF Boprisindex | Ursprunglig serie ")
## ACF uppvisar successivt avtagande s.k. spikar
## vid laggarna. Genom visuell inspektion kan vi konstatera
## att serien inte �r station�r. 


## Simuleringen av autokorrelations(ACF)-samt partiella autokorrelationsplottar (PACF)
## dock prim�rt ACF indikerar att ursprungsserien "HOXSWE" �r icke-station�r,
## som d�rtill karakt�riseras av autokorrelation. P� grund av detta
## beh�ver serien genomg� en transformation. D� vi arbetar med ARIMA modeller
## i detta projekt, ska vi g�ra serien differensstation�r genom att
## ta f�rsta differensen. V�rt att notera, d� vi har m�nadsdata (S=12),
## kan det finnas indikation p� att en s�songs ARIMA (SARIMA) kan bli 
## aktuellt att modellera d.v.s kan kr�va en s�songsdifferensning i detta fall
## ut�ver f�rsta differensen. Vi ska unders�ka det senare.


## Genomf�r f�rsta differensen av urprungsserien f�r att uppn� station�ritet.
## (p,d,q) <- icke-s�songskompontenter.

par(mfrow=c(2,1))
d.HOXSWE <- diff(HOXSWE)
plot(d.HOXSWE, main = "F�RSTA DIFFERENSEN | Boprisindex HOXSWE", xlab = "Tid",
     col ="black", las=1)
## Efter genomf�rd differensning, har v�ntev�rdet och variansen av serien blivit 
## oberoende av tiden, dvs mer konstant �n tidigare. D� vi arbetar med m�nadsdata
## g�r det d�rtill �ven att utr�na inslag av s�songsvariation med skarpa och
## h�ga toppar i serien efter genomf�rda f�rsta differensen.

ADF.test(d.HOXSWE)
## Genom att genomf�ra Augmented Dickey Fuller testet �terigen i syfte
## att f� det bekr�ftat ifall vi fortfarande har en enhetsrot eller ej.
## Enligt utskriftet fr�n ADF-testet kan vi utr�na att teststatistikan
## f�r tau3 i absolutbelopp p� 2.04 fortfarande understiger valfri signifikansniv�. 
## Vi kan konstatera att vi fortfarande har en enhetsrot. 
## Vi skall nu h�rn�st genomf�ra en s�songsdifferensning.


## Till f�ljd av det vi kom fram till efter f�rsta differensen ska vi nu
## genomf�ra en s�songsdifferensning d�r S = 12 p� grund av m�nadsdata.
## (P,D,Q) <- s�songskomponenter 

diff12.HOXSWE <- diff(d.HOXSWE,12)
plot(diff12.HOXSWE, main = " S�songs Differensning | Boprisindex HOXSWE", xlab = "Tid",
     col ="red", las=1)
## Efter den genomf�rda s�songsdifferensning kan vi observera att
## de tidigare n�mnda h�ga toppar har eliminerats mer med undantag
## f�r skarpa rusningen mot b�rjan av 2010. S�songsdifferensning
## appliceras som en skillnad mellan ett v�rde och ett v�rde med lag som 
## �r en multipel av "S" i detta fall S=12 d�rav X_t-12.


## Vi forts�tter vidare med att testa ifall det f�religger en enhetsrot
## p� den s�songsdifferensade serien denna g�ng.
ADF.test(diff12.HOXSWE)
## Teststatistikan tau3 p� 3.95 i absolutbelopp �verstiger 3.43
## i absolutbelopp p� 5% niv�n. Vi kan f�rkasta nollhypotesen
## avseende enhetsrot. Serien �r station�r samt har inte l�ngre
## n�gon enhetsrot.

## Exporterar tablell fr�n ADF-testet p� s�songsdifferensade serien
## till latex.
exportADF.diff12.HOXSWE <- ADF.test(diff12.HOXSWE)
exportADF.diff12.HOXSWE 
stargazer(exportADF.diff12.HOXSWE, type ="latex")

####################################################################
## 
##      KPSS-testet (Kwiatkowski-Phillips-Schmidt-Shin)
##
####################################################################

## Nollhypotesen vid ett KPSS-test testar ocks� f�r station�ritet.

## H0: Station�r
## HA: Icke-station�r 

## Teststatistikan �r ett m�tt p� variansen i testekvationen och om
## den �r s.k. 'liten', �r detta d� en indikation p� att v�r serie
## �r station�r. F�r att serien ska klassificeras som station�r kr�vs
## det att nollhypotesen i det genomf�rda KPSS-testet inte f�rkastas.

ur.kpss(HOXSWE, type="tau")@teststat
## Teststatiska: 0.3179527
ur.kpss(HOXSWE, type ="tau")@cval
## F�r fram de kritiska v�rdena p� 10%, 5%, 2.5% och 1% niv�n.
## Vi observerar att den erh�llna teststatistikan �vertiger 
## samtliga kritiska v�rdena p� valfri signifikans niv�.
## Med det sagt, ursprungsdatan �r ej station�rt


## Vi unders�kar vidare nu ifall den s�songsdifferensade
## serien har blivit station�rt.
ur.kpss(diff12.HOXSWE, type ="tau")@teststat
## Teststatistika: 0.04388372
ur.kpss(diff12.HOXSWE, type = "tau")@cval
## Teststatistikan p� 0.04388372 understiger samtliga kritiska v�rden
## p� valfri niv�. 0.04388372 < 0.146 p� 5% niv�n. Vi kan d�rav
## konstatera att vi ej kan f�rksata nollhypotesen avseende station�ritet.
## Den s�songsdifferensade serien �r nu station�r p� 5% niv�n samt
## �ven valfri vald signifikans niv�.


## P� grund genomf�randet av f�rsta differensen som standardmetodik
## i syfte att uppn� station�ritet och �ven till�mpning av 
## s�songsdifferensning till f�ljd av misstanke om behovet av s�songskomponenter,
## har vi till f�ljd av f�rsta- och s�songsdifferensning erh�llit f�ljande
## integrationsordningar: "d = 1" & "D = 1" i modellen ARIMA(p,d,q)(P,D,Q)[s]
## d�r s=12, som skall estimeras.


#############################################################################
##
## SAMK�RNING AV FIGURER. 
##
#############################################################################


## Samk�r b�de den f�rsta differensade och urprungsdatan (Icke-station�ra) ihop.

par(fin=c(100,100))
layout(matrix(c(1,1,2,3), 2, 2, byrow =TRUE))
plot.ts(d.HOXSWE, main = "F�RSTA DIFFERENSEN OCH URSPRUNGSDATA | HOXSWE", axes = FALSE, col = "blue",
        ylab = "", type = "l", lwd = 1)
axis(side=4)
mtext(side=4, "BOPRISINDEX", at=c(155), line = 1)
axis(side=1)
par(new=TRUE)
plot.ts(HOXSWE, axes = FALSE, col = "red", ylab = "%", lty = 1)
axis(side = 2)
box()
plot.ts(d.HOXSWE, main = "F�RSTA DIFFERENSEN (%)", xlab="Tid", col = "red")
plot.ts(HOXSWE, main = "BOPRISINDEX HOXSWE", xlab="Tid", col = "blue")


## Samk�r b�de den s�songsdifferensade och urprungsdatan (Icke-station�ra) ihop.

par(fin=c(100,100))
layout(matrix(c(1,1,2,3), 2, 2, byrow =TRUE))
plot.ts(diff12.HOXSWE, main = "S�SONGSDIFFERENSAD OCH URSPRUNGSDATA | HOXSWE", axes = FALSE, col = "blue",
        ylab = "", type = "l", lwd = 1)
axis(side=4)
mtext(side=4, "BOPRISINDEX", at=c(155), line = 1)
axis(side=1)
par(new=TRUE)
plot.ts(HOXSWE, axes = FALSE, col = "red", ylab = "%", lty = 1)
axis(side = 2)
box()
plot.ts(diff12.HOXSWE, main = "S�SONGSDIFFERENSAD (%)", xlab="Tid",ylab = "%", col = "red")
plot.ts(HOXSWE, main = "BOPRISINDEX HOXSWE", xlab="Tid", ylab = "%", col = "blue")



## Vi ska nu studera ACF och PACF i syfte mekaniskt
## estimera modellordningar f�r ARIMA-modellerna.
## Till f�ljd av s�songsdifferensningen som vi genomf�rde
## kommer vi beh�v att estimera en SARIMA(p,d,q)(P,D,Q)[12] d�r S=12
## p.g.a m�nadsdata.
## D�r ordningen f�r de autoregressiva AR(p) och movinge average 
## komponenterna MA(q) kommer att estimeras genom visuell inspektion
## av ACF och PACF p� f�rsta differensade correlogram och 
## p� s� vis estimera (p,d,q) medan samma metodik kommer att
## till�mpas f�r att estimera SAR(p) och SMA(q) fast
## p� den s�songsdifferensade serien.

par(mfrow=c(2,1))
acf(d.HOXSWE, main ="ACF F�rsta Differens")
pacf(d.HOXSWE, main = "PACF F�rsta Differens") 
## G�r att observera en signifikant s.k. spik vid f�rsta laggen i ACF
## vilket kan indikera en MA(1) samtidigt som man observerar
## spikar utanf�r konfidensbandet. Vad g�ller PACF, betraktar
## man den mest signikanta och d�rtill intressanta spik vid
## f�rsta laggen, kanske en AR(1) d.v.s SARIMA(1,1,1)(P,D,Q)[12].
## Men vi forts�tter att unders�ka.


## En tumregel �r enligt (Enders,2015, p.216) att s�tta laggen till 3 �r
## d.v.s f�r m�nadsdata till 36. 
par(mfrow=c(2,1))
acf(d.HOXSWE, lag.max= 36, main ="ACF F�rsta Differnens | lagmax 36")
pacf(d.HOXSWE, lag.max= 36, main ="PACF F�rsta Differens | lagmax 36")
## Vi ut�kar antalet laggar och genom grafisk inspektion kan vi
## observera 2 signifikanta s.k. spikar vid runt lag 1(M12) och 2(M24) I PACF 
## vilket kan indikera en AR(2) medan ACF uppvisar ett successivt d�mpande
## m�nster. ACF indikerar p� behovet av till�mpning av s�songskomponenter.


## Vi ut�kar antal laggar till n�got extremt som 50 f�r fortsatt inspektion.
acf(d.HOXSWE, lag.max = 50, main ="ACF F�rsta Differens | lagmax 50")
pacf(d.HOXSWE, lag.max = 50, main ="PACF F�rsta Differens| lagmax 50")
## ACF forts�tter att bekr�fta ett successivt avtagande m�nster vid varje enskild lag.
## PACF bekr�ftar  �terigen p� en AR(2)


## �nnu en g�ng ut�kar vi antal laggar till n�got extremt som 100 f�r inspektion.
acf(d.HOXSWE, lag.max = 100, main ="ACF F�rsta Differens | lagmax 100")
pacf(d.HOXSWE, lag.max = 100, main ="PACF F�rsta Differens| lagmax 100")

## Utan funktionen "lag.max", ser det ut som en ARIMA(1,1,1)
## integrerad av ordning 1 d�r d=1 med varsin autoregressiv komponent
## samt moving average komponent.
## N�r vi v�l nyttjar funktionen "lag.max" kan vi observera
## av avtagande m�nster i ACF vid varje enskild lagg vilket
## indikerar p� s�songsvariation samtidigt PACFB
## uppvisar tv� signifikanta spikar vid f�rsta och andra laggen.
## Till f�ljd av ACF successiva avtagande karakt�r, kan det 
## uppfattas som ARIMA(2,1,0) men vi forts�tter med unders�kningen.


## Men, p� grund av indikation av s�songsvariation, ska vi nu unders�ka samt
## mekaniskt estimera s�songskomponenterna (P,D,Q) ur SARIMA (p,d,q)(P,D,Q)[12].
## Vid estimation av s�songskomponenterna ska vi studera m�nster vid de enskilda
## laggarna. F�r v�rt m�nadsdata, ska vi studera vid lag 1 (M12), 2 (M24) 
## och 3 (M36) 

par(mfrow=c(2,1))
acf(diff12.HOXSWE, main ="ACF S�songs Differensad")
pacf(diff12.HOXSWE, main = "PACF S�songs Differensad") 
## ACF uppvisar ett kort segment med avtagande spikar
## som sedan faller in i bandet, dock uppvisas en signfikant
## spik borta vid lag 1 (M12).


## En tumregel �r enligt (Enders,2015, p.216) att s�tta laggen till 3 �r
## d.v.s f�r m�nadsdata till 36. 
par(mfrow=c(2,1))
acf(diff12.HOXSWE, lag.max = 36, main ="ACF S�songs Differensad | lagmax 36")
pacf(diff12.HOXSWE, lag.max = 36, main ="PACF S�songs Differensad | lagmax 36")



## Ut�kar antal laggar till n�got extremt som 50 f�r inspektion.
par(mfrow=c(2,1))
acf(diff12.HOXSWE, lag.max = 50, main ="ACF S�songs Differensad | lagmax 50")
pacf(diff12.HOXSWE, lag.max = 50, main ="PACF S�songs Differensad | lagmax 50")



## Ut�kar antal laggar till n�got extremt som 100 f�r inspektion och tydlighetens
## skull.
par(mfrow=c(2,1))
acf(diff12.HOXSWE, lag.max = 100, main ="ACF S�songs Differensad | lagmax 100")
pacf(diff12.HOXSWE, lag.max = 100, main ="PACF S�songs Differensad | lagmax 100")


## Genom visuell inspektion kan vi observera ett 
## ACF uppvisar ett avtagande m�nster under ett kort segment, och faller relativt 
## hastigt under konfidensbandet. 
## Autokorrelationsplotten uppvisar en signifikant spik vid lag 1 (M12).
## vilket kan indikera p� en SMA(1) d�r Q=1 d.v.s
## en s�songs moving average komponent medan PACF p� den s�songsdifferensade
## serien uppvisar ett n�got mer tvetydigt m�nster.
## PACF uppvisar s.k. spikar vid lag 1(M12) och lag 3(M36) och likas�
## uppviser PACF intressant m�nster vid lag 2 (M12).
## Man skulle kunna utr�na ett avtagande m�nster fr�n lag 1 till lag 3.


## EXPORTERA till figur.
par(mfrow=c(2,2))
acf(d.HOXSWE, lag.max = 100, main ="ACF F�rsta Differens")
pacf(d.HOXSWE, lag.max = 100, main ="PACF F�rsta Differens")
acf(diff12.HOXSWE, lag.max = 100, main ="ACF S�songsdifferensad")
pacf(diff12.HOXSWE, lag.max = 100, main ="PACF S�songsdifferensad")


## Avslutningsvis till�mpar vi AUTO.ARIMA() funktionen som i f�rsig
## v�ljer den ultimata modellen utifr�n informationskriterier.

auto.arima(HOXSWE) # # ARIMA(1,1,1)(0,1,1)[12] # d=1 och D=1 p� Ursprungsdata

auto.arima(HOXSWE, trace=TRUE) 
## Vill unders�ka grundad p� vilka modeller som ARIMA(1,1,1)(0,1,1)[12] valts ut.  


#############################################################################
##
##  2) ESTIMERING (AV OLIKA SARIMA MODELLORDNINGAR)
##
#############################################################################



## ARIMA(2,1,0)(0,1,1)[12]
HOXSWE.arima210011 <- arima(HOXSWE, order = c(2,1,0), seasonal = c(0,1,1))
coeftest(HOXSWE.arima210011) 
## Icke-signfikant AR(2) komponent, �r p� AR(1) och SMA(1)
## h�ggradigt signifikanta.


## ARIMA(1,1,0)(0,1,1)
HOXSWE.arima110011 <- arima(HOXSWE, order = c(1,1,0), seasonal = c(0,1,1))
coeftest(HOXSWE.arima110011)  
## H�ggradirgt sigfnikanta parameterestimat.
## Den modellordning som ordningen �ndras till f�r 2018:M01
## 2017:M12 samt 2017:M11
## Modellen som f�rel�r modellordningar enligt auto.arima beroende p� tidsperiod)


## ARIMA(1,1,1)(0,1,1)
HOXSWE.arima111011 <- arima(HOXSWE, order = c(1,1,1), seasonal = c(0,1,1))
coeftest(HOXSWE.arima111011) 
## Samtliga parameterestimaten �r h�ggradigt signfifikanta.


###########################################################################
##
##  3) Diagnostik
##
###########################################################################


## Jarque-Bera Test (Test av normalitet)
## Detta test till�mpas f�r att unders�ka ifall residualerna
## �r normalf�rdelade.

## H0: Residualerna �r normalf�rdelade
## HA: Residualerna �r EJ normalf�rdelade

jarque.bera.test(residuals(HOXSWE.arima210011)) # P-v�rde: 0.01718
jarque.bera.test(residuals(HOXSWE.arima110011)) # P-v�rde: 0.0328
jarque.bera.test(residuals(HOXSWE.arima111011)) # P-v�rde: 0.02322

## Ingen av de mekaniskt estimerade modellerna uppfyllde antagandet om 
## normalitet bland residualerna.
## Dock s� forts�tter vi med diagnostiken trots medvetenheten om det.

## LJUNG-BOX TEST ( Test av autokorrelation i residualer)

## Genom att utf�ra Ljung-Box Testet f�r autokorrelation,
## kan vi unders�ka ifall det finns kvarvarande autokorrelation
## i residualerna.

## H0: Finns EJ kvarvarande autokorrelation
## HA: Finns kvarvarande autokorrelation.

Box.test(resid(HOXSWE.arima210011), lag=4, type="L", fitdf = 3)  # P-v�rde = 0.1288
Box.test(resid(HOXSWE.arima111011), lag=4, type="L", fitdf = 3)  # P-v�rde = 0.2028
Box.test(resid(HOXSWE.arima110011), lag=4, type="L", fitdf = 3)  # P-v�rde = 0.02802

## Enbart modellen SARIMA(1,1,0)(0,1,1)[12] uppvisar att den har kvarvarande
## autokorrelation d� P-v�rdet p� 0.02802 understiger 5% niv�n vilket m�jligg�r
## att nollhypotesen avseende ingen kvarvarande autokorrelation
## i residualerna f�rkastas.Genom funktionen "coeftest" har vi satt "fitdf" 
## till antal koefficienter justerat f�r interceptet d.v.s utan interceptet och
## interceptet f�rsvinner till f�ljd av differensning. S� "fitdf" �r satt lika med
## antal parametrar.

## Vi v�ljer att arbeta vidare med den mekaniskt estimerade modellen
## och den modell som auto.arima v�ljer.

## ARIMA(2,1,0)(0,1,1)[12]
par(mfrow=c(3,2))
plot(residuals(HOXSWE.arima210011), main ="Residualsplot | ARIMA(2,1,0)(0,1,1)[12]")
hist(residuals(HOXSWE.arima210011), main ="ARIMA(2,1,0)(0,1,1)[12]", col = "gray", xlab = "Residual")
acf(residuals(HOXSWE.arima210011), main = "ACF residuals | ARIMA(2,1,0)(0,1,1)[12]")
pacf(residuals(HOXSWE.arima210011), main = "PACF residuals | ARIMA(2,1,0)(0,1,1)[12]")
qqnorm(residuals(HOXSWE.arima210011), main = "Normal Q-Q Plot | ARIMA(2,1,0)(0,1,1)[12]")
abline(a = 0, b=1, h=0, v=0, col=c("gray", "red", "blue"),
       lty = c(1,2,2))


## ARIMA(1,1,1)(0,1,1)[12]
par(mfrow=c(3,2))
plot(residuals(HOXSWE.arima111011), main ="Residualsplot | SARIMA(1,1,1)(0,1,1)[12]")
hist(residuals(HOXSWE.arima111011), main= "Histogram of residuals | SARIMA(1,1,1)(0,1,1)[12]",col = "gray", xlab = "Residual")
acf(residuals(HOXSWE.arima111011), main ="ACF residals | SARIMA(1,1,1)(0,1,1)[12]")
pacf(residuals(HOXSWE.arima111011), main ="PACF residals | SARIMA(1,1,1)(0,1,1)[12]")
qqnorm(residuals(HOXSWE.arima111011), main = "Normal Q-Q Plot | SARIMA(1,1,1)(0,1,1)[12]")
abline(a = 0, b=1, h=0, v=0, col=c("gray", "red", "blue"),
       lty = c(1,2,2))


## Genom grafisk inspektion av QQ ploten, kan vi se att det f�religger
## n�gra extremv�rden, v�rden som ligger betydligt l�ngt ifr�n den
## den r�ta linj�n som g�r ingenom origo. D� vi �ven tidigare
## f�rkastade nollhypotesen avseende normalitet vid JB-testet, f�r samtliga estimerade
## ARIMA-modeller, finns det sk�l till att unders�ka ifall vi har m�jligheten
## att eliminera problemen med residualernas egenskaper. Vi v�ljer
## att g�ra det f�r de tv� modeller vi har slussat fram grundad p� utfallen under
## olika diagnostiktesten.


## ARIMA(2,1,0)(0,1,1)[12] : p-value = 0.1541
RES.210011 <- residuals(HOXSWE.arima210011)
MAX.210011 <- RES.210011 == max(RES.210011)
MIN.210011 <- RES.210011 == min(RES.210011)
MAXMIN.210011 <- cbind(MAX.210011, MIN.210011)
HOXSWE.arima210011.X <- arima(HOXSWE, order = c(2,1,0), seasonal = c(0,1,1), xreg= MAXMIN.210011) 

## Genomf�r JB-testet �terigen.
jarque.bera.test(residuals(HOXSWE.arima210011.X))
## NORMALF�RDELAT d� det observerade p-v�rdet p� 0.1541 �verstiger
## 5% niv�n. 


## ARIMA(1,1,1)(0,1,1)[12] : p-value = 0.1161
RES.111011 <- residuals(HOXSWE.arima111011)
MAX.111011 <- RES.111011 == max(RES.111011)
MIN.111011 <- RES.111011 == min(RES.111011)
MAXMIN.111011 <- cbind(MAX.111011, MIN.111011)
HOXSWE.arima111011.X <- arima(HOXSWE, order = c(1,1,1), seasonal = c(0,1,1), xreg= MAXMIN.111011) 

## Genomf�r JB-testet �terigen.
jarque.bera.test(residuals(HOXSWE.arima111011.X))
# NORMALF�RDELAT ocks�.

## Vi kan ej f�rkasta nollhypotesen avseende att residualerna �r normala
## i b�da fallen.


#############################################################################
##
## MODELL UTV�RDERING MED INFORMATIONSKRITERIER
##
#############################################################################


## AIC (Akaike Information Criterion)

SARIMAaic = auto.arima(HOXSWE, trace=TRUE, ic="aic")
# Best model: SARIMA(1,1,1)(0,1,1)[12]  : 460.4947

## BIC:

SARIMAbic = auto.arima(HOXSWE, trace=TRUE, ic="bic")
## Best model: ARIMA(1,1,0)(0,1,1)[12] : 470.2072

## Genom BIC som IC, inser vi d�remot att v�r mekaniskt estimerade modell
## SARIMA(2,1,0)(0,1,1)[12] kommer p� 3:e plats, dock s� tar
## SARIMA(1,1,1)(0,1,1)[12] 2:a plats i detta fall ist�llet f�r 1:a.
## Vi ser �ven att modellen ARIMA(1,1,0)(0,1,1)[12] �r det ultimata enligt
## BIC. V�rt att ha i beaktelse, �r det facto att d� bestraffningen �r st�rre,
## s� f�redras modell med f�rre parametrar.


## Med hj�lp av den rangordning av modeller som informationskriterier genomf�r
## i syfte att utv�rdera de estimerade modeller, g�r det att observera att
## det f�religger skillnader mellan ARIMA(1,1,1)(0,1,1)[12]
## och ARIMA(2,1,0)(0,1,1)[12] i termer av den rangordning man f�r.


## ARIMA(1,1,1)(0,1,1)[12]
## ARIMA(2,1,0)(0,1,1)[12]


########################################################################
##
## REKURSIVA PROGNOSER
##
########################################################################

## Vi har anv�nt ett dataset fram till 2016:M01
## trots att hela serien HOX str�cker sig fram till 2018:M01.
## Det vi ska g�ra �r att successivt anv�nda denna hittils utnyttjade informationen.
## Vi ska ponera att vi st�ndigt f�r ny information.
## Detta inneb�r att f�r varje prognos vi g�r fram till och med 2018:M01
## har vi ett utfall att benchmarka med fr.o.m �r 2016. Detta arbetss�tt
## kallas f�r pseudo-out-sample-forecasts p� engelska, d�r vi ponerar att
## vi inte hade det faktiska utfallsdatan f�r de kommande tv� �ren
## efter 2016.

## Sedan tidigare vet vi om att auto.arima(HOXSWE) identifierade
## en SARIMA (1,1,1)(0,1,1)[12] dessutom utifr�n informationskriterier.


###################################################################
# REKURSIV PROGNOS - SARIMA (1,1,1)(0,1,1)[12]
#
# 
# auto.arima() -> SARIMA (1,1,1)(0,1,1)[12]
###################################################################


## Vi skapar en s.k. loop som ska i v�rt fall inneh�lla v�ra prognoser.
## Vi uppmanar loopen att b�rja skapa prognoser fr�n 2016:M02
## kommande 24 m�nader.

Prognos.HOXSWE.arima111011  <- ts(matrix(NA, nrow = 24, ncol = 1),
                                  start = c(2016, 2), frequency = 12)
for (i in 1:24){
  EndDate <- 2016.0083 + (i - 1) / 12
  Data <- window(HOXSWE_hela, end = EndDate)
  Result <- arima(Data, order = c(1, 1, 1),
                  seasonal= list(order = c(0, 1, 1)))
  Prognos.HOXSWE.arima111011[i] <- forecast(Result, h = 1)$mean
}
## 1/12 = 0.083 (Varje m�nad �r 0.083-del av ett �r)
## 2016.0083 = Januari 2016 dvs(2016:M01). Det var fram till
## 2016:M01 som vi estimerade ARIMA-modellerna och fr�n och med 
## kommer vi l�tsas som om vi ej har faktiska utfallsdatan.


Prognos.HOXSWE.arima111011 
## F�r fram pseudo-out-sample-forecasts f�r de kommande 24 m�nader
## med start ifr�n 2016:M02 fram till 2018:M01.


## Studera de kommande prognoserna med utfallsdata
Utfall.fr�n201602<- window(HOXSWE_hela, start = c(2016,02))
window(cbind(Utfall.fr�n201602, Prognos.HOXSWE.arima111011), end = c(2018,02))
ts.plot(Utfall.fr�n201602, main ="Utfallsserie fr�n 2016:M02")
ts.plot(Prognos.HOXSWE.arima111011, main="Psuedo-out-sample-forecasts fr�n 2016:M02")


## Samk�r Utfall fr�n 2016 och Prognostiserade SARIMA(1,1,1)(0,1,1)[12]
ts.plot(Utfall.fr�n201602, Prognos.HOXSWE.arima111011, 
        main ="Utfallsdatan & Pseudo SARIMA(1,1,1)(0,1,1)[12]",
        gpars=list(xlab = "Time",col =c("black","red")))
legend("topleft", legend = c("Utfall fr�n 2016", "Pseudo SARIMA111011"), col = c("black", "red"), lty = 1, cex=0.6)


## Samk�r hela HOX serien fr�n 2005:M01 till 2018:M01 samt prognostiserade SARIMA(1,1,1)(0,1,1)[12]

## Utfall.hela = hela serien fr�n 2005 till 2018 i fallet f�r SARIMA(1,1,0)(0,1,1)[12]
Utfall.hela05till18 <- window(HOXSWE_hela, start = c(2005,1))
plot(Utfall.hela05till18, main ="HOX")
window(cbind(Utfall.hela05till18, Prognos.HOXSWE.arima111011))
ts.plot(Utfall.hela05till18 , Prognos.HOXSWE.arima111011, 
        main ="HOX Utfallsdata & Pseudo SARIMA(1,1,1)(0,1,1)[12]", 
        gpars=list(xlab = "Time",col =c("black","red")))

legend("topleft", legend = c("HOXSWE", "Pseudo SARIMA111011"), 
       col = c("black", "red"), lwd =1, lty = 1,  cex=0.6)



#######################################################################
# REKURSIV PROGNOS - SARIMA (2,1,0)(0,1,1)[12]
# 
# Den mekaniskt estimerade modellordningen -> SARIMA (2,1,0)(0,1,1)[12]
#######################################################################

## Vi skapar �terigen en loop h�r igen som ska i v�rt fall inneh�lla 
## v�ra prognoser.
## Vi uppmanar loopen att b�rja skapa prognoser fr�n 2016:M02 som ska k�ra
## kommande 24 m�nader.

Prognos.HOXSWE.arima210011  <- ts(matrix(NA, nrow = 24, ncol = 1),
                                  start = c(2016, 2), frequency = 12)

for (i in 1:24){
  EndDate <- 2016.0083 + (i - 1) / 12
  Data <- window(HOXSWE_hela, end = EndDate)
  Result <- arima(Data, order = c(2, 1, 0),
                  seasonal= list(order = c(0, 1, 1)))
  Prognos.HOXSWE.arima210011[i] <- forecast(Result, h = 1)$mean
}
## 1/12 = 0.083 (Varje m�nad �r 0.083-del av ett �r)
## 2016.0083 = Januari 2016 dvs(2016:M01). Det var fram till
## 2016:M01 som vi estimerade ARIMA-modellerna och fr�n och med nu 
## kommer vi l�tsas som om vi ej har faktiska utfallsdatan.


Prognos.HOXSWE.arima210011
## F�r fram pseudo-out-sample-forecasts f�r de kommande 24 m�nader
## med start ifr�n 2016:M02 fram till 2018:M01.


Utfall <- window(HOXSWE_hela, start = c(2016,2))
window(cbind(Utfall.fr�n201602, Prognos.HOXSWE.arima210011), end = c(2018,2))


## Samk�r Utfall och Prognostiserade SARIMA(2,1,0)(0,1,1)[12]

ts.plot(Utfall.fr�n201602, Prognos.HOXSWE.arima210011,
        main ="Utfall & Prognostiserade SARIMA(2,1,0)(0,1,1)[12]", 
        gpars=list(xlab = "Time",col =c("black","purple")))
legend("topleft", legend = c("Utfall fr�n 2016", "Pseudo SARIMA210011"), col = c("black", "purple"), lty = 1, cex=0.60)


#######################################################################
## 
## Samk�r HELA serien fr�n 2005:M01 till 2018:M01 samt prognostiserade 
## SARIMA(2,1,0)(0,1,1)[12]
##
#######################################################################


plot(Utfall.hela05till18, main="HOX",ylab="%")
window(cbind(Utfall.hela05till18, Prognos.HOXSWE.arima210011), end = c(2018,02))
ts.plot(Utfall.hela05till18, Prognos.HOXSWE.arima210011, 
        main ="Hela Utfall & Prognostiserade SARIMA(2,1,0)(0,1,1)[12]",
        gpars=list(xlab = "Time", col =c("black","purple")))
legend("topleft", legend = c("HOXSWE", "Pseudo SARIMA210011"), 
       col = c("black", "purple"), lty = 1, cex=0.6)


#######################################################################
## 
##  Samk�r utfallsdata, SARIMA(1,1,1)(0,1,1) och SARIMA(2,1,0)(0,1,1)
##
#######################################################################

ts.plot(Utfall.fr�n201602, Prognos.HOXSWE.arima210011, Prognos.HOXSWE.arima111011,
        main ="Utfallsdata & SARIMA111011 & SARIMA210011", 
        gpars=list(xlab = "Time",col =c("black","purple", "red")))
legend("topleft", legend = c("Utfallsdata fr�n 2016", "Pseudo SARIMA210011",
                             "Pseudo SARIMA111011"), col = c("black", "purple" ,"red"), lty = 1, cex=0.55)

## B�da av v�ra estimerade modeller SARIMA(1,1,1)(0,1,1) och SARIMA(2,1,0)(0,1,1)
## f�ljer ursprungsserien v�l. Mycket marginella skillnader
## mellan de genomf�ra pseudo-out-of-forecasts av modellerna
## SARIMA(1,1,1)(0,1,1) och SARIMA(2,1,0)(0,1,1).



#######################################################################
## Optimalitets Test.
##
## Nu ska vi testa �ven f�r vilken modellordning som �r optimal 
## d.v.s unbiased!
## Att prognosen �r icke-tendenti�s �r ett viktigt villkor som �r
## n�dv�ndigt f�r en prognos att vara optimal.
#######################################################################

Prognos.arima.1B <- ts(matrix(NA, nrow = 24, ncol = 1),
                       start = c(2016, 2), frequency = 12)


M.Order2 <- ts(matrix(NA, nrow = 24, ncol = 7),
               start = c(2016, 2), frequency = 12,
               names=c("p","q","P","Q","F","d","D"))

for (i in 1:24){
  EndDate <- 2016.0083 + (i - 1) / 12
  Data <- window(HOXSWE_hela, end = EndDate)
  Result <- auto.arima(Data)
  Prognos.arima.1B[i] <- forecast(Result, h = 24)$mean
  M.Order2[i,] <- Result$arma
}

M.Order2
## Visar sig vara samma modellordning f�rutom sista 3 m�nader.
## F�resl�r SARIMA(1,1,1)(0,1,1)[12] fr�n 2016:M02 till 2017:M10.
## Fr�n 2017:M11 �ndras modellordningen till SARIMA(1,1,0)(0,1,1)[12].

## V�rt att notera, modellen SARIMA(1,1,0)(0,1,1)[12] estimerades
## tidigare i projektet dock fallerade modellen b�de p�
## normalitet samtidigt som den led av kvarvarande
## autokorrelation i residualerna. D�rav valde vi inte att
## arbeta med den modell p.g.a den inte uppfyllde
## antagandena vid genomf�randet av standardtesterna.


window(cbind(Utfall.fr�n201602, Prognos.HOXSWE.arima111011 , Prognos.arima.1B),
       start = c(2016, 2), end = c(2018, 1))
## F�r m�naden 2017:M11, f�ngar den rekursiva upp marginellt b�ttre.
## F�r m�naden 2017:M12 f�ngar den rekursiva SARIMA(1,1,1)(0,1,1)
## n�got b�ttre upp �n SARIMA(1,1,0)(0,1,1).
## D�remot f�r m�naden 2018:M01 framst�s SARIMA(1,1,0)(0,1,1)
## som att det f�ngar upp b�ttre d� punktprognosen p� 225.4712
## �r n�rmre utfallsdatan p� 228.71 �n den rekursiva SARIMA(1,1,1)(0,1,1)
## vars punktprognos �r 224.7824



#################################################################
# RULLANDE PROGNOSER
#
#################################################################

## Vi pr�var �ven med att till�mpa rullande prognoser i syfte
## med att j�mf�ra med rekursiva prognoser. Vid till�mpning av
## rullande prognoser, kommer nya observationer att adderas
## samtidigt som de �ldsta observationerna exkluderas. P� s� vis
## kommer datasetet vara ideligen of�r�ndrad.



Prognos.arima.rullande <- ts(matrix(NA, nrow = 24, ncol = 1),
                             start = c(2016, 2), frequency = 12)

M.Order4 <- ts(matrix(NA, nrow = 24, ncol = 7),
               start = c(2016, 2), frequency = 12,
               names=c("p","q","P","Q","F","d","D"))

for (i in 1:24){
  StartDate <- 2005.0083 + (i-1)/12
  EndDate <- 2016.0083 + (i-1)/12
  Data <- window(HOXSWE_hela, start = StartDate, end = EndDate)
  Result <- auto.arima(Data)
  Prognos.arima.rullande[i] <- forecast(Result, h = 24)$mean
  M.Order4[i,] <- Result$arma
}

M.Order4
window(cbind(Utfall.fr�n201602,Prognos.arima.1B,
             Prognos.arima.rullande, Prognos.HOXSWE.arima111011, Prognos.HOXSWE.arima210011), end = c(2018, 1))

Samtligaprognoser <- window(cbind(Utfall.fr�n201602,Prognos.arima.1B,
                                  Prognos.arima.rullande, Prognos.HOXSWE.arima111011,
                                  Prognos.HOXSWE.arima210011), end = c(2018, 1))


samtligaprognoser <- as.data.frame(window(cbind(Utfall.fr�n201602,Prognos.arima.1B,
                                                Prognos.arima.rullande,
                                                Prognos.HOXSWE.arima111011, Prognos.HOXSWE.arima210011), end = c(2018, 1)))

## Exportera utfallsdata fr. 2016:M02 till 2018:M01,
## rekursiv prognos SARIMA(1,1,1)(0,1,1)[12], Pseudo 1B (modellen som f�rel�r
## modellordningar enligt auto.arima beroende p� tidsperiod) samt
## rullande prognos.
stargazer(samtligaprognoser, type="latex", summary=FALSE, font.size = "scriptsize")



#########################################################################
## Samk�r serier p�:
##
## Utfallsdata fr�n 2016 till 2018,
## utfallsdata fr�n 2005 till 2018, rullande prognos
## Pseudo 1B(rekursiv prognos d�r modellordningen �ndras enligt auto.arima
## samt rekursiva SARIMA(1,1,1)(0,1,1)[12] och SARIMA(2,1,0)(0,1,1)[12]
##########################################################################

window(cbind(Utfall.hela05till18, Prognos.HOXSWE.arima111011, Prognos.arima.1B, 
             Prognos.arima.rullande, Prognos.HOXSWE.arima210011), end = c(2018, 1))

Allihopa <- window(cbind(Utfall.hela05till18, Prognos.HOXSWE.arima111011, 
                         Prognos.arima.1B, Prognos.arima.rullande, Prognos.HOXSWE.arima210011), end = c(2018, 1))

Allihopa
## Hela utfallsserien fr�n 2005-2018 samt de rekursiva
## pseudo-out-sample-forecasts, rullande prognos.



## SAMK�R ALLA 4 serier ihop med HOX fr�n 2016 till 2018.
ts.plot(Utfall.fr�n201602, Prognos.HOXSWE.arima111011,Prognos.arima.1B, 
        Prognos.arima.rullande, Prognos.HOXSWE.arima210011,  main ="Samk�r samtliga serier fr. 2016",
        gpars=list(xlab = "Time", col =c("black","purple", "red", "green", "pink")))

legend("topleft", legend = c("Utfall fr�n 2016", "SARIMA111011", "SARIMA210011", "Pseudo 1B","Rullande Prognos"), 
       col = c("black", "purple", "red", "green", "pink"), lty = 1, cex=0.6)



## SAMK�R ALLA 4 serier ihop med HOX fr�n 2005 till 2018.
ts.plot(Utfall.hela05till18, Prognos.HOXSWE.arima111011,Prognos.arima.1B, 
        Prognos.arima.rullande,Prognos.HOXSWE.arima210011,  main ="Samk�r samtliga serier fr.2005",
        gpars=list(xlab = "Time", col =c("black","purple", "red", "green", "pink")))

legend("topleft", legend = c("Utfall HOX", "SARIMA111011", "SARIMA210011", "Pseudo 1B", " Rullande Prognos"), 
       col = c("black", "purple", "red", "green", "pink"), lty = 1, cex=0.6)



###################################################################
# PROGNOSUTV�RDERING
#
#
################################################################### 

## Rekursiv -  SARIMA(2,1,0)(0,1,1)[12]
FE.Prognos.HOXSWE.arima111011 <- Utfall.fr�n201602 - Prognos.HOXSWE.arima111011 

## Rekursiv -  SARIMA(2,1,0)(0,1,1)[12]
FE.Prognos.HOXSWE.arima210011 <- Utfall.fr�n201602 - Prognos.HOXSWE.arima210011

## Rekursiv - Pseudo 1B: d�r modellordningen �ndras utifr�n auto.arima vid olika tidsperioder
FE.Prognos.arima.1B <- Utfall.fr�n201602 - Prognos.arima.1B

## Rullande
FE.Prognos.arima.rullande <- Utfall.fr�n201602 - Prognos.arima.rullande

###############################################################################

coeftest(dynlm(FE.Prognos.HOXSWE.arima111011 ~1), vcov. = NeweyWest) 
## SARIMA(1,1,1)(0,1,1)[12] med ett P-v�rde:  0.6624 
## (Prognosen �r unbiased p� 5% niv�n.)


coeftest(dynlm(FE.Prognos.arima.1B  ~1), vcov. = NeweyWest) 
## P-v�rde: 0.5979 (Prognosen �r unbiased)


coeftest(dynlm(FE.Prognos.HOXSWE.arima210011 ~ 1 ), vcov. = NeweyWest) 
## SARIMA(2,1,0)(0,1,1)[12] med ett P-v�rde: 0.6523
## (Prognosen �r unbiased p� 5% niv�n.)
## trots att Pseudo 1B modell aldrig f�reslog SARIMA(2,1,0)(0,1,1)[12] 
## n�gong�ng.

coeftest(dynlm(FE.Prognos.arima.rullande  ~ 1 ), vcov. = NeweyWest) 
## P-v�rde: 0.5046 (Prognosen �r unbiased)


## I f�ljande sekvens avseende prognosprecision, skall vi testa
## hypotesen om lika prognosprecision genom Diebold-Mariano-testet.

## H0: f�rlustdifferensen �r noll 
## HA: f�rlustdifferensen �r skild fr�n noll 

prognoser <- c("FE.Prognos.HOXSWE.arima111011", "FE.Prognos.arima.1B",
               "FE.Prognos.arima.rullande", "FE.Prognos.HOXSWE.arima210011")

(testlista <- combn(prognoser, 2))
## Vi f�r en lista p� samtliga prognoser
## samt d�rtill en list p� parvisa testerna vi vill g�ra.


## Diebold och Mariano

DM.TEST <- function(x){
  require(dynlm)
  require(lmtest)
  require(sandwich)
  fe1 <- get(x[1])
  fe2 <- get(x[2])
  res <- dynlm(I(fe1^2 - fe2^2) ~ 1)
  round(coeftest(res, vcov. = NeweyWest)[4], 3)
}

apply(testlista, 2, DM.TEST)

## Ser att ingen av prognoserna f�rkastar nollhypotesen
## avseende lika f�rlustdifferens.
## D� samtliga p-v�rden �verstiger den valda
## signifikansniv� p� 5%, kan vi inte f�rkasta nollhypotesen
## om lika f�rlustdifferens avsende prognosfelen.


## F�r unders�kning av prognosprecision, kan �ven standardiserade
## statistika m�tt s�som RMSE & MAE till�mpas.

accuracy(HOXSWE.arima111011)
## RMSE: 1.4512, MAE: 1.065833

accuracy(HOXSWE.arima210011)
## RMSE: 1.459459, MAE:1.070971

## Det marginella l�gre root mean squared error och
## mean absolue error statistikor, ger indikation p�
## SARIMA(1,1,1)(0,1,1)[12] �r den datagenereringsprocess
## med l�gst prognosfel och d�rmed h�gsta prognosprecision
## sinsemellan de tv� modellerna.

#######################################################################
# END
#######################################################################

