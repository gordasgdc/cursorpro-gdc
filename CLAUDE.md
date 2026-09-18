# CursorPro GDC — reguli de arhitectură

> **[SYSTEM DIRECTIVE FOR CLAUDE: DO NOT DELETE OR OVERWRITE EXISTING RULES. ONLY APPEND NEW RULES.]**
> Jurnal viu, nu document care se rescrie. La orice actualizare, adaugă la finalul secțiunii potrivite — nu șterge/înlocui reguli vechi decât dacă sunt explicit invalidate de o schimbare reală (și atunci marchează-le **[ÎNVECHIT]** cu motivul, nu le șterge din istoric).

Citit automat de Claude Code la fiecare sesiune în acest repo. App nativ Swift/AppKit, menu-bar only (`LSUIElement`), înlocuitor pentru "Pro Mouse for Mac". Vezi și memoria `cursorpro-project` pentru lecțiile tehnice complete (Zoom/TCC/signing).

## [PARTEA 1: REGULI GLOBALE ECOSISTEM GDC] — mutată în `~/Developer/CLAUDE.md`

> Din 2026-09-18, regulile globale stau într-un singur fișier,
> `~/Developer/CLAUDE.md`, citit automat de Claude Code în orice proiect din
> `~/Developer/`. Nu se mai copiază aici. Ce era specific acestui repo în fosta
> Partea 1 (statusuri, excepții) e la finalul fișierului.

## [PARTEA 2: SPECIFICAȚII TEHNICE PROIECT]

## REGULĂ PERMANENTĂ: Locația proiectului pe disc (2026-08-25)
Acest repo trăiește în **`~/Developer/CursorPro`**, NU în `~/Downloads`.
Motiv: `~/Downloads` e curățat automat de CleanMyMac/Hazel pe acest Mac —
a șters alte repo-uri de sursă în timpul unei sesiuni de lucru anterioare
(recuperate din Coș la timp). Vezi `~/Developer/GDCPluginManager/PROJECT_STRUCTURE.md`
pentru context complet despre relocarea structurii de proiecte GDC.

## REGULĂ PERMANENTĂ: Uninstaller obligatoriu în orice pachet (2026-08-25)
Fiecare build/release TREBUIE să includă, alături de pachetul semnat și
notarizat:
1. Instalatorul (`.pkg` semnat cu `Developer ID Installer` + notarizat +
   stapled — vezi `build_installer.sh`).
2. **Uninstaller-ul complet** (`Dezinstalare_CursorPro.command`) — oprește
   procesele, resetează permisiunile TCC (`tccutil reset`), șterge
   aplicația + toate fișierele din `~/Library/` (Application Support,
   Caches, Preferences, Saved Application State, Logs). Cablat automat în
   `build_installer.sh` — copiat în `dist/` și inclus în
   `CursorProGDC-Mac.zip`, la rădăcina arhivei. NU genera un script nou de
   fiecare dată — editează `Dezinstalare_CursorPro.command` din rădăcina
   repo-ului, sursa unică de adevăr.

**[ÎNVECHIT 2026-08-25]** Exista anterior un launcher `Instalare_CursorPro.command`
care rula `xattr -dr com.apple.quarantine` pe `.pkg` înainte să-l deschidă —
ELIMINAT complet (fișier șters din repo). Motiv: pachetul e deja semnat +
notarizat + **stapled** (`xcrun stapler staple`, vezi `codesigning/sign-and-notarize.sh`),
deci Gatekeeper îl acceptă NATIV la dublu-click, cu sau fără quarantine flag —
orice comandă `xattr`/bypass e inutilă și arată neprofesionist/suspect,
exact cum a semnalat corect Cristi. Arhiva `CursorProGDC-Mac.zip` conține
acum DOAR 3 fișiere la rădăcină: `CursorProGDC.pkg`, `Dezinstalare_CursorPro.command`,
PDF-ul de instrucțiuni. Curățarea unei instalări vechi (evitarea a două
copii ale `.app` pe disc) se face acum corect, în `installer/scripts/preinstall`
(`pkgbuild --scripts`) — pkill + `rm -rf` pe copia veche, NIMIC legat de
Gatekeeper/quarantine acolo.
3. **Sincronizare 100% site ↔ GitHub Release**: linkul de descărcare de pe
   `docs/index.html` trebuie să trimită mereu la
   `releases/latest/download/CursorProGDC-Mac.zip` (niciodată la un tag
   fix sau un fișier hostat separat) — verificat 2026-08-25: linkul era deja
   corect, dar verifică din nou la orice restructurare de release.

