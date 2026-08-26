# Genereaza Instructiuni-CursorProGDC.pdf, RO/EN/ES, cu reportlab.
# Foloseste Arial (nu Helvetica standard-14) pentru diacriticele romanesti.
#
# AUDIT 2026-08-26: PDF-ul anterior (fara acest script, generat manual)
# era invechit si gresit pe 2 puncte reale, corectate aici:
# 1. Spunea ca aplicatia NU e semnata Apple si cerea click-dreapta ->
#    Deschide (bypass Gatekeeper) - FALS, aplicatia e semnata + notarizata
#    + stapled de mult (vezi CLAUDE.md, sectiunea "[ÎNVECHIT]" despre
#    eliminarea launcher-ului de bypass) - instalarea e directa, fara
#    avertismente.
# 2. Folosea "cumperi"/"cumpara" pentru cei 9 EUR - inlocuit cu formularea
#    de donatie (vezi CLAUDE.md Partea 1, Regula 3 - fara "pret"/
#    "cumpara"/"vanzare").
# Era si monolingv (doar RO) - acum RO/EN/ES, ca tot ecosistemul GDC.
#
# Ruleaza cu: python3 installer/generate_pdf.py
import os
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import SimpleDocTemplate, Paragraph, ListFlowable, ListItem, PageBreak

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Instructiuni-CursorProGDC.pdf")

