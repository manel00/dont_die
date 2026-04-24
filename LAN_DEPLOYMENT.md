# Instrucciones de Despliegue LAN - BioDeath Arena

## Cómo exportar el juego

1. Abre Godot 4.6
2. Ve a **Project > Export**
3. Selecciona el preset **"Windows"**
4. Clic en **"Export Project"**
5. Guarda en la carpeta `export/` como `Zombies3D-Windows.exe`

## Cómo jugar en LAN

### En el PC del HOST (servidor):

1. Ejecuta `Zombies3D-Windows.exe`
2. En el menú principal verás tu **HOST IP** (ej: 192.168.1.100)
3. Selecciona el mapa y modo de enemigos
4. Clic en **"⚡ HOST LAN"**
5. **ImportANTE**: Si tienes Windows Firewall, permite el acceso cuando lo pida

### En los PCs de los CLIENTES:

1. Copia `Zombies3D-Windows.exe` al otro PC
2. Ejecuta el juego
3. Tienes dos opciones:

**Opción A - Buscar automáticamente:**
- Clic en **"🔍 BUSCAR PARTIDAS"**
- El juego encontrará servidores en la red
- Selecciona el servidor encontrado
- Clic en **"🌐 JOIN LAN"**

**Opción B - Manual:**
- Pide al host la IP que aparece en su pantalla
- Escribe la IP en el campo de texto
- Clic en **"🌐 JOIN LAN"**

## Solución de problemas

### "NO GAMES FOUND"
- El host debe tener el puerto **8910** abierto en el firewall
- Verifica que estén en la misma red (mismo router)

### "CONNECTION FAILED"
- Verifica la IP del host sea correcta
- Desactiva temporalmente el antivirus/firewall en ambos PCs

### El juego no responde
- Cierra y reinicia ambos juegos
- El host debe iniciar primero y esperar a que aparezcan los clientes