Această regulă se aplică și la `gdc-plugin-manager` (Mac+Windows) — vezi
`CLAUDE.md`/`CHANGELOG.md` de acolo pentru portarea echivalentă.

## Bug investigat 2026-08-25: iconița din Menu Bar dispare instant

**Raportat**: aplicația pornește, iconița din bara de sus dispare aproape
instant, dar procesul rămâne viu (vizibil în Activity Monitor, necesită
Force Quit).

**Investigație făcută** (nu doar presupunere):
- Verificat live pe acest Mac: proces pornit, iconița confirmată prezentă
  prin Accessibility API (`osascript` → `menu bar item 1 of menu bar 1`,
  descriere "CursorPro") imediat după lansare ȘI după 15+ secunde — **nu
  am putut reproduce bug-ul aici**.
- `log show` pe procesul CursorPro în timpul lansării — niciun
  error/fault/exception.
- Revizuit tot codul `NSStatusItem`: un singur apel la `buildStatusItem()`,
  un singur punct de atribuire a `statusItem`, niciun `removeStatusItem`
  nicăieri, niciun al doilea `setActivationPolicy` care ar putea perturba
  starea. Simbolul SF (`cursorarrow.motionlines`) confirmat valid.
- Verificat garda de instanță unică (`NSRunningApplication.runningApplications`)
  — logica e corectă: instanța nouă se termină pe ea însăși dacă găsește
  una existentă, nu afectează instanța supraviețuitoare.

**Concluzie**: cel mai probabil specific configurației de sistem a
testerului (ex. "Automatically hide and show the menu bar" din Control
Center, Stage Manager, sau un monitor extern cu setări particulare), nu un
bug de cod reprodus aici. **Hardening aplicat** (fără a pretinde un fix
confirmat): `statusItem.isVisible = true` explicit + logging de diagnostic
în `DebugLog.swift` (`~/Desktop/cursorpro_debug.log`) la crearea
status item-ului.

**Pentru diagnosticare reală data viitoare**: cere testerului
`~/Desktop/cursorpro_debug.log` IMEDIAT după ce bug-ul apare (înainte de
Force Quit), plus versiunea exactă de macOS, dacă are Stage Manager
activ, și dacă are "Automatically hide and show the menu bar" activat în
System Settings → Control Center. Nu re-încerca fix-uri oarbe fără acest
semnal concret.

## DIRECTIVĂ PERMANENTĂ SUPREMĂ: Checklist obligatoriu la FIECARE release (2026-08-25)
Valabilă pentru TOATE aplicațiile ecosistemului GDC (CursorPro, GDC Plugin
Manager + Furnizor, GDC Plugin Manager Windows, DataMover, GDC Production
Manager, și orice proiect nou). Înainte de a raporta un release ca fiind
gata, TREBUIE bifate intern toate cele 4 puncte de mai jos — dacă unul
lipsește, spune-o explicit, nu declara release-ul "gata".

1. **Versiune vizibilă în UI** — About/Meniu/Settings/Footer trebuie să
   arate versiunea curentă (`v1.2.21` etc.), fără excepție.
2. **Verificator de actualizări** — la pornire sau printr-un buton
   „Caută actualizări", aplicația verifică versiunea de pe server/GitHub
   și notifică userul când există un release mai nou.
3. **Pachetul standard de release** — orice arhivă livrată clientului
   conține FĂRĂ EXCEPȚIE:
   - executabilul/installer-ul semnat + notarizat,
   - `Dezinstalare_[NumeAplicație].command` (dezinstalare completă:
     procese, permisiuni TCC, toate fișierele din `~/Library/`),
   - un ghid/PDF de instrucțiuni.
