# Pong in Assembly (NASM)

This is a simple Pong game written in assembly language (NASM) for Linux x86 (32-bit).

## Requirements

- **Docker** installed on your system (Windows, macOS, or Linux).

## How to Run the Game (Easy Way)

We have included scripts to make execution easier without needing to type long commands.

### On Windows
Simply double-click the `run.bat` file or run it from the terminal:
```cmd
.\run.bat
```

### On Linux / macOS
Grant execution permissions to the script and run it:
```bash
chmod +x run.sh
./run.sh
```

---

## Manual Execution with Docker

If you prefer to do it manually:

1. **Build the image:**
   ```bash
   docker build -t pong-asm .
   ```

2. **Run the game:**
   It is **mandatory** to use the `-it` flag to enable keyboard input.
   ```bash
   docker run -it pong-asm
   ```
   *(Note: We have removed the `--rm` flag, so the container will remain stopped in your Docker list after playing).*

## FAQ

**Can I click the "Run" button in Docker Desktop?**
No, not directly. The game needs an interactive terminal to read key presses (W, S, Q). Docker Desktop runs containers in the background without keyboard input by default. You must use the provided scripts or the terminal.

## Controls

- **W**: Move paddle up.
- **S**: Move paddle down.
- **Q**: Quit the game.
- **SPACE**: Start the game from the main menu.