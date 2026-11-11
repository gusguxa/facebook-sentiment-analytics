import os
import time
from dotenv import load_dotenv
from playwright.sync_api import sync_playwright

load_dotenv(override=True)
email = (os.getenv('FB_EMAIL') or '').strip()
password = (os.getenv('FB_PASSWORD') or '').strip()

ruta_sesion = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'fb_sesion_activa.json')

print("Iniciando navegador Chromium...")
with sync_playwright() as p:
    browser = p.chromium.launch(
        headless=False,
        args=['--disable-blink-features=AutomationControlled', '--start-maximized']
    )
    context = browser.new_context(
        locale='es-MX',
        viewport=None,
        no_viewport=True
    )
    page = context.new_page()

    page.goto('https://www.facebook.com/')

    if email and password:
        try:
            if page.locator('input[name="email"]').is_visible(timeout=3000):
                page.fill('input[name="email"]', email)
                page.fill('input[name="pass"]', password)
                page.press('input[name="pass"]', 'Enter')
        except Exception:
            pass

    print("\n=======================================================")
    print(">> Por favor inicia sesión en la ventana de Facebook <<")
    print(">> El sistema esperará hasta que entres al inicio.    <<")
    print("=======================================================\n")

    inicio_ts = time.time()
    # Espera hasta 10 minutos o hasta que aparezca la cookie de sesión c_user
    while time.time() - inicio_ts < 600:
        try:
            page.wait_for_timeout(1500)
            cookies = context.cookies()
            if any(c.get('name') == 'c_user' for c in cookies):
                print("Cookie de sesión 'c_user' detectada.")
                page.wait_for_timeout(3000)
                context.storage_state(path=ruta_sesion)
                print(f"¡EXITO! Archivo guardado en: {ruta_sesion}")
                break
            if page.is_closed():
                print("La ventana fue cerrada por el usuario.")
                break
        except Exception as e:
            print(f"Ventana cerrada o error: {e}")
            break

    try:
        browser.close()
    except Exception:
        pass