4. **Sincronizare site ↔ GitHub Releases** — linkurile de download de pe
   site trebuie să pointeze mereu la `releases/latest/download/...`
   (HTTP 200 verificat, nu presupus) și să menționeze numărul ultimei
   versiuni.

## Etapa 2026-09-11 — Lupă/halo la dimensiuni mari + persistența preferințelor

Cerut de Cristi: plaje mult mai generoase pentru Zoom și Halo, potrivite pentru
medii profesionale (monitoare mari, prezentări), plus randare constantă la
60/120fps la dimensiunile noi.

**1. Dimensiunea lupei — de la constantă la reglaj (200–900px).**
`AppState.zoomWindowDiameter` era `static let 360`. Nota din cod avertiza
explicit împotriva a „două slidere care se bat pe același rezultat" — dar acea
notă e despre raza SURSEI capturate, care rămâne și acum strict derivată
(`zoomRadius = diametru / (2 × factor)`). Cele două reglaje înseamnă lucruri
diferite și nu se suprapun: `zoomFactor` = *cât* mărește, `zoomWindowDiameter`
= *cât de mare e lupa pe ecran*. Invariantul e neatins.

**Capcană reală**: fereastra lupei se construiește O SINGURĂ DATĂ și e apoi
reutilizată la fiecare activare — fără `applyDiameterIfChanged()`, o schimbare
din Preferințe n-ar fi avut niciun efect până la repornire. Se redimensionează
și masca circulară (`cornerRadius`) și eticheta de culoare, altfel lupa ar fi
devenit un pătrat cu colțuri rotunjite mic.

**2. Halo: 12–400px (era 12–80), grosime 1–20 (era 1–10).**

**3. Scroll proporțional, nu aditiv.** Cu increment absolut, același gest
însemna +0.5× atât la 1.2× (salt uriaș) cât și la 10× (imperceptibil). Zoomul
e perceput logaritmic, deci incrementul se scalează cu factorul curent.

**4. Invalidație dinamică — câștigul real de performanță.**
Înainte: `Timer` fix la 1/60s care punea `needsDisplay = true` pe TOT view-ul,
adică repictarea întregului ecran (pe 4K, ~8.8M pixeli) de 60 ori/secundă, doar
ca să miște un inel. Acum: se invalidează doar uniunea (poziție veche ∪ poziție
nouă) a halo-ului, cu cădere înapoi pe invalidare totală când e activ un mod
care chiar desenează oriunde (spotlight, desen, efecte de click, badge de taste)
— corect înainte de rapid. Peste 50% din suprafață, invalidarea parțială nu mai
aduce nimic și se trece tot pe totală.

**BUG EVITAT, găsit citind codul de desenare**: stilul `.crosshair` desenează
patru liniuțe care ies în afara cercului cu `d × 0.4` FIECARE. Un calcul naiv
`d/2 + lineWidth` le-ar fi tăiat la marginea regiunii invalidate. Formula
`maxHaloExtent` le include explicit. Verificat pe **7644 de combinații** din
toată plaja (12...400 × 1...20 × 2 stiluri): regiunea invalidată acoperă
întotdeauna ce se desenează, cu marjă minimă de 4.5px pentru anti-aliasing.

`ctx.clear(bounds)` → `ctx.clear(dirtyRect)`: cu invalidare parțială, ștergerea
trebuie limitată la regiunea redesenată.

**5. `CADisplayLink` în loc de `Timer`.** Timer-ul fix la 60Hz pierdea jumătate
din cadre pe ProMotion (120Hz) și se vedea ca micro-sacadare. `displayLink` e
disponibil nativ pe `NSView` de la macOS 14 — deja minimul aplicației.

**6. GĂSIT LA AUDIT: preferințele nu se salvau DELOC.**
`AppState` n-avea nicio persistență — culoare, dimensiuni, taste configurate,
tot se pierdea la fiecare închidere. A devenit blocant odată cu plajele mari:
o unealtă pe care o reglezi pentru monitorul tău și care uită totul la
repornire nu e utilizabilă profesional — fix scenariul pentru care s-au cerut
valorile mari. Adăugat `AppStatePersistence.swift`.

