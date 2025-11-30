:: filepath: /home/pablo/proyectos-nasm/run.bat
@echo off
echo Construyendo la imagen...
docker build -t pong-asm .
echo.
echo Iniciando el juego...
:: Quitamos --rm para que el contenedor persista (se puede ver en Docker Desktop despues)
docker run -it pong-asm
pause