pdfmetrics.registerFont(TTFont("Arial", "/System/Library/Fonts/Supplemental/Arial.ttf"))
pdfmetrics.registerFont(TTFont("Arial-Bold", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"))
styles = getSampleStyleSheet()
ACCENT = colors.HexColor("#B96A1E")
MUTED = colors.HexColor("#6a6a6a")
NOTE_BG = colors.HexColor("#FBF1E6")

title_style = ParagraphStyle("Title", parent=styles["Title"], fontName="Arial-Bold", fontSize=19, spaceAfter=2, textColor=colors.HexColor("#1a1a1a"))
subtitle_style = ParagraphStyle("Subtitle", parent=styles["Normal"], fontName="Arial", fontSize=11, textColor=MUTED, spaceAfter=20)
h2_style = ParagraphStyle("H2", parent=styles["Heading2"], fontName="Arial-Bold", fontSize=13, textColor=ACCENT, spaceBefore=16, spaceAfter=6)
body_style = ParagraphStyle("Body", parent=styles["Normal"], fontName="Arial", fontSize=10.5, leading=15, textColor=colors.HexColor("#1a1a1a"), spaceAfter=6)
step_style = ParagraphStyle("Step", parent=body_style, leftIndent=4, spaceAfter=5)
note_style = ParagraphStyle("Note", parent=body_style, backColor=NOTE_BG, leftIndent=10, fontSize=10)
footer_style = ParagraphStyle("Footer", parent=styles["Normal"], fontName="Arial", fontSize=8.5, textColor=colors.HexColor("#8a8a8a"), spaceBefore=20)


def numbered(items):
    return ListFlowable(
        [ListItem(Paragraph(it, step_style), leftIndent=16) for it in items],
        bulletType="1", start="1", leftIndent=16, spaceBefore=2, spaceAfter=8,
    )


def note(text):
    return Paragraph(text, note_style)


def page(d):
    flow = [Paragraph("CursorPro GDC", title_style), Paragraph(d["subtitle"], subtitle_style)]
    for h, body in d["sections"]:
        flow.append(Paragraph(h, h2_style))
        if isinstance(body, list):
            flow.append(numbered(body))
        elif isinstance(body, tuple):
            flow.append(note(body[0]))
        else:
            flow.append(Paragraph(body, body_style))
    flow.append(Paragraph("CursorPro GDC — github.com/gordasgdc/cursorpro-gdc", footer_style))
    return flow


RO = dict(
    subtitle="Instrucțiuni de instalare și utilizare — Română",
    sections=[
        ("1. Instalare", [
            "Descarcă fișierul <b>CursorProGDC.pkg</b> de pe pagina de descărcare sau din secțiunea Releases de pe GitHub.",
            "Dublu-click pe <b>CursorProGDC.pkg</b> — pachet semnat și notarizat oficial de Apple, se instalează direct, fără avertismente Gatekeeper și fără să confirmi nimic manual.",
            "Urmează pașii instalatorului. Va trebui să accepți Termenii și Condițiile pentru a continua. Aplicația se instalează automat în folderul Applications.",
        ]),
        ("2. Prima pornire și permisiunile", [
            "La prima deschidere, CursorPro GDC are nevoie de două permisiuni din System Settings → Privacy & Security: <b>Accessibility</b> (ca să urmărească mouse-ul și tastele apăsate global) și <b>Screen Recording</b> (doar pentru funcția Zoom, ca să poată mări zona din jurul cursorului).",
            "Important: după ce acorzi o permisiune, închide complet aplicația (click-dreapta pe iconița din bara de sus → Închide CursorPro GDC) și redeschide-o din Applications — macOS nu aplică o permisiune nou-acordată unei aplicații deja pornite.",
            "CursorPro GDC nu înregistrează, stochează sau trimite nimic din ce vezi pe ecran — tot ce ține de Zoom se procesează local și dispare imediat ce eliberezi tasta.",
        ]),
        ("3. Folosire rapidă", "Toate modurile se activează ținând apăsată o tastă (reconfigurabil din Preferințe): <b>Halo cursor</b> (comutator permanent din meniu), <b>Spotlight</b> (implicit Control), <b>Desen</b> (implicit Option, 4 unelte), <b>Zoom</b> (implicit Shift, nivel de mărire 2x–6x reglabil din Preferințe)."),
        ("4. Trial și activare", [
            "Aplicația funcționează complet, fără restricții, timp de <b>3 zile</b> de la prima pornire. După aceea, funcțiile principale se opresc automat până activezi o licență.",
            "Deschide Preferințe → Licență. Acolo vezi ID-ul unic al calculatorului tău.",
            "Apasă „Scrie-mi pe WhatsApp pentru licență” — mesajul include automat ID-ul tău.",
            "După ce primești codul de licență, lipește-l în câmpul dedicat și apasă Activează.",
        ]),
        ("", ("<b>Donație:</b> 9 € — susține continuarea dezvoltării aplicației, o singură dată, fără abonament. Nu e o vânzare — activarea se face manual, prin WhatsApp, pe baza donației.",)),
        ("5. Actualizări", "Din meniul CursorPro GDC (bara de sus) → „Caută actualizări…” — verifică dacă există o versiune mai nouă și te duce direct la pagina de descărcare dacă da."),
        ("6. Suport", "Pentru orice întrebare, scrie-mi pe WhatsApp (buton în Preferințe → Licență) sau deschide un Issue pe GitHub."),
    ],
)

EN = dict(
    subtitle="Installation and usage instructions — English",
    sections=[
        ("1. Installation", [
            "Download <b>CursorProGDC.pkg</b> from the download page or the GitHub Releases section.",
            "Double-click <b>CursorProGDC.pkg</b> — a package officially signed and notarized by Apple, installs directly, no Gatekeeper warnings and nothing to confirm manually.",
            "Follow the installer steps. You'll need to accept the Terms and Conditions to continue. The app installs automatically into the Applications folder.",
        ]),
        ("2. First launch and permissions", [
            "On first launch, CursorPro GDC needs two permissions from System Settings → Privacy & Security: <b>Accessibility</b> (to track the mouse and pressed keys globally) and <b>Screen Recording</b> (only for the Zoom feature, to magnify the area around the cursor).",
            "Important: after granting a permission, fully quit the app (right-click the menu bar icon → Quit CursorPro GDC) and reopen it from Applications — macOS doesn't apply a newly granted permission to an already-running app.",
            "CursorPro GDC never records, stores, or sends anything you see on screen — everything related to Zoom is processed locally and disappears the instant you release the key.",
        ]),
        ("3. Quick usage", "Every mode activates by holding a key (reconfigurable in Preferences): <b>Cursor Halo</b> (permanent toggle from the menu), <b>Spotlight</b> (default Control), <b>Draw</b> (default Option, 4 tools), <b>Zoom</b> (default Shift, 2x–6x magnification adjustable in Preferences)."),
        ("4. Trial and activation", [
            "The app works fully, with no restrictions, for <b>3 days</b> from first launch. After that, the main features stop automatically until you activate a license.",
            "Open Preferences → License. There you'll see your computer's unique ID.",
            "Tap \"Message me on WhatsApp for a license\" — the message automatically includes your ID.",
            "Once you receive the license code, paste it into the field and tap Activate.",
        ]),
        ("", ("<b>A donation, not a list price:</b> €9 — supports ongoing development, one-time, no subscription. Not a sale — activation happens manually, over WhatsApp, based on the donation.",)),
        ("5. Updates", "From the CursorPro GDC menu (top bar) → \"Check for Updates…\" — checks whether a newer version exists and takes you straight to the download page if so."),
        ("6. Support", "For any question, message me on WhatsApp (button in Preferences → License) or open an Issue on GitHub."),
    ],
)

ES = dict(
    subtitle="Instrucciones de instalación y uso — Español",
    sections=[
        ("1. Instalación", [
            "Descarga <b>CursorProGDC.pkg</b> desde la página de descarga o la sección Releases de GitHub.",
            "Doble clic en <b>CursorProGDC.pkg</b> — paquete firmado y notarizado oficialmente por Apple, se instala directamente, sin avisos de Gatekeeper y sin confirmar nada manualmente.",
            "Sigue los pasos del instalador. Deberás aceptar los Términos y Condiciones para continuar. La app se instala automáticamente en la carpeta Aplicaciones.",
        ]),
        ("2. Primer inicio y permisos", [
            "En el primer inicio, CursorPro GDC necesita dos permisos en System Settings → Privacy & Security: <b>Accessibility</b> (para rastrear el ratón y las teclas pulsadas globalmente) y <b>Screen Recording</b> (solo para la función Zoom, para ampliar el área alrededor del cursor).",
            "Importante: después de conceder un permiso, cierra completamente la app (clic derecho en el icono de la barra superior → Salir de CursorPro GDC) y vuelve a abrirla desde Aplicaciones — macOS no aplica un permiso recién concedido a una app ya en ejecución.",
            "CursorPro GDC nunca graba, almacena ni envía nada de lo que ves en pantalla — todo lo relacionado con Zoom se procesa localmente y desaparece en cuanto sueltas la tecla.",
        ]),
        ("3. Uso rápido", "Cada modo se activa manteniendo pulsada una tecla (reconfigurable en Preferencias): <b>Halo del cursor</b> (interruptor permanente desde el menú), <b>Spotlight</b> (por defecto Control), <b>Dibujo</b> (por defecto Option, 4 herramientas), <b>Zoom</b> (por defecto Shift, ampliación 2x–6x ajustable en Preferencias)."),
        ("4. Prueba y activación", [
            "La app funciona completamente, sin restricciones, durante <b>3 días</b> desde el primer inicio. Después, las funciones principales se detienen automáticamente hasta que actives una licencia.",
            "Abre Preferencias → Licencia. Allí verás el ID único de tu ordenador.",
            "Pulsa «Escríbeme por WhatsApp para la licencia» — el mensaje incluye automáticamente tu ID.",
            "Cuando recibas el código de licencia, pégalo en el campo correspondiente y pulsa Activar.",
        ]),
        ("", ("<b>Una donación, no un precio de lista:</b> 9 € — apoya el desarrollo continuo, una sola vez, sin suscripción. No es una venta — la activación se hace manualmente, por WhatsApp, en base a la donación.",)),
        ("5. Actualizaciones", "Desde el menú CursorPro GDC (barra superior) → «Buscar actualizaciones…» — comprueba si existe una versión más nueva y te lleva directamente a la página de descarga si la hay."),
        ("6. Soporte", "Para cualquier pregunta, escríbeme por WhatsApp (botón en Preferencias → Licencia) o abre un Issue en GitHub."),
    ],
)

doc = SimpleDocTemplate(OUT, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm, topMargin=2.2 * cm, bottomMargin=2.2 * cm)
story = []
for i, lang in enumerate([RO, EN, ES]):
    story.extend(page(lang))
    if i < 2:
        story.append(PageBreak())
doc.build(story)
print("wrote", OUT)