**Capcană evitată deliberat**: NU se abonează la `objectWillChange`.
`mouseLocation` e și el `@Published`, deci acel semnal se emite la fiecare
mișcare de mouse (60-120/sec) — chiar și cu debounce, ar fi însemnat o scriere
pe disc la fiecare 0.4s în permanență, degeaba, cât timp aplicația stă pornită
în bara de meniu. Se abonează explicit doar la publisher-ele preferințelor
(`Publishers.MergeMany`). Costul conștient: o preferință nouă trebuie adăugată
și în acea listă. Valorile citite se ÎNCADREAZĂ în plaja curentă la load —
altfel o plajă restrânsă într-o versiune viitoare ar lăsa slider-ul pornit în
afara barei.

Versiune: 1.2.2 → **1.3.0** (MINOR, Regula 14). Nu s-a atins varianta Windows
(`CursorProWin`) — cerere explicit doar pentru macOS; paritatea rămâne TODO
declarat, vezi `CHANGELOG.md`.

## Etapa 2026-09-12 (v1.3.1) — Permisiuni care nu se rețin + spotlight cu urme

Două reclamații de la Cristi, cu **o cauză comună** plus un defect propriu de
randare. Mac only, cerut explicit — Windows neatins.

### 1. Permisiunile cerute la fiecare pornire — cauza REALĂ, găsită în TCC

Verificat direct în baza de date TCC a sistemului, nu presupus:

```
sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select service,client,auth_value,hex(csreq) from access where client='com.gordasgdc.cursorpro';"
```

Rândurile existau, cu `auth_value = 2` (permis) — deci Setările de sistem
arătau bifa aprinsă. Dar `csreq` (cerința de semnătură pe care macOS o
salvează la acordare) conținea un **hash de certificat**,
`997CF9CE02CED6DDEA46B132469A94512FD10FA5` — identic cu SHA-1 al
certificatului local auto-semnat „CursorPro" din breloc
(`security find-certificate -c CursorPro -Z`).

Aplicația instalată era însă semnată **Developer ID** (`anchor apple generic`,
OU `8AR6XP8MG7`) — deci NU satisfăcea cerința salvată. macOS o trata ca pe o
aplicație necunoscută → cerea permisiunea la fiecare pornire, în timp ce
rândul vechi rămânea vizibil ca „acordat". Reacordarea nu repara nimic; doar
ștergerea rândului repara, ceea ce explică exact „de fiecare dată să mă apuc
să scot, să șterg, să relansez permisiunile".

**Sursa oscilației**: `build_app.sh` cădea TĂCUT pe
`codesign --sign "CursorPro"` (auto-semnat) ori de câte ori
`APPLE_SIGN_IDENTITY_APP` nu era exportat în shell. Build local → auto-semnat;
instalare din release → Developer ID; și tot așa. Comentariul din script
prezisese problema, dar o descria ca întâmplându-se „O SINGURĂ DATĂ" — în
realitate se repetă la fiecare alternanță.

**Reparat:**
- `build_app.sh` caută acum singur identitatea `Developer ID Application` din
  breloc și o folosește — aceeași identitate ca la build-urile livrate. Fără
  ea și fără `APPLE_SIGN_IDENTITY_APP`, scriptul **eșuează explicit** în loc să
  cadă pe auto-semnat; fallback-ul rămâne disponibil doar prin
  `CURSORPRO_ALLOW_SELFSIGNED=1`, cu avertisment zgomotos.
- `PermissionsChecker` capătă `signingIdentity` (din `SecCodeCopySigningInformation`),
  `evaluateOnLaunch()` și `resetStaleGrants()` (`tccutil reset` pe
  Accessibility/ScreenCapture/ListenEvent, fără parolă de admin — sunt
  permisiunile propriei aplicații).
- `AppDelegate` nu mai cheamă `requestAccessibilityIfNeeded()` neconditionat la
  fiecare lansare. Distinge trei cazuri: totul OK / prima rulare / **intrare
  invechită**, iar pentru al treilea arată o fereastră care explică situația și
  repară cu un buton. Prag: a doua pornire consecutivă fără încredere (nu
  prima, ca să nu sperie un user aflat la prima rulare).
- Element de meniu permanent „Repară permisiunile…", pentru cazul în care
  userul ajunge acolo singur.

