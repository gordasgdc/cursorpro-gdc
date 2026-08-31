# Changelog — CursorPro GDC

Jurnal scurt, orientat spre utilizator, al schimbărilor livrate clienților
— o intrare per versiune, cu dată. Complementar jurnalului tehnic detaliat
din CLAUDE.md (acolo sunt și deciziile/motivele/pitfall-urile; aici doar
rezumatul a "ce s-a schimbat", ușor de scanat rapid).

## v1.0.7 (2026-08-31) — Zoom arăta conținut din spatele propriilor ferestre

Cauza reală a problemei de mai jos (v1.0.6): lupa de Zoom excludea din
captură TOATE ferestrele aplicației, nu doar suprapunerile transparente —
deci dacă țineai Zoom chiar deasupra ferestrei de Preferințe, aceasta
devenea invizibilă pentru lupă, care arăta în schimb orice se afla în
spatele ei pe ecran. Acum se exclud strict doar suprapunerile invizibile
(Halo/Spotlight/Desen) — orice fereastră reală, inclusiv Preferințele,
rămâne vizibilă și corect mărită.

## v1.0.6 (2026-08-31) — Zoom arăta uneori conținut dintr-o zonă greșită

La mișcări rapide/mari ale mouse-ului (ex. în timpul unei prezentări),
lupa de Zoom putea afișa pentru o clipă conținut dintr-o zonă complet
diferită de poziția reală a cursorului, în loc să urmărească exact locul
unde se află mouse-ul. Reparat.

## v1.0.5 (2026-08-31) — Preț dinamic din Furnizor

Suma de donație din fereastra de Preferințe (Licență) + mesajul WhatsApp
se citește acum din `pricing.json` (Furnizor), nu mai e fixă în cod —
orice ofertă programată apare automat, fără recompilare.