**Făcut pe mașina lui Cristi, în această sesiune**: `tccutil reset` pe ambele
servicii — rândurile invechite au dispărut (`select ... where client=...`
întoarce gol). Următoarea acordare se leagă de Developer ID și rămâne validă.

### 2. Spotlight blocat pe ecran + pătrățele la mișcarea mouse-ului

Două defecte distincte, care se compun:

- **Modul rămânea pornit**: `isSpotlightActive`/`isDrawActive`/`isZoomActive`
  se actualizau EXCLUSIV din `.flagsChanged`, primit prin monitorul global
  `NSEvent` — care nu livrează nimic cât timp Accesibilitatea nu e efectiv
  activă (problema 1!) și poate rata ridicarea tastei când focusul trece la
  altă aplicație. Un singur eveniment pierdut = mod blocat pornit la
  nesfârșit. Corpul lui `.flagsChanged` a fost extras în
  `InputMonitor.applyModifierFlags(_:)`, iar `reconcileModifierState()` — apelat
  la FIECARE cadru din `OverlayView` — citește sincron `NSEvent.modifierFlags`
  (starea reală a tastaturii, independentă de livrarea evenimentelor) și
  corectează diferența. `clearKey` e scos din reconciliere: e o acțiune, nu o
  stare — reaplicată periodic ar șterge desenele la nesfârșit.
- **Pătrățelele**: `draw(_:)` ștergea `dirtyRect`, nu `bounds`. La trecerea de
  la un element care acoperă tot ecranul (masca de spotlight) înapoi la halo,
  invalidarea redevenea parțială, iar `ctx.clear(dirtyRect)` tăia un
  dreptunghi transparent prin masca rămasă desenată — pe sub care se vedea
  desktopul. Exact efectul de „burete în Photoshop" descris. Adăugat
  `lastFrameWasFullScreen`: un cadru complet în plus după ultimul cadru „plin",
  iar ștergerea folosește `bounds` cât timp e implicat un element pe tot
  ecranul.

**Neverificabil automat, rămâne de confirmat manual de Cristi**: acordarea
efectivă a permisiunii (interacțiune fizică cu fereastra de sistem) și
comportamentul vizual al spotlight-ului la ținerea/eliberarea tastei.

### Completări specifice acestui repo, mutate din fosta Partea 1 (2026-09-18)

Păstrate verbatim. Regula generală la care se referă fiecare e în
`~/Developer/CLAUDE.md`.

**Regula 20:**

**Status acest repo (2026-08-27): IMPLEMENTAT.** `Sources/CursorPro/
SelfUpdater.swift` (nou, port 1:1 din `GDCVault`/`DataMover`/
`CGConvertor`) — `UpdateChecker.swift` citește URL-ul asset-ului
`CursorProGDC.pkg` din `assets[]`. Include o fereastră minimală de
progres proprie (`UpdateProgressWindow`, `window.level = .floating`) —
necesară explicit aici: CursorPro e `LSUIElement` (menu-bar-only, fără
Dock icon), fără ea userul n-ar vedea NIMIC cât timp update-ul se
descarcă/instalează. Versiune → `1.0.4`. **WARNING nemodificat**: pasul
de instalare (promptul de parolă admin) nu poate fi verificat automat —
necesită confirmare manuală, o dată, de Cristi.

**[CORECTAT 2026-09-04]** Afirmația "doar aplicație Mac, fără client
Windows" de mai sus NU mai e adevărată — vezi
`~/Developer/CursorProWin` (`gordasgdc/cursorpro-gdc-win`, repo nou,
public), primul schelet (tray icon + Licență) portat 1:1. Self-Updater-ul
de mai sus rămâne NEPORTAT încă pe Windows — vezi `CHANGELOG.md` din acel
repo pentru lista completă TODO paritate.

**Regula 21:**

**Status acest repo (2026-08-28, verificat): NU SE APLICA.** Auditat la cererea lui Cristi — CursorPro nu proceseaza fisiere mari (personalizare cursor, resurse mici, fara transfer/copiere de date in bloc). Regula 21 ramane relevanta doar daca se adauga vreodata o functie de import/export de fisiere mari.